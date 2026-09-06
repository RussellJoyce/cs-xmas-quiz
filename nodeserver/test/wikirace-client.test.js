'use strict';

//The wikirace client's protocol handling, driven without a browser.
//
//The client is the half of the round that decides what a team sees, and most of what it
//does is react to messages. A stub DOM is enough to drive all of that, and catches the
//things that would otherwise only show up on a phone in a room full of people: a title
//with a comma in it, a refused move, a reconnect part way through a race.

const { test, describe, beforeEach } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const STATIC = path.join(__dirname, '..', 'static');

//--- A DOM, of sorts -------------------------------------------------------------------

function makeElement(id) {
    const el = {
        id: id,
        textContent: '',
        innerHTML: '',
        scrollTop: 0,
        handlers: {},
        classes: new Set(),
        children: [],
        classList: {
            add: c => el.classes.add(c),
            remove: c => el.classes.delete(c),
            contains: c => el.classes.has(c)
        },
        addEventListener: (name, fn) => { (el.handlers[name] = el.handlers[name] || []).push(fn); },
        getAttribute: name => el.attrs[name],
        attrs: {},
        //Fires a handler the way a browser would.
        fire: (name, event) => (el.handlers[name] || []).forEach(fn => fn(event || {}))
    };
    return el;
}

//A link inside an article, as the click delegation sees it.
function makeLink(articleId) {
    const link = makeElement('a');
    link.attrs['data-s'] = String(articleId);
    link.closest = sel => (sel === 'a[data-s]' ? link : null);
    return link;
}

function loadClient(options) {
    const opts = options || {};
    const elements = {};
    ['article', 'title', 'page', 'target', 'hops', 'clock', 'here', 'back',
     'curtain', 'curtainIcon', 'curtainText', 'curtainSub', 'toast'].forEach(id => {
        elements[id] = makeElement(id);
    });

    const sockets = [];
    const navigations = [];
    const fetched = [];

    class FakeWebSocket {
        constructor(url) {
            this.url = url;
            this.readyState = 1;
            this.sent = [];
            sockets.push(this);
        }
        send(m) { this.sent.push(m); }
        close() { this.readyState = 3; if(this.onclose) this.onclose({}); }
        //Deliver a message from the server.
        deliver(m) { if(this.onmessage) this.onmessage({ data: m }); }
        drain() { const s = this.sent; this.sent = []; return s; }
    }
    FakeWebSocket.OPEN = 1;

    const documentStub = {
        getElementById: id => elements[id] || makeElement(id),
        addEventListener: () => {}
    };

    //The client traps the phone's back gesture, so the harness needs somewhere for those
    //history entries to go and a way to fire the gesture.
    const historyStub = {
        entries: [],
        pushState: (state, title, url) => historyStub.entries.push(url)
    };
    const windowHandlers = {};

    const locationStub = {
        search: opts.search || '?port=8093&vcid=phone1',
        hostname: 'localhost',
        pathname: '/wikirace/',
        get href() { return ''; },
        set href(v) { navigations.push(v); },
        //The pages swap with replace() rather than href, so that switching between the
        //buzzer and the wikirace does not leave entries for the back gesture to walk out on.
        replace: v => navigations.push(v)
    };

    const context = {
        document: documentStub,
        location: locationStub,
        history: historyStub,
        addEventListener: (name, fn) => { (windowHandlers[name] = windowHandlers[name] || []).push(fn); },
        WebSocket: FakeWebSocket,
        console: { log: () => {}, error: () => {} },
        setTimeout: () => 0,
        clearTimeout: () => {},
        setInterval: () => 0,
        clearInterval: () => {},
        Date: Date,
        Math: Math,
        parseInt: parseInt,
        String: String,
        fetch: function(url) {
            fetched.push(url);
            if(url.indexOf('meta.json') >= 0) {
                return Promise.resolve({ ok: true, json: () => Promise.resolve({ shard: 1000 }) });
            }
            const id = parseInt(url.slice(url.lastIndexOf('/') + 1), 10);
            if(opts.missing && opts.missing.indexOf(id) >= 0) {
                return Promise.resolve({ ok: false, status: 404 });
            }
            const body = {
                ok: true,
                json: () => Promise.resolve({
                    t: 'Article ' + id,
                    h: '<p>body of ' + id + '</p>',
                    l: [id + 1]
                })
            };
            //A response that lands after a later one, which is what broke resyncs.
            if(opts.slow && opts.slow.indexOf(id) >= 0) {
                return new Promise(resolve => {
                    let hops = 0;
                    const later = () => (++hops > 12 ? resolve(body) : Promise.resolve().then(later));
                    later();
                });
            }
            return Promise.resolve(body);
        }
    };
    context.window = context;
    vm.createContext(context);

    vm.runInContext(fs.readFileSync(path.join(STATIC, 'wsparams.js'), 'utf8'), context);
    vm.runInContext(fs.readFileSync(path.join(STATIC, 'wikirace', 'wikirace.js'), 'utf8'), context);

    return { elements, sockets, navigations, fetched, context,
             history: historyStub,
             //Fire the phone's back gesture.
             back: () => (windowHandlers.popstate || []).forEach(fn => fn({})),
             socket: () => sockets[sockets.length - 1] };
}

