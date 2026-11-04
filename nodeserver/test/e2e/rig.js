'use strict';

//Runs the whole quiz for an end-to-end test: the real node server in this process, the real
//Quiz Server app, and real phone pages in the multi-client harness.
//
//    scenario ──Playwright──▶ harness + phones ──wss──▶ node server ◀──ws── Quiz Server.app
//    scenario ──────────────── probe socket ──────────────────────────────▶ (TestProbe.swift)
//
//Everything uses ephemeral ports and throwaway certificates, so a real server left running
//on this machine is neither disturbed nor talked to by mistake.

const { execFileSync, spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const WebSocket = require('ws');
const { firefox } = require('playwright');

const { startWebsocketServers, startWebServers } = require('../../server');
const { muteLogs, testCerts } = require('../helpers');

const REPO = path.resolve(__dirname, '../../..');
const DERIVED = path.join(REPO, 'nodeserver/.e2e-build');
const APP_BINARY = path.join(DERIVED, 'Build/Products/Debug/Quiz Server.app/Contents/MacOS/Quiz Server');
const POLL_MS = 50;

//Incremental, so this is only slow the first time. Unsigned, as it only ever runs from here.
function buildApp() {
    try {
        execFileSync('xcodebuild', [
            '-project', path.join(REPO, 'Quiz Server/Quiz Server.xcodeproj'),
            '-scheme', 'Quiz Server', '-configuration', 'Debug',
            '-derivedDataPath', DERIVED, 'CODE_SIGNING_ALLOWED=NO', '-quiet', 'build'
        ], { stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 64 * 1024 * 1024 });
    } catch(err) {
        throw new Error('xcodebuild failed:\n' + String(err.stdout).slice(-4000) + String(err.stderr).slice(-4000));
    }
}

//Polls until `check` returns something truthy, and returns that. Scenarios wait with this
//and never with a fixed sleep. A failure says what was last seen rather than only "timed out".
async function until(what, check, timeoutMs) {
    const deadline = Date.now() + (timeoutMs || 10000);
    let last;
    for(;;) {
        try {
            last = await check();
            if(last) return last;
        } catch(err) {
            last = err.message;
        }
        if(Date.now() > deadline) {
            throw new Error('timed out waiting for ' + what + '. Last saw: ' + JSON.stringify(last));
        }
        await new Promise(resolve => setTimeout(resolve, POLL_MS));
    }
}

//Records what crosses the node server, so a failure can show the conversation.
function tapWire(state) {
    const wire = [];
    const started = Date.now();
    const note = (dir, msg) => wire.push({ t: Date.now() - started, dir: dir, msg: String(msg) });

    const fromHost = state.handleServerMessage.bind(state);
    state.handleServerMessage = raw => { note('host→srv', raw); fromHost(raw); };
    const fromClient = state.handleClientMessage.bind(state);
    state.handleClientMessage = (key, sock, raw) => { note(state.label(key) + '→srv', raw); fromClient(key, sock, raw); };

    ['toClients', 'toServers', 'toLeds'].forEach(name => {
        const real = state.transport[name];
        state.transport[name] = msg => { note('srv→' + name.slice(2).toLowerCase(), msg); real(msg); };
    });

    wire.has = (dir, msg) => wire.some(w => w.dir === dir && w.msg === msg);
    //The poll is once a second for as long as the app runs, and only ever noise
    wire.dump = () => wire.filter(w => !['ls', 'pi', 'co'].includes(w.msg) && !/^lr/.test(w.msg))
                          .map(w => String(w.t).padStart(7) + '  ' + w.dir.padEnd(12) + w.msg).join('\n');
    return wire;
}

//The quiz software, as seen through TestProbe.swift
class Host {
    constructor(socket) {
        this.socket = socket;
        this.nextId = 1;
        this.waiting = new Map();
        socket.on('message', data => {
            const reply = JSON.parse(data.toString());
            const w = this.waiting.get(reply.id);
            if(!w) return;
            this.waiting.delete(reply.id);
            if(reply.error) w.reject(new Error('probe: ' + reply.error));
            else w.resolve(reply.result);
        });
    }

    command(op, path, value) {
        const id = this.nextId++;
        return new Promise((resolve, reject) => {
            this.waiting.set(id, { resolve, reject });
            this.socket.send(JSON.stringify({ id, op, path, value }));
        });
    }

    click(path) { return this.command('click', path); }
    set(path, value) { return this.command('set', path, value); }
    read(path) { return this.command('read', path); }
    scene() { return this.command('scene'); }
    screenshot(file) { return this.command('screenshot', file); }
    window(action) { return this.command('window', action); }

    //Resolves once the app has handled everything the server has sent it so far. Without
    //this, asserting that the app ignored something can pass only because it has not arrived.
    async settled() {
        const before = await this.command('barriers');
        this.sendToApp('co');
        await until('the app to catch up', async () => (await this.command('barriers')) > before);
    }

    //Text on the audience's screen, as far as it is actually visible: a label inside a node
    //that is faded out does not count.
    async visibleText() {
        const found = [];
        const walk = (node, alpha) => {
            const seen = alpha * node.alpha;
            if(node.hidden || seen <= 0.01) return;
            if(node.text) found.push(node.text);
            (node.children || []).forEach(child => walk(child, seen));
        };
        const scene = await this.scene();
        if(scene.nodes) walk(scene.nodes, 1);
        return found;
    }

    //Reports how long a 0.2s SKAction really took, or null if it never finished.
    renderTick(timeoutMs) {
        return Promise.race([
            this.command('renderTick'),
            new Promise(resolve => setTimeout(() => resolve(null), timeoutMs || 3000))
        ]);
    }
}

//One team's phone: the real game.js, in one of the harness's iframes
class Phone {
    constructor(page, number) {
        this.frame = page.frameLocator('#screen-' + number + ' iframe');
        this.buzzer = this.frame.locator('#buzzer');
    }

    async isOn() {
        return /buttonOn/.test(await this.buzzer.getAttribute('class'));
    }
}

async function startQuiz(options) {
    const teams = options.teams;
    const unmute = muteLogs();
    const cleanups = [unmute];
    const close = async () => {
        for(const clean of cleanups.reverse()) {
            try { await clean(); } catch(err) { console.error('cleanup: ' + err.message); }
        }
    };

    try {
        const certs = testCerts();

        //An empty root, and no corpus: the real questions are neither in git nor stable
        const root = fs.mkdtempSync(path.join(os.tmpdir(), 'quiz-e2e-root-'));
        cleanups.push(() => fs.rmSync(root, { recursive: true, force: true }));

        const ws = startWebsocketServers({
            certs, dev: true, numTeams: teams, clientWssPort: 0, serverPort: 0, ledsPort: 0,
            bindAddress: '127.0.0.1', wsBindAddress: '127.0.0.1', wikiDir: root
        });
        cleanups.push(() => new Promise(resolve => {
            [...ws.servers.wserver.clients, ...ws.servers.wleds.clients, ...ws.servers.wclient.clients]
                .forEach(c => c.terminate());
            ws.close(resolve);
        }));
        await ws.ready();
        const wire = tapWire(ws.state);

        const web = startWebServers({
            certs, dev: true, httpPort: 0, httpsPort: 0, bindAddress: '127.0.0.1'
        });
        cleanups.push(() => {
            web.server.close();
            web.http.close();
            web.server.closeAllConnections();
            web.http.closeAllConnections();
        });
        await new Promise(resolve => web.server.listening ? resolve() : web.server.once('listening', resolve));

        //The LED port, as a board would see it
        const leds = [];
        const ledSocket = new WebSocket('ws://127.0.0.1:' + ws.ports().leds);
        ledSocket.on('message', data => leds.push(data.toString()));
        cleanups.push(() => ledSocket.terminate());

        //The app dials out to this once its controller window is up
        const probeServer = new WebSocket.Server({ host: '127.0.0.1', port: 0 });
        cleanups.push(() => new Promise(resolve => {
            probeServer.clients.forEach(c => c.terminate());
            probeServer.close(resolve);
        }));
        await new Promise(resolve => probeServer.once('listening', resolve));
        const probeConnected = new Promise(resolve => probeServer.once('connection', resolve));

        const appLog = [];
        const app = spawn(APP_BINARY, ['-ApplePersistenceIgnoreState', 'YES'], {
            env: Object.assign({}, process.env, {
                QUIZ_TEST_PROBE: 'ws://127.0.0.1:' + probeServer.address().port + '/',
                QUIZ_SERVER_URL: 'ws://127.0.0.1:' + ws.ports().server + '/',
                QUIZ_ROOT: root,
                QUIZ_TEAMS: String(teams)
            }),
            stdio: ['ignore', 'pipe', 'pipe']
        });
        app.stdout.on('data', d => appLog.push(d.toString()));
        app.stderr.on('data', d => appLog.push(d.toString()));
        const appExited = new Promise(resolve => app.once('exit', (code, signal) => resolve({ code, signal })));
        cleanups.push(() => {
            app.kill('SIGKILL');
            return appExited;
        });

        const socket = await Promise.race([
            probeConnected,
            appExited.then(how => {
                throw new Error('the app exited during launch: ' + JSON.stringify(how) + '\n' + appLog.join(''));
            }),
            new Promise((_, reject) => setTimeout(() => reject(new Error(
                'the app did not reach the probe in 30s\n' + appLog.join(''))), 30000))
        ]);
        const host = new Host(socket);
        host.sendToApp = msg => ws.state.transport.toServers(msg);

        const browser = await firefox.launch({ headless: !!process.env.E2E_HEADLESS });
        cleanups.push(() => browser.close());
        const context = await browser.newContext({
            ignoreHTTPSErrors: true,
            viewport: { width: 1300, height: 800 }
        });
        const page = await context.newPage();
        const pageErrors = [];
        page.on('pageerror', err => pageErrors.push(err.message));

        await page.goto('https://127.0.0.1:' + web.server.address().port + '/test/multi-client.html');
        await page.fill('#cfg-port', String(ws.ports().clientWss));
        await page.check('#cfg-displayall');
        await page.selectOption('#cfg-count', String(teams));
        await page.evaluate(() => connectAll());

        const phones = [null];
        for(let n = 1; n <= teams; n++) phones[n] = new Phone(page, n);

        //Every phone has been given its team by the server, and has shown it
        for(let n = 1; n <= teams; n++) {
            await until('phone ' + n + ' to hold team ' + n,
                        async () => (await phones[n].buzzer.textContent()) === 'TEAM ' + n);
        }

        return { host, phones, page, wire, leds, appLog, pageErrors, until, close };
    } catch(err) {
        await close();
        throw err;
    }
}

module.exports = { buildApp, startQuiz, until };
