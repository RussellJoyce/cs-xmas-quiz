'use strict';

//End-to-end over real WebSockets on ephemeral ports. These cover the wiring that the
//protocol unit tests deliberately stub out: URL/vcid parsing, the two client servers,
//and messages actually crossing between a client and the quiz software.

const { test, describe, before, after } = require('node:test');
const assert = require('node:assert');
const WebSocket = require('ws');
const net = require('net');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const { startWebsocketServers, defaultConfig } = require('../server');
const { muteLogs } = require('./helpers');

//A ws client that buffers what it receives so a test can await messages in order.
function connect(port, query) {
    const ws = new WebSocket('ws://127.0.0.1:' + port + (query || ''));
    const received = [];
    const waiting = [];
    ws.on('message', function(data) {
        const msg = data.toString();
        const w = waiting.shift();
        if(w) w(msg); else received.push(msg);
    });
    ws.next = function(timeoutMs) {
        if(received.length) return Promise.resolve(received.shift());
        return new Promise((resolve, reject) => {
            const timer = setTimeout(() => reject(new Error('timed out waiting for a message')),
                                     timeoutMs || 2000);
            waiting.push(m => { clearTimeout(timer); resolve(m); });
        });
    };
    //Resolves once several messages have arrived, in order.
    ws.nextN = async function(n) {
        const out = [];
        for(let i = 0; i < n; i++) out.push(await ws.next());
        return out;
    };
    ws.opened = new Promise(resolve => ws.on('open', resolve));
    return ws;
}

//Nothing should arrive on this socket. Give it a moment to prove it.
function expectSilence(ws, ms) {
    return new Promise(resolve => setTimeout(resolve, ms || 150))
        .then(() => ws.next(1).then(
            m => { throw new Error('unexpected message: ' + m); },
            () => {}));
}


//Speaks the WebSocket handshake by hand so that we can then send a frame the ws library
//would never produce. Resolves once the bad frame has gone out.
function sendMalformedFrame(port, frame) {
    return new Promise(function(resolve, reject) {
        const sock = net.connect(port, '127.0.0.1', function() {
            sock.write('GET /?vcid=malformed HTTP/1.1\r\n' +
                       'Host: 127.0.0.1\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n' +
                       'Sec-WebSocket-Key: ' + crypto.randomBytes(16).toString('base64') + '\r\n' +
                       'Sec-WebSocket-Version: 13\r\n\r\n');
        });
        let done = false;
        sock.on('data', function(d) {
            if(!done && d.toString().includes(' 101 ')) {
                done = true;
                sock.write(frame);
                setTimeout(function() { sock.destroy(); resolve(); }, 150);
            }
        });
        sock.on('error', function(err) { if(!done) reject(err); });
        setTimeout(() => reject(new Error('no handshake from port ' + port)), 2000);
    });
}

//FIN + text opcode, payload length 3, MASK bit clear. RFC 6455 requires client frames to
//be masked, so ws rejects this with WS_ERR_EXPECTED_MASK and emits 'error' on the socket.
const UNMASKED_FRAME = Buffer.from([0x81, 0x03, 0x61, 0x62, 0x63]);
//Opcode 0x0b is reserved and must be rejected too.
const RESERVED_OPCODE_FRAME = Buffer.from([0x8b, 0x80, 0x00, 0x00, 0x00, 0x00]);

