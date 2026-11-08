'use strict';

const path = require('path');

//Questions about the shipped corpus, for choosing wikirace puzzles: how far apart two
//articles are, the routes between them, and how easy a target is to find.
//
//Works on anything shaped like nodeserver's WikiCorpus (titles, offsets, targets,
//distancesTo), so the answers are exactly what the game will enforce.

//How many articles link to each article. A rough measure of fame, and of how findable a
//target is: the fewer the links in, the more a team has to know where it lives.
function inDegrees(corpus) {
    const deg = new Int32Array(corpus.size);
    for(let i = 0; i < corpus.targets.length; i++) deg[corpus.targets[i]]++;
    return deg;
}

//Rank by in-degree, 1 being the most linked-to article in the corpus.
function fameRanks(deg) {
    const order = Array.from(deg.keys()).sort((a, b) => deg[b] - deg[a] || a - b);
    const rank = new Int32Array(deg.length);
    order.forEach((id, i) => { rank[id] = i + 1; });
    return rank;
}

//Distance from `start` to every article, following links forwards. -1 is unreachable.
function distancesFrom(corpus, start) {
    const n = corpus.size;
    const dist = new Int32Array(n).fill(-1);
    const queue = new Int32Array(n);
    let head = 0, tail = 0;
    dist[start] = 0;
    queue[tail++] = start;
    while(head < tail) {
        const v = queue[head++];
        for(let p = corpus.offsets[v]; p < corpus.offsets[v + 1]; p++) {
            const w = corpus.targets[p];
            if(dist[w] < 0) { dist[w] = dist[v] + 1; queue[tail++] = w; }
        }
    }
    return dist;
}

//For every article, how many different shortest routes run from it to the target that
//`dist` was measured to. Floating point, because popular pairs run into the millions.
function routeCounts(corpus, dist) {
    const n = corpus.size;
    const ways = new Float64Array(n);
    const byDist = Array.from(dist.keys()).filter(v => dist[v] >= 0).sort((a, b) => dist[a] - dist[b]);
    for(const v of byDist) {
        if(dist[v] === 0) { ways[v] = 1; continue; }
        let sum = 0;
        for(let p = corpus.offsets[v]; p < corpus.offsets[v + 1]; p++) {
            const w = corpus.targets[p];
            if(dist[w] === dist[v] - 1) sum += ways[w];
        }
        ways[v] = sum;
    }
    return ways;
}

//Up to `count` different shortest routes from `from`, as id arrays. Each step is chosen in
//proportion to the routes it leads to, so every shortest route is equally likely and the
//sample is not dominated by whichever link happens to come first.
function sampleRoutes(corpus, dist, ways, from, count, random = Math.random) {
    if(dist[from] < 0) return [];
    const seen = new Map();
    for(let attempt = 0; attempt < count * 40 && seen.size < count; attempt++) {
        const route = [from];
        let v = from;
        while(dist[v] > 0) {
            let pick = random() * ways[v];
            let next = -1;
            for(let p = corpus.offsets[v]; p < corpus.offsets[v + 1]; p++) {
                const w = corpus.targets[p];
                if(dist[w] !== dist[v] - 1) continue;
                next = w;
                pick -= ways[w];
                if(pick < 0) break;
            }
            route.push(next);
            v = next;
        }
        seen.set(route.join(','), route);
    }
    return Array.from(seen.values());
}

//How forgiving a puzzle is: the number of routes of exactly k links, for k up to `maxLinks`.
//`walks[k][v]` counts walks of k links between v and the anchor, towards it when `toward`,
//away from it otherwise, so one call covers every article paired with the anchor.
//
//Walks are not routes in general, since a walk may go round in a loop. But for a pair d
//apart, a walk of d or d+1 links cannot repeat an article: cutting out the loop would leave
//a walk shorter than d. So walks[d] and walks[d+1] are exact counts of the shortest routes
//and of the routes one hop longer, which is what a team that misses the best line is
//choosing among. Self-links are skipped, as clicking one gets a team nowhere.
function walkCounts(corpus, anchor, maxLinks, toward) {
    const n = corpus.size;
    let prev = new Float64Array(n);
    prev[anchor] = 1;
    const walks = [prev];
    for(let k = 1; k <= maxLinks; k++) {
        const cur = new Float64Array(n);
        for(let v = 0; v < n; v++) {
            const start = corpus.offsets[v], end = corpus.offsets[v + 1];
            if(toward) {
                //Walks from v: through each link out of v, then on from there
                let sum = 0;
                for(let p = start; p < end; p++) {
                    const w = corpus.targets[p];
                    if(w !== v) sum += prev[w];
                }
                cur[v] = sum;
            } else if(prev[v] !== 0) {
                //Walks to v carry on along each link out of v
                for(let p = start; p < end; p++) {
                    const w = corpus.targets[p];
                    if(w !== v) cur[w] += prev[v];
                }
            }
        }
        walks.push(cur);
        prev = cur;
    }
    return walks;
}

//Exact title first, then ignoring case. Null if neither.
function findTitle(corpus, title) {
    if(!corpus._byTitle) {
        corpus._byTitle = new Map();
        corpus._byLower = new Map();
        corpus.titles.forEach((t, id) => {
            corpus._byTitle.set(t, id);
            if(!corpus._byLower.has(t.toLowerCase())) corpus._byLower.set(t.toLowerCase(), id);
        });
    }
    if(corpus._byTitle.has(title)) return corpus._byTitle.get(title);
    const lower = corpus._byLower.get(title.toLowerCase());
    return lower === undefined ? null : lower;
}

//Titles containing `text`, ignoring case, most famous first.
function searchTitles(corpus, deg, text, limit) {
    const needle = text.toLowerCase();
    const hits = [];
    corpus.titles.forEach((t, id) => { if(t.toLowerCase().includes(needle)) hits.push(id); });
    hits.sort((a, b) => deg[b] - deg[a]);
    return hits.slice(0, limit);
}

//The hand-picked races. They are the quiz's answers, so they live with the other questions
//in Questions/, which is not in git, rather than beside these tools. QUIZ_WIKI_CURATED
//points somewhere else.
const CURATED = process.env.QUIZ_WIKI_CURATED ||
    path.join(__dirname, '..', '..', '..', 'Questions', 'Wikirace', 'curated.json');

module.exports = { CURATED,  inDegrees, fameRanks, distancesFrom, routeCounts, walkCounts, sampleRoutes, findTitle, searchTitles };
