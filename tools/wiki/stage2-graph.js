'use strict';

//Stage 2: build the link graph of the rendered articles (i.e. not as they appear in the ZIM, but as they will be shipped to the server)
//Reads corpus/build/{articles,redirects}.json
//Writes corpus/build/graph-full.bin  (CSR: header, offsets, targets)

const fs = require('fs');
const path = require('path');
const os = require('os');
const { fork } = require('child_process');

const BUILD = path.join(__dirname, 'corpus', 'build');
const WORKERS = parseInt(process.env.QUIZ_WORKERS || String(os.cpus().length), 10);
const KEEP_INFOBOXES = process.env.QUIZ_INFOBOXES === '1';

//---- Worker ---------------------------------------------------------------------------

function runWorker(index, total) {
    const { openArchive } = require('./lib/zim');
    const { renderArticle } = require('./lib/render');

    const { slugs } = JSON.parse(fs.readFileSync(path.join(BUILD, 'articles.json'), 'utf8'));
    const redirects = JSON.parse(fs.readFileSync(path.join(BUILD, 'redirects.json'), 'utf8'));

    const idOf = new Map();
    for(let id = 0; id < slugs.length; id++) idOf.set(slugs[id], id);

    //An href resolves to the id of the article it ends up at, following a redirect if there is one, or null if it leaves the corpus
    function canonical(p) {
        if(p === null) return null;
        let id = idOf.get(p);
        if(id === undefined) {
            id = redirects[p];
            if(id === undefined) return null;
        }
        return id;
    }

    const archive = openArchive();
    const out = fs.openSync(path.join(BUILD, 'edges-' + index + '.bin'), 'w');
    //Articles with no body. mwoffliner writes a ~200 byte placeholder for every article that is linked to but was not selected for the ZIM
    const stubs = [];

    const BUFFER_INTS = 1 << 20;
    let buf = new Int32Array(BUFFER_INTS);
    let used = 0;
    function flush() {
        if(used === 0) return;
        fs.writeSync(out, Buffer.from(buf.buffer, 0, used * 4));
        used = 0;
    }
    function emit(src, targets) {
        if(used + 2 + targets.length > BUFFER_INTS) flush();
        buf[used++] = src;
        buf[used++] = targets.length;
        for(const t of targets) buf[used++] = t;
    }

    let done = 0, failed = 0, links = 0, bytes = 0;
    const started = Date.now();

    for(const entry of archive.iterByPath()) {
        if(entry.isRedirect) continue;
        const src = idOf.get(entry.path);
        if(src === undefined) continue;           //media
        if(src % total !== index) continue;       //not this worker's stride

        let html;
        try {
            const item = entry.getItem(false);
            if(item.mimetype !== 'text/html') continue;
            html = item.data.toString();
        } catch(err) {
            failed++;
            continue;
        }

        let rendered;
        try {
            rendered = renderArticle(html, canonical, { keepInfoboxes: KEEP_INFOBOXES });
        } catch(err) {
            failed++;
            continue;
        }
        if(!rendered) { stubs.push(src); continue; }

        //A self link is not a move, and would show up as a loop in the graph.
        const targets = rendered.outlinks.filter(t => t !== src);
        emit(src, targets);
        links += targets.length;
        bytes += rendered.html.length;
        done++;

        if(index === 0 && done % 2000 === 0) {
            const rate = done / ((Date.now() - started) / 1000);
            const eta = (total * (223149 / total - done) / (rate * total)) / 60;
            process.send({ progress: done, rate: Math.round(rate * total), eta: eta.toFixed(1) });
        }
    }

    flush();
    fs.closeSync(out);
    fs.writeFileSync(path.join(BUILD, 'stubs-' + index + '.bin'),
                     Buffer.from(Int32Array.from(stubs).buffer));
    process.send({ finished: true, done, failed, links, bytes, stubs: stubs.length });
}

//---- Parent ---------------------------------------------------------------------------

function runParent() {
    console.log('rendering every article to find the real link graph');
    console.log('infoboxes: ' + (KEEP_INFOBOXES ? 'KEPT' : 'stripped') + ', ' + WORKERS + ' workers\n');

    const started = Date.now();
    const totals = { done: 0, failed: 0, links: 0, bytes: 0, stubs: 0 };
    let running = WORKERS;

    for(let i = 0; i < WORKERS; i++) {
        const child = fork(__filename, ['worker', String(i), String(WORKERS)]);
        child.on('message', function(msg) {
            if(msg.progress) {
                console.log('  ~' + (msg.progress * WORKERS).toLocaleString() + ' articles  (' +
                            msg.rate.toLocaleString() + '/s, ~' + msg.eta + ' min left)');
            }
            if(msg.finished) {
                totals.done += msg.done;
                totals.failed += msg.failed;
                totals.links += msg.links;
                totals.bytes += msg.bytes;
                totals.stubs += msg.stubs;
            }
        });
        child.on('exit', function(code) {
            if(code !== 0) console.log('  worker exited with code ' + code);
            if(--running === 0) merge(started, totals);
        });
    }
}

