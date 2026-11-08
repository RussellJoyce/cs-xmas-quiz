'use strict';

const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, '..', '..', 'nodeserver', 'static', 'wiki');

const index = JSON.parse(fs.readFileSync(path.join(OUT, 'index.json'), 'utf8'));
const puzzles = JSON.parse(fs.readFileSync(path.join(OUT, 'puzzles.json'), 'utf8'));

const raw = fs.readFileSync(path.join(OUT, 'graph.bin'));
const header = new Int32Array(raw.buffer, raw.byteOffset, 2);
const n = header[0], m = header[1];
const offsets = new Int32Array(raw.buffer, raw.byteOffset + 8, n + 1);
const targets = new Int32Array(raw.buffer, raw.byteOffset + 8 + (n + 1) * 4, m);

function article(id) {
    return JSON.parse(fs.readFileSync(path.join(OUT, 'a', String(Math.floor(id / index.shard)), id + '.json'), 'utf8'));
}

//Shortest path, forwards, so we can then replay it against the article files.
function shortestPath(from, to) {
    const prev = new Int32Array(n).fill(-1);
    const seen = new Uint8Array(n);
    const queue = new Int32Array(n);
    let head = 0, tail = 0;
    seen[from] = 1; queue[tail++] = from;
    while(head < tail) {
        const v = queue[head++];
        if(v === to) break;
        for(let p = offsets[v]; p < offsets[v + 1]; p++) {
            const w = targets[p];
            if(!seen[w]) { seen[w] = 1; prev[w] = v; queue[tail++] = w; }
        }
    }
    if(!seen[to]) return null;
    const out = [to];
    for(let v = to; v !== from; v = prev[v]) out.unshift(prev[v]);
    return out;
}

console.log(n.toLocaleString() + ' articles, ' + m.toLocaleString() + ' links\n');

let failures = 0;
for(const puzzle of puzzles.slice(0, 8)) {
    const route = shortestPath(puzzle.start, puzzle.target);
    if(!route) { console.log('NO ROUTE for ' + puzzle.startTitle + ' -> ' + puzzle.targetTitle); failures++; continue; }

    //is the next article actually a link on the page?
    const names = [];
    for(let i = 0; i < route.length; i++) {
        const here = article(route[i]);
        names.push(here.t);
        if(i + 1 < route.length && !here.l.includes(route[i + 1])) {
            console.log('  BROKEN: "' + here.t + '" does not link to id ' + route[i + 1]);
            failures++;
        }
    }
    console.log((route.length - 1) + ' hops:  ' + names.join('  →  '));
}

//Spot-check one article's shipped body against its graph row.
const sample = article(0);
const row = Array.from(targets.subarray(offsets[0], offsets[1]));
console.log('\nsample article id 0: "' + sample.t + '"');
console.log('  body ' + (sample.h.length / 1024).toFixed(1) + ' KB, ' + sample.l.length + ' links');
console.log('  graph row matches shipped links: ' +
            (row.length === sample.l.length && row.every(x => sample.l.includes(x))));
console.log('  first 12 links: ' + sample.l.slice(0, 12).map(id => index.titles[id]).join(', '));
console.log('  body opens: ' + sample.h.replace(/<[^>]*>/g, '').slice(0, 180).trim() + '…');

//The ideal line recorded with each puzzle has to be walkable too, and has to be as short
//as the puzzle claims. It is what the host compares a team's effort against, so a wrong
//one is worse than none at all.
console.log('\nchecking the routes recorded in puzzles.json');
let routeProblems = 0, routesChecked = 0;
function checkRoute(puzzle, ids, titles) {
    routesChecked++;
    if(ids.length - 1 !== puzzle.hops) {
        console.log('  ' + puzzle.startTitle + ': route is ' + (ids.length - 1) +
                    ' hops, puzzle says ' + puzzle.hops);
        routeProblems++;
    }
    if(ids[0] !== puzzle.start || ids[ids.length - 1] !== puzzle.target) {
        console.log('  ' + puzzle.startTitle + ': route does not run from the start to the target');
        routeProblems++;
    }
    //Every hop must be a link a team could actually have clicked.
    for(let i = 0; i < ids.length; i++) {
        const here = article(ids[i]);
        if(i + 1 < ids.length && !here.l.includes(ids[i + 1])) {
            console.log('  ' + puzzle.startTitle + ': "' + here.t + '" does not link to "' +
                        titles[i + 1] + '"');
            routeProblems++;
        }
        if(here.t !== titles[i]) {
            console.log('  ' + puzzle.startTitle + ': titles and ids disagree at step ' + i);
            routeProblems++;
        }
    }
}
for(const puzzle of puzzles) {
    if(!puzzle.route || !puzzle.routeIds) {
        console.log('  ' + puzzle.startTitle + ': no route recorded');
        routeProblems++;
        continue;
    }
    checkRoute(puzzle, puzzle.routeIds, puzzle.route);
    //The extra routes shown to the host have to be just as real, and all different
    const more = puzzle.moreRouteIds || [];
    more.forEach((ids, k) => checkRoute(puzzle, ids, (puzzle.moreRoutes || [])[k] || []));
    const distinct = new Set([puzzle.routeIds].concat(more).map(r => r.join(',')));
    if(distinct.size !== more.length + 1) {
        console.log('  ' + puzzle.startTitle + ': the same route is recorded twice');
        routeProblems++;
    }
    //And no shorter route may exist, or the "ideal" is not ideal.
    const best = shortestPath(puzzle.start, puzzle.target);
    if(best && best.length - 1 < puzzle.hops) {
        console.log('  ' + puzzle.startTitle + ': a shorter route exists (' +
                    (best.length - 1) + ' hops)');
        routeProblems++;
    }
}
console.log(routeProblems === 0
    ? '  all ' + routesChecked + ' routes recorded for ' + puzzles.length + ' puzzles are walkable and genuinely shortest'
    : '  ' + routeProblems + ' PROBLEMS');

console.log((failures === 0 && routeProblems === 0)
    ? '\nALL PATHS WALKABLE'
    : '\n' + (failures + routeProblems) + ' FAILURES');
