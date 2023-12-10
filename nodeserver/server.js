const WebSocketServer = require('ws').Server;
const fs = require('fs');
const https = require('https');
const express = require('express');
const dns = require('native-dns');

var clients = {};

var lastView = "buzzer";
var lastGeoImage = "start.jpg";

//Certificates for SSL
const certkey = 'certs/privkey1.pem';
const certchain = 'certs/fullchain1.pem';

//DNS record
const dnshostname = 'iangray.me.uk';
const hostaddress = '192.168.1.2';

const wclientHttpsServer = https.createServer({
    key: fs.readFileSync(certkey, 'utf8'),
    cert: fs.readFileSync(certchain, 'utf8')
});
wclient = new WebSocketServer({ server: wclientHttpsServer });
wclientHttpsServer.listen(8090, "0.0.0.0");

wserver = new WebSocketServer({ port: 8091 });
wleds = new WebSocketServer({ port: 8092 });

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

function sendMessageToAllClients(message) {
    wclient.clients.forEach(function each(c) {
        c.send(message);
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
                    case "on":
                        if(id = parseInt(message.slice(2))) {
                            if(c = getClientByID(id)) {
                                console.log("On: " + id);
                                c.sock.send("on");
                            } //else client not connected
                        }
                        break;
                    case "of":
                        if(id = parseInt(message.slice(2))) {
                            if(c = getClientByID(id)) {
                                console.log("Off: " + id);
                                c.sock.send("of");
                            } //else client not connected
                        }
                        break;
                    case "le":
                        console.log("To LEDs: " + message);
                        wleds.clients.forEach(function each(c) {
                            c.send(message.slice(2));
                        });
                        break;
                    case "di":
                        const team = parseInt(message.slice(2));
                        console.log("Disconnect request from quiz software for team " + team);
                        if(c = getClientByID(team)) {
                            c.sock.send("vipickteam");
                            c.id = null;
                        } //else client not connected
                        break;
                    case "vi":
                        lastView = message.slice(2);
                        console.log("View change to view: " + lastView);
                        sendMessageToAllClients(message);
                        break;
                    case "im":
                        lastGeoImage = message.slice(2);
                        console.log("Geography image: " + lastGeoImage);
                        sendMessageToAllClients(message);
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


wclient.on('connection', function connection(ws, req) {
    //Clients are identified by their IP address (meaning multiple browsers on the same device are the same "button")
    var client = req.connection.remoteAddress;

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
                //If the client has not yet picked a valid team, we only listen for the 'pt' message
                if(clients[client].id == null) {
                    if(message.slice(0,2) == "pt") {
                        teampick = message.slice(2);
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
                                c.send(message);
                            });
                            break;
                    }
                }
            }
        } catch(err) {
            console.log("ERROR: " + err.message + " handling message from client");
        }
    });
});

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
