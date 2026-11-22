'use strict';

/*
What the demo videos (tools/*-demo.js) have in common: a phone page in a browser, served from
static/ with the quiz server's socket mocked, a drawn hand that moves, presses and taps, and
the frames joined into an MP4.

Every frame is posed and then screenshotted, rather than recorded in real time. That keeps
the motion smooth and the timing exact however slow the capture is, and lets the frames be
captured at 2x for a sharp result. The page's clock is Playwright's fake one, moved on by
one frame per frame, so the page's own timers keep video time too.

    node tools/<name>-demo.js [out.mp4] [WxH]

WxH is the phone's screen in CSS pixels, 390x690 by default (a little squarer than a modern
phone, to sit beside other things on a slide). The video is twice that.
*/

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');
const { firefox } = require('playwright');

const FPS = 30;
const SCALE = 2;
const STATIC = path.join(__dirname, '..', 'static');
const ORIGIN = 'http://quiz.local';
const T0 = new Date('2026-12-18T19:30:00Z').getTime();

const ease = t => t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
const easeOut = t => 1 - Math.pow(1 - t, 3);
const lerp = (a, b, t) => a + (b - a) * t;
const sleep = ms => new Promise(r => setTimeout(r, ms));

//Runs in the page: the hand, the ripple, and the means of posing them
function overlay(scroller) {
    const style = document.createElement('style');
    style.textContent = `
        #demoHand {
            position: fixed; left: 0; top: 0; z-index: 100; pointer-events: none;
            font-size: 76px; line-height: 1; opacity: 0;
            transform-origin: 42% 6%;
        }
        #demoRipple {
            position: fixed; z-index: 99; pointer-events: none; border-radius: 50%;
            border: 3px solid #ffffff; background: rgba(255,255,255,0.25); opacity: 0;
        }`;

    const hand = document.createElement('div');
    hand.id = 'demoHand';
    hand.textContent = '👆';
    const ripple = document.createElement('div');
    ripple.id = 'demoRipple';
    document.addEventListener('DOMContentLoaded', () => {
        document.head.appendChild(style);
        document.body.appendChild(ripple);
        document.body.appendChild(hand);
    });

    //The fingertip of the glyph, as a fraction of its box: what lands on (x, y)
    const TIP_X = 0.42, TIP_Y = 0.06;

    window.demoPose = function(p) {
        const w = hand.offsetWidth || 76, h = hand.offsetHeight || 76;
        //lift: 0 = touching the glass, 1 = raised towards the viewer
        const lift = p.lift || 0;
        const scale = (p.press ? 0.9 : 1) + lift * 0.1;
        hand.style.opacity = p.opacity;
        hand.style.transform = `translate(${p.x - TIP_X * w}px, ${p.y - TIP_Y * h}px) scale(${scale})`;
        hand.style.filter = `drop-shadow(0 ${4 + 10 * lift}px ${6 + 8 * lift}px rgba(0,0,0,0.55))`;
        if(p.scroll !== undefined && scroller) document.querySelector(scroller).scrollTop = p.scroll;
        if(p.ripple !== undefined && p.ripple !== null) {
            const r = 8 + 34 * p.ripple;
            ripple.style.left = (p.rx - r) + 'px';
            ripple.style.top = (p.ry - r) + 'px';
            ripple.style.width = ripple.style.height = (2 * r) + 'px';
            ripple.style.opacity = 0.9 * (1 - p.ripple);
        } else {
            ripple.style.opacity = 0;
        }
    };
}

