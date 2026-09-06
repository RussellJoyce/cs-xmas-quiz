'use strict';

//Stage 5: write what the quiz server actually serves.
//
//Output, into nodeserver/static/wiki/:
//   a/<id/1000>/<id>.json   one article: {t: title, h: html, l: [id, ...]}
//   index.json              id -> title, for the host's puzzle picker and the big display
//   graph.bin               CSR adjacency, for the server's move validation
//   puzzles.json            candidate start/target pairs with their shortest-path length

const fs = require('fs');
const path = require('path');
const os = require('os');
const { fork } = require('child_process');

const BUILD = path.join(__dirname, 'corpus', 'build');
const OUT = path.join(__dirname, '..', '..', 'nodeserver', 'static', 'wiki');
const WORKERS = parseInt(process.env.QUIZ_WORKERS || String(os.cpus().length), 10);
const KEEP_INFOBOXES = process.env.QUIZ_INFOBOXES === '1';
const SHARD = 1000;

function loadCorpus() {
    return JSON.parse(fs.readFileSync(path.join(BUILD, 'corpus.json'), 'utf8'));
}

function loadGraph() {
    const raw = fs.readFileSync(path.join(BUILD, 'graph.bin'));
    const header = new Int32Array(raw.buffer, raw.byteOffset, 2);
    const n = header[0], m = header[1];
    return {
        n, m,
        offsets: new Int32Array(raw.buffer, raw.byteOffset + 8, n + 1),
        targets: new Int32Array(raw.buffer, raw.byteOffset + 8 + (n + 1) * 4, m)
    };
}

//---- Worker ---------------------------------------------------------------------------

function runWorker(index, total) {
    const { openArchive } = require('./lib/zim');
    const { renderArticle } = require('./lib/render');

    const corpus = loadCorpus();
    const idOf = new Map();
    for(let id = 0; id < corpus.slugs.length; id++) idOf.set(corpus.slugs[id], id);
    const redirects = JSON.parse(fs.readFileSync(path.join(BUILD, 'redirects.json'), 'utf8'));
    const { slugs: allSlugs } = JSON.parse(fs.readFileSync(path.join(BUILD, 'articles.json'), 'utf8'));

    //A link is kept only if it lands inside the shipped corpus
    function canonical(p) {
        if(p === null) return null;
        let id = idOf.get(p);
        if(id !== undefined) return id;
        //Not a corpus article directly; it may be a redirect to one.
        const globalId = redirects[p];
        if(globalId === undefined) return null;
        id = idOf.get(allSlugs[globalId]);
        return id === undefined ? null : id;
    }

    const archive = openArchive();
    const outdeg = new Int32Array(corpus.slugs.length);
    let done = 0, bytes = 0;

    for(let id = index; id < corpus.slugs.length; id += total) {
        const slug = corpus.slugs[id];
        let html;
        try {
            html = archive.getEntryByPath(slug).getItem(true).data.toString();
        } catch(err) {
            process.send({ error: slug + ': ' + err.message });
            continue;
        }

        const rendered = renderArticle(html, canonical, { keepInfoboxes: KEEP_INFOBOXES });
        if(!rendered) { process.send({ error: slug + ': no body' }); continue; }

        const links = rendered.outlinks.filter(t => t !== id);
        outdeg[id] = links.length;

        const dir = path.join(OUT, 'a', String(Math.floor(id / SHARD)));
        fs.mkdirSync(dir, { recursive: true });
        const body = JSON.stringify({ t: corpus.titles[id], h: rendered.html, l: links });
        fs.writeFileSync(path.join(dir, id + '.json'), body);

        bytes += body.length;
        done++;
        if(index === 0 && done % 1000 === 0) process.send({ progress: done * total });
    }

    fs.writeFileSync(path.join(BUILD, 'outdeg-' + index + '.bin'), Buffer.from(outdeg.buffer));
    process.send({ finished: true, done, bytes });
}

