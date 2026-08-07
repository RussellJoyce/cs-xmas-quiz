'use strict';

const WebSocket = require('ws');
const WebSocketServer = WebSocket.Server;
const fs = require('fs');
const https = require('https');
const express = require('express');
const dns = require('native-dns');

var clients = {};

var lastView = "buzzer";
var lastGeoImage = "start.jpg";

//DNS record
const dnshostname = 'christmasquiz.win';
const hostaddress = '192.168.1.2';

//Certificates for SSL
const certkey = 'certs/live/' + dnshostname + '/privkey.pem';
const certchain = 'certs/live/' + dnshostname + '/fullchain.pem';

const wclientHttpsServer = https.createServer({
    key: fs.readFileSync(certkey, 'utf8'),
    cert: fs.readFileSync(certchain, 'utf8')
});
const wclient = new WebSocketServer({ server: wclientHttpsServer });
wclientHttpsServer.listen(8090, "0.0.0.0");

const wclientWs = new WebSocketServer({ port: 8093 }); // Plain WS for local/test clients
const wserver = new WebSocketServer({ port: 8091 });
const wleds = new WebSocketServer({ port: 8092 });

function getClientByID(id) {
    for(var c in clients) {
        if(clients[c].hasOwnProperty("id")) {
            if(clients[c].id == id) {
                return clients[c];
            }
        }
    }
    return null;
}

/*function getUnusedClientID() {
    var id = 1;
    while(getClientByID(id)) {
        id++;
    }
    return id;
}*/

//Send to one socket, tolerating sockets that are closing or already dead.
//A throw here must not abort a broadcast part-way and silently skip the rest.
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

function sendMessageToAllClients(message) {
    wclient.clients.forEach(function each(c) {
        safeSend(c, message);
    });
    wclientWs.clients.forEach(function each(c) {
        safeSend(c, message);
    });
}


wserver.on('connection', function(ws) {
    console.log("Quiz software connected")
    ws.send('connected');

    ws.on('message', function incoming(message) {
        //Messages from the quiz software to the clients
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
                            const c = getClientByID(id);
                            if(c) {
                              console.log("Sending message to client " + id + ": " + message.slice(0,2));
                              safeSend(c.sock, message.slice(0,2));
                            } //else client not connected
                        }
                        break;
                    }
                    case "le": //Set LED function
                        console.log("To LEDs: " + message);
                        wleds.clients.forEach(function each(c) {
                            safeSend(c, message.slice(2));
                        });
                        break;
                    case "di": { //Disconnect client
                        const team = parseInt(message.slice(2));
                        console.log("Disconnect request from quiz software for team " + team);
                        const c = getClientByID(team);
                        if(c) {
                            safeSend(c.sock, "vipickteam");
                            c.id = null;
                        } //else client not connected
                        break;
                    }
                    case "vi": //Set view
                        lastView = message.slice(2);
                        console.log("View change to view: " + lastView);
                        sendMessageToAllClients(message);
                        break;
                    case "im": //Set geography image
                        lastGeoImage = message.slice(2);
                        console.log("Geography image: " + lastGeoImage);
                        sendMessageToAllClients(message);
                        break;
                    case "ls": { //List clients
                        //Only recently-active clients that have actually claimed a team.
                        //Without the id check, clients sat on the team picker emit nulls into the list.
                        const idList = Object.values(clients)
                          .filter(c => c.id != null && c.timestamp > (Date.now() - 10000))
                          .map(c => c.id).join(",");
                        wserver.clients.forEach(client => {
                            safeSend(client, "lr" + idList);
                        });
                        break;
                    }
                    case "ha": //Reset all higher/lowers
                        sendMessageToAllClients("hn");
                        break;
                    default:
                        //Else just forward it on to all clients
                        console.log("To all: " + message);
                        sendMessageToAllClients(message);
                        break;
                }
            }
        } catch(err) {
            console.log("ERROR: " + err.message + " handling message from quiz software to client");
        }
    });
});

wleds.on('connection', function(ws) {
    console.log("LEDs connected")
    ws.send('a01'); //New leds are set to Megamas
    ws.on('message', function incoming(message) {
        ws.send(message);
    })
})


