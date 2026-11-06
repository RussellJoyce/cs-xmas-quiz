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
const { firefox, webkit } = require('playwright');

//E2E_PHONES=touch runs the phones in WebKit with a touchscreen instead of Firefox with a mouse.
//The phone page listens for touchstart rather than mousedown whenever touch is available, so
//every press on a phone has to go through Phone.press, tapAt or drag to work in both.
const TOUCH = process.env.E2E_PHONES === 'touch';
//The shortest gap between two touches on one phone, a little over the pages' longest guard
const TOUCH_GAP_MS = 600;

const { startWebsocketServers, startWebServers } = require('../../server');
const { muteLogs, testCerts } = require('../helpers');
const { writeFixtures } = require('./fixtures');

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
            //A Playwright call on a page part way through navigating can wait for ever
            let stuck;
            last = await Promise.race([check(), new Promise((_, reject) => {
                stuck = setTimeout(() => reject(new Error('the check itself got stuck')), Math.max(deadline - Date.now(), 1000));
            })]);
            clearTimeout(stuck);
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
        //Nothing more is coming, so anything still waiting has failed, and at once
        this.dead = false;
        socket.on('close', () => {
            this.dead = true;
            this.waiting.forEach(w => w.reject(new Error('probe: the app has gone away')));
            this.waiting.clear();
        });
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
        if(this.dead) return Promise.reject(new Error('probe: the app has gone away'));
        return new Promise((resolve, reject) => {
            //The app dying, or a command it cannot answer, should fail the scenario and not hang it
            const timer = setTimeout(() => {
                this.waiting.delete(id);
                reject(new Error('probe: no answer to ' + op + ' ' + (path || '')));
            }, 10000);
            this.waiting.set(id, {
                resolve: result => { clearTimeout(timer); resolve(result); },
                reject: err => { clearTimeout(timer); reject(err); }
            });
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
}

//One team's phone: the real game.js, in one of the harness's iframes
class Phone {
    constructor(page, number) {
        this.page = page;
        this.number = number;
        this.frame = page.frameLocator('#screen-' + number + ' iframe');
        this.buzzer = this.frame.locator('#buzzer');
        this.textbox = this.frame.locator('#textbox');
        this.enter = this.frame.locator('#textenterbutton');
        this.higher = this.frame.locator('#higher');
        this.lower = this.frame.locator('#lower');
        this.map = this.frame.locator('#geoimg');
        this.pin = this.frame.locator('#geomark');
        this.waveTrack = this.frame.locator('#wavetrack');
        this.waveValue = this.frame.locator('#wavevalue');
        this.article = this.frame.locator('#article');
        this.articleTitle = this.frame.locator('#title');
        this.hops = this.frame.locator('#hops');
        this.back = this.frame.locator('#back');
    }

    tile(option) { return this.frame.locator('#multibutton' + option); }
    teamButton(team) { return this.frame.locator('#teambutton' + team); }
    tiles() { return this.frame.locator('.multiButton').count(); }
    wallTile(word) { return this.frame.locator('.wallTile').filter({ hasText: new RegExp('^' + word + '$') }); }
    wallTileCount(cls) { return this.frame.locator('.wallTile.' + cls).count(); }
    link(title) { return this.article.locator('a').filter({ hasText: title }); }

    //Touches come no faster than a person makes them. The pages cancel a touchend that comes
    //soon after the previous one (400ms in the wiki race, 500ms elsewhere), so that iOS cannot
    //turn a double tap into two clicks, and a test tapping at machine speed loses its taps.
    async humanPace() {
        const wait = (this.lastTouch || 0) + TOUCH_GAP_MS - Date.now();
        if(wait > 0) await new Promise(resolve => setTimeout(resolve, wait));
    }

    async touched(action) {
        await this.humanPace();
        try { await action(); } finally { this.lastTouch = Date.now(); }
    }

    //A press on an element: a tap on a touchscreen, a click with a mouse
    async press(locator) {
        if(TOUCH) await this.touched(() => locator.tap());
        else await locator.click();
    }

    //A tap at a fraction of the way across and down an element. In page coordinates, as the
    //harness scales its phones and a locator's click position does not allow for that.
    async tapAt(locator, fx, fy) {
        const box = await locator.boundingBox();
        const x = box.x + box.width * fx, y = box.y + box.height * fy;
        if(TOUCH) await this.touched(() => this.page.touchscreen.tap(x, y));
        else await this.page.mouse.click(x, y);
    }

    //A drag across an element, at height fy, from fraction fromX to toX of its width.
    //Playwright's touchscreen can only tap, so a touch drag is made of touch events sent by
    //hand. Those are in the phone's own coordinates, as they are dispatched inside its frame.
    async drag(locator, fromX, toX, fy, steps = 10) {
        const along = i => fromX + (toX - fromX) * i / steps;
        if(TOUCH) {
            const rect = await locator.evaluate(el => {
                const r = el.getBoundingClientRect();
                return { x: r.left, y: r.top, width: r.width, height: r.height };
            });
            const touch = f => [{ identifier: 0, clientX: rect.x + rect.width * f, clientY: rect.y + rect.height * fy }];
            const send = (type, touches, changed) =>
                locator.dispatchEvent(type, { touches, targetTouches: touches, changedTouches: changed });

            await this.touched(async () => {
                await send('touchstart', touch(fromX), touch(fromX));
                for(let i = 1; i <= steps; i++) await send('touchmove', touch(along(i)), touch(along(i)));
                await send('touchend', [], touch(toX));
            });
        } else {
            const box = await locator.boundingBox();
            const at = f => [box.x + box.width * f, box.y + box.height * fy];
            await this.page.mouse.move(...at(fromX));
            await this.page.mouse.down();
            for(let i = 1; i <= steps; i++) await this.page.mouse.move(...at(along(i)));
            await this.page.mouse.up();
        }
    }

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
        await this.press(this.enter);
    }

    async hasClass(locator, name) {
        return ((await locator.getAttribute('class')) || '').split(/\s+/).includes(name);
    }
}

