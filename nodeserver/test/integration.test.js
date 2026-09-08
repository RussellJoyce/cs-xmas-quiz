'use strict';

//End-to-end over real WebSockets on ephemeral ports. These cover the wiring that the
//protocol unit tests deliberately stub out: URL/vcid parsing, the client server, and
//messages actually crossing between a client and the quiz software.
//
//Clients speak wss and nothing else, so every one of these runs over TLS against a
//throwaway self-signed certificate (see helpers.testCerts). That is the point rather than
//an inconvenience: the transport under test is the transport the phones use.

const { test, describe, before, after } = require('node:test');
const assert = require('node:assert');
const WebSocket = require('ws');
const net = require('net');
const tls = require('tls');
const https = require('https');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const { startWebsocketServers, startWebServers, defaultConfig, logDevMode } = require('../server');
const { muteLogs, captureLogs, testCerts } = require('./helpers');
const log = require('../log');

//A client socket that buffers what it receives so a test can await messages in order.
//The certificate is self-signed and issued for a name we are not using, so the name check
//is off; what is being tested here is the wiring, not the certificate. cert.test.js is
//what has an opinion about the real one.
function connect(port, query) {
    return wrap(new WebSocket('wss://127.0.0.1:' + port + (query || ''),
                              { rejectUnauthorized: false }));
}

//The quiz software and the LED controllers are not clients: they sit on the quiz laptop
//and on the LED boards, on the wired side of the server, and their ports are plain ws in
//production as well. Only the phones' transport moved to TLS-only.
function connectPlain(port, query) {
    return wrap(new WebSocket('ws://127.0.0.1:' + port + (query || '')));
}

