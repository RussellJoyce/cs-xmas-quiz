'use strict';

//The quiz protocol, with no networking in it.
//Everything here works against a `transport` object supplied by the caller
//
//    transport.toClients(message)   broadcast to every connected buzzer client
//    transport.toServers(message)   send to the quiz software
//    transport.toLeds(message)      send to the LED controllers
//
//server.js wires those to the real WebSocket servers and the tests just use arrays

const WebSocket = require('ws');
const log = require('./log');

const DEFAULT_VIEW = "buzzer";
const DEFAULT_GEO_IMAGE = "start.jpg";
const DEFAULT_NUM_TEAMS = 14;
const ACTIVE_WINDOW_MS = 10000; //Clients ping every 5s, so this tolerates one missed ping.

//Send to one socket, tolerating sockets that are closing or already dead.
function safeSend(sock, message) {
    if(!sock || sock.readyState != WebSocket.OPEN) {
        return;
    }
    try {
        sock.send(message);
    } catch(err) {
        log.error('srv', null, null, "send failed (" + err.message + ") for '" + message + "'");
    }
}

//ws 7 gives us messages as strings, but ws 8 and later hand over Buffers
//Thanks Javascript - Thavascript.
function asText(message) {
    if(typeof message === 'string') return message;
    if(message === null || message === undefined) return '';
    return String(message); //Buffer.toString() decodes as utf8, which is what a text frame is
}

//Clients are identified by their IP address (meaning multiple browsers on the same device
//are the same "button"), optionally qualified by a `vcid` query parameter so that the test
//harnesses can run many independent clients from one machine.
function clientKey(ip, vcid) {
    return vcid ? ip + '_' + vcid : ip;
}

//The key for a client that has just connected.
//Normally IP, but if the test harness is connecting it can supply a `vcid` query parameter to distinguish
function clientKeyForConnection(ip, url, allowVcid) {
    if(!allowVcid) return clientKey(ip, null);
    let vcid = null;
    try {
        vcid = new URL(url || '/', 'http://localhost').searchParams.get('vcid');
    } catch(err) {
        vcid = null;
    }
    return clientKey(ip, vcid);
}

//Returns the canonical team id for a 'pt' payload, or null if it is not a real team.
function validTeam(payload, numTeams) {
    if(!/^[0-9]+$/.test(payload)) return null;
    const n = parseInt(payload, 10);
    if(n < 1 || n > numTeams) return null;
    return String(n);
}

class QuizState {
    constructor(transport, options) {
        this.transport = transport;
        this.numTeams = (options && options.numTeams) || DEFAULT_NUM_TEAMS;
        this.clients = {};
        this.lastView = DEFAULT_VIEW;
        this.lastGeoImage = DEFAULT_GEO_IMAGE;
        //Short handles for the log. 
        this.nextHandle = 1;
    }

    //What a client is called in the log: its team once it has one, its handle before that.
    labelOf(client) {
        if(!client) return '?';
        return client.id != null ? 'T' + client.id : client.handle;
    }

    label(key) {
        return this.labelOf(this.clients[key]);
    }

    getClientByID(id) {
        for(var c in this.clients) {
            if(this.clients[c].hasOwnProperty("id")) {
                if(this.clients[c].id == id) {
                    return this.clients[c];
                }
            }
        }
        return null;
    }

    //NOTE: clients are deliberately never removed. Entries in `clients` outlive their socket
    //so that a team's identity survives a phone sleeping, wifi dropping, or the browser being
    //backgrounded: when the same client reconnects it is recognised here and put straight back
    //into its team and the current view. 
    //A team stays claimed until the quiz software releases it with 'di'.
    addClient(key, sock) {
        if(this.clients.hasOwnProperty(key) && this.clients[key].id != null) {
            //Client already connected before, so has an ID, but this is a different socket.
            const client = this.clients[key];
            log.info(this.labelOf(client), null, null, 'reconnected as ' + client.handle + ', back to view ' + this.lastView);
            client.sock = sock;
            safeSend(sock, 'vi' + this.lastView); //Forward them to the current view
            safeSend(sock, 'im' + this.lastGeoImage); //Set the geography image
        } else {
            const known = this.clients[key];
            const handle = (known && known.handle) || ('c' + this.nextHandle++);
            log.info(handle, null, null,
                     (known ? 'reconnected without a team' : 'new client') +
                     ' (' + key + '), sent to the team picker');
            this.clients[key] = {id: null, sock: sock, handle: handle};
            //The unrecognised client is forwarded to the "select team" view for them to pick who they are
            safeSend(sock, 'vipickteam');
        }
    }

