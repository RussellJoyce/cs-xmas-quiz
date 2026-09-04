#!/usr/bin/env node
'use strict';

/*
Drives the LED simulator without the Swift app.

Starts the node server's websocket listeners on the ports from nodeserver/config.json,
then connects to the quiz software port and sends 'le' commands, exactly as Quiz Server
does. ledsim connects to the LED port at the other end, so the whole chain is exercised:

    drive.js --> node server --> ledsim

Usage:
    node drive.js                 run the demo sequence, looping
    node drive.js a01 b03 r050    send those commands (without the 'le' prefix) and exit
    node drive.js --server-only   just run the server, and type commands on stdin
*/

const path = require('path');
const NODESERVER = path.join(__dirname, '..', '..', 'nodeserver');
const { startWebsocketServers } = require(path.join(NODESERVER, 'server.js'));
const WebSocket = require(path.join(NODESERVER, 'node_modules', 'ws'));
const cfg = require(path.join(NODESERVER, 'config.json'));

//A canned tour of the protocol. [command, milliseconds to hold it for]
const DEMO = [
    ['a01', 4000],   //Megamas, the idle animation
    ['t03', 1500],   //Solid team 3 colour
    ['c255000000', 1000],
    ['c000255000', 1000],
    ['c000000255', 1000],
    ['p01', 1500],   //Pulse red
    ['p02', 1500],   //Pulse green
    ['b00', 2500],   //Buzz, cycling through the buzzer animations
    ['b01', 2500],
    ['b02', 2500],
    ['b03', 2500],
    ['b04', 2500],
    ['b05', 2500],
    ['q05', 1500],   //Team pulse
    ['a02', 3000],   //Timer twinkle
    ['r000', 300],   //Counter winding up
    ['r050', 300],
    ['r100', 300],
    ['r150', 300],
    ['r199', 1500],
    ['a00', 1000]    //Off
];

const args = process.argv.slice(2);
const serverOnly = args.includes('--server-only');
const oneShot = args.filter(a => !a.startsWith('--'));

const handle = startWebsocketServers({
    certs: null,
    clientWsPort: cfg.ports.clientWs,
    serverPort: cfg.ports.server,
    ledsPort: cfg.ports.leds,
    bindAddress: '127.0.0.1',
    wsBindAddress: '127.0.0.1',
    numTeams: cfg.numTeams
});

handle.ready().then(() => {
    const ports = handle.ports();
    console.log('LED controllers: ws://127.0.0.1:' + ports.leds + '/');

    const quiz = new WebSocket('ws://127.0.0.1:' + ports.server + '/');
    quiz.on('error', err => { console.error('driver: ' + err.message); process.exit(1); });
    quiz.on('open', () => {
        const send = c => { console.log('-> ' + c); quiz.send('le' + c); };

        if(oneShot.length) {
            oneShot.forEach(send);
            setTimeout(() => process.exit(0), 500);
            return;
        }
        if(serverOnly) {
            console.log("type a command (without 'le') and press return, ctrl-C to quit");
            process.stdin.setEncoding('utf8');
            process.stdin.on('data', d => d.split('\n').map(s => s.trim()).filter(Boolean).forEach(send));
            return;
        }

        //Walk the demo sequence, looping forever.
        let i = 0;
        const step = () => {
            const [command, hold] = DEMO[i % DEMO.length];
            send(command);
            i++;
            setTimeout(step, hold);
        };
        step();
    });
});
