'use strict';

//Shared fakes for the protocol tests.

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
    const real = console.log;
    console.log = () => {};
    return () => { console.log = real; };
}

module.exports = { FakeSocket, recordingTransport, muteLogs, OPEN, CLOSED };
