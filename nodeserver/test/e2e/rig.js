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

function newestChange(dir) {
    let newest = 0;
    for(const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        newest = Math.max(newest, entry.isDirectory() ? newestChange(full) : fs.statSync(full).mtimeMs);
    }
    return newest;
}

//Each scenario file is its own process and would otherwise spend 20s asking xcodebuild to do
//nothing, so it is only asked when a source has changed since it last succeeded.
function buildApp() {
    const stamp = path.join(DERIVED, 'built-ok');
    const project = path.join(REPO, 'Quiz Server/Quiz Server.xcodeproj');
    const changed = Math.max(newestChange(path.join(REPO, 'Quiz Server/Quiz Server')), newestChange(project));
    if(fs.existsSync(stamp) && fs.statSync(stamp).mtimeMs > changed) return;

    try {
        //Unsigned, as it only ever runs from here
        execFileSync('xcodebuild', [
            '-project', project, '-scheme', 'Quiz Server', '-configuration', 'Debug',
            '-derivedDataPath', DERIVED, 'CODE_SIGNING_ALLOWED=NO', '-quiet', 'build'
        ], { stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 64 * 1024 * 1024 });
    } catch(err) {
        throw new Error('xcodebuild failed:\n' + String(err.stdout).slice(-4000) + String(err.stderr).slice(-4000));
    }
    fs.writeFileSync(stamp, '');
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

//Records what crosses the node server, so a failure can show the conversation. The record
//outlives any one server, and carries on through a restart.
function newWire() {
    const wire = [];
    const started = Date.now();
    wire.note = (dir, msg) => wire.push({ t: Date.now() - started, dir: dir, msg: String(msg) });
    wire.has = (dir, msg, since) => wire.slice(since || 0).some(w => w.dir === dir && w.msg === msg);
    //The poll is once a second for as long as the app runs, and only ever noise
    wire.dump = () => wire.filter(w => !['ls', 'pi', 'co'].includes(w.msg) && !/^lr/.test(w.msg))
                          .map(w => String(w.t).padStart(7) + '  ' + w.dir.padEnd(12) + w.msg).join('\n');
    return wire;
}

function tapWire(state, wire) {
    const fromHost = state.handleServerMessage.bind(state);
    state.handleServerMessage = raw => { wire.note('host→srv', raw); fromHost(raw); };
    const fromClient = state.handleClientMessage.bind(state);
    state.handleClientMessage = (key, sock, raw) => { wire.note(state.label(key) + '→srv', raw); fromClient(key, sock, raw); };

    ['toClients', 'toServers', 'toLeds'].forEach(name => {
        const real = state.transport[name];
        state.transport[name] = msg => { wire.note('srv→' + name.slice(2).toLowerCase(), msg); real(msg); };
    });
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

    //Checkboxes and toggles, without having to know how they start
    async setToggle(path, on) {
        if((await this.read(path)).on !== on) await this.click(path);
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
        this.number = number;
        this.frame = page.frameLocator('#screen-' + number + ' iframe');
        this.buzzer = this.frame.locator('#buzzer');
        this.textbox = this.frame.locator('#textbox');
        this.enter = this.frame.locator('#textenterbutton');
        this.higher = this.frame.locator('#higher');
        this.lower = this.frame.locator('#lower');
        this.map = this.frame.locator('#geoimg');
        this.pin = this.frame.locator('#geomark');
    }

    tile(option) { return this.frame.locator('#multibutton' + option); }
    teamButton(team) { return this.frame.locator('#teambutton' + team); }
    tiles() { return this.frame.locator('.multiButton').count(); }

    async isOn() {
        return /buttonOn/.test(await this.buzzer.getAttribute('class'));
    }

    //Which of the page's views is on show
    view() {
        return this.frame.locator('.view').evaluateAll(views =>
            views.filter(v => getComputedStyle(v).display !== 'none').map(v => v.id).join());
    }

    async answerText(text) {
        await this.textbox.fill(text);
        await this.enter.click();
    }

    async hasClass(locator, name) {
        return ((await locator.getAttribute('class')) || '').split(/\s+/).includes(name);
    }
}

//Everything the rounds need in order to be entered and recognised
const ROUNDS = {
    idle:        { tab: 'tabitemIdleSnow',    scene: 'SnowIdleScene',    view: 'buzzer' },
    buzzers:     { tab: 'tabitemBuzzers',     scene: 'BuzzerScene',      view: 'buzzer' },
    text:        { tab: 'tabitemText',        scene: 'TextScene',        view: 'text' },
    trueFalse:   { tab: 'tabitemtruefalse',   scene: 'TrueFalseScene',   view: 'higherlower' },
    multichoice: { tab: 'tabitemMultiChoice', scene: 'MultiChoiceScene', view: 'multi' },
    geography:   { tab: 'tabitemGeography',   scene: 'GeographyScene',   view: 'geo' }
};

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
        const wire = newWire();
        const leds = [];

        //An empty root, and no corpus: the real questions are neither in git nor stable
        const root = fs.mkdtempSync(path.join(os.tmpdir(), 'quiz-e2e-root-'));
        cleanups.push(() => fs.rmSync(root, { recursive: true, force: true }));
        const picksFile = path.join(root, 'picks.json');


        //--- The node server. Ports are kept once chosen, so that a restart is the same server
        //    to everything trying to get back to it.
        let ws = null;
        let ledSocket = null;
        let ports = { clientWss: 0, server: 0, leds: 0 };

        async function startServer() {
            ws = startWebsocketServers({
                certs, dev: true, numTeams: teams, picksFile,
                clientWssPort: ports.clientWss, serverPort: ports.server, ledsPort: ports.leds,
                bindAddress: '127.0.0.1', wsBindAddress: '127.0.0.1', wikiDir: root
            });
            await ws.ready();
            ports = ws.ports();
            tapWire(ws.state, wire);

            //The LED port, as a board would see it
            ledSocket = new WebSocket('ws://127.0.0.1:' + ports.leds);
            ledSocket.on('message', data => leds.push(data.toString()));
            ledSocket.on('error', () => {});
        }

        function stopServer() {
            ledSocket.terminate();
            const { wclient, wserver, wleds } = ws.servers;
            return new Promise(resolve => {
                [...wserver.clients, ...wleds.clients, ...wclient.clients].forEach(c => c.terminate());
                ws.close(resolve);
            });
        }

        await startServer();
        cleanups.push(() => stopServer());

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


        //--- The app. It dials out to this once its controller window is up.
        const probeServer = new WebSocket.Server({ host: '127.0.0.1', port: 0 });
        cleanups.push(() => new Promise(resolve => {
            probeServer.clients.forEach(c => c.terminate());
            probeServer.close(resolve);
        }));
        await new Promise(resolve => probeServer.once('listening', resolve));

        const appLog = [];
        let killApp = null;
        let host = null;

        async function launchApp() {
            const probeConnected = new Promise(resolve => probeServer.once('connection', resolve));
            const app = spawn(APP_BINARY, ['-ApplePersistenceIgnoreState', 'YES'], {
                env: Object.assign({}, process.env, {
                    QUIZ_TEST_PROBE: 'ws://127.0.0.1:' + probeServer.address().port + '/',
                    QUIZ_SERVER_URL: 'ws://127.0.0.1:' + ports.server + '/',
                    QUIZ_ROOT: root,
                    QUIZ_TEAMS: String(teams)
                }),
                stdio: ['ignore', 'pipe', 'pipe']
            });
            app.stdout.on('data', d => appLog.push(d.toString()));
            app.stderr.on('data', d => appLog.push(d.toString()));
            const appExited = new Promise(resolve => app.once('exit', (code, signal) => resolve({ code, signal })));
            killApp = () => { app.kill('SIGKILL'); return appExited; };

            let launchTimer;
            const socket = await Promise.race([
                probeConnected,
                appExited.then(how => {
                    throw new Error('the app exited during launch: ' + JSON.stringify(how) + '\n' + appLog.join(''));
                }),
                new Promise((_, reject) => {
                    launchTimer = setTimeout(() => reject(new Error(
                        'the app did not reach the probe in 30s\n' + appLog.join(''))), 30000);
                })
            ]);
            clearTimeout(launchTimer); //Or the test process waits it out before it can exit
            host = new Host(socket);
            host.sendToApp = msg => ws.state.transport.toServers(msg);
        }

        await launchApp();
        cleanups.push(() => killApp());


        //--- The phones
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
        await page.fill('#cfg-port', String(ports.clientWss));
        await page.check('#cfg-displayall');
        await page.selectOption('#cfg-count', String(teams));
        await page.evaluate(() => connectAll());

        const phones = [null];
        for(let n = 1; n <= teams; n++) phones[n] = new Phone(page, n);

        async function phoneHoldsTeam(n) {
            await until('phone ' + n + ' to hold team ' + n,
                        async () => (await phones[n].buzzer.textContent()) === 'TEAM ' + n);
        }
        for(let n = 1; n <= teams; n++) await phoneHoldsTeam(n);


        const quiz = {
            phones, page, wire, leds, appLog, pageErrors, until, close,
            get host() { return host; },

            //Moves to a round and waits until the display and every phone have got there.
            //Entering the round already on show would do nothing, so that is a reset instead.
            async round(name, phonesToCheck) {
                const round = ROUNDS[name];
                if((await host.scene()).scene === round.scene) await host.click('resetRound:');
                else await host.click(round.tab);
                await until('the ' + round.scene, async () => (await host.scene()).scene === round.scene);
                for(const n of phonesToCheck || phones.keys()) {
                    if(!phones[n]) continue;
                    await until('phone ' + n + ' on view ' + round.view, async () => (await phones[n].view()) === round.view);
                }
            },

            //A phone tap, once it is certain the app has had it. Without this, asserting that
            //the app ignored something could pass only because it had not arrived yet.
            async tapped(n, code, locator) {
                const seen = wire.filter(w => w.dir === 'T' + n + '→srv' && w.msg.startsWith(code)).length;
                await locator.click();
                await until('team ' + n + "'s " + code + ' to reach the server', () =>
                    wire.filter(w => w.dir === 'T' + n + '→srv' && w.msg.startsWith(code)).length > seen);
                await host.settled();
            },

            //The numbered buttons fire virtual buzzes until the mode button is switched over
            async setPlaying(n, playing) {
                await host.setToggle('virtualBuzzersBtn', false);
                await host.setToggle('buzzerButton' + n, !playing);
                await until('phone ' + n + ' to go ' + (playing ? 'on' : 'off'),
                            async () => (await phones[n].isOn()) === playing);
            },


            //--- Things going wrong

            //The server dies and comes back. The picks file survives that, unless told otherwise.
            async restartServer(opts) {
                await stopServer();
                if(opts && opts.losePicks) fs.rmSync(picksFile, { force: true });
                await startServer();
            },

            //A crash rather than a quit: nothing gets to say goodbye
            async restartApp() {
                await killApp();
                await launchApp();
            },

            //A message as though from the app, for a round whose questions are not in the fixtures
            asHost(message) {
                ws.state.handleServerMessage(message);
            },

            //The wifi going: the phone sees its socket die and has to reconnect
            dropPhone(n) {
                ws.state.getClientByID(n).sock.terminate();
            },

            reloadPhone(n) { return page.evaluate(i => clients[i].reloadPhone(), n); },
            powerPhone(n, on) { return page.evaluate(([i, o]) => clients[i].powerPhone(o), [n, on]); },

            //Waits until a phone has reconnected since this point in the wire, and holds its team
            async phoneBack(n, since) {
                await until('phone ' + n + ' to reconnect', () => wire.has('T' + n + '→srv', 're', since));
                await phoneHoldsTeam(n);
            },

            //Waits until the app has reconnected to the server and told it the state of play
            async appResynced(since) {
                await until('the app to resync', () =>
                    wire.slice(since).some(w => w.dir === 'host→srv' && w.msg.startsWith('rsvs')));
                await host.settled();
            }
        };
        return quiz;
    } catch(err) {
        await close();
        throw err;
    }
}

