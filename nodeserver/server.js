'use strict';

//Wiring only. The protocol itself lives in protocol.js so that it can be tested without binding ports or reading certificates.

const WebSocketServer = require('ws').Server;
const fs = require('fs');
const crypto = require('crypto');
const https = require('https');
const express = require('express');
const dns = require('native-dns');
const { QuizState, safeSend, clientKeyForConnection, asText } = require('./protocol');
const log = require('./log');

//Deployment settings live in config.json
const CONFIG_FILE = __dirname + '/config.json';

//Every port the server listens on. Named here so a missing one is a startup error naming
//the key, rather than a server that quietly never listens for something.
const REQUIRED_PORTS = ['clientWss', 'clientWs', 'server', 'leds', 'http', 'https', 'dns'];

//Checks a parsed config and returns it normalised. Separate from reading the file so the
//rules can be tested against made-up configs without writing over the real one.
function validateDeploymentConfig(file, where) {
    const from = where || 'config';

    if(!file.domain) throw new Error(from + ' has no "domain"');
    if(!file.hostAddress) throw new Error(from + ' has no "hostAddress"');
    if(!file.ports) throw new Error(from + ' has no "ports"');

    const ports = {};
    REQUIRED_PORTS.forEach(function(name) {
        const value = file.ports[name];
        //0 means "let the OS choose", which the tests use. Anything else must be a real port.
        if(!Number.isInteger(value) || value < 0 || value > 65535) {
            throw new Error(from + ' needs an integer 0-65535 for ports.' + name + ', got ' + JSON.stringify(value));
        }
        ports[name] = value;
    });

    //Two servers on one port would surface as EADDRINUSE
    const takenBy = {};
    REQUIRED_PORTS.forEach(function(name) {
        const value = ports[name];
        if(value === 0) return;
        if(takenBy[value]) {
            throw new Error(from + ' uses port ' + value + ' for both "' + takenBy[value] + '" and "' + name + '"');
        }
        takenBy[value] = name;
    });

    //Must match numTeams in the quiz software's Settings.swift.
    if(!Number.isInteger(file.numTeams) || file.numTeams < 1) {
        throw new Error(from + ' needs an integer "numTeams" of at least 1, got ' + JSON.stringify(file.numTeams));
    }

    return { domain: file.domain, hostAddress: file.hostAddress, ports: ports, numTeams: file.numTeams };
}

function loadDeploymentConfig() {
    let file;
    try {
        file = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
    } catch(err) {
        throw new Error("Cannot read " + CONFIG_FILE + ": " + err.message);
    }
    //Applied before validation so an override is checked like anything else.
    if(process.env.QUIZ_DOMAIN) file.domain = process.env.QUIZ_DOMAIN;
    if(process.env.QUIZ_HOST_ADDRESS) file.hostAddress = process.env.QUIZ_HOST_ADDRESS;
    return validateDeploymentConfig(file, CONFIG_FILE);
}