/*
Opens `url` (a path under static/) with `socket(ws)` standing in for the quiz server.
`scroller` is the selector of the element a pose's `scroll` applies to, if any. `css` is
added to the page.
*/
async function startDemo({ name, url, socket, scroller, css }) {
    const out = path.resolve(process.argv[2] || name + '-demo.mp4');
    const size = /^(\d+)x(\d+)$/.exec(process.argv[3] || '390x690');
    if(!size) throw new Error('Size should be WxH, e.g. 390x690');
    const W = +size[1], H = +size[2];

    const frames = fs.mkdtempSync(path.join(os.tmpdir(), name + '-demo-'));
    let frame = 0;
    let clockAt = T0;

    const browser = await firefox.launch();
    const context = await browser.newContext({
        viewport: { width: W, height: H }, deviceScaleFactor: SCALE
    });
    const page = await context.newPage();

    await page.route(ORIGIN + '/**', route => {
        let file = decodeURIComponent(new URL(route.request().url()).pathname);
        if(file.endsWith('/')) file += 'index.html';
        const full = path.join(STATIC, path.normalize(file));
        if(!full.startsWith(STATIC) || !fs.existsSync(full)) return route.fulfill({ status: 404 });
        //With a charset, as Express gives one: index.html does not declare its own, and
        //without it the browser reads the page's emoji as Windows-1252
        const types = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css',
                        '.json': 'application/json' };
        const type = types[path.extname(full)];
        route.fulfill(type ? { path: full, contentType: type + '; charset=utf-8' } : { path: full });
    });
    await page.routeWebSocket(/:8090/, socket);

    await page.addInitScript(overlay, scroller || null);
    if(css) await page.addInitScript(text => {
        document.addEventListener('DOMContentLoaded', () => {
            const s = document.createElement('style');
            s.textContent = text;
            document.head.appendChild(s);
        });
    }, css);
    if(process.env.DEMO_DEBUG) page.on("console", m => console.log("[page]", m.text()));
    //Paused, as otherwise the fake clock still runs at real speed between our steps
    await page.clock.install({ time: T0 - 1000 });
    await page.clock.pauseAt(T0);
    await page.goto(ORIGIN + url);

    //Polled from here rather than with waitForFunction, which waits on the page's
    //animation frames and timers, and those only move when we move the clock
    async function until(fn, arg, what) {
        for(let i = 0; i < 200; i++) {
            if(await page.evaluate(fn, arg)) return;
            await page.clock.runFor(1);
            clockAt += 1;
            await sleep(25);
        }
        throw new Error('Timed out waiting for ' + (what || fn.toString()));
    }

    const hand = { x: W * 0.78, y: H * 0.86, opacity: 0, lift: 1, press: false };

    function framePath(n) {
        return path.join(frames, String(n).padStart(5, '0') + '.png');
    }

    //Moves the page's clock on to the time of the current frame
    async function tick() {
        const t = T0 + Math.round(frame * 1000 / FPS);
        if(t > clockAt) await page.clock.runFor(t - clockAt);
        clockAt = Math.max(clockAt, t);
    }

    //One posed frame
    async function shot(pose) {
        await tick();
        if(pose) await page.evaluate(p => window.demoPose(p), pose);
        const file = framePath(frame);
        await page.screenshot({ path: file });
        frame++;
        return file;
    }

    //Stillness. Copies one frame unless `live`, which is for when the page itself will
    //change meanwhile (a timer, say) and every frame has to be taken.
    async function hold(secs, opts) {
        const n = Math.max(1, Math.round(secs * FPS));
        if(opts && opts.live) {
            for(let i = 0; i < n; i++) await shot(hand);
            return;
        }
        const first = await shot(hand);
        for(let i = 1; i < n; i++) {
            fs.copyFileSync(first, framePath(frame));
            frame++;
        }
        await tick();
    }

    //Moves the hand (and anything else a pose has) from where it is to `to`. `extra(t)`
    //can override parts of each frame's pose.
    async function move(secs, to, extra) {
        const from = { ...hand };
        const n = Math.max(1, Math.round(secs * FPS));
        for(let i = 1; i <= n; i++) {
            const t = ease(i / n);
            const p = {};
            for(const k of ['x', 'y', 'opacity', 'lift', 'scroll']) {
                if(to[k] !== undefined && from[k] !== undefined) p[k] = lerp(from[k], to[k], t);
                else if(to[k] !== undefined) p[k] = to[k];
                else if(from[k] !== undefined && k !== 'scroll') p[k] = from[k];
            }
            p.press = to.press !== undefined ? to.press : from.press;
            if(extra) Object.assign(p, extra(i / n));
            await shot(p);
            Object.assign(hand, p);
        }
    }

    //Reach for (x, y) and press there. `act` runs at the moment of contact (to make the
    //page respond), and the ripple spreads while the finger stays down.
    async function tap(x, y, act, opts) {
        opts = opts || {};
        await move(opts.reach || 0.4, { x, y: y - 6, lift: 0.6, press: false });
        await move(0.07, { y, lift: 0, press: true });
        if(act) await act();
        const n = Math.round((opts.ripple || 0.3) * FPS);
        for(let f = 1; f <= n; f++) {
            await shot({ ...hand, rx: x, ry: y, ripple: f / n });
        }
    }

    async function finish() {
        await browser.close();
        console.log(frame + ' frames, ' + (frame / FPS).toFixed(1) + 's');
        execFileSync('ffmpeg', ['-y', '-loglevel', 'error',
            '-framerate', String(FPS), '-i', path.join(frames, '%05d.png'),
            '-c:v', 'libx264', '-preset', 'slow', '-crf', '18', '-pix_fmt', 'yuv420p',
            '-movflags', '+faststart', '-an', out], { stdio: 'inherit' });
        fs.rmSync(frames, { recursive: true });
        console.log('Wrote ' + out);
    }

    return { page, W, H, hand, until, shot, hold, move, tap, finish, FPS };
}

module.exports = { startDemo, ease, easeOut, lerp, STATIC };
