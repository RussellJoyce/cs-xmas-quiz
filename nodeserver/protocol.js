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

const DEFAULT_VIEW = "buzzer";
const DEFAULT_GEO_IMAGE = "start.jpg";

//Teams are 1-based and there are this many of them (matching numTeams in the quiz
//software's Settings.swift). Overridable via the QuizState constructor.
const DEFAULT_NUM_TEAMS = 14;

//A client is "active" for the 'ls' listing if it has been heard from this recently.
//Clients ping every 5s, so this tolerates one missed ping.
const ACTIVE_WINDOW_MS = 10000;

//Send to one socket, tolerating sockets that are closing or already dead.
function safeSend(sock, message) {
    if(!sock || sock.readyState != WebSocket.OPEN) {
        return;
    }
    try {
        sock.send(message);
    } catch(err) {
        console.log("ERROR: " + err.message + " sending '" + message + "' to a client");
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
//harness can run many independent clients from one machine.
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
            console.log("Client reconnected: " + key);
            this.clients[key].sock = sock;
            safeSend(sock, 'vi' + this.lastView); //Forward them to the current view
            safeSend(sock, 'im' + this.lastGeoImage); //Set the geography image
        } else {
            //New client
            console.log("New client connected: " + key);
            this.clients[key] = {id: null, sock: sock};
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
                        const id = parseInt(message.slice(2)); //Teams are 1-based, so 0/NaN are both invalid
                        if(id) {
                            const c = this.getClientByID(id);
                            if(c) {
                                console.log("Sending message to client " + id + ": " + message.slice(0,2));
                                safeSend(c.sock, message.slice(0,2));
                            } //else client not connected
                        }
                        break;
                    }
                    case "le": //Set LED function
                        console.log("To LEDs: " + message);
                        this.transport.toLeds(message.slice(2));
                        break;
                    case "di": { //Disconnect client
                        const team = parseInt(message.slice(2));
                        console.log("Disconnect request from quiz software for team " + team);
                        const c = this.getClientByID(team);
                        if(c) {
                            safeSend(c.sock, "vipickteam");
                            c.id = null;
                        } //else client not connected
                        break;
                    }
                    case "vi": //Set view
                        this.lastView = message.slice(2);
                        console.log("View change to view: " + this.lastView);
                        this.transport.toClients(message);
                        break;
                    case "im": //Set geography image
                        this.lastGeoImage = message.slice(2);
                        console.log("Geography image: " + this.lastGeoImage);
                        this.transport.toClients(message);
                        break;
                    case "ls": { //List clients
                        //Only recently-active clients that have actually claimed a team.
                        //Without the id check, clients sat on the team picker emit nulls into the list.
                        const idList = Object.values(this.clients)
                          .filter(c => c.id != null && c.timestamp > (Date.now() - ACTIVE_WINDOW_MS))
                          .map(c => c.id).join(",");
                        this.transport.toServers("lr" + idList);
                        break;
                    }
                    case "ha": //Reset all higher/lowers
                        this.transport.toClients("hn");
                        break;
                    default:
                        //Else just forward it on to all clients
                        console.log("To all: " + message);
                        this.transport.toClients(message);
                        break;
                }
            }
        } catch(err) {
            console.log("ERROR: " + err.message + " handling message from quiz software to client");
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
                        const teampick = validTeam(message.slice(2), this.numTeams);
                        console.log("Client picking team " + message.slice(2));
                        if(teampick == null) {
                            //Not a team that exists. Answer with 'px' rather than staying
                            //silent so a client cannot sit waiting for a reply that will
                            //never come; the real UI only offers 1..numTeams anyway.
                            console.log("Rejected invalid team '" + message.slice(2) + "' from client " + key);
                            safeSend(sock, "px");
                        } else if(this.getClientByID(teampick) == null) {
                            console.log("Team " + teampick + " assigned to client " + key)
                            this.clients[key].id = teampick;
                            safeSend(sock, "ok" + teampick);
                            safeSend(sock, 'vi' + this.lastView);
                            safeSend(sock, 'im' + this.lastGeoImage);
                        } else {
                            console.log("Team " + teampick + " is already taken by client " + key);
                            //The team is already taken so ignore it
                            safeSend(sock, "px");
                        }
                    }
                } else {
                    switch(message.slice(0,2)) {
                        case "re":
                            //Client wants an ID
                            safeSend(sock, 'ok' + this.clients[key].id);
                            break;
                        case "pi": //ping from client
                            safeSend(sock, "pb");
                            break;
                        case "pt": {
                            //A client picking a team it already holds.
                            const teampick = validTeam(message.slice(2), this.numTeams);
                            if(teampick !== null && teampick === this.clients[key].id) {
                                safeSend(sock, "ok" + this.clients[key].id);
                            } else {
                                //Asking for a different team while already holding one.
                                console.log("Client " + key + " holds team " + this.clients[key].id + " and cannot move to '" + message.slice(2) + "'");
                                safeSend(sock, "px");
                            }
                            break;
                        }
                        default:
                            //Else just forward it on
                            console.log("Client: " + message);
                            this.transport.toServers(message);
                            break;
                    }
                }
            }
        } catch(err) {
            console.log("ERROR: " + err.message + " handling message from client");
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