//Reassembles the workers' edge files into one CSR graph
function merge(started, totals) {
    console.log('\nrendered ' + totals.done.toLocaleString() + ' articles in ' +
                ((Date.now() - started) / 1000 / 60).toFixed(1) + ' min');
    console.log('  placeholders  ' + totals.stubs.toLocaleString() + ' (linked to but not in the ZIM)');
    console.log('  failed        ' + totals.failed.toLocaleString());
    console.log('  shipped html  ' + (totals.bytes / 1024 / 1024 / 1024).toFixed(2) + ' GB' +
                ' (mean ' + Math.round(totals.bytes / totals.done / 1024) + ' KB/article)');
    console.log('  edges         ' + totals.links.toLocaleString() +
                ' (mean out-degree ' + (totals.links / totals.done).toFixed(1) + ')');

    const { slugs } = JSON.parse(fs.readFileSync(path.join(BUILD, 'articles.json'), 'utf8'));
    const n = slugs.length;

    console.log('\nmerging into CSR');

    //Placeholders dropped
    const isStub = new Uint8Array(n);
    let stubCount = 0;
    for(let i = 0; i < WORKERS; i++) {
        const file = path.join(BUILD, 'stubs-' + i + '.bin');
        if(!fs.existsSync(file)) continue;
        const raw = fs.readFileSync(file);
        const ids = new Int32Array(raw.buffer, raw.byteOffset, raw.length / 4);
        for(const id of ids) { isStub[id] = 1; stubCount++; }
        fs.unlinkSync(file);
    }
    console.log('  placeholders marked: ' + stubCount.toLocaleString() +
                ', real articles: ' + (n - stubCount).toLocaleString());

    //Two sweeps over the workers' output: the first sizes each article's slice of the target array, the second fills it
    const files = [];
    for(let i = 0; i < WORKERS; i++) {
        const file = path.join(BUILD, 'edges-' + i + '.bin');
        if(fs.existsSync(file)) files.push(file);
    }

    function sweep(visit) {
        for(const file of files) {
            const raw = fs.readFileSync(file);
            const ints = new Int32Array(raw.buffer, raw.byteOffset, raw.length / 4);
            for(let p = 0; p < ints.length; ) {
                const src = ints[p++];
                const count = ints[p++];
                for(let k = 0; k < count; k++) {
                    const t = ints[p + k];
                    if(!isStub[t]) visit(src, t);
                }
                p += count;
            }
        }
    }

    const outdeg = new Int32Array(n);
    let dropped = 0;
    sweep(src => outdeg[src]++);

    const offsets = new Int32Array(n + 1);
    for(let i = 0; i < n; i++) offsets[i + 1] = offsets[i] + outdeg[i];
    const targets = new Int32Array(offsets[n]);
    const cursor = Int32Array.from(offsets.subarray(0, n));
    sweep((src, t) => { targets[cursor[src]++] = t; });

    dropped = totals.links - offsets[n];
    console.log('  edges to placeholders dropped: ' + dropped.toLocaleString() +
                ' of ' + totals.links.toLocaleString() +
                ' (' + (dropped / totals.links * 100).toFixed(1) + '%)');
    files.forEach(f => fs.unlinkSync(f));

    const header = new Int32Array([n, offsets[n]]);
    const out = path.join(BUILD, 'graph-full.bin');
    fs.writeFileSync(out, Buffer.concat([
        Buffer.from(header.buffer),
        Buffer.from(offsets.buffer),
        Buffer.from(targets.buffer)
    ]));

    console.log('  nodes ' + n.toLocaleString() + ', edges ' + offsets[n].toLocaleString() +
                ', ' + (fs.statSync(out).size / 1024 / 1024).toFixed(1) + ' MB');

    //---- What the stripped graph actually looks like -----------------------------------

    const indegree = new Int32Array(n);
    for(let i = 0; i < targets.length; i++) indegree[targets[i]]++;

    const realIds = [];
    for(let i = 0; i < n; i++) if(!isStub[i]) realIds.push(i);
    const ranked = realIds.slice().sort((a, b) => indegree[b] - indegree[a]);
    console.log('\ntop 25 by in-degree, now that references and navboxes are gone:');
    for(let i = 0; i < 25; i++) {
        console.log('  ' + String(indegree[ranked[i]]).padStart(6) + '  ' + slugs[ranked[i]]);
    }

    //Percentiles over the real articles only; including 173k placeholders would put
    //every percentile below p78 at zero and tell us nothing.
    const sortedOut = Int32Array.from(realIds.map(i => outdeg[i])).sort();
    const sortedIn = Int32Array.from(realIds.map(i => indegree[i])).sort();
    const at = (a, q) => a[Math.floor(a.length * q)];
    console.log('\nover the ' + realIds.length.toLocaleString() + ' real articles:');
    console.log('out-degree: p10=' + at(sortedOut, 0.1) + ' p50=' + at(sortedOut, 0.5) +
                ' p90=' + at(sortedOut, 0.9) + ' max=' + sortedOut[sortedOut.length - 1]);
    console.log('in-degree:  p50=' + at(sortedIn, 0.5) + ' p90=' + at(sortedIn, 0.9) +
                ' p99=' + at(sortedIn, 0.99) + ' max=' + sortedIn[sortedIn.length - 1]);
    console.log('dead ends (real articles with no outbound links): ' +
                realIds.filter(i => outdeg[i] === 0).length.toLocaleString());

    fs.writeFileSync(path.join(BUILD, 'indegree.bin'), Buffer.from(indegree.buffer));
    fs.writeFileSync(path.join(BUILD, 'real.bin'), Buffer.from(isStub.buffer));
    console.log('\nwrote ' + out + ' and indegree.bin');
}

if(process.argv[2] === 'worker') {
    runWorker(parseInt(process.argv[3], 10), parseInt(process.argv[4], 10));
} else {
    runParent();
}
