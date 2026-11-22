'use strict';

/*
Renders a short looping MP4 of a team playing the wikirace on a phone, for a slide that
shows the audience what they will see.

    node tools/wikirace-demo.js [out.mp4] [WxH]

It shows the real phone page (static/wikirace) reading the real corpus (static/wiki), with the
quiz server's socket mocked so that no server or app is needed. See demo-rig.js.
*/

const path = require('path');
const { startDemo, easeOut, STATIC } = require('./demo-rig');
const { WikiCorpus } = require('../wikirace');

const ROUTE = ['English language', 'Old English', 'Northumbria', 'River Mersey',
               'The Beatles', 'UK Albums Chart'];

//---------------------------------------------------------------------------------------
// The race itself, from the corpus

const corpus = WikiCorpus.load(path.join(STATIC, 'wiki'));
if(!corpus) throw new Error('No wiki corpus in static/wiki');
const ids = ROUTE.map(t => {
    const id = corpus.titles.indexOf(t);
    if(id < 0) throw new Error('Not in the corpus: ' + t);
    return id;
});
for(let i = 0; i + 1 < ids.length; i++) {
    if(!corpus.isLinked(ids[i], ids[i + 1])) {
        throw new Error(ROUTE[i] + ' does not link to ' + ROUTE[i + 1]);
    }
}
const dist = corpus.distancesTo(ids[ids.length - 1]);

//---------------------------------------------------------------------------------------
// In the page

//Where to scroll the article so the link sits a little below the middle, and where the
//link then is on screen
function aim(to) {
    const page = document.getElementById('page');
    const a = document.querySelector(`#article a[data-s="${to}"]`);
    const pr = page.getBoundingClientRect();
    const box = a.getClientRects()[0];   //the first line, in case it wraps
    const inPage = box.top - pr.top + page.scrollTop;
    const max = page.scrollHeight - page.clientHeight;
    const scroll = Math.max(0, Math.min(max, inPage - page.clientHeight * 0.5));
    return {
        scroll,
        x: box.left + Math.min(box.width * 0.5, 50),
        y: pr.top + inPage - scroll + box.height * 0.55
    };
}

const title = () => document.getElementById('title').textContent;
const curtainUp = () => !document.getElementById('curtain').classList.contains('hidden');

//---------------------------------------------------------------------------------------

async function main() {
    //The quiz server, as far as one team on this route needs it
    let server = null;
    let hops = 0;
    function socket(ws) {
        server = ws;
        ws.onMessage(msg => {
            msg = String(msg);
            if(msg === 'pi') ws.send('pb');
            else if(msg === 're') ws.send('ok1');
            else if(msg.startsWith('wl1,')) {
                const to = parseInt(msg.slice(4), 10);
                hops++;
                ws.send('wg' + to + ',' + hops + ',' + dist[to]);
            }
        });
    }

    const demo = await startDemo({
        name: 'wikirace', url: '/wikirace/', socket, scroller: '#page',
        //The look of a link under a finger, which :active cannot give a synthetic click
        css: '#article a.demoPressed { background: #6fe3ff; color: #0d0e15; border-radius: 3px; }'
    });
    const { page, W, H, hand, until, hold, move, tap } = demo;
    const rest = () => ({ x: W * 0.78, y: H * 0.80, lift: 1, press: false });

    await until(() => document.getElementById('curtainText').textContent === 'Ready', null, 'Ready');

    //Waiting for the race
    hand.scroll = 0;
    await hold(1.2);

    //Off they go
    server.send('wr' + ids[0] + ',' + ids[ids.length - 1] + ',' +
                ROUTE[0] + '|' + ROUTE[ROUTE.length - 1]);
    server.send('wg' + ids[0] + ',0,' + dist[ids[0]]);
    await until(t => document.getElementById('title').textContent === t &&
                     document.getElementById('curtain').classList.contains('hidden'), ROUTE[0]);
    await hold(0.6);
    await move(0.5, { ...rest(), opacity: 1 });
    await hold(0.3);

    for(let i = 0; i + 1 < ids.length; i++) {
        const next = ids[i + 1];
        const target = await page.evaluate(aim, next);

        //Flick up until the link is in view: the page follows the finger for a short drag,
        //then coasts to a stop on its own while the hand lifts away
        let scroll = hand.scroll || 0;
        const FLICK = 900, DRAG = 200;
        while(target.scroll - scroll > 4) {
            const seg = Math.min(FLICK, target.scroll - scroll);
            const drag = Math.min(DRAG, seg);
            const coast = seg - drag;
            const startY = H * 0.68;
            await move(0.22, { x: W * 0.66, y: startY, lift: 1, press: false });
            await move(0.06, { lift: 0, press: true });
            const from = scroll;
            await move(0.2, { y: startY - drag, scroll: from + drag, lift: 0, press: true });
            if(coast > 0) {
                await move(0.3 + coast / 1600, { y: startY - drag - 30, lift: 1, press: false },
                           t => ({ scroll: from + drag + coast * easeOut(t) }));
            } else {
                await move(0.12, { lift: 1, press: false, y: startY - drag - 10 });
            }
            scroll = from + seg;
            hand.scroll = scroll;
        }

        //Find the link and tap it
        await hold(0.15);
        await tap(target.x, target.y, () => page.evaluate(to => {
            document.querySelector(`#article a[data-s="${to}"]`).classList.add('demoPressed');
        }, next), { reach: 0.42, ripple: 0.35 });

        //The server says yes and the next article appears
        await page.evaluate(to => document.querySelector(`#article a[data-s="${to}"]`).click(), next);
        await until(t => document.getElementById('title').textContent === t, ROUTE[i + 1]);
        Object.assign(hand, { scroll: 0, press: false, lift: 0.6 });

        if(i + 2 < ids.length) {
            //Long enough to see the new title and the counter drop
            await hold(0.6);
        } else {
            //Arrived: a moment on the target, then the celebration
            await move(0.45, { ...rest(), opacity: 0 });
            await hold(0.7);
            server.send('wf');
            await until(curtainUp, null, 'the celebration');
            await hold(2.5);
        }
    }

    await demo.finish();
}

main().catch(err => { console.error(err); process.exit(1); });