//The client connects only after it has read meta.json, so tests wait for that.
async function connected(client) {
    for(let i = 0; i < 20 && client.sockets.length === 0; i++) await Promise.resolve();
    const sock = client.socket();
    sock.onopen({});
    return sock;
}

//Article rendering is a fetch, so give the promises a chance to settle.
async function settle() {
    for(let i = 0; i < 20; i++) await Promise.resolve();
}

//--- Tests ------------------------------------------------------------------------------

describe('the wikirace client', () => {

    test('carries the vcid into its websocket URL', async () => {
        //Without this the harness wall becomes one client wearing fourteen hats.
        const client = loadClient();
        const sock = await connected(client);
        //wss and nothing else: the server has no plain client port any more.
        assert.match(sock.url, /^wss:\/\/localhost:8093\/\?vcid=phone1$/);
    });

    test('asks who it is as soon as it connects', async () => {
        const client = loadClient();
        const sock = await connected(client);
        assert.deepStrictEqual(sock.drain(), ['re']);
    });

    test('waits when there is no race running', async () => {
        const client = loadClient();
        const sock = await connected(client);
        sock.deliver('ok3');
        assert.match(client.elements.curtainText.textContent, /Ready|Waiting/);
    });

    describe('starting a race', () => {
        test('names the target, even when its title contains a comma', async () => {
            const client = loadClient();
            const sock = await connected(client);
            sock.deliver('ok1');
            sock.deliver('wr0,2,Start|Washington, D.C.');
            await settle();
            //Splitting on commas naively would show "Washington" here.
            assert.strictEqual(client.elements.target.textContent, 'Washington, D.C.');
        });

        test('does not render anything on its own: only wg puts a page on screen', async () => {
            //Two renders in flight at once is how a resynced client ends up showing a page
            //the server does not think it is on, with every visible link refused.
            const client = loadClient();
            const sock = await connected(client);
            sock.deliver('ok1');
            sock.deliver('wr7,2,Seven|Two');
            await settle();
            assert.deepStrictEqual(client.fetched.filter(u => u.indexOf('/a/') >= 0), []);
        });

        test('renders the start article when the server sends it', async () => {
            const client = loadClient();
            const sock = await connected(client);
            sock.deliver('ok1');
            sock.deliver('wr7,2,Seven|Two');
            sock.deliver('wg7,0');
            await settle();
            assert.ok(client.fetched.some(u => u.endsWith('/wiki/a/0/7.json')), client.fetched.join(', '));
            assert.strictEqual(client.elements.title.textContent, 'Article 7');
            assert.ok(client.elements.curtain.classList.contains('hidden'));
        });

        test('shards the article URL the way the corpus is laid out', async () => {
            const client = loadClient();
            const sock = await connected(client);
            sock.deliver('ok1');
            sock.deliver('wr12345,2,A|B');
            sock.deliver('wg12345,0');
            await settle();
            assert.ok(client.fetched.some(u => u.endsWith('/wiki/a/12/12345.json')), client.fetched.join(', '));
        });
    });

    describe('following a link', () => {
        async function racing() {
            const client = loadClient();
            const sock = await connected(client);
            sock.deliver('ok4');
            sock.deliver('wr0,99,Start|Target');
            sock.deliver('wg0,0');
            await settle();
            sock.drain();
            return { client, sock };
        }

        test('asks the server rather than just going there', async () => {
            const { client, sock } = await racing();
            client.elements.article.fire('click', { target: makeLink(42), preventDefault: () => {} });
            assert.deepStrictEqual(sock.drain(), ['wl4,42']);
            //Nothing on screen has changed: the server has not answered yet.
            assert.strictEqual(client.elements.title.textContent, 'Article 0');
        });

        test('renders only what the server authorises, and takes the hop count from it', async () => {
            const { client, sock } = await racing();
            client.elements.article.fire('click', { target: makeLink(42), preventDefault: () => {} });
            sock.deliver('wg42,1');
            await settle();
            assert.strictEqual(client.elements.title.textContent, 'Article 42');
            assert.strictEqual(client.elements.hops.textContent, 1);
        });

        test('a refused move leaves the team where it was, with the right hop count', async () => {
            //The client must never quietly disagree with the server about either.
            const { client, sock } = await racing();
            client.elements.article.fire('click', { target: makeLink(42), preventDefault: () => {} });
            sock.deliver('wx');
            await settle();
            assert.strictEqual(client.elements.title.textContent, 'Article 0');
            assert.strictEqual(client.elements.hops.textContent, 0);
            assert.match(client.elements.toast.textContent, /not a link/i);
        });

        test('a second tap while waiting is ignored', async () => {
            //Otherwise the second move is judged against a page the team has left.
            const { client, sock } = await racing();
            client.elements.article.fire('click', { target: makeLink(42), preventDefault: () => {} });
            client.elements.article.fire('click', { target: makeLink(43), preventDefault: () => {} });
            assert.deepStrictEqual(sock.drain(), ['wl4,42']);
        });

        test('a tap that is not on a link does nothing', async () => {
            const { client, sock } = await racing();
            const notALink = makeElement('p');
            notALink.closest = () => null;
            client.elements.article.fire('click', { target: notALink, preventDefault: () => {} });
            assert.deepStrictEqual(sock.drain(), []);
        });
    });

    describe('going back', () => {
        test('asks the server, and only once it has somewhere to go back to', async () => {
            const client = loadClient();
            const sock = await connected(client);
            sock.deliver('ok4');
            sock.deliver('wr0,99,Start|Target');
            sock.deliver('wg0,0');
            await settle();
            sock.drain();

            //At the start there is nothing to undo, so nothing is sent.
            client.elements.back.fire('click', {});
            assert.deepStrictEqual(sock.drain(), []);

            client.elements.article.fire('click', { target: makeLink(42), preventDefault: () => {} });
            sock.deliver('wg42,1');
            await settle();
            sock.drain();

            client.elements.back.fire('click', {});
            assert.deepStrictEqual(sock.drain(), ['wb4']);
        });
    });

    describe('finishing', () => {
        test('arriving raises the celebration and stops accepting taps', async () => {
            const client = loadClient();
            const sock = await connected(client);
            sock.deliver('ok4');
            sock.deliver('wr0,99,Start|Target');
            sock.deliver('wg0,0');
            await settle();
            sock.drain();

            sock.deliver('wf');
            assert.ok(client.elements.curtain.classList.contains('won'));
            client.elements.article.fire('click', { target: makeLink(42), preventDefault: () => {} });
            assert.deepStrictEqual(sock.drain(), []);
        });

        test('time being called freezes the page', async () => {
            const client = loadClient();
            const sock = await connected(client);
            sock.deliver('ok4');
            sock.deliver('wr0,99,Start|Target');
            sock.deliver('wg0,0');
            await settle();
            sock.drain();

            sock.deliver('we');
            assert.match(client.elements.curtainText.textContent, /Time/);
            client.elements.article.fire('click', { target: makeLink(42), preventDefault: () => {} });
            assert.deepStrictEqual(sock.drain(), []);
        });

        test('time being called after arriving leaves the celebration up', async () => {
            const client = loadClient();
            const sock = await connected(client);
            sock.deliver('ok4');
            sock.deliver('wr0,99,Start|Target');
            sock.deliver('wg0,0');
            await settle();
            sock.deliver('wf');
            sock.deliver('we');
            assert.ok(client.elements.curtain.classList.contains('won'));
        });
    });

    describe('leaving the round', () => {
        test('a view that is not the wikirace sends the team back to the buzzer', async () => {
            const client = loadClient();
            const sock = await connected(client);
            sock.deliver('vibuzzer');
            //The query string has to survive, or a harness client loses its identity.
            assert.deepStrictEqual(client.navigations, ['/?port=8093&vcid=phone1']);
        });

        test('being told we are still on the wikirace stays put', async () => {
            const client = loadClient();
            const sock = await connected(client);
            sock.deliver('viwikirace');
            assert.deepStrictEqual(client.navigations, []);
        });

        test('a client with no team goes back to pick one', async () => {
            const client = loadClient();
            const sock = await connected(client);
            sock.deliver('vipickteam');
            assert.strictEqual(client.navigations.length, 1);
        });
    });

    describe('the phone back gesture', () => {
        async function racing() {
            const client = loadClient();
            const sock = await connected(client);
            sock.deliver('ok4');
            sock.deliver('wr0,99,Start|Target');
            sock.deliver('wg0,0');
            await settle();
            sock.drain();
            return { client, sock };
        }

        test('is swallowed rather than leaving the round', async () => {
            //Left alone it took the team out to the buzzer, which bounced them back here,
            //and every one of those round trips is a resync.
            const { client } = await racing();
            client.back();
            assert.deepStrictEqual(client.navigations, []);
        });

        test('acts as the round own Back once there is somewhere to go', async () => {
            const { client, sock } = await racing();

            //At the start there is nothing to undo, so nothing is sent.
            client.back();
            assert.deepStrictEqual(sock.drain(), []);

            client.elements.article.fire('click', { target: makeLink(42), preventDefault: () => {} });
            sock.deliver('wg42,1');
            await settle();
            sock.drain();

            client.back();
            assert.deepStrictEqual(sock.drain(), ['wb4']);
        });

        test('keeps an entry available so the gesture can be caught again', async () => {
            const { client } = await racing();
            const before = client.history.entries.length;
            client.back();
            client.back();
            assert.ok(client.history.entries.length > before,
                      'a consumed history entry must be replaced or the next gesture escapes');
        });
    });

    describe('a slow article response', () => {
        test('cannot overwrite a newer one', async () => {
            //The bug this guards: on a resync the client was asked for the start article
            //and then for where it actually was. Both fetches ran at once, and when the
            //start one landed last it won — leaving the team looking at a page the server
            //did not think it was on, with every link it could see refused.
            const client = loadClient({ slow: [7] });
            const sock = await connected(client);
            sock.deliver('ok1');
            sock.deliver('wr7,99,Start|Target');
            sock.deliver('wg7,0');     //asked for the slow article
            sock.deliver('wg500,3');   //then immediately for a different one
            await settle();
            assert.strictEqual(client.elements.title.textContent, 'Article 500');
            assert.strictEqual(client.elements.hops.textContent, 3);
        });
    });

    describe('reconnecting mid-race', () => {
        test('lands back on its own article with the server hop count', async () => {
            const client = loadClient();
            const sock = await connected(client);
            sock.deliver('ok2');
            //What the server sends a returning client: the race, then where it actually is.
            sock.deliver('wr0,99,Start|Target');
            sock.deliver('wg500,3');
            await settle();
            assert.strictEqual(client.elements.title.textContent, 'Article 500');
            assert.strictEqual(client.elements.hops.textContent, 3);
        });
    });

    describe('a broken corpus', () => {
        test('says so rather than showing a blank page', async () => {
            const client = loadClient({ missing: [7] });
            const sock = await connected(client);
            sock.deliver('ok1');
            sock.deliver('wr7,2,Seven|Two');
            sock.deliver('wg7,0');
            await settle();
            assert.match(client.elements.curtainText.textContent, /Could not load/);
        });
    });
});