//NOTE: there is deliberately no 'close' handler. Entries in `clients` outlive their socket
//so that a team's identity survives a phone sleeping, wifi dropping, or the browser being
//backgrounded: when the same client reconnects it is recognised below and put straight back
//into its team and the current view. The cost is that `clients` only grows during an
//evening, and a team stays claimed until the quiz software releases it with 'di'.
function handleClientConnection(ws, req) {
    //Clients are identified by their IP address (meaning multiple browsers on the same device are the same "button")
    var ip = req.connection.remoteAddress;
    var vcid = new URL(req.url, 'http://localhost').searchParams.get('vcid');
    var client = vcid ? ip + '_' + vcid : ip;

    if(clients.hasOwnProperty(client) && clients[client].id != null) {
        //Client already connected before, so has an ID, but this is a different socket.
        console.log("Client reconnected: " + client);
        clients[client].sock = ws;
        ws.send('vi' + lastView); //Forward them to the current view
        ws.send('im' + lastGeoImage); //Set the geography image
    } else {
        //New client
        console.log("New client connected: " + client);
        clients[client] = {id: null, sock: ws};
        //The unrecognised client is forwarded to the "select team" view for them to pick who they are
        ws.send('vipickteam');
    }

    ws.on('message', function incoming(message) {
        //Messages from the clients to the quiz software
        try {
            if(message.length >= 2) {
                //Maintain client timestamp to track activity
                clients[client].timestamp = Date.now();

                //If the client has not yet picked a valid team, we only listen for the 'pt' message
                if(clients[client].id == null) {
                    if(message.slice(0,2) == "pt") {
                        const teampick = message.slice(2);
                        console.log("Client picking team " + message.slice(2));
                        if(getClientByID(teampick) == null) {
                            console.log("Team " + teampick + " assigned to client " + client)
                            clients[client].id = teampick;
                            ws.send("ok" + teampick);
                            ws.send('vi' + lastView);
                            ws.send('im' + lastGeoImage);
                        } else {
                            console.log("Team " + teampick + " is already taken by client " + client);
                            //The team is already taken so ignore it
                            ws.send("px");
                        }
                    }
                } else {
                    switch(message.slice(0,2)) {
                        case "re":
                            //Client wants an ID
                            ws.send('ok' + clients[client].id);
                            break;
                        case "pi": //ping from client
                            ws.send("pb");
                            break;
                        default:
                            //Else just forward it on
                            console.log("Client: " + message);
                            wserver.clients.forEach(function each(c) {
                                safeSend(c, message);
                            });
                            break;
                    }
                }
            }
        } catch(err) {
            console.log("ERROR: " + err.message + " handling message from client");
        }
    });
}
wclient.on('connection', handleClientConnection);
wclientWs.on('connection', handleClientConnection);

// Server to redirect HTTP requests to HTTPS
const http = express();
http.get('*', function(req, res) {
    res.redirect('https://' + req.headers.host + req.url);
});
http.listen(80, "0.0.0.0", function(){
    console.log('HTTPS redirect server running on port 80...');
});

// Actual HTTPS server
const app = express();
app.use(express.static(__dirname+'/static'));
const options = {
    key: fs.readFileSync(certkey, 'utf8'),
    cert: fs.readFileSync(certchain, 'utf8')
};
const server = https.createServer(options, app);
server.listen(443, "0.0.0.0", function(){
    console.log('Quiz Server running super securely on port 443...');
});

// DNS server because hey why not?
var dnsserver = dns.createServer();
dnsserver.on('request', function (request, response) {
    //console.log("DNS request for " + request.question[0].name)
    response.answer.push(
        dns.A({
            //name: request.question[0].name,
            name: dnshostname,
            address: hostaddress,
            ttl: 10}));
    response.send();
});
dnsserver.on('error', function (err, buff, req, res) {
    console.log(err.stack);
});
dnsserver.on('listening', function () {
    console.log("DNS server running on port 53...");
});
dnsserver.serve(53);