//One app, server and browser for a whole file of scenarios, with each failure explained.
function quizScenarios(name, options, body) {
    const nodeTest = require('node:test');
    nodeTest.describe(name, () => {
        let quiz = null;
        nodeTest.before(async () => {
            buildApp();
            quiz = await startQuiz(options);
            if(options.setUp) await options.setUp(quiz);
        });
        nodeTest.after(async () => { if(quiz) await quiz.close(); });

        //What a failure needs in order to be understood: the conversation, and the picture.
        const scenario = (title, fn, testOptions) => nodeTest.test(title, testOptions || {}, async () => {
            try {
                await fn(quiz);
            } catch(err) {
                const shot = path.join(os.tmpdir(), 'quiz-e2e-' + title.replace(/\W+/g, '-').slice(0, 50) + '.png');
                await quiz.host.screenshot(shot).catch(() => {});
                //A new error, because node:test prints an AssertionError's diff and not its message
                throw new Error(err.message + '\n\nWire:\n' + quiz.wire.dump() + '\n\nScreenshot: ' + shot, { cause: err });
            }
        });

        body(scenario);

        scenario('no phone page threw an error', async q => {
            require('node:assert').deepStrictEqual(q.pageErrors, []);
        });
    });
}

module.exports = { buildApp, startQuiz, quizScenarios, until };