function defaultConfig(overrides) {
    const deployment = loadDeploymentConfig();
    const cfg = Object.assign({
        dnsHostname: deployment.domain,
        hostAddress: deployment.hostAddress,
        clientWssPort: deployment.ports.clientWss,  //Buzzer clients over TLS (what the phones use)
        clientWsPort: deployment.ports.clientWs,    //Buzzer clients over plain ws (local/test clients)
        serverPort: deployment.ports.server,        //The quiz software
        ledsPort: deployment.ports.leds,            //The LED controllers
        httpPort: deployment.ports.http,            //Probably 80
        httpsPort: deployment.ports.https,          //Probably 443
        dnsPort: deployment.ports.dns,              //Probably 53
        staticDir: __dirname + '/static',
        numTeams: deployment.numTeams,

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


const DAY_MS = 24 * 60 * 60 * 1000;

//Reads the certificate and reports how long it has left
function certStatus(certs) {
    if(!certs) return null;
    try {
        //X509Certificate takes the leaf from a fullchain, which is the one that expires first.
        const cert = new crypto.X509Certificate(fs.readFileSync(certs.cert));
        const validTo = new Date(cert.validTo);
        if(isNaN(validTo.getTime())) return null;
        return {
            subject: cert.subject,
            validTo: validTo,
            //Positive means days left, negative means days since it expired.
            days: Math.floor((validTo.getTime() - Date.now()) / DAY_MS)
        };
    } catch(err) {
        return { error: err.message };
    }
}

function certMessages(status) {
    if(!status) return ["Certificate: not configured, so TLS is off"];
    if(status.error) return ["*** Certificate: could not be read (" + status.error + ")"];

    const when = status.validTo.toISOString().slice(0, 10);
    if(status.days < 0) {
        return ["*** CERTIFICATE EXPIRED " + (-status.days) + " days ago, on " + when, "*** Fix with:  ./renew-cert.sh"];
    }
    return ["Certificate valid for another " + status.days + " days (until " + when + ")"];
}

//Every listener announces itself in the same shape when it actually binds
function listenLine(name, port, what) {
    const column = (s, width) => (s.length >= width ? s + ' ' : s + ' '.repeat(width - s.length));
    return 'listen  ' + column(name, 6) + column(String(port), 6) + what;
}

function logCertStatus(certs) {
    const status = certStatus(certs);
    const bad = Boolean(status && (status.error || status.days < 0));
    certMessages(status).forEach(line => (bad ? log.bootError(line) : log.boot(line)));
    return status;
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
    }, { numTeams: cfg.numTeams });

    //Every socket needs an 'error' listener. `who` may be a function, so that a client is
    //named by whatever it is called at the time of the error: it may have claimed a team
    //since it connected, and the log should follow it.
    function guard(ws, who) {
        ws.on('error', function(err) {
            log.error(typeof who === 'function' ? who() : who, null, null,
                      'socket error: ' + err.message + (err.code ? ' (' + err.code + ')' : ''));
        });
    }

    wserver.on('connection', function(ws) {
        log.info('quiz', null, null, 'quiz software connected');
        guard(ws, 'quiz');
        safeSend(ws, 'connected');
        ws.on('message', message => state.handleServerMessage(message));
    });

    wleds.on('connection', function(ws) {
        log.info('leds', null, null, 'LED controller connected, set to Megamas (a01)');
        guard(ws, 'leds');
        safeSend(ws, 'a01'); //New leds are set to Megamas
        ws.on('message', message => safeSend(ws, asText(message)));
    });

    function handleClientConnection(ws, req, allowVcid) {
        const ip = req.connection.remoteAddress;
        const key = clientKeyForConnection(ip, req.url, allowVcid);

        guard(ws, () => state.label(key));
        state.addClient(key, ws);
        ws.on('message', message => state.handleClientMessage(key, ws, message));
    }
    //Only the plain ws port lets a client name itself; see clientKeyForConnection.
    clientServers.forEach(function(s) {
        s.on('connection', (ws, req) => handleClientConnection(ws, req, s === wclientWs));
    });

    function guardServer(s, what) {
        s.on('error', function(err) {
            if(err.code == 'EADDRINUSE' || err.code == 'EACCES') {
                log.bootError('FATAL: cannot listen for ' + what + ': ' + err.message);
                process.exit(1);
            }
            log.error('srv', null, null, what + ' listener: ' + err.message);
        });
    }
    //Announced from the 'listening' event rather than from the config, so the line is proof
    //that the socket bound, and so that a test asking for port 0 reports what it actually got.
    function announce(s, name, what) {
        s.on('listening', function() {
            const addr = s.address();
            log.boot(listenLine(name, addr ? addr.port : '?', what));
        });
    }
    if(wclientHttpsServer) announce(wclientHttpsServer, 'wss', 'clients over TLS');
    announce(wclientWs, 'ws', 'clients');
    announce(wserver, 'quiz', 'quiz software');
    announce(wleds, 'leds', 'LED controllers');

    guardServer(wclientWs, "plain ws clients");
    guardServer(wserver, "the quiz software");
    guardServer(wleds, "the LEDs");
    if(wclient) guardServer(wclient, "wss clients");
    if(wclientHttpsServer) guardServer(wclientHttpsServer, "the wss listener");

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
        log.boot(listenLine('http', cfg.httpPort, 'redirects everything to https'));
    });

    const app = express();
    app.use(express.static(cfg.staticDir));
    const server = https.createServer(readCerts(cfg.certs), app);
    server.listen(cfg.httpsPort, cfg.bindAddress, function() {
        log.boot(listenLine('https', cfg.httpsPort, 'the buzzer web app'));
    });

    return { http, server };
}

// DNS server because hey why not?
function startDnsServer(overrides) {
    const cfg = defaultConfig(overrides);

    const dnsserver = dns.createServer();
    dnsserver.on('request', function (request, response) {
        //Every phone joining the wifi asks, so this only appears at QUIZ_LOG=debug, where
        //it answers "is the phone even reaching us?".
        const asked = request.question && request.question[0];
        log.debug('dns', null, null, 'request for ' + (asked ? asked.name : 'nothing'));
        response.answer.push(
            dns.A({
                //name: request.question[0].name,
                name: cfg.dnsHostname,
                address: cfg.hostAddress,
                ttl: 10}));
        response.send();
    });
    dnsserver.on('error', function (err, buff, req, res) {
        log.error('srv', null, null, 'dns: ' + (err.stack || err.message));
    });
    dnsserver.on('listening', function () {
        log.boot(listenLine('dns', cfg.dnsPort, cfg.dnsHostname + ' → ' + cfg.hostAddress));
    });
    dnsserver.serve(cfg.dnsPort);
    return dnsserver;
}

module.exports = { startWebsocketServers, startWebServers, startDnsServer, defaultConfig,
                   loadDeploymentConfig, validateDeploymentConfig, REQUIRED_PORTS,
                   certStatus, certMessages, logCertStatus, CONFIG_FILE };

//Only start listening when run directly, so that tests can require this file.
if(require.main === module) {
    const cfg = defaultConfig();
    log.boot('quiz server starting...');
    log.boot('serving ' + cfg.dnsHostname + ' → ' + cfg.hostAddress + ' for ' + cfg.numTeams + ' teams');
    if(!cfg.certs) log.boot('no certificates configured, so wss is off');
    startWebsocketServers();
    startWebServers();
    startDnsServer();
    logCertStatus(cfg.certs);
}