//Everything the rounds need in order to be entered and recognised, named as RoundType is
const ROUNDS = {
    idleSnow:    { tab: 'tabitemIdleSnow',    scene: 'SnowIdleScene',    view: 'buzzer' },
    buzzers:     { tab: 'tabitemBuzzers',     scene: 'BuzzerScene',      view: 'buzzer' },
    text:        { tab: 'tabitemText',        scene: 'TextScene',        view: 'text' },
    trueFalse:   { tab: 'tabitemtruefalse',   scene: 'TrueFalseScene',   view: 'higherlower' },
    multichoice: { tab: 'tabitemMultiChoice', scene: 'MultiChoiceScene', view: 'multi' },
    geography:   { tab: 'tabitemGeography',   scene: 'GeographyScene',   view: 'geo' },
    numbers:     { tab: 'tabitemNumbers',     scene: 'NumbersScene',     view: 'text' },
    pointless:   { tab: 'tabitemPointless',   scene: 'PointlessScene',   view: 'text' },
    wavelength:  { tab: 'tabitemWavelength',  scene: 'WavelengthScene',  view: 'wavelength' },
    onlyConnect: { tab: 'tabitemOnlyConnect', scene: 'OnlyConnectScene', view: 'onlyconnect' },
    timer:       { tab: 'tabitemTimer',       scene: 'TimerScene',       view: 'buzzer' },
    scores:      { tab: 'tabitemScores',      scene: 'ScoresScene',      view: 'buzzer' },
    wikirace:    { tab: 'tabitemWikiRace',    scene: 'WikiRaceScene',    view: null } //A page of its own
};