function wrap(ws) {
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
//
//`secure` picks the transport: the client port is TLS, while the quiz software and LED
//ports are plain, so a raw socket has to know which it is talking to.
function sendMalformedFrame(port, frame, secure) {
    return new Promise(function(resolve, reject) {
        const open = secure
            ? cb => tls.connect({ port: port, host: '127.0.0.1', rejectUnauthorized: false }, cb)
            : cb => net.connect(port, '127.0.0.1', cb);
        const sock = open(function() {
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
        //Port 0 lets the OS pick, so a running production server is never in the way.
        //dev: true, because these tests give their clients names and the server only
        //believes a client about its name in development mode.
        handle = startWebsocketServers({
            certs: testCerts(),
            dev: true,
            clientWssPort: 0, serverPort: 0, ledsPort: 0,
            bindAddress: '127.0.0.1', wsBindAddress: '127.0.0.1'
        });
        await handle.ready();
        ports = handle.ports();
    });

    after(async () => {
        await new Promise(resolve => handle.close(resolve));
        unmute();
    });

    test('the OS assigned real ports', () => {
        assert.ok(ports.clientWss > 0);
        assert.ok(ports.server > 0);
        assert.ok(ports.leds > 0);
    });

    test('the quiz software is greeted on connect', async () => {
        const quiz = connectPlain(ports.server);
        assert.strictEqual(await quiz.next(), 'connected');
        quiz.close();
    });

    test('the LEDs are given a starting animation on connect', async () => {
        const leds = connectPlain(ports.leds);
        assert.strictEqual(await leds.next(), 'a01');
        leds.close();
    });

    test('a client is sent to the team picker on connect', async () => {
        const c = connect(ports.clientWss, '/?vcid=a');
        assert.strictEqual(await c.next(), 'vipickteam');
        c.close();
    });

    test('vcid separates clients arriving from the same address', async () => {
        //Both are 127.0.0.1; only the vcid tells them apart.
        const a = connect(ports.clientWss, '/?vcid=a');
        const b = connect(ports.clientWss, '/?vcid=b');
        await a.next();
        await b.next();

        a.send('pt1');
        assert.deepStrictEqual(await a.nextN(5), ['ok1', 'vibuzzer', 'imstart.jpg', 'mo4,A', 'on']);

        //b is a different client, so it can take a different team rather than
        //inheriting a's.
        b.send('pt2');
        assert.strictEqual((await b.nextN(5))[0], 'ok2');

        a.close();
        b.close();
    });

    test('a buzz travels from a client to the quiz software', async () => {
        const quiz = connectPlain(ports.server);
        await quiz.next();  //'connected'
        const c = connect(ports.clientWss, '/?vcid=buzzer');
        await c.next();
        c.send('pt5');
        await c.nextN(5);

        c.send('zz5');
        assert.strictEqual(await quiz.next(), 'zz5');

        quiz.close();
        c.close();
    });

    test('the quiz software can light one client and not another', async () => {
        const quiz = connectPlain(ports.server);
        await quiz.next();
        const a = connect(ports.clientWss, '/?vcid=r1');
        const b = connect(ports.clientWss, '/?vcid=r2');
        await a.next(); await b.next();
        a.send('pt7'); await a.nextN(5);
        b.send('pt8'); await b.nextN(5);

        quiz.send('on7');
        assert.strictEqual(await a.next(), 'on');
        await expectSilence(b);

        quiz.close(); a.close(); b.close();
    });

    test('a view change reaches every connected client', async () => {
        const quiz = connectPlain(ports.server);
        await quiz.next();
        const a = connect(ports.clientWss, '/?vcid=v1');
        const b = connect(ports.clientWss, '/?vcid=v2');
        await a.next(); await b.next();

        quiz.send('vinumbers');
        assert.strictEqual(await a.next(), 'vinumbers');
        assert.strictEqual(await b.next(), 'vinumbers');

        //And it becomes the view a later client is dropped into.
        quiz.send('di0');   //no-op, just to order the next assertion after the broadcast
        const late = connect(ports.clientWss, '/?vcid=v3');
        assert.strictEqual(await late.next(), 'vipickteam');
        late.send('pt11');
        assert.deepStrictEqual(await late.nextN(5), ['ok11', 'vinumbers', 'imstart.jpg', 'mo4,A', 'on']);

        quiz.close(); a.close(); b.close(); late.close();
        //Put the view back for any later test.
        const reset = connectPlain(ports.server);
        await reset.next();
        reset.send('vibuzzer');
        reset.close();
    });

    test('a client that drops and returns keeps its team', async () => {
        const c = connect(ports.clientWss, '/?vcid=sleepy');
        await c.next();
        c.send('pt12');
        await c.nextN(5);

        //Phone sleeps.
        c.close();
        await new Promise(resolve => setTimeout(resolve, 100));

        //Phone wakes up and reconnects with the same identity.
        const again = connect(ports.clientWss, '/?vcid=sleepy');
        const first = await again.next();
        assert.notStrictEqual(first, 'vipickteam', 'must not be sent back to the picker');
        assert.ok(first.startsWith('vi'), 'is put back into the current view');

        again.send('re');
        await again.nextN(3);  //the 'im', 'mo' and 'on' that follow the view
        assert.strictEqual(await again.next(), 'ok12', 'still team 12');
        again.close();
    });

    test('ls reports the teams that are actually playing', async () => {
        const quiz = connectPlain(ports.server);
        await quiz.next();
        const c = connect(ports.clientWss, '/?vcid=listed');
        await c.next();
        c.send('pt14');
        await c.nextN(5);

        //An idle client that connects but never picks must not appear.
        const idle = connect(ports.clientWss, '/?vcid=idle');
        await idle.next();

        quiz.send('ls');
        const list = await quiz.next();
        assert.ok(list.startsWith('lr'), 'got ' + list);
        assert.ok(list.includes('14'), 'team 14 is listed: ' + list);
        assert.ok(!list.includes('null'), 'no nulls from teamless clients: ' + list);

        quiz.close(); c.close(); idle.close();
    });

    test('LED commands are routed to the LEDs only', async () => {
        const quiz = connectPlain(ports.server);
        await quiz.next();
        const leds = connectPlain(ports.leds);
        await leds.next();  //'a01'
        const c = connect(ports.clientWss, '/?vcid=nonled');
        await c.next();

        quiz.send('le{"cmd":"setanimation","animation":"rainbow"}');
        assert.strictEqual(await leds.next(), '{"cmd":"setanimation","animation":"rainbow"}');
        await expectSilence(c);

        quiz.close(); leds.close(); c.close();
    });

    test('rubbish over the wire does not bring the server down', async () => {
        const quiz = connectPlain(ports.server);
        await quiz.next();
        const c = connect(ports.clientWss, '/?vcid=junk');
        await c.next();

        ['', 'a', 'pt', 'onX', 'di', '\u{1f384}', 'x'.repeat(50000)]
            .forEach(m => { quiz.send(m); c.send(m); });

        //Still alive and serving.
        const after = connect(ports.clientWss, '/?vcid=alive');
        assert.strictEqual(await after.next(), 'vipickteam');

        quiz.close(); c.close(); after.close();
    });

    //These are the reason every socket needs an 'error' listener: Node throws on an
    //unhandled 'error' event, so before the guards a single bad frame from one phone
    //killed the process and every buzzer in the room. The server runs inside this test
    //process, so if the guard is missing these do not fail politely -- they take the
    //whole test run down, which is the point.
    test('a malformed frame from a client does not kill the server', async () => {
        await sendMalformedFrame(ports.clientWss, UNMASKED_FRAME, true);

        const after = connect(ports.clientWss, '/?vcid=survivor');
        assert.strictEqual(await after.next(), 'vipickteam', 'server still serving clients');
        after.close();
    });

    test('a reserved opcode from a client does not kill the server', async () => {
        await sendMalformedFrame(ports.clientWss, RESERVED_OPCODE_FRAME, true);

        const after = connect(ports.clientWss, '/?vcid=survivor2');
        assert.strictEqual(await after.next(), 'vipickteam');
        after.close();
    });

    test('a malformed frame on the quiz software port does not kill the server', async () => {
        await sendMalformedFrame(ports.server, UNMASKED_FRAME);

        const quiz = connectPlain(ports.server);
        assert.strictEqual(await quiz.next(), 'connected');
        quiz.close();
    });

    test('a malformed frame on the LED port does not kill the server', async () => {
        await sendMalformedFrame(ports.leds, UNMASKED_FRAME);

        const leds = connectPlain(ports.leds);
        assert.strictEqual(await leds.next(), 'a01');
        leds.close();
    });

    test('a client that survives a neighbour\'s bad frame keeps its team', async () => {
        //The blast radius question: one phone misbehaving must not disturb anyone else.
        const c = connect(ports.clientWss, '/?vcid=bystander');
        await c.next();
        c.send('pt13');
        await c.nextN(5);

        await sendMalformedFrame(ports.clientWss, UNMASKED_FRAME, true);

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

//Everything above runs with dev: true, because those tests name their clients. This block
//is the other half: what a client can do to a server started the way a real quiz starts it.
describe('with development mode off', () => {
    let handle, ports, unmute;

    before(async () => {
        unmute = muteLogs();
        //No `dev`, so the server is in the state it is in on the night.
        handle = startWebsocketServers({
            certs: testCerts(),
            clientWssPort: 0, serverPort: 0, ledsPort: 0,
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
        const ws = connect(ports.clientWss, '/?vcid=ignored');
        assert.strictEqual(await ws.next(), 'vipickteam');
        ws.send('pt1');
        assert.deepStrictEqual(await ws.nextN(5), ['ok1', 'vibuzzer', 'imstart.jpg', 'mo4,A', 'on']);
        ws.close();
    });

    test('vcid is ignored, so one address is one client and therefore one team', async () => {
        //The point of the switch. Without it a single phone could open fourteen tabs,
        //name each one differently and claim every team before anybody else picked.
        //
        //The proof that the name was ignored is that the server welcomes this connection
        //back to the current view instead of offering it the team picker: a client
        //genuinely keyed on 'someoneelse' would be new, and new clients pick a team.
        const impostor = connect(ports.clientWss, '/?vcid=someoneelse');
        assert.deepStrictEqual(await impostor.nextN(4), ['vibuzzer', 'imstart.jpg', 'mo4,A', 'on']);
        impostor.close();
    });

    test('and the team it lands on is the one the first connection claimed', async () => {
        //Same address, so the same client: asking for the team it already holds is
        //confirmed rather than refused.
        const again = connect(ports.clientWss, '/?vcid=whatever');
        await again.nextN(4);
        again.send('pt1');
        assert.strictEqual(await again.next(), 'ok1');
        again.close();
    });
});


//---------------------------------------------------------------------------------------
// The web servers
//---------------------------------------------------------------------------------------

//Fetches a path over https, ignoring the self-signed certificate.
function get(port, path) {
    return new Promise(function(resolve, reject) {
        //agent: false, or the keep-alive socket outlives the request and server.close()
        //never finishes, which hangs the whole run rather than failing anything.
        const req = https.request({ host: '127.0.0.1', port: port, path: path,
                                    agent: false, rejectUnauthorized: false }, function(res) {
            res.resume();
            res.on('end', () => resolve(res.statusCode));
        });
        req.on('error', reject);
        req.end();
    });
}

describe('what the web server hands out', () => {
    let unmute;
    before(() => { unmute = muteLogs(); });
    after(() => { unmute(); });

    async function serving(dev) {
        const web = startWebServers({
            certs: testCerts(), dev: dev,
            httpPort: 0, httpsPort: 0, bindAddress: '127.0.0.1'
        });
        await new Promise(resolve => {
            if(web.server.listening) resolve(); else web.server.once('listening', resolve);
        });
        return {
            port: web.server.address().port,
            close: () => {
                web.server.close();
                web.http.close();
                //Anything still connected would keep the listener alive.
                web.server.closeAllConnections && web.server.closeAllConnections();
                web.http.closeAllConnections && web.http.closeAllConnections();
            }
        };
    }

    test('the client app is served either way', async () => {
        const s = await serving(false);
        assert.strictEqual(await get(s.port, '/index.html'), 200);
        s.close();
    });

    test('the test harnesses are NOT served to a real quiz', async () => {
        //A room full of phones has no business being able to open the client wall.
        const s = await serving(false);
        assert.strictEqual(await get(s.port, '/test/client-wall.html'), 404);
        s.close();
    });

    test('development mode serves them at /test', async () => {
        const s = await serving(true);
        assert.strictEqual(await get(s.port, '/test/client-wall.html'), 200);
        assert.strictEqual(await get(s.port, '/test/multi-client.html'), 200);
        s.close();
    });

    test('development mode does not otherwise change what is served', async () => {
        const s = await serving(true);
        assert.strictEqual(await get(s.port, '/index.html'), 200);
        s.close();
    });
});

describe('the development mode warning', () => {
    test('is one line, and says so plainly', () => {
        const lines = captureLogs('debug');
        logDevMode(true);
        lines.stop();
        assert.strictEqual(lines.length, 1);
        assert.match(lines[0].line, /Server is running in development mode/);
    });

    test('is at error level, so it cannot be missed in a busy log', () => {
        const lines = captureLogs('debug');
        logDevMode(true);
        lines.stop();
        assert.strictEqual(lines[0].level, log.LEVELS.error);
    });

    test('says nothing at all when the server is in its normal state', () => {
        const lines = captureLogs('debug');
        logDevMode(false);
        lines.stop();
        assert.strictEqual(lines.length, 0);
    });
});
