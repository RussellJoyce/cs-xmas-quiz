'use strict';

//Wiring only. The protocol itself lives in protocol.js so that it can be tested without binding ports or reading certificates.

const WebSocketServer = require('ws').Server;
const fs = require('fs');
const https = require('https');
const express = require('express');
const dns = require('native-dns');
const { QuizState, safeSend, clientKey, asText } = require('./protocol');

//DNS record
const DNS_HOSTNAME = 'christmasquiz.win';
const HOST_ADDRESS = '192.168.1.2';

function defaultConfig(overrides) {
    const cfg = Object.assign({
        dnsHostname: DNS_HOSTNAME,
        hostAddress: HOST_ADDRESS,
        clientWssPort: 8090,    //Buzzer clients over TLS (what the phones use)
        clientWsPort: 8093,     //Buzzer clients over plain ws (local/test clients)
        serverPort: 8091,       //The quiz software
        ledsPort: 8092,         //The LED controllers
        httpPort: 80,
        httpsPort: 443,
        dnsPort: 53,
        staticDir: __dirname + '/static',

        //Two bind addresses
        //the https listeners are explicitly IPv4, while the bare WebSocket servers are left
        //unbound so they get a dual-stack IPv6 socket and accept IPv6 clients too.
        bindAddress: "0.0.0.0",
        wsBindAddress: undefined
    }, overrides);

    //Certificates for SSL. Pass certs: null to run without TLS (the ws-only test setup).
    if(!cfg.hasOwnProperty('certs')) {
        cfg.certs = {
            key: 'certs/live/' + cfg.dnsHostname + '/privkey.pem',
            cert: 'certs/live/' + cfg.dnsHostname + '/fullchain.pem'
        };
    }
    return cfg;
}

function readCerts(certs) {
    return {
        key: fs.readFileSync(certs.key, 'utf8'),
        cert: fs.readFileSync(certs.cert, 'utf8')
    };
}

//The four WebSocket servers plus the protocol state they share.
function startWebsocketServers(overrides) {
    const cfg = defaultConfig(overrides);

    //Buzzer clients arrive on two servers: wss for real phones, plain ws for test clients.
    let wclientHttpsServer = null;
    let wclient = null;
    if(cfg.certs) {
        wclientHttpsServer = https.createServer(readCerts(cfg.certs));
        wclient = new WebSocketServer({ server: wclientHttpsServer });
        wclientHttpsServer.listen(cfg.clientWssPort, cfg.bindAddress);
    }

    const wclientWs = new WebSocketServer({ port: cfg.clientWsPort, host: cfg.wsBindAddress });
    const wserver = new WebSocketServer({ port: cfg.serverPort, host: cfg.wsBindAddress });
    const wleds = new WebSocketServer({ port: cfg.ledsPort, host: cfg.wsBindAddress });

    const clientServers = wclient ? [wclient, wclientWs] : [wclientWs];

    const state = new QuizState({
        toClients: function(message) {
            clientServers.forEach(s => s.clients.forEach(c => safeSend(c, message)));
        },
        toServers: function(message) {
            wserver.clients.forEach(c => safeSend(c, message));
        },
        toLeds: function(message) {
            wleds.clients.forEach(c => safeSend(c, message));
        }
    });

    wserver.on('connection', function(ws) {
        console.log("Quiz software connected");
        safeSend(ws, 'connected');
        ws.on('message', message => state.handleServerMessage(message));
    });

    wleds.on('connection', function(ws) {
        console.log("LEDs connected");
        safeSend(ws, 'a01'); //New leds are set to Megamas
        //asText keeps this a text frame: echoing a Buffer straight back would send a
        //binary frame, which the ESP firmware does not expect.
        ws.on('message', message => safeSend(ws, asText(message)));
    });

    function handleClientConnection(ws, req) {
        const ip = req.connection.remoteAddress;
        const vcid = new URL(req.url, 'http://localhost').searchParams.get('vcid');
        const key = clientKey(ip, vcid);

        state.addClient(key, ws);
        ws.on('message', message => state.handleClientMessage(key, ws, message));
    }
    clientServers.forEach(s => s.on('connection', handleClientConnection));

    //listen() is asynchronous, so address() is null until the server is up. Tests that ask
    //for port 0 need to await ready() before they can find out what they actually got.
    function listening(s) {
        return new Promise(function(resolve) {
            if(s.address()) resolve(); else s.once('listening', resolve);
        });
    }

    return {
        state: state,
        servers: { wclient, wclientWs, wserver, wleds },
        ready: function() {
            const waiting = [wclientWs, wserver, wleds].map(listening);
            if(wclientHttpsServer) waiting.push(listening(wclientHttpsServer));
            return Promise.all(waiting);
        },
        ports: function() {
            return {
                clientWss: wclientHttpsServer ? wclientHttpsServer.address().port : null,
                clientWs: wclientWs.address().port,
                server: wserver.address().port,
                leds: wleds.address().port
            };
        },
        close: function(cb) {
            const closeables = [wclientWs, wserver, wleds];
            if(wclient) closeables.push(wclient);
            let remaining = closeables.length + (wclientHttpsServer ? 1 : 0);
            const done = () => { if(--remaining <= 0 && cb) cb(); };
            closeables.forEach(s => s.close(done));
            if(wclientHttpsServer) wclientHttpsServer.close(done);
        }
    };
}

//HTTP redirect to HTTPS, and the HTTPS server that serves the client web app.
function startWebServers(overrides) {
    const cfg = defaultConfig(overrides);

    const http = express();
    http.get('*', function(req, res) {
        res.redirect('https://' + req.headers.host + req.url);
    });
    http.listen(cfg.httpPort, cfg.bindAddress, function() {
        console.log('HTTPS redirect server running on port ' + cfg.httpPort + '...');
    });

    const app = express();
    app.use(express.static(cfg.staticDir));
    const server = https.createServer(readCerts(cfg.certs), app);
    server.listen(cfg.httpsPort, cfg.bindAddress, function() {
        console.log('Quiz Server running super securely on port ' + cfg.httpsPort + '...');
    });

    return { http, server };
}

// DNS server because hey why not?
function startDnsServer(overrides) {
    const cfg = defaultConfig(overrides);

    const dnsserver = dns.createServer();
    dnsserver.on('request', function (request, response) {
        //console.log("DNS request for " + request.question[0].name)
        response.answer.push(
            dns.A({
                //name: request.question[0].name,
                name: cfg.dnsHostname,
                address: cfg.hostAddress,
                ttl: 10}));
        response.send();
    });
    dnsserver.on('error', function (err, buff, req, res) {
        console.log(err.stack);
    });
    dnsserver.on('listening', function () {
        console.log("DNS server running on port " + cfg.dnsPort + "...");
    });
    dnsserver.serve(cfg.dnsPort);
    return dnsserver;
}

module.exports = { startWebsocketServers, startWebServers, startDnsServer, defaultConfig };

//Only start listening when run directly, so that tests can require this file.
if(require.main === module) {
    startWebsocketServers();
    startWebServers();
    startDnsServer();
}
