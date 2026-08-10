'use strict';

//The log is the only thing anybody looks at on the night, so its shape is worth pinning
//down: the columns line up, the noisy traffic stays out of the way unless asked for, and a
//client can be followed from the moment it connects to the team it ends up holding.

const { test, describe, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');

const log = require('../log');
const { QuizState } = require('../protocol');
const { FakeSocket, recordingTransport, captureLogs } = require('./helpers');

let lines;
beforeEach(() => { lines = captureLogs('debug'); });
afterEach(() => lines.stop());

//The line without its timestamp, which is the part worth asserting on.
function body(entry) {
    return entry.line.replace(/^\d\d:\d\d:\d\d\.\d\d\d /, '');
}
function bodies() {
    return lines.map(body);
}

describe('the shape of a line', () => {
    test('reads as time, level, route, code, meaning', () => {
        log.info('T7', 'quiz', 'zz', 'buzz');
        assert.match(lines[0].line, /^\d\d:\d\d:\d\d\.\d\d\d INFO  T7     → quiz  zz  buzz$/);
    });

    test('columns line up whatever the endpoints are called', () => {
        log.info('T7', 'quiz', 'zz', 'buzz');
        log.info('c11', 'srv', 'pt', 'claims team 3');
        log.info('quiz', 'leds', 'le', 'a03');
        //Fixed offsets rather than "they are all the same", so a change to the layout has
        //to be made deliberately here as well as in log.js.
        const ARROW = 13, CODE = 21;
        assert.deepStrictEqual(bodies().map(l => l.indexOf('→')), [ARROW, ARROW, ARROW],
                               'the arrows are not in one column');
        assert.deepStrictEqual(bodies().map(l => l.slice(CODE, CODE + 2)), ['zz', 'pt', 'le'],
                               'the codes are not in one column');
    });

    test('a message with no destination leaves the arrow out but keeps the columns', () => {
        log.info('c3', null, null, 'new client (10.0.0.1), sent to the team picker');
        log.info('T7', 'quiz', 'zz', 'buzz');
        //A connection or a startup line has no code, so its text lines up with the meaning
        //of every other line rather than staggering the page.
        assert.ok(!bodies()[0].includes('→'));
        assert.strictEqual(bodies()[0].indexOf('new client'), bodies()[1].indexOf('buzz'));
    });

    test('no line ends in trailing whitespace', () => {
        log.info('T7', 'quiz', 'zz', 'buzz');
        log.boot('serving quiz.example.com');
        assert.ok(bodies().every(l => l === l.replace(/\s+$/, '')));
    });

    test('an over-long name pushes the line out rather than being cut short', () => {
        //Truncating would produce a name that matches no other line, which is worse than ugly.
        log.info('T7', '::ffff:10.0.0.1', 'zz', 'buzz');
        assert.match(body(lines[0]), /::ffff:10\.0\.0\.1/);
    });
});

describe('levels', () => {
    test('errors and warnings are reported at a level the sink can act on', () => {
        log.error('srv', null, null, 'boom');
        log.warn('c1', 'srv', 'pt', 'refused');
        log.info('quiz', 'all', 'vi', 'view → buzzer');
        assert.deepStrictEqual(lines.map(l => l.level), [log.LEVELS.error, log.LEVELS.warn, log.LEVELS.info]);
    });

    test('the level filters, so a quiet run stays quiet', () => {
        log.setLevel('warn');
        log.debug('T7', 'srv', 'pi', 'ping');
        log.info('quiz', 'all', 'vi', 'view → buzzer');
        log.warn('c1', 'srv', 'pt', 'refused');
        log.error('srv', null, null, 'boom');
        assert.deepStrictEqual(bodies().map(l => l.slice(0, 5)), ['WARN ', 'ERROR']);
    });

    test('a mistyped level is ignored rather than being fatal', () => {
        //A typo in QUIZ_LOG at the start of a quiz night must not stop the server.
        log.setLevel('info');
        log.setLevel('verbose-ish');
        log.debug('T7', 'srv', 'pi', 'ping');
        log.info('quiz', 'all', 'vi', 'view → buzzer');
        assert.strictEqual(lines.length, 1, 'the level moved when it should not have');
    });

    test('setters hand back the old value so it can be put back', () => {
        const was = log.setLevel('warn');
        assert.strictEqual(was, 'debug');
        assert.strictEqual(log.setLevel(was), 'warn');
    });
});

describe('decoding the protocol', () => {
    test('a code becomes English, with its payload kept', () => {
        assert.strictEqual(log.describe('vibuzzer'), 'view buzzer');
        assert.strictEqual(log.describe('zz7'), 'buzz 7');
        assert.strictEqual(log.describe('hn'), 'clear higher/lower');
    });

    test('an unknown code is called out, not passed off as meaningful', () => {
        assert.strictEqual(log.describe('qq42'), "unrecognised 'qq42'");
    });

    test('every code the protocol acts on has a translation', () => {
        //If a code is added to protocol.js and not here, the log silently degrades to
        //"unrecognised", which looks like a fault rather than an omission.
        ['on', 'of', 'hh', 'hl', 'hn', 'ha', 'vi', 'im', 'di', 'le', 'ls', 'lr',
         'pt', 're', 'pi', 'pb', 'ok', 'px', 'zz', 'hi', 'lo', 'tt', 'ii'].forEach(code => {
            assert.ok(log.CODES[code], 'no translation for ' + code);
        });
    });
});

describe('following a client through a game', () => {
    function game() {
        const state = new QuizState(recordingTransport(), { numTeams: 14 });
        return state;
    }

    test('a client is named by its handle before a team and by its team after', () => {
        const state = game();
        const sock = new FakeSocket();
        state.addClient('10.0.0.1', sock);
        state.handleClientMessage('10.0.0.1', sock, 'pt7');
        state.handleClientMessage('10.0.0.1', sock, 'zz7');

        assert.match(bodies()[0], /^INFO  c1 .*new client \(10\.0\.0\.1\)/);
        assert.match(bodies()[1], /^INFO  c1 .*pt  claims team 7 — granted, now T7/);
        assert.match(bodies()[2], /^INFO  T7 .*→ quiz  zz  buzz 7/);
    });

    test('the full address appears once, so the short handle can be traced back to a device', () => {
        const state = game();
        state.addClient('::ffff:10.0.0.1', new FakeSocket());
        const withAddress = bodies().filter(l => l.includes('::ffff:10.0.0.1'));
        assert.strictEqual(withAddress.length, 1);
    });

    test('a contested team warns and names both devices', () => {
        //The usual cause is somebody sitting at the wrong table, and the fix needs to know
        //which two phones are arguing.
        const state = game();
        const first = new FakeSocket(), second = new FakeSocket();
        state.addClient('10.0.0.1', first);
        state.handleClientMessage('10.0.0.1', first, 'pt7');
        state.addClient('10.0.0.2', second);
        state.handleClientMessage('10.0.0.2', second, 'pt7');

        const refusal = lines.find(l => body(l).includes('refused'));
        assert.strictEqual(refusal.level, log.LEVELS.warn);
        assert.match(body(refusal), /^WARN  c2 .*claims team 7 — refused, already held by c1/);
    });

    test('a team that reconnects keeps the handle it started with', () => {
        const state = game();
        state.addClient('10.0.0.1', new FakeSocket());
        state.handleClientMessage('10.0.0.1', new FakeSocket(), 'pt7');
        state.addClient('10.0.0.1', new FakeSocket());   //phone woke up on a new socket
        assert.match(bodies().pop(), /^INFO  T7 .*reconnected as c1/);
    });

    test('the polling traffic is out of the way at INFO but there at DEBUG', () => {
        const state = game();
        const sock = new FakeSocket();
        state.addClient('10.0.0.1', sock);
        state.handleClientMessage('10.0.0.1', sock, 'pt7');

        const noisy = () => {
            state.handleClientMessage('10.0.0.1', sock, 'pi');
            state.handleServerMessage('ls');
        };
        const before = lines.length;
        noisy();
        assert.strictEqual(lines.length - before, 2, 'the noise is missing at DEBUG');

        log.setLevel('info');
        const quiet = lines.length;
        noisy();
        assert.strictEqual(lines.length, quiet, 'pings and polling leaked into a normal run');
    });

    test('a message to a team that is not connected explains itself at DEBUG', () => {
        //"I pressed the button and nothing happened" is the question this answers.
        const state = game();
        state.handleServerMessage('on7');
        assert.match(bodies()[0], /^DEBUG quiz .*→ T7 .*on  dropped, team not connected/);
    });
});