//---- Parent ---------------------------------------------------------------------------

function runParent() {
    const corpus = loadCorpus();
    console.log('emitting ' + corpus.slugs.length.toLocaleString() + ' articles to ' + OUT);
    console.log('infoboxes: ' + (KEEP_INFOBOXES ? 'KEPT' : 'stripped') + ', ' + WORKERS + ' workers\n');

    fs.rmSync(path.join(OUT, 'a'), { recursive: true, force: true });
    fs.mkdirSync(OUT, { recursive: true });

    const started = Date.now();
    const totals = { done: 0, bytes: 0, errors: 0 };
    let running = WORKERS;

    for(let i = 0; i < WORKERS; i++) {
        const child = fork(__filename, ['worker', String(i), String(WORKERS)]);
        child.on('message', function(msg) {
            if(msg.progress) console.log('  ~' + msg.progress.toLocaleString() + ' articles');
            if(msg.error) { totals.errors++; if(totals.errors < 10) console.log('  ! ' + msg.error); }
            if(msg.finished) { totals.done += msg.done; totals.bytes += msg.bytes; }
        });
        child.on('exit', () => { if(--running === 0) finish(started, totals, corpus); });
    }
}

function finish(started, totals, corpus) {
    console.log('\nwrote ' + totals.done.toLocaleString() + ' articles in ' +
                ((Date.now() - started) / 1000 / 60).toFixed(1) + ' min');
    console.log('  errors        ' + totals.errors);
    console.log('  on disk       ' + (totals.bytes / 1024 / 1024).toFixed(0) + ' MB' +
                ' (mean ' + Math.round(totals.bytes / totals.done / 1024) + ' KB/article)');

    // check graph.bin against the outlinks we just wrote, because they had better be the same
    const graph = loadGraph();
    const emitted = new Int32Array(graph.n);
    for(let i = 0; i < WORKERS; i++) {
        const file = path.join(BUILD, 'outdeg-' + i + '.bin');
        if(!fs.existsSync(file)) continue;
        const raw = fs.readFileSync(file);
        const part = new Int32Array(raw.buffer, raw.byteOffset, raw.length / 4);
        for(let id = 0; id < part.length; id++) if(part[id]) emitted[id] = part[id];
        fs.unlinkSync(file);
    }

    let mismatched = 0;
    for(let id = 0; id < graph.n; id++) {
        if(emitted[id] !== graph.offsets[id + 1] - graph.offsets[id]) mismatched++;
    }
    if(mismatched === 0) {
        console.log('\n  ✓ every article ships exactly the links the graph says it has');
    } else {
        console.log('\n  *** ' + mismatched + ' articles ship a different number of links than');
        console.log('  *** graph.bin records. The server would accept or refuse moves that');
        console.log('  *** do not match what teams can see. Do not use this build.');
    }

    //---- Index and graph --------------------------------------------------------------

    fs.writeFileSync(path.join(OUT, 'index.json'), JSON.stringify({
        titles: corpus.titles,
        slugs: corpus.slugs,
        shard: SHARD
    }));
    fs.writeFileSync(path.join(OUT, 'meta.json'), JSON.stringify({
        shard: SHARD,
        articles: corpus.titles.length,
        built: new Date().toISOString().slice(0, 10)
    }));
    fs.copyFileSync(path.join(BUILD, 'graph.bin'), path.join(OUT, 'graph.bin'));

    //---- Puzzles ----------------------------------------------------------------------

    console.log('\nlooking for playable start/target pairs');
    const puzzles = findPuzzles(graph, corpus);
    fs.writeFileSync(path.join(OUT, 'puzzles.json'), JSON.stringify(puzzles, null, 1));
    console.log('  wrote ' + puzzles.length + ' candidates to puzzles.json');

    const total = fs.readdirSync(path.join(OUT, 'a')).length;
    console.log('\ncorpus ready: ' + OUT + ' (' + total + ' shards)');
}

