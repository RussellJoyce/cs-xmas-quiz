'use strict';

//Shared fakes for the protocol tests.

const log = require('../log');

const OPEN = 1;
const CLOSED = 3;

//Stands in for a ws socket. Throws on send when not open, exactly as ws does, so that
//the safeSend guards are actually exercised rather than assumed.
class FakeSocket {
    constructor(name) {
        this.name = name || 'sock';
        this.readyState = OPEN;
        this.sent = [];
    }
    send(message) {
        if(this.readyState != OPEN) {
            throw new Error("WebSocket is not open");
        }
        this.sent.push(message);
    }
    close() { this.readyState = CLOSED; }
    //Take and clear what has been sent, which is what most assertions want.
    drain() { const s = this.sent; this.sent = []; return s; }
}

//Records what the protocol tried to send outwards.
function recordingTransport() {
    const t = {
        clients: [],
        servers: [],
        leds: [],
        toClients: m => t.clients.push(m),
        toServers: m => t.servers.push(m),
        toLeds: m => t.leds.push(m)
    };
    return t;
}

//The protocol logs a lot, which is useful in production and noise in a test run.
//Set VERBOSE=1 to see it.
function muteLogs() {
    if(process.env.VERBOSE) return () => {};
    const realSink = log.setSink(() => {});
    const realLog = console.log;      //A few third-party bits still use console directly
    console.log = () => {};
    return () => { log.setSink(realSink); console.log = realLog; };
}

//Captures the log instead of hiding it, so a test can assert on what was written.
//Returns an array of {level, line} that fills as the code under test runs, and a stop()
//that puts the previous sink back.
function captureLogs(level) {
    const lines = [];
    const wasSink = log.setSink((lvl, line) => lines.push({ level: lvl, line: line }));
    const wasLevel = log.setLevel(level || 'debug');
    const wasColour = log.setColour(false);   //Assertions should not have to strip escapes
    lines.stop = () => { log.setSink(wasSink); log.setLevel(wasLevel); log.setColour(wasColour); };
    return lines;
}

module.exports = { FakeSocket, recordingTransport, muteLogs, captureLogs, OPEN, CLOSED };
