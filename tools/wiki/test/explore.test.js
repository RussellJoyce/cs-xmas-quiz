'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const { WikiCorpus } = require('../../../nodeserver/wikirace');
const X = require('../lib/explore');

//   0 A ──► 1 B ──► 3 D
//   │               ▲
//   └──► 2 C ───────┘      and D ──► A, so everything is reachable
//
//Two shortest routes from A to D, one hop from B or C.
function diamond() {
    const links = [[1, 2], [3], [3], [0]];
    const offsets = new Int32Array(links.length + 1);
    links.forEach((row, i) => { offsets[i + 1] = offsets[i] + row.length; });
    return new WikiCorpus({ titles: ['A', 'B', 'C', 'Dog'], offsets, targets: Int32Array.from(links.flat()) });
}

test('counts every shortest route', () => {
    const c = diamond();
    const ways = X.routeCounts(c, c.distancesTo(3));
    assert.deepStrictEqual(Array.from(ways), [2, 1, 1, 1]);
});

test('samples each shortest route, and only shortest ones', () => {
    const c = diamond();
    const dist = c.distancesTo(3);
    const routes = X.sampleRoutes(c, dist, X.routeCounts(c, dist), 0, 10).map(r => r.join(''));
    assert.deepStrictEqual(routes.sort(), ['013', '023']);
});

test('distances forwards are not distances backwards', () => {
    const c = diamond();
    assert.strictEqual(X.distancesFrom(c, 0)[3], 2);
    assert.strictEqual(X.distancesFrom(c, 3)[0], 1);
});

test('finds a title exactly, then ignoring case, else not at all', () => {
    const c = diamond();
    assert.strictEqual(X.findTitle(c, 'Dog'), 3);
    assert.strictEqual(X.findTitle(c, 'dog'), 3);
    assert.strictEqual(X.findTitle(c, 'Cat'), null);
});

test('in-degree and fame rank agree', () => {
    const deg = X.inDegrees(diamond());
    assert.deepStrictEqual(Array.from(deg), [1, 1, 1, 2]);
    assert.strictEqual(X.fameRanks(deg)[3], 1);
});

//A random graph, and every simple route between two articles found the slow way
function randomCorpus(n, links, seed) {
    let a = seed;
    const rand = () => { a = (a * 1103515245 + 12345) % 2147483648; return a / 2147483648; };
    const rows = Array.from({ length: n }, () => []);
    for(let i = 0; i < links; i++) {
        const from = Math.floor(rand() * n), to = Math.floor(rand() * n);
        if(!rows[from].includes(to)) rows[from].push(to);   //self-links included, to be skipped
    }
    const offsets = new Int32Array(n + 1);
    rows.forEach((row, i) => { offsets[i + 1] = offsets[i] + row.length; });
    return new WikiCorpus({ titles: rows.map((_, i) => 'T' + i), offsets, targets: Int32Array.from(rows.flat()) });
}

function simpleRoutes(c, from, to, length) {
    let found = 0;
    (function walk(v, seen, left) {
        if(left === 0) { if(v === to) found++; return; }
        for(const w of c.outlinks(v)) if(!seen.has(w)) walk(w, new Set(seen).add(w), left - 1);
    })(from, new Set([from]), length);
    return found;
}

test('walk counts are exact route counts for the shortest length and one more, both ways', () => {
    for(const seed of [1, 2, 3, 4, 5]) {
        const c = randomCorpus(14, 40, seed);
        for(let target = 0; target < c.size; target++) {
            const dist = c.distancesTo(target);
            const toward = X.walkCounts(c, target, c.size + 1, true);
            for(let start = 0; start < c.size; start++) {
                const d = dist[start];
                if(d <= 0) continue;
                const away = X.walkCounts(c, start, d + 1, false);
                for(const k of [d, d + 1]) {
                    const real = simpleRoutes(c, start, target, k);
                    assert.strictEqual(toward[k][start], real, `T${start}→T${target} at ${k} links, towards`);
                    assert.strictEqual(away[k][target], real, `T${start}→T${target} at ${k} links, away`);
                }
            }
        }
    }
});