    //Messages from the quiz software to the clients
    handleServerMessage(raw) {
        const message = asText(raw);
        try {
            if(message.length >= 2) { //All valid messages are 2 or more characters long
                switch(message.slice(0,2)) {
                    case "on": //Activate buzzer
                    case "of": //Deactivate buzzer
                    case "hh": //Emphasise higher
                    case "hl": //Emphasise lower
                    case "hn": { //Deemphasise higher and lower
                        const code = message.slice(0,2);
                        const id = parseInt(message.slice(2)); //Teams are 1-based, so 0/NaN are both invalid
                        if(id) {
                            const c = this.getClientByID(id);
                            if(c) {
                                log.info('quiz', 'T' + id, code, log.describe(code));
                                safeSend(c.sock, code);
                            } else {
                                log.debug('quiz', 'T' + id, code, 'dropped, team not connected');
                            }
                        } else {
                            log.warn('quiz', 'all', code, "no such team in '" + message + "', ignored");
                        }
                        break;
                    }
                    case "le": //Set LED function
                        log.info('quiz', 'leds', 'le', message.slice(2));
                        this.transport.toLeds(message.slice(2));
                        break;
                    case "di": { //Disconnect client
                        const team = parseInt(message.slice(2)); //Teams are 1-based, so 0/NaN are both invalid
                        const c = team ? this.getClientByID(team) : null;
                        if(!team) {
                            log.warn('quiz', 'all', 'di', "no such team in '" + message + "', ignored");
                        } else if(c) {
                            log.info('quiz', 'T' + team, 'di',
                                     'released ' + c.handle + ', back to the team picker');
                            safeSend(c.sock, "vipickteam");
                            c.id = null;
                        } else {
                            log.debug('quiz', 'T' + team, 'di', 'nothing to release, team not held');
                        }
                        break;
                    }
                    case "vi": //Set view
                        this.lastView = message.slice(2);
                        log.info('quiz', 'all', 'vi', 'view → ' + this.lastView);
                        this.transport.toClients(message);
                        break;
                    case "im": //Set geography image
                        this.lastGeoImage = message.slice(2);
                        log.info('quiz', 'all', 'im', 'image → ' + this.lastGeoImage);
                        this.transport.toClients(message);
                        break;
                    case "ls": { //List clients
                        //Only recently-active clients that have actually claimed a team.
                        //Without the id check, clients sat on the team picker emit nulls into the list.
                        const active = Object.values(this.clients).filter(c => c.id != null && c.timestamp > (Date.now() - ACTIVE_WINDOW_MS));
                        const idList = active.map(c => c.id).join(",");
                        //The quiz software polls this constantly. It contains who is actually alive.
                        log.debug('srv', 'quiz', 'lr', active.length + ' teams active: ' + (idList || 'none'));
                        this.transport.toServers("lr" + idList);
                        break;
                    }
                    case "h1": //Label higher/lower
                    case "h2": //Label true/false
                        log.info('quiz', 'all', message.slice(0,2), log.describe(message.slice(0,2)));
                        this.transport.toClients(message.slice(0,2));
                        break;
                    case "ha": //Reset all higher/lowers
                        log.info('quiz', 'all', 'ha', log.describe('ha'));
                        this.transport.toClients("hn");
                        break;
                    default:
                        //Every message the quiz software sends has a case above, so anything
                        //here is a typo or a version mismatch.
                        log.warn('quiz', 'all', message.slice(0,2), 'dropped, ' + log.describe(message));
                        break;
                }
            }
        } catch(err) {
            log.error('quiz', 'srv', message.slice(0,2), 'failed handling message from the quiz software: ' + err.message);
        }
    }