describe('over real sockets', () => {
    let handle, ports, unmute;

    before(async () => {
        unmute = muteLogs();
        //certs: null skips the wss server, so no certificates are needed.
        //Port 0 lets the OS pick, so a running production server is never in the way.
        handle = startWebsocketServers({
            certs: null,
            clientWsPort: 0, serverPort: 0, ledsPort: 0,
            bindAddress: '127.0.0.1', wsBindAddress: '127.0.0.1'
        });
        await handle.ready();
        ports = handle.ports();
    });

    after(async () => {
        await new Promise(resolve => handle.close(resolve));
        unmute();
    });

    test('the OS assigned real ports and no wss server was started', () => {
        assert.ok(ports.clientWs > 0);
        assert.ok(ports.server > 0);
        assert.ok(ports.leds > 0);
        assert.strictEqual(ports.clientWss, null);
    });

    test('the quiz software is greeted on connect', async () => {
        const quiz = connect(ports.server);
        assert.strictEqual(await quiz.next(), 'connected');
        quiz.close();
    });

    test('the LEDs are given a starting animation on connect', async () => {
        const leds = connect(ports.leds);
        assert.strictEqual(await leds.next(), 'a01');
        leds.close();
    });

    test('a client is sent to the team picker on connect', async () => {
        const c = connect(ports.clientWs, '/?vcid=a');
        assert.strictEqual(await c.next(), 'vipickteam');
        c.close();
    });

    test('vcid separates clients arriving from the same address', async () => {
        //Both are 127.0.0.1; only the vcid tells them apart.
        const a = connect(ports.clientWs, '/?vcid=a');
        const b = connect(ports.clientWs, '/?vcid=b');
        await a.next();
        await b.next();

        a.send('pt1');
        assert.deepStrictEqual(await a.nextN(3), ['ok1', 'vibuzzer', 'imstart.jpg']);

        //b is a different client, so it can take a different team rather than
        //inheriting a's.
        b.send('pt2');
        assert.strictEqual((await b.nextN(3))[0], 'ok2');

        a.close();
        b.close();
    });

    test('a buzz travels from a client to the quiz software', async () => {
        const quiz = connect(ports.server);
        await quiz.next();  //'connected'
        const c = connect(ports.clientWs, '/?vcid=buzzer');
        await c.next();
        c.send('pt5');
        await c.nextN(3);

        c.send('zz5');
        assert.strictEqual(await quiz.next(), 'zz5');

        quiz.close();
        c.close();
    });

    test('the quiz software can light one client and not another', async () => {
        const quiz = connect(ports.server);
        await quiz.next();
        const a = connect(ports.clientWs, '/?vcid=r1');
        const b = connect(ports.clientWs, '/?vcid=r2');
        await a.next(); await b.next();
        a.send('pt7'); await a.nextN(3);
        b.send('pt8'); await b.nextN(3);

        quiz.send('on7');
        assert.strictEqual(await a.next(), 'on');
        await expectSilence(b);

        quiz.close(); a.close(); b.close();
    });

    test('a view change reaches every connected client', async () => {
        const quiz = connect(ports.server);
        await quiz.next();
        const a = connect(ports.clientWs, '/?vcid=v1');
        const b = connect(ports.clientWs, '/?vcid=v2');
        await a.next(); await b.next();

        quiz.send('vinumbers');
        assert.strictEqual(await a.next(), 'vinumbers');
        assert.strictEqual(await b.next(), 'vinumbers');

        //And it becomes the view a later client is dropped into.
        quiz.send('di0');   //no-op, just to order the next assertion after the broadcast
        const late = connect(ports.clientWs, '/?vcid=v3');
        assert.strictEqual(await late.next(), 'vipickteam');
        late.send('pt11');
        assert.deepStrictEqual(await late.nextN(3), ['ok11', 'vinumbers', 'imstart.jpg']);

        quiz.close(); a.close(); b.close(); late.close();
        //Put the view back for any later test.
        const reset = connect(ports.server);
        await reset.next();
        reset.send('vibuzzer');
        reset.close();
    });

    test('a client that drops and returns keeps its team', async () => {
        const c = connect(ports.clientWs, '/?vcid=sleepy');
        await c.next();
        c.send('pt12');
        await c.nextN(3);

        //Phone sleeps.
        c.close();
        await new Promise(resolve => setTimeout(resolve, 100));

        //Phone wakes up and reconnects with the same identity.
        const again = connect(ports.clientWs, '/?vcid=sleepy');
        const first = await again.next();
        assert.notStrictEqual(first, 'vipickteam', 'must not be sent back to the picker');
        assert.ok(first.startsWith('vi'), 'is put back into the current view');

        again.send('re');
        await again.next();  //the 'im' that follows the view
        assert.strictEqual(await again.next(), 'ok12', 'still team 12');
        again.close();
    });

    test('ls reports the teams that are actually playing', async () => {
        const quiz = connect(ports.server);
        await quiz.next();
        const c = connect(ports.clientWs, '/?vcid=listed');
        await c.next();
        c.send('pt14');
        await c.nextN(3);

        //An idle client that connects but never picks must not appear.
        const idle = connect(ports.clientWs, '/?vcid=idle');
        await idle.next();

        quiz.send('ls');
        const list = await quiz.next();
        assert.ok(list.startsWith('lr'), 'got ' + list);
        assert.ok(list.includes('14'), 'team 14 is listed: ' + list);
        assert.ok(!list.includes('null'), 'no nulls from teamless clients: ' + list);

        quiz.close(); c.close(); idle.close();
    });

    test('LED commands are routed to the LEDs only', async () => {
        const quiz = connect(ports.server);
        await quiz.next();
        const leds = connect(ports.leds);
        await leds.next();  //'a01'
        const c = connect(ports.clientWs, '/?vcid=nonled');
        await c.next();

        quiz.send('le{"cmd":"setanimation","animation":"rainbow"}');
        assert.strictEqual(await leds.next(), '{"cmd":"setanimation","animation":"rainbow"}');
        await expectSilence(c);

        quiz.close(); leds.close(); c.close();
    });

    test('rubbish over the wire does not bring the server down', async () => {
        const quiz = connect(ports.server);
        await quiz.next();
        const c = connect(ports.clientWs, '/?vcid=junk');
        await c.next();

        ['', 'a', 'pt', 'onX', 'di', '\u{1f384}', 'x'.repeat(50000)]
            .forEach(m => { quiz.send(m); c.send(m); });

        //Still alive and serving.
        const after = connect(ports.clientWs, '/?vcid=alive');
        assert.strictEqual(await after.next(), 'vipickteam');

        quiz.close(); c.close(); after.close();
    });

    //These are the reason every socket needs an 'error' listener: Node throws on an
    //unhandled 'error' event, so before the guards a single bad frame from one phone
    //killed the process and every buzzer in the room. The server runs inside this test
    //process, so if the guard is missing these do not fail politely -- they take the
    //whole test run down, which is the point.
    test('a malformed frame from a client does not kill the server', async () => {
        await sendMalformedFrame(ports.clientWs, UNMASKED_FRAME);

        const after = connect(ports.clientWs, '/?vcid=survivor');
        assert.strictEqual(await after.next(), 'vipickteam', 'server still serving clients');
        after.close();
    });

    test('a reserved opcode from a client does not kill the server', async () => {
        await sendMalformedFrame(ports.clientWs, RESERVED_OPCODE_FRAME);

        const after = connect(ports.clientWs, '/?vcid=survivor2');
        assert.strictEqual(await after.next(), 'vipickteam');
        after.close();
    });

    test('a malformed frame on the quiz software port does not kill the server', async () => {
        await sendMalformedFrame(ports.server, UNMASKED_FRAME);

        const quiz = connect(ports.server);
        assert.strictEqual(await quiz.next(), 'connected');
        quiz.close();
    });

    test('a malformed frame on the LED port does not kill the server', async () => {
        await sendMalformedFrame(ports.leds, UNMASKED_FRAME);

        const leds = connect(ports.leds);
        assert.strictEqual(await leds.next(), 'a01');
        leds.close();
    });

    test('a client that survives a neighbour\'s bad frame keeps its team', async () => {
        //The blast radius question: one phone misbehaving must not disturb anyone else.
        const c = connect(ports.clientWs, '/?vcid=bystander');
        await c.next();
        c.send('pt13');
        await c.nextN(3);

        await sendMalformedFrame(ports.clientWs, UNMASKED_FRAME);

        c.send('re');
        assert.strictEqual(await c.next(), 'ok13');
        c.close();
    });
});


