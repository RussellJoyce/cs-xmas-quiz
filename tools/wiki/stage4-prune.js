'use strict';

//Stage 4: reduce the selected candidates to a set where every race is winnable.
//
//we keep only the largest strongly connected component, in which every ordered pair 
//is reachable in both directions by construction.
//
//Reads corpus/build/{selected.json, graph-full.bin, articles.json}
//Writes corpus/build/corpus.json

const fs = require('fs');
const path = require('path');

const BUILD = path.join(__dirname, 'corpus', 'build');

//Reads the CSR written by stage 2.
function loadGraph(file) {
    const raw = fs.readFileSync(file);
    const header = new Int32Array(raw.buffer, raw.byteOffset, 2);
    const n = header[0], m = header[1];
    const offsets = new Int32Array(raw.buffer, raw.byteOffset + 8, n + 1);
    const targets = new Int32Array(raw.buffer, raw.byteOffset + 8 + (n + 1) * 4, m);
    return { n, m, offsets, targets };
}

//Breadth-first over a CSR, returning the bitmap of everything reached from `from`.
function reachable(n, offsets, targets, from) {
    const seen = new Uint8Array(n);
    const queue = new Int32Array(n);
    let head = 0, tail = 0;
    seen[from] = 1;
    queue[tail++] = from;
    while(head < tail) {
        const v = queue[head++];
        for(let p = offsets[v]; p < offsets[v + 1]; p++) {
            const w = targets[p];
            if(!seen[w]) { seen[w] = 1; queue[tail++] = w; }
        }
    }
    return seen;
}

//Turns an edge list into CSR. Used for both the induced subgraph and its reverse.
function toCsr(n, edges) {
    const outdeg = new Int32Array(n);
    for(let i = 0; i < edges.length; i += 2) outdeg[edges[i]]++;
    const offsets = new Int32Array(n + 1);
    for(let i = 0; i < n; i++) offsets[i + 1] = offsets[i] + outdeg[i];
    const targets = new Int32Array(offsets[n]);
    const cursor = Int32Array.from(offsets.subarray(0, n));
    for(let i = 0; i < edges.length; i += 2) targets[cursor[edges[i]]++] = edges[i + 1];
    return { offsets, targets };
}

function main() {
    const selected = JSON.parse(fs.readFileSync(path.join(BUILD, 'selected.json'), 'utf8'));
    const { slugs, titles } = JSON.parse(fs.readFileSync(path.join(BUILD, 'articles.json'), 'utf8'));
    const full = loadGraph(path.join(BUILD, 'graph-full.bin'));

    const ids = selected.ids;
    const n = ids.length;
    console.log(n.toLocaleString() + ' candidates from stage 3');

    //---- Induce the subgraph ----------------------------------------------------------

    //Local ids run 0..n-1 over the candidates. Everything from here works in local space
    //and only converts back at the end.
    const localOf = new Int32Array(full.n).fill(-1);
    for(let i = 0; i < n; i++) localOf[ids[i]] = i;

    const edges = [];
    for(let i = 0; i < n; i++) {
        const g = ids[i];
        for(let p = full.offsets[g]; p < full.offsets[g + 1]; p++) {
            const to = localOf[full.targets[p]];
            if(to >= 0) edges.push(i, to); //links out of the candidate set simply vanish
        }
    }
    console.log('induced subgraph: ' + (edges.length / 2).toLocaleString() + ' edges' +
                ' (mean out-degree ' + (edges.length / 2 / n).toFixed(1) + ')');

    const forward = toCsr(n, edges);
    const reverseEdges = new Array(edges.length);
    for(let i = 0; i < edges.length; i += 2) {
        reverseEdges[i] = edges[i + 1];
        reverseEdges[i + 1] = edges[i];
    }
    const backward = toCsr(n, reverseEdges);

    //---- The giant component ----------------------------------------------------------

    //Start from the most linked-to candidate, which stage 3 sorted to the front.
    const root = 0;
    console.log('\nseed article: ' + slugs[ids[root]]);

    const canReach = reachable(n, forward.offsets, forward.targets, root);
    const reachedBy = reachable(n, backward.offsets, backward.targets, root);

    const keep = [];
    for(let i = 0; i < n; i++) if(canReach[i] && reachedBy[i]) keep.push(i);

    console.log('  reachable from it:    ' + canReach.reduce((a, b) => a + b, 0).toLocaleString());
    console.log('  that reach it:        ' + reachedBy.reduce((a, b) => a + b, 0).toLocaleString());
    console.log('  strongly connected:   ' + keep.length.toLocaleString() +
                ' (' + (keep.length / n * 100).toFixed(1) + '% of candidates)');

    if(keep.length < n * 0.5) {
        console.log('\n  *** less than half the candidates survived. Either the selection is');
        console.log('  *** too wide or the seed is not in the giant component. Worth a look.');
    }

    //---- Emit -------------------------------------------------------------------------

    //Final ids run 0..keep.length-1 in the order the candidates were ranked, so id 0 is
    //still the most linked-to article and the corpus stays sorted by notability.
    const finalOf = new Int32Array(n).fill(-1);
    keep.forEach((local, i) => { finalOf[local] = i; });

    const outEdges = [];
    for(const local of keep) {
        const from = finalOf[local];
        for(let p = forward.offsets[local]; p < forward.offsets[local + 1]; p++) {
            const to = finalOf[forward.targets[p]];
            if(to >= 0) outEdges.push(from, to);
        }
    }
    const finalGraph = toCsr(keep.length, outEdges);

    const corpus = {
        slugs: keep.map(local => slugs[ids[local]]),
        titles: keep.map(local => titles[ids[local]]),
        indegree: keep.map(local => selected.indegree[local])
    };

    fs.writeFileSync(path.join(BUILD, 'corpus.json'), JSON.stringify(corpus));
    const header = new Int32Array([keep.length, outEdges.length / 2]);
    fs.writeFileSync(path.join(BUILD, 'graph.bin'), Buffer.concat([
        Buffer.from(header.buffer),
        Buffer.from(finalGraph.offsets.buffer),
        Buffer.from(finalGraph.targets.buffer)
    ]));

    //---- What the playable corpus looks like ------------------------------------------

    const outdeg = [];
    for(let i = 0; i < keep.length; i++) outdeg.push(finalGraph.offsets[i + 1] - finalGraph.offsets[i]);
    outdeg.sort((a, b) => a - b);
    const at = q => outdeg[Math.floor(outdeg.length * q)];

    console.log('\nplayable corpus: ' + keep.length.toLocaleString() + ' articles, ' +
                (outEdges.length / 2).toLocaleString() + ' links');
    console.log('out-degree: min=' + outdeg[0] + ' p10=' + at(0.1) + ' p50=' + at(0.5) +
                ' p90=' + at(0.9) + ' max=' + outdeg[outdeg.length - 1]);
    console.log('\nwrote corpus.json and graph.bin');
}

main();