    //Messages from the clients to the quiz software
    handleClientMessage(key, sock, raw) {
        const message = asText(raw);
        try {
            if(message.length >= 2) {
                //Maintain client timestamp to track activity
                this.clients[key].timestamp = Date.now();

                //If the client has not yet picked a valid team, we only listen for the 'pt' message
                if(this.clients[key].id == null) {
                    if(message.slice(0,2) == "pt") {
                        const who = this.label(key);
                        const asked = message.slice(2);
                        const teampick = validTeam(asked, this.numTeams);
                        if(teampick == null) {
                            log.warn(who, 'srv', 'pt', "asked for team '" + asked + "', which does not exist — refused");
                            safeSend(sock, "px");
                        } else if(this.getClientByID(teampick) == null) {
                            log.info(who, 'srv', 'pt', 'claims team ' + teampick + ' — granted, now T' + teampick);
                            this.clients[key].id = teampick;
                            safeSend(sock, "ok" + teampick);
                            safeSend(sock, 'vi' + this.lastView);
                            safeSend(sock, 'im' + this.lastGeoImage);
                        } else {
                            const holder = this.getClientByID(teampick);
                            log.warn(who, 'srv', 'pt', 'claims team ' + teampick + ' — refused, already held by ' + holder.handle);
                            safeSend(sock, "px");
                        }
                    } else {
                        log.debug(this.label(key), 'srv', message.slice(0,2),
                                  'ignored, this client has not picked a team yet');
                    }
                } else {
                    const who = this.label(key);
                    switch(message.slice(0,2)) {
                        case "re": //Client wants an ID
                            log.debug(who, 'srv', 're', 'resume, told team ' + this.clients[key].id);
                            safeSend(sock, 'ok' + this.clients[key].id);
                            break;
                        case "pi": //Ping from client
                            log.debug(who, 'srv', 'pi', 'ping');
                            safeSend(sock, "pb");
                            break;
                        case "pt": { //A client picking a team it already holds.
                            const teampick = validTeam(message.slice(2), this.numTeams);
                            if(teampick !== null && teampick === this.clients[key].id) {
                                log.debug(who, 'srv', 'pt', 'confirms team ' + teampick);
                                safeSend(sock, "ok" + this.clients[key].id);
                            } else {
                                //Asking for a different team while already holding one.
                                log.warn(who, 'srv', 'pt',
                                         "cannot move to team '" + message.slice(2) + "' while holding team " +
                                         this.clients[key].id + " — refused");
                                safeSend(sock, "px");
                            }
                            break;
                        }
                        case "zz": //Buzz
                        case "hi": //Higher, or true
                        case "lo": //Lower, or false
                        case "tt": //Text answer
                        case "wv": //Wavelength slider guess
                        case "ii": { //Map guess
                            //Check that the claimed team is actually the one that the client holds
                            const code = message.slice(0,2);
                            const named = message.slice(2).split(",")[0];
                            if(validTeam(named, this.numTeams) === this.clients[key].id) {
                                log.info(who, 'quiz', code, log.describe(message));
                                this.transport.toServers(message);
                            } else {
                                log.warn(who, 'srv', code, "dropped, answered as team '" + named + "'");
                            }
                            break;
                        }
                        default:
                            //Unrecognised message from a client. Dropped.
                            log.warn(who, 'srv', message.slice(0,2), 'dropped, ' + log.describe(message));
                            break;
                    }
                }
            }
        } catch(err) {
            log.error(this.label(key), 'srv', message.slice(0,2), 'failed handling message from client: ' + err.message);
        }
    }
}

module.exports = {
    QuizState,
    safeSend,
    clientKey,
    clientKeyForConnection,
    asText,
    validTeam,
    DEFAULT_NUM_TEAMS,
    DEFAULT_VIEW,
    DEFAULT_GEO_IMAGE,
    ACTIVE_WINDOW_MS
};
