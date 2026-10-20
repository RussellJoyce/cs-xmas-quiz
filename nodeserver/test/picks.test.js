'use strict';

//Team picks surviving a restart: the file itself, QuizState saving and restoring through
//it, and a real server being stopped and started again under a phone.

const { test, describe, before, after } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const WebSocket = require('ws');

const { PickStore, MAX_AGE_MS } = require('../picks');
const { QuizState } = require('../protocol');
const { startWebsocketServers } = require('../server');
const { FakeSocket, recordingTransport, muteLogs, captureLogs, testCerts } = require('./helpers');

function tempFile() {
    return path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'quiz-picks-')), 'state', 'picks.json');
}

//Holds what was saved, so a second QuizState can be "restarted" from it.
function memoryStore(initial) {
    const store = {
        saved: initial || null,
        saves: 0,
        load: () => store.saved,
        save: picks => { store.saves++; store.saved = { picks: picks, savedAt: new Date(), stale: false }; }
    };
    return store;
}


describe('the picks file', () => {
    let unmute;
    before(() => { unmute = muteLogs(); });
    after(() => unmute());

    test('round-trips, creating its directory', () => {
        const store = new PickStore(tempFile());
        store.save({ '10.0.0.1': '3', '10.0.0.2': '7' });
        const back = store.load();
        assert.deepStrictEqual(back.picks, { '10.0.0.1': '3', '10.0.0.2': '7' });
        assert.strictEqual(back.stale, false);
    });

    test('no file is nothing to restore, not an error', () => {
        assert.strictEqual(new PickStore(tempFile()).load(), null);
    });

    test('a corrupt file is refused and moved aside, so the next save cannot destroy it', () => {
        const file = tempFile();
        fs.mkdirSync(path.dirname(file), { recursive: true });
        fs.writeFileSync(file, '{"picks": {"10.0.0.1": "3"');   //cut off mid-write
        assert.throws(() => new PickStore(file).load(), /moved aside/);
        assert.ok(fs.existsSync(file + '.bad'));
        assert.ok(!fs.existsSync(file));
    });

    test('valid JSON of the wrong shape is refused too', () => {
        const file = tempFile();
        fs.mkdirSync(path.dirname(file), { recursive: true });
        fs.writeFileSync(file, '["10.0.0.1"]');
        assert.throws(() => new PickStore(file).load(), /not a picks file/);
    });

    test('picks from another night are marked stale', () => {
        const file = tempFile();
        fs.mkdirSync(path.dirname(file), { recursive: true });
        fs.writeFileSync(file, JSON.stringify({ savedAt: Date.now() - MAX_AGE_MS - 1000, picks: { a: '1' } }));
        const back = new PickStore(file).load();
        assert.strictEqual(back.stale, true);
        assert.deepStrictEqual(back.picks, {});
    });

    test('a save leaves no temporary file behind', () => {
        const file = tempFile();
        new PickStore(file).save({});
        assert.deepStrictEqual(fs.readdirSync(path.dirname(file)), ['picks.json']);
    });
});


describe('QuizState with a store', () => {
    let unmute;
    before(() => { unmute = muteLogs(); });
    after(() => unmute());

    test('a pick is saved', () => {
        const store = memoryStore();
        const state = new QuizState(recordingTransport(), { numTeams: 14, store: store });
        const s = new FakeSocket();
        state.addClient('10.0.0.1', s);
        state.handleClientMessage('10.0.0.1', s, 'pt5');
        assert.deepStrictEqual(store.saved.picks, { '10.0.0.1': '5' });
    });

    test('a refused pick saves nothing', () => {
        const store = memoryStore();
        const state = new QuizState(recordingTransport(), { numTeams: 14, store: store });
        const s = new FakeSocket();
        state.addClient('10.0.0.1', s);
        state.handleClientMessage('10.0.0.1', s, 'pt99');
        assert.strictEqual(store.saves, 0);
    });

    test('a release by the quiz software is saved', () => {
        const store = memoryStore();
        const state = new QuizState(recordingTransport(), { numTeams: 14, store: store });
        const s = new FakeSocket();
        state.addClient('10.0.0.1', s);
        state.handleClientMessage('10.0.0.1', s, 'pt5');
        state.handleServerMessage('di5');
        assert.deepStrictEqual(store.saved.picks, {});
    });

    test('after a restart a returning phone gets its team back, not the picker', () => {
        const store = memoryStore();
        const first = new QuizState(recordingTransport(), { numTeams: 14, store: store });
        const s = new FakeSocket();
        first.addClient('10.0.0.1', s);
        first.handleClientMessage('10.0.0.1', s, 'pt5');

        const second = new QuizState(recordingTransport(), { numTeams: 14, store: store });
        const again = new FakeSocket();
        second.addClient('10.0.0.1', again);
        assert.ok(!again.sent.includes('vipickteam'), 'sent to the picker: ' + again.sent);
        second.handleClientMessage('10.0.0.1', again, 're');
        assert.strictEqual(again.sent[again.sent.length - 1], 'ok5');
    });

    test('a restored team cannot be taken by another phone before its own comes back', () => {
        const store = memoryStore({ picks: { '10.0.0.1': '5' }, savedAt: new Date(), stale: false });
        const state = new QuizState(recordingTransport(), { numTeams: 14, store: store });
        const other = new FakeSocket();
        state.addClient('10.0.0.2', other);
        state.handleClientMessage('10.0.0.2', other, 'pt5');
        assert.strictEqual(other.sent[other.sent.length - 1], 'px');
    });

    test('a restored team is not reported as active until its phone is heard from', () => {
        const store = memoryStore({ picks: { '10.0.0.1': '5' }, savedAt: new Date(), stale: false });
        const transport = recordingTransport();
        const state = new QuizState(transport, { numTeams: 14, store: store });
        state.handleServerMessage('ls');
        assert.deepStrictEqual(transport.servers, ['lr']);
    });

    test('saved entries that are not teams, or are duplicates, are dropped', () => {
        const lines = captureLogs('info');
        const store = memoryStore({ picks: { a: '5', b: '5', c: '99', d: 'x', e: '2' },
                                    savedAt: new Date(), stale: false });
        const state = new QuizState(recordingTransport(), { numTeams: 14, store: store });
        lines.stop();
        const held = Object.values(state.clients).map(c => c.id).sort();
        assert.deepStrictEqual(held, ['2', '5']);
        assert.strictEqual(lines.filter(l => /dropped/.test(l.line)).length, 3);
    });

    test('a store that cannot be read leaves an empty, working server', () => {
        const store = { load: () => { throw new Error('disk on fire'); }, save: () => {} };
        const state = new QuizState(recordingTransport(), { numTeams: 14, store: store });
        const s = new FakeSocket();
        state.addClient('10.0.0.1', s);
        assert.deepStrictEqual(s.sent, ['vipickteam']);
    });

    test('a store that cannot be written does not stop the pick', () => {
        const store = { load: () => null, save: () => { throw new Error('disk full'); } };
        const state = new QuizState(recordingTransport(), { numTeams: 14, store: store });
        const s = new FakeSocket();
        state.addClient('10.0.0.1', s);
        state.handleClientMessage('10.0.0.1', s, 'pt5');
        assert.strictEqual(s.sent[1], 'ok5');
    });

    test('without a store nothing is read or written', () => {
        //What --nostorage gives: picks live and die with the process.
        const state = new QuizState(recordingTransport(), { numTeams: 14 });
        assert.strictEqual(state.store, null);
        const s = new FakeSocket();
        state.addClient('10.0.0.1', s);
        state.handleClientMessage('10.0.0.1', s, 'pt5');   //must not throw
        assert.strictEqual(s.sent[1], 'ok5');
    });
});