//Distance from every article to `target`, by breadth-first search over the reversed graph.
function distancesTo(graph, target) {
    const n = graph.n;
    //Reverse adjacency, built once per call. At 2.1M edges this is a few tens of ms.
    const indeg = new Int32Array(n);
    for(let i = 0; i < graph.targets.length; i++) indeg[graph.targets[i]]++;
    const roff = new Int32Array(n + 1);
    for(let i = 0; i < n; i++) roff[i + 1] = roff[i] + indeg[i];
    const rtar = new Int32Array(graph.m);
    const cursor = Int32Array.from(roff.subarray(0, n));
    for(let v = 0; v < n; v++) {
        for(let p = graph.offsets[v]; p < graph.offsets[v + 1]; p++) rtar[cursor[graph.targets[p]]++] = v;
    }

    const dist = new Int32Array(n).fill(-1);
    const queue = new Int32Array(n);
    let head = 0, tail = 0;
    dist[target] = 0;
    queue[tail++] = target;
    while(head < tail) {
        const v = queue[head++];
        for(let p = roff[v]; p < roff[v + 1]; p++) {
            const w = rtar[p];
            if(dist[w] < 0) { dist[w] = dist[v] + 1; queue[tail++] = w; }
        }
    }
    return dist;
}

//Proposes pairs. this needs expanding but works at the moment
function findPuzzles(graph, corpus) {
    const FAMOUS = 2000;    //the top slice of the corpus by in-degree
    const HOPS = [3, 4, 5];
    const TARGETS = 60;
    const PER_BUCKET = 1;   //per target, per hop count

    const out = [];
    for(let t = 0; t < TARGETS; t++) {
        //Spread through the famous slice rather than taking the top 60, which would be
        //all countries and wars.
        const target = 20 + Math.floor(t * (FAMOUS - 20) / TARGETS);
        const dist = distancesTo(graph, target);

        const buckets = new Map(HOPS.map(h => [h, []]));
        for(let s = 0; s < FAMOUS; s++) {
            if(s === target) continue;
            const bucket = buckets.get(dist[s]);
            if(bucket) bucket.push(s);
        }

        for(const hops of HOPS) {
            const candidates = buckets.get(hops);
            for(let k = 0; k < PER_BUCKET && candidates.length > 0; k++) {
                const start = candidates[Math.floor(candidates.length * (k + 1) / (PER_BUCKET + 1))];
                out.push({
                    start: start,
                    target: target,
                    startTitle: corpus.titles[start],
                    targetTitle: corpus.titles[target],
                    hops: hops
                });
            }
        }
    }

    out.sort((a, b) => a.hops - b.hops || a.startTitle.localeCompare(b.startTitle));
    return out;
}

function puzzlesOnly() {
    const corpus = loadCorpus();
    const graph = loadGraph();
    console.log('rebuilding puzzles from the existing corpus');
    const puzzles = findPuzzles(graph, corpus);
    fs.writeFileSync(path.join(OUT, 'puzzles.json'), JSON.stringify(puzzles, null, 1));

    const byHops = {};
    puzzles.forEach(p => { byHops[p.hops] = (byHops[p.hops] || 0) + 1; });
    console.log('  ' + puzzles.length + ' candidates: ' +
                Object.entries(byHops).map(([h, n]) => n + ' at ' + h + ' hops').join(', '));
    console.log('\na sample:');
    for(const hops of [3, 4, 5]) {
        puzzles.filter(p => p.hops === hops).slice(0, 4).forEach(p =>
            console.log('  ' + hops + ' hops   ' + p.startTitle + '  →  ' + p.targetTitle));
    }
}

if(process.argv[2] === 'worker') {
    runWorker(parseInt(process.argv[3], 10), parseInt(process.argv[4], 10));
} else if(process.argv[2] === 'puzzles') {
    puzzlesOnly();
} else {
    runParent();
}
