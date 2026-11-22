'use strict';

/*
Renders a short looping MP4 of a team solving the connecting wall on a phone, mistakes and
all, for a slide that shows the audience what they will see.

    node tools/wall-demo.js [out.mp4] [WxH]

It shows the real phone page (static/index.html) with the quiz server's socket mocked. See
demo-rig.js. The wall is made up for the purpose, not one from Questions/.
*/

const { startDemo } = require('./demo-rig');

//In the order the tiles are laid out, left to right and top to bottom
const WALL = [
    'Comet',   'Juno',   'Bounty',  'Starr',
    'Mars',    'Dasher', 'Mercury', 'Vulcan',
    'Kruger',  'Galaxy', 'Cupid',   'Prancer',
    'Neptune', 'Topic',  'Dancer',  'Flintoff'
];

const GROUPS = [
    ['Dasher', 'Dancer', 'Prancer', 'Comet'],      //Santa's reindeer
    ['Cupid', 'Juno', 'Neptune', 'Vulcan'],        //Roman gods
    ['Mars', 'Galaxy', 'Bounty', 'Topic'],         //Chocolate bars
    ['Mercury', 'Flintoff', 'Starr', 'Kruger']     //Freddies
];

//What the team taps, in order. A word tapped twice in a row is picked and then put back.
const PLAY = [
    ['Comet', 'Mars', 'Galaxy', 'Neptune'],                        //"space", wrong
    ['Dasher', 'Prancer', 'Dancer', 'Cupid'],                      //reindeer, but not Cupid
    ['Dasher', 'Prancer', 'Dancer', 'Comet'],                      //reindeer
    ['Juno', 'Mercury', 'Mercury', 'Neptune', 'Vulcan', 'Cupid'],  //gods, after second thoughts
    ['Mercury', 'Mars', 'Galaxy', 'Starr'],                        //"space" again, wrong
    ['Mars', 'Galaxy', 'Bounty', 'Topic']                          //chocolate; the Freddies follow
];

const TEAM = 3;
const pos = word => {
    const i = WALL.indexOf(word);
    if(i < 0) throw new Error('Not on the wall: ' + word);
    return i + 1;
};
const groupOf = positions => GROUPS.find(g => {
    const want = g.map(pos).sort().join();
    return [...positions].sort().join() === want;
});

async function main() {
    let server = null;
    let guess = null;   //the positions of the guess waiting for a verdict
    function socket(ws) {
        server = ws;
        ws.onMessage(msg => {
            msg = String(msg);
            if(msg === 'pi') ws.send('pb');
            else if(msg === 're') {
                ws.send('ok' + TEAM);
                ws.send('vionlyconnect');
            }
            else if(msg === 'cr' + TEAM) ws.send('cw' + WALL.join('|'));
            else if(msg.startsWith('cg' + TEAM + ',')) {
                guess = msg.slice(3 + String(TEAM).length).split(',').map(Number);
            }
        });
    }

    const demo = await startDemo({ name: 'wall', url: '/', socket });
    const { page, W, H, hand, until, hold, move, tap, FPS } = demo;
    const rest = () => ({ x: W * 0.80, y: H * 0.95, lift: 1, press: false });

    await until(n => window.wallTiles && wallTiles.length === n && wallTiles[0].textContent !== '',
                WALL.length, 'the wall');

    //Where a finger goes on a tile: a little below its middle
    const tiles = await page.evaluate(() => wallTiles.map(t => {
        const r = t.getBoundingClientRect();
        return { x: r.left + r.width * 0.5, y: r.top + r.height * 0.58 };
    }));

    await hold(0.8);
    await move(0.5, { ...rest(), opacity: 1 });

    for(const taps of PLAY) {
        for(const word of taps) {
            const p = pos(word);
            const t = tiles[p - 1];
            //A little jitter, so the finger does not land on the same spot of every tile
            const jx = ((p * 37) % 11 - 5), jy = ((p * 53) % 9 - 4);
            await tap(t.x + jx, t.y + jy, () => page.evaluate(i => {
                wallTiles[i].dispatchEvent(new MouseEvent(eventtouse, { bubbles: true }));
            }, p - 1), { reach: 0.32, ripple: 0.2 });
            await move(0.1, { lift: 0.6, press: false, y: hand.y - 8 });
        }

        //Four picked and sent. A moment of waiting (the tiles dim), then the verdict.
        if(!guess) throw new Error('No guess was sent for ' + taps.join(', '));
        const sent = guess;
        guess = null;
        await move(0.35, rest());
        const group = groupOf(sent);
        server.send((group ? 'cs' : 'cx') + sent.join(','));

        if(group) {
            await hold(0.9);
            //With three found the quiz software solves the last one itself
            const solved = await page.evaluate(() => Object.keys(wallSolved).length);
            if(solved === 12) {
                const remaining = await page.evaluate(() =>
                    wallTiles.map((t, i) => i + 1).filter(p => !wallSolved[p]));
                server.send('cs' + remaining.join(','));
                await move(0.4, { ...rest(), opacity: 0 });
                await hold(2.2);
            }
        } else {
            //The crosses come down on the page's own timer
            await hold(1.25, { live: true });
        }
    }

    await demo.finish();
}

main().catch(err => { console.error(err); process.exit(1); });