//The phones connect over wss, so the TLS path deserves one end-to-end check. The
//certificates are not in the repository, so this skips on a checkout that has none.
function certsPresent() {
    const cfg = defaultConfig();
    const dir = path.dirname(module.filename);
    return [cfg.certs.key, cfg.certs.cert]
        .every(p => fs.existsSync(path.resolve(dir, '..', p)));
}

describe('over TLS', { skip: certsPresent() ? false : 'no certificates in certs/live' }, () => {
    let handle, ports, unmute;

    before(async () => {
        unmute = muteLogs();
        //Real certificates, but an ephemeral port so a running server is not disturbed.
        handle = startWebsocketServers({
            clientWssPort: 0, clientWsPort: 0, serverPort: 0, ledsPort: 0,
            bindAddress: '127.0.0.1', wsBindAddress: '127.0.0.1'
        });
        await handle.ready();
        ports = handle.ports();
    });

    after(async () => {
        await new Promise(resolve => handle.close(resolve));
        unmute();
    });

    test('a client can join over wss and claim a team', async () => {
        //The certificate is for the configured domain, not 127.0.0.1, so skip the name
        //check. Note this also skips the expiry check, so this test passing says nothing
        //about whether the certificate is still valid -- that is cert.test.js's job.
        const ws = new WebSocket('wss://127.0.0.1:' + ports.clientWss + '/?vcid=tls',
                                 { rejectUnauthorized: false });
        const got = [];
        ws.on('message', d => got.push(d.toString()));
        await new Promise((resolve, reject) => { ws.on('open', resolve); ws.on('error', reject); });

        ws.send('pt1');
        await new Promise(resolve => setTimeout(resolve, 250));
        assert.deepStrictEqual(got, ['vipickteam', 'ok1', 'vibuzzer', 'imstart.jpg']);
        ws.close();
    });

    test('wss and plain ws clients share one set of teams', async () => {
        //Continues from the test above, which left team 1 held over wss: the server is
        //shared across this block, and a team stays claimed until 'di' releases it.
        //A plain-ws test client must not be able to take a team already held over wss.
        const plain = connect(ports.clientWs, '/?vcid=tls3');
        await plain.next();
        plain.send('pt1');
        assert.strictEqual(await plain.next(), 'px');
        plain.close();
    });

    test('vcid is ignored over wss, so one address is one client', async () => {
        //Asking for a name the wss port has never heard of still lands on the key the
        //earlier test used, because over wss the address alone decides. The proof is that
        //the server welcomes us back to the current view instead of offering the team
        //picker: a client that had genuinely been keyed on 'someoneelse' would be new.
        const impostor = new WebSocket('wss://127.0.0.1:' + ports.clientWss + '/?vcid=someoneelse',
                                       { rejectUnauthorized: false });
        const got = [];
        impostor.on('message', d => got.push(d.toString()));
        await new Promise((resolve, reject) => { impostor.on('open', resolve); impostor.on('error', reject); });
        await new Promise(resolve => setTimeout(resolve, 250));

        assert.deepStrictEqual(got, ['vibuzzer', 'imstart.jpg']);
        impostor.close();
    });
});