async function startQuiz(options) {
    //How many teams the phones and the server have. The app is told the same unless a scenario
    //wants them to disagree, as they will if the host starts it with fewer than config.json.
    const teams = options.teams;
    const appTeams = options.appTeams || teams;
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

        //The real questions are neither in git nor stable
        const root = fs.mkdtempSync(path.join(os.tmpdir(), 'quiz-e2e-root-'));
        cleanups.push(() => fs.rmSync(root, { recursive: true, force: true }));
        const { staticDir, wikiDir } = writeFixtures(root);
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
                bindAddress: '127.0.0.1', wsBindAddress: '127.0.0.1', wikiDir
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
            certs, dev: true, httpPort: 0, httpsPort: 0, bindAddress: '127.0.0.1', staticDir
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
                    QUIZ_TEAMS: String(appTeams)
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
        //Headless unless asked, as a covered window stops producing animation frames, and
        //Playwright waits for those before it will click. E2E_HEADED=1 to watch the phones.
        const browser = await (TOUCH ? webkit : firefox).launch({ headless: !process.env.E2E_HEADED });
        cleanups.push(() => browser.close());
        //Not isMobile, which would also apply the harness page's meta viewport and lay it out
        //again. hasTouch alone is what makes the phone page choose touchstart.
        const context = await browser.newContext({
            ignoreHTTPSErrors: true,
            viewport: { width: 1300, height: 800 },
            hasTouch: TOUCH
        });
        //A locator that will never resolve should say so soon, as a scenario has many of them
        context.setDefaultTimeout(8000);
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
                //Not by scene, as the old one is still on show during the transition
                if((await host.scene()).round === name) await host.click('resetRound:');
                else await host.click(round.tab);
                await until('the ' + round.scene, async () => (await host.scene()).scene === round.scene);
                for(const n of phonesToCheck || phones.keys()) {
                    if(!phones[n]) continue;
                    if(round.view) {
                        await until('phone ' + n + ' on view ' + round.view, async () => (await phones[n].view()) === round.view);
                    } else {
                        await until('phone ' + n + ' on its page', async () => (await phones[n].article.count()) === 1);
                    }
                }
            },

            //A phone tap, once it is certain the app has had it. Without this, asserting that
            //the app ignored something could pass only because it had not arrived yet.
            async tapped(n, code, locator) {
                const seen = wire.filter(w => w.dir === 'T' + n + '→srv' && w.msg.startsWith(code)).length;
                await phones[n].press(locator);
                await until('team ' + n + "'s " + code + ' to reach the server', () =>
                    wire.filter(w => w.dir === 'T' + n + '→srv' && w.msg.startsWith(code)).length > seen);
                await host.settled();
            },

            //The numbered buttons fire virtual buzzes until the mode button is switched over
            async setPlaying(n, playing) {
                await host.setToggle('virtualBuzzersBtn', false);
                await host.setToggle('buzzerButton' + n, !playing);
                //The race page has no button to grey
                await until('phone ' + n + ' to go ' + (playing ? 'on' : 'off'), async () =>
                    (await phones[n].buzzer.count()) === 0 || (await phones[n].isOn()) === playing);
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

            //Anything at all, down a phone's own socket, once the app has dealt with it. This
            //is what a confused page or a hand-rolled client can send, so the server still
            //gets its say on who is allowed to send what.
            async rawFrom(n, message) {
                const since = wire.length;
                //Through the page's own socket, as the race page does not lend it to the harness
                await phones[n].frame.locator('body').evaluate((_, m) => ws.send(m), message);
                await until('"' + message + '" to reach the server', () => wire.has('T' + n + '→srv', message, since));
                await host.settled();
            },

            //Back to everybody playing, whatever the last scenario left behind
            async allPlaying() {
                await host.setToggle('virtualBuzzersBtn', false);
                for(let n = 1; n <= appTeams; n++) {
                    if((await host.read('buzzerButton' + n)).on) await quiz.setPlaying(n, true);
                }
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

            //The same, for a page without a buzzer to show the team
            async phoneReconnected(n, since) {
                await until('phone ' + n + ' to reconnect', () => wire.has('T' + n + '→srv', 're', since));
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
                //A crash is the finding. The scenarios after it can still say something.
                if(quiz.host.dead) {
                    const log = quiz.appLog.join('').slice(-1500);
                    await quiz.restartApp();
                    err.message = 'THE APP CRASHED. ' + err.message + '\n\nApp log:\n' + log;
                }
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

module.exports = { buildApp, startQuiz, quizScenarios, until, TOUCH };
