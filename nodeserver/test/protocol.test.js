'use strict';

const { test, describe, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');

const { QuizState, safeSend, clientKey, asText, ACTIVE_WINDOW_MS,
        DEFAULT_VIEW, DEFAULT_GEO_IMAGE } = require('../protocol');
const { FakeSocket, recordingTransport, muteLogs } = require('./helpers');

let unmute;
beforeEach(() => { unmute = muteLogs(); });
afterEach(() => { unmute(); });

//Set up a state with `n` connected clients, teams not yet picked.
function setup(n) {
    const transport = recordingTransport();
    const state = new QuizState(transport);
    const socks = [];
    for(let i = 1; i <= (n || 0); i++) {
        const s = new FakeSocket('c' + i);
        state.addClient('10.0.0.9_test' + i, s);
        socks.push(s);
    }
    return { state, transport, socks };
}

//Connect client i and claim team i, returning the sockets.
function setupTeams(n) {
    const ctx = setup(n);
    ctx.socks.forEach((s, i) => {
        ctx.state.handleClientMessage('10.0.0.9_test' + (i + 1), s, 'pt' + (i + 1));
        s.drain();
    });
    return ctx;
}


describe('client identity', () => {
    test('a bare IP is the client key when no vcid is given', () => {
        assert.strictEqual(clientKey('10.0.0.9', null), '10.0.0.9');
    });

    test('vcid distinguishes clients sharing an IP', () => {
        //This is the whole reason the test harness can run 16 clients from one browser.
        assert.notStrictEqual(clientKey('10.0.0.9', 'test1'), clientKey('10.0.0.9', 'test2'));
    });

    test('a new client is sent to the team picker', () => {
        const { socks } = setup(1);
        assert.deepStrictEqual(socks[0].sent, ['vipickteam']);
    });

    test('two clients on one IP with different vcids are independent', () => {
        const { state, socks } = setup(2);
        state.handleClientMessage('10.0.0.9_test1', socks[0], 'pt1');
        assert.ok(socks[0].sent.includes('ok1'));
        assert.strictEqual(state.clients['10.0.0.9_test2'].id, null);
    });
});


describe('picking a team', () => {
    test('claiming a free team confirms it and sends the current view and image', () => {
        const { state, socks } = setup(1);
        socks[0].drain();
        state.handleClientMessage('10.0.0.9_test1', socks[0], 'pt3');
        assert.deepStrictEqual(socks[0].sent,
            ['ok3', 'vi' + DEFAULT_VIEW, 'im' + DEFAULT_GEO_IMAGE]);
        assert.strictEqual(state.clients['10.0.0.9_test1'].id, '3');
    });

    test('claiming a taken team is rejected with px and changes nothing', () => {
        const { state, socks } = setup(2);
        state.handleClientMessage('10.0.0.9_test1', socks[0], 'pt3');
        socks[1].drain();
        state.handleClientMessage('10.0.0.9_test2', socks[1], 'pt3');
        assert.deepStrictEqual(socks[1].sent, ['px']);
        assert.strictEqual(state.clients['10.0.0.9_test2'].id, null);
    });

    test('a client without a team is ignored except for pt', () => {
        const { state, transport, socks } = setup(1);
        socks[0].drain();
        ['zz1', 're', 'pi', 'tt1,hello', 'ii1,50,50'].forEach(m =>
            state.handleClientMessage('10.0.0.9_test1', socks[0], m));
        assert.deepStrictEqual(socks[0].sent, [], 'nothing sent back');
        assert.deepStrictEqual(transport.servers, [], 'nothing forwarded to the quiz software');
    });
});


describe('reconnection', () => {
    test('a reconnecting client keeps its team and is replayed the current state', () => {
        const { state, socks } = setupTeams(1);
        state.handleServerMessage('vigeography');
        state.handleServerMessage('imfrance.jpg');

        //Phone sleeps, browser reopens the socket.
        const fresh = new FakeSocket('c1-again');
        state.addClient('10.0.0.9_test1', fresh);

        assert.deepStrictEqual(fresh.sent, ['vigeography', 'imfrance.jpg']);
        assert.strictEqual(state.clients['10.0.0.9_test1'].id, '1');
        assert.strictEqual(state.clients['10.0.0.9_test1'].sock, fresh,
            'messages for team 1 now go to the new socket');
    });

    test('a client that never picked a team goes back to the picker on reconnect', () => {
        const { state } = setup(1);
        const fresh = new FakeSocket('c1-again');
        state.addClient('10.0.0.9_test1', fresh);
        assert.deepStrictEqual(fresh.sent, ['vipickteam']);
    });

    test('client entries deliberately survive a dead socket', () => {
        //Documenting intent: nothing removes clients, so a sleeping phone keeps its team.
        const { state, socks } = setupTeams(1);
        socks[0].close();
        assert.strictEqual(state.getClientByID('1').id, '1');
    });
});


describe('routing from the quiz software', () => {
    ['on', 'of', 'hh', 'hl', 'hn'].forEach(cmd => {
        test(cmd + ' reaches only the addressed team', () => {
            const { state, socks } = setupTeams(2);
            state.handleServerMessage(cmd + '1');
            assert.deepStrictEqual(socks[0].sent, [cmd]);
            assert.deepStrictEqual(socks[1].sent, []);
        });
    });

    test('the payload is stripped before it reaches the client', () => {
        const { state, socks } = setupTeams(1);
        state.handleServerMessage('on1');
        assert.deepStrictEqual(socks[0].sent, ['on'], 'client receives "on", not "on1"');
    });

    test('team 0 addresses nobody, because teams are 1-based', () => {
        const { state, socks } = setupTeams(1);
        state.handleServerMessage('on0');
        assert.deepStrictEqual(socks[0].sent, []);
    });

    test('a non-numeric team addresses nobody and does not throw', () => {
        const { state, socks } = setupTeams(1);
        state.handleServerMessage('onX');
        assert.deepStrictEqual(socks[0].sent, []);
    });

    test('a message for an absent team is dropped quietly', () => {
        const { state } = setupTeams(1);
        state.handleServerMessage('on9');   //must not throw
    });

    test('vi broadcasts and becomes the view replayed to later clients', () => {
        const { state, transport } = setup(0);
        state.handleServerMessage('vigeography');
        assert.deepStrictEqual(transport.clients, ['vigeography']);
        assert.strictEqual(state.lastView, 'geography');
    });

    test('im broadcasts and becomes the image replayed to later clients', () => {
        const { state, transport } = setup(0);
        state.handleServerMessage('imspain.jpg');
        assert.deepStrictEqual(transport.clients, ['imspain.jpg']);
        assert.strictEqual(state.lastGeoImage, 'spain.jpg');
    });

    test('ha resets every higher/lower', () => {
        const { state, transport } = setup(0);
        state.handleServerMessage('ha');
        assert.deepStrictEqual(transport.clients, ['hn']);
    });

    test('le forwards to the LEDs with the prefix stripped', () => {
        const { state, transport } = setup(0);
        state.handleServerMessage('le{"cmd":"setanimation","animation":"rainbow"}');
        assert.deepStrictEqual(transport.leds, ['{"cmd":"setanimation","animation":"rainbow"}']);
        assert.deepStrictEqual(transport.clients, [], 'LED traffic does not reach clients');
    });

    test('an unrecognised message is broadcast to all clients unchanged', () => {
        const { state, transport } = setup(0);
        state.handleServerMessage('sc1,42');
        assert.deepStrictEqual(transport.clients, ['sc1,42']);
    });

    test('di returns a team to the picker and frees the number', () => {
        const { state, socks } = setupTeams(2);
        state.handleServerMessage('di1');
        assert.deepStrictEqual(socks[0].sent, ['vipickteam']);
        assert.strictEqual(state.clients['10.0.0.9_test1'].id, null);

        //The freed team can now be claimed by somebody else.
        state.handleClientMessage('10.0.0.9_test1', socks[0], 'pt1');
        assert.ok(socks[0].sent.includes('ok1'));
    });
});


describe('the ls client listing', () => {
    test('lists teams that have been heard from recently', () => {
        const { state, transport, socks } = setupTeams(2);
        state.handleClientMessage('10.0.0.9_test1', socks[0], 'pi');
        state.handleClientMessage('10.0.0.9_test2', socks[1], 'pi');
        state.handleServerMessage('ls');
        assert.deepStrictEqual(transport.servers, ['lr1,2']);
    });

    test('excludes clients that have not claimed a team', () => {
        //Regression: without the id check these appear in the list as "null".
        const { state, transport, socks } = setupTeams(1);
        const idle = new FakeSocket('idle');
        state.addClient('10.0.0.9_idle', idle);
        state.handleClientMessage('10.0.0.9_idle', idle, 'pi');   //active, but teamless

        state.handleClientMessage('10.0.0.9_test1', socks[0], 'pi');
        state.handleServerMessage('ls');
        assert.deepStrictEqual(transport.servers, ['lr1']);
    });

    test('excludes clients that have gone quiet', () => {
        const { state, transport, socks } = setupTeams(2);
        state.handleClientMessage('10.0.0.9_test1', socks[0], 'pi');
        state.handleClientMessage('10.0.0.9_test2', socks[1], 'pi');
        state.clients['10.0.0.9_test2'].timestamp = Date.now() - (ACTIVE_WINDOW_MS + 1000);

        state.handleServerMessage('ls');
        assert.deepStrictEqual(transport.servers, ['lr1']);
    });

    test('is empty when nobody is playing', () => {
        const { state, transport } = setup(0);
        state.handleServerMessage('ls');
        assert.deepStrictEqual(transport.servers, ['lr']);
    });
});


describe('messages from clients', () => {
    test('re re-sends the client its team', () => {
        const { state, socks } = setupTeams(1);
        state.handleClientMessage('10.0.0.9_test1', socks[0], 're');
        assert.deepStrictEqual(socks[0].sent, ['ok1']);
    });

    test('pi is answered with pb and does not reach the quiz software', () => {
        const { state, transport, socks } = setupTeams(1);
        state.handleClientMessage('10.0.0.9_test1', socks[0], 'pi');
        assert.deepStrictEqual(socks[0].sent, ['pb']);
        assert.deepStrictEqual(transport.servers, []);
    });

    test('a buzz is forwarded to the quiz software verbatim', () => {
        const { state, transport, socks } = setupTeams(1);
        state.handleClientMessage('10.0.0.9_test1', socks[0], 'zz1');
        assert.deepStrictEqual(transport.servers, ['zz1']);
    });

    test('buzz order is preserved', () => {
        //Who buzzed first is the one thing this server absolutely must get right.
        const { state, transport, socks } = setupTeams(3);
        state.handleClientMessage('10.0.0.9_test3', socks[2], 'zz3');
        state.handleClientMessage('10.0.0.9_test1', socks[0], 'zz1');
        state.handleClientMessage('10.0.0.9_test2', socks[1], 'zz2');
        assert.deepStrictEqual(transport.servers, ['zz3', 'zz1', 'zz2']);
    });

    test('text and geography answers are forwarded', () => {
        const { state, transport, socks } = setupTeams(1);
        state.handleClientMessage('10.0.0.9_test1', socks[0], 'tt1,a wild guess');
        state.handleClientMessage('10.0.0.9_test1', socks[0], 'ii1,42,17');
        assert.deepStrictEqual(transport.servers, ['tt1,a wild guess', 'ii1,42,17']);
    });

    test('activity is timestamped', () => {
        const { state, socks } = setupTeams(1);
        const before = Date.now();
        state.handleClientMessage('10.0.0.9_test1', socks[0], 'pi');
        assert.ok(state.clients['10.0.0.9_test1'].timestamp >= before);
    });
});


describe('bad input', () => {
    const junk = ['', 'a', 'z', 'pt', 'on', 'di', 'ls', 'zz', '  ', '\n',
                  'onX', 'di-1', 'ptNaN', '\u{1f984}\u{1f984}', 'x'.repeat(10000)];

    test('nothing from the quiz software throws', () => {
        const { state } = setupTeams(2);
        junk.forEach(m => state.handleServerMessage(m));
    });

    test('nothing from a client throws, with or without a team', () => {
        const { state, socks } = setupTeams(1);
        const idle = new FakeSocket('idle');
        state.addClient('10.0.0.9_idle', idle);
        junk.forEach(m => {
            state.handleClientMessage('10.0.0.9_test1', socks[0], m);
            state.handleClientMessage('10.0.0.9_idle', idle, m);
        });
    });

    test('a one-character message is ignored entirely', () => {
        const { state, transport, socks } = setupTeams(1);
        state.handleClientMessage('10.0.0.9_test1', socks[0], 'z');
        assert.deepStrictEqual(transport.servers, []);
        assert.deepStrictEqual(socks[0].sent, []);
    });

    test('a team claim is not validated as a number', () => {
        //Documenting current behaviour rather than endorsing it: pt takes any string.
        const { state, socks } = setup(1);
        state.handleClientMessage('10.0.0.9_test1', socks[0], 'pt<script>');
        assert.strictEqual(state.clients['10.0.0.9_test1'].id, '<script>');
    });
});


describe('safeSend', () => {
    test('sends to an open socket', () => {
        const s = new FakeSocket();
        safeSend(s, 'hello');
        assert.deepStrictEqual(s.sent, ['hello']);
    });

    test('drops a closed socket without throwing', () => {
        const s = new FakeSocket();
        s.close();
        safeSend(s, 'hello');
        assert.deepStrictEqual(s.sent, []);
    });

    test('tolerates a null socket', () => {
        safeSend(null, 'hello');
    });

    test('a throwing socket does not escape', () => {
        const unmuted = { readyState: 1, send() { throw new Error('boom'); } };
        safeSend(unmuted, 'hello');
    });

    test('one dead client does not stop a broadcast reaching the rest', () => {
        //The bug this guards: forEach over sockets, one throws, everybody after it is skipped.
        const dead = new FakeSocket('dead');
        const alive = new FakeSocket('alive');
        dead.close();
        [dead, alive].forEach(s => safeSend(s, 'vibuzzer'));
        assert.deepStrictEqual(alive.sent, ['vibuzzer']);
    });
});


describe('message framing', () => {
    //ws 7 delivers text frames as strings; ws 8 and later deliver Buffers. Without the
    //asText coercion the switch statements stop matching (strict equality against a
    //Buffer) while the loose-equality 'pt' check carries on working, so the failure is
    //partial and misleading. These run the protocol over Buffers to pin that down.
    const buf = s => Buffer.from(s, 'utf8');

    test('asText leaves a string alone', () => {
        assert.strictEqual(asText('on1'), 'on1');
    });

    test('asText decodes a Buffer as utf8', () => {
        assert.strictEqual(asText(buf('on1')), 'on1');
        assert.strictEqual(asText(buf('tt1,caf\u00e9')), 'tt1,caf\u00e9');
    });

    test('asText turns null and undefined into an ignorable empty string', () => {
        assert.strictEqual(asText(null), '');
        assert.strictEqual(asText(undefined), '');
    });

    test('a team can be claimed with a Buffer', () => {
        const { state, socks } = setup(1);
        socks[0].drain();
        state.handleClientMessage('10.0.0.9_test1', socks[0], buf('pt3'));
        assert.deepStrictEqual(socks[0].sent,
            ['ok3', 'vi' + DEFAULT_VIEW, 'im' + DEFAULT_GEO_IMAGE]);
    });

    test('the quiz software can route with a Buffer', () => {
        const { state, transport, socks } = setupTeams(2);
        state.handleServerMessage(buf('on1'));
        assert.deepStrictEqual(socks[0].sent, ['on']);
        assert.deepStrictEqual(socks[1].sent, []);
        //The specific failure mode: an unmatched switch falls through to default, which
        //broadcasts. A buzzer command must never reach every team that way.
        assert.deepStrictEqual(transport.clients, []);
    });

    test('a Buffer ping is answered, not forwarded as an answer', () => {
        //The client-side version of the same fallthrough.
        const { state, transport, socks } = setupTeams(1);
        state.handleClientMessage('10.0.0.9_test1', socks[0], buf('pi'));
        assert.deepStrictEqual(socks[0].sent, ['pb']);
        assert.deepStrictEqual(transport.servers, []);
    });

    test('a Buffer view change is stored as a string, not a Buffer', () => {
        const { state, transport } = setup(0);
        state.handleServerMessage(buf('vigeography'));
        assert.strictEqual(state.lastView, 'geography');
        assert.deepStrictEqual(transport.clients, ['vigeography']);
    });

    test('a buzz sent as a Buffer is forwarded as a string', () => {
        const { state, transport, socks } = setupTeams(1);
        state.handleClientMessage('10.0.0.9_test1', socks[0], buf('zz1'));
        assert.deepStrictEqual(transport.servers, ['zz1']);
        assert.strictEqual(typeof transport.servers[0], 'string',
            'the quiz software must receive text, not a binary frame');
    });

    test('a null message is ignored rather than throwing', () => {
        const { state, transport, socks } = setupTeams(1);
        state.handleClientMessage('10.0.0.9_test1', socks[0], null);
        state.handleServerMessage(undefined);
        assert.deepStrictEqual(transport.servers, []);
        assert.deepStrictEqual(socks[0].sent, []);
    });
});