describe('round broadcasts', () => {
    let unmute;
    before(() => { unmute = muteLogs(); });
    after(() => unmute());

    test('go to phones holding a team, and not to those on the picker', () => {
        const state = new QuizState(recordingTransport(), { numTeams: 14 });
        const playing = new FakeSocket('playing');
        const picking = new FakeSocket('picking');
        state.addClient('10.0.0.1', playing);
        state.addClient('10.0.0.2', picking);
        state.handleClientMessage('10.0.0.1', playing, 'pt5');
        assert.deepStrictEqual(state.teamSockets(), [playing]);
    });

    test('skip a team whose phone has not come back since a restart', () => {
        const store = memoryStore({ picks: { '10.0.0.1': '5' }, savedAt: new Date(), stale: false });
        const state = new QuizState(recordingTransport(), { numTeams: 14, store: store });
        assert.deepStrictEqual(state.teamSockets(), []);
    });
});


describe('a real server restarting under a phone', () => {
    let unmute;
    before(() => { unmute = muteLogs(); });
    after(() => unmute());

    function start(file) {
        const handle = startWebsocketServers({
            certs: testCerts(), dev: true, picksFile: file,
            clientWssPort: 0, serverPort: 0, ledsPort: 0,
            bindAddress: '127.0.0.1', wsBindAddress: '127.0.0.1'
        });
        return handle.ready().then(() => handle);
    }

    function phone(port) {
        const ws = new WebSocket('wss://127.0.0.1:' + port + '/?vcid=restart', { rejectUnauthorized: false });
        const received = [];
        ws.on('message', m => received.push(m.toString()));
        ws.received = received;
        ws.until = function(pred) {
            return new Promise((resolve, reject) => {
                const t0 = Date.now();
                (function poll() {
                    const hit = received.find(pred);
                    if(hit) return resolve(hit);
                    if(Date.now() - t0 > 2000) return reject(new Error('never got it: ' + received));
                    setTimeout(poll, 20);
                })();
            });
        };
        return ws;
    }

    test('keeps the team when a file is given', async () => {
        const file = tempFile();
        let server = await start(file);
        let p = phone(server.ports().clientWss);
        await p.until(m => m === 'vipickteam');
        p.send('pt9');
        await p.until(m => m === 'ok9');
        p.close();
        await new Promise(resolve => server.close(resolve));

        server = await start(file);
        p = phone(server.ports().clientWss);
        await p.until(m => m.startsWith('vi'));
        assert.ok(!p.received.includes('vipickteam'), 'back at the picker: ' + p.received);
        p.send('re');
        await p.until(m => m === 'ok9');
        p.close();
        await new Promise(resolve => server.close(resolve));
    });

    test('forgets it with no file, which is what --nostorage gives', async () => {
        let server = await start(null);
        let p = phone(server.ports().clientWss);
        await p.until(m => m === 'vipickteam');
        p.send('pt9');
        await p.until(m => m === 'ok9');
        p.close();
        await new Promise(resolve => server.close(resolve));

        server = await start(null);
        p = phone(server.ports().clientWss);
        await p.until(m => m === 'vipickteam');
        p.close();
        await new Promise(resolve => server.close(resolve));
    });
});
