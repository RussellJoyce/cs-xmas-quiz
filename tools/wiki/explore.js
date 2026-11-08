'use strict';

//Explore the shipped wikirace corpus to choose puzzles. Run with no arguments for help.
//
//Reads nodeserver/static/wiki (the same index.json and graph.bin the server validates moves
//against), so a distance reported here is the distance the game will enforce.

const fs = require('fs');
const path = require('path');
const { WikiCorpus } = require('../../nodeserver/wikirace');
const X = require('./lib/explore');

const WIKI = process.env.QUIZ_WIKI_DIR || path.join(__dirname, '..', '..', 'nodeserver', 'static', 'wiki');
const CURATED = X.CURATED;

const HELP = `Explore the wikirace corpus to choose puzzles.

  node explore.js find <text>                  titles containing <text>, most linked-to first
  node explore.js route <start> <target>       distance, how many shortest routes, a sample of them
          [--routes N]                         how many routes to show (default 8)
  node explore.js near --to <target> --hops H  starts exactly H hops from <target>
  node explore.js near --from <start> --hops H targets exactly H hops from <start>
          [--famous N]                         only the N most linked-to articles (default 3000)
          [--limit N]                          how many to list (default 40)
          [--sort fame|routes]                 best known first (default), or most forgiving first
  node explore.js random --hops H              random pairs H hops apart, both ends famous,
          [--famous N] [--count N]             for browsing for funny ones (defaults 3000, 30)
          [--min-routes N]                     only pairs with at least N routes one hop longer
  node explore.js add <start> <target> [note]  check a pair and add it to the curated list
  node explore.js curated                      list the curated puzzles and check they still resolve

The curated list is Questions/Wikirace/curated.json, which git ignores like the other
questions. Set QUIZ_WIKI_CURATED to use another file.

"links in" is how many articles link to an article. A target with few is hard to find.

"routes" is how forgiving a puzzle is: "6 / 204" means 6 shortest routes and 204 that take one
hop more. Teams seldom find a shortest route, so the second number is the better guide to how
frustrating a race will be. Both are exact counts.
Titles are matched exactly, then ignoring case. Quote titles with spaces.`;

function fail(message) {
    console.error(message);
    process.exit(1);
}

function parse(argv) {
    const positional = [], flags = {};
    for(let i = 0; i < argv.length; i++) {
        if(argv[i].startsWith('--')) flags[argv[i].slice(2)] = argv[++i];
        else positional.push(argv[i]);
    }
    return { positional, flags };
}

function int(flags, name, fallback) {
    if(flags[name] === undefined) return fallback;
    const n = parseInt(flags[name], 10);
    if(!Number.isInteger(n) || n < 0) fail('--' + name + ' needs a whole number, got ' + flags[name]);
    return n;
}

function load() {
    const corpus = WikiCorpus.load(WIKI);
    if(!corpus) fail('no corpus at ' + WIKI + '. Build it with the stages in README.md.');
    const deg = X.inDegrees(corpus);
    return { corpus, deg, rank: X.fameRanks(deg) };
}

function resolve(ctx, title) {
    const id = X.findTitle(ctx.corpus, title);
    if(id !== null) return id;
    const close = X.searchTitles(ctx.corpus, ctx.deg, title, 8).map(i => '  ' + ctx.corpus.titles[i]);
    fail('"' + title + '" is not in the corpus.' + (close.length ? ' Titles containing it:\n' + close.join('\n') : ''));
}

function describe(ctx, id) {
    return ctx.corpus.titles[id] + '  (' + ctx.deg[id] + ' links in, #' + ctx.rank[id] + ')';
}

function count(ways) {
    return ways >= 1e6 ? ways.toExponential(1) : Math.round(ways).toLocaleString();
}

//Shortest routes and routes one hop longer, for one pair `hops` apart
function forgiveness(ctx, start, target, hops) {
    const walks = X.walkCounts(ctx.corpus, target, hops + 1, true);
    return { shortest: walks[hops][start], longer: walks[hops + 1][start] };
}

function routes(f) {
    return count(f.shortest) + ' / ' + count(f.longer) + ' routes';
}

//---- Commands -------------------------------------------------------------------------

function find(ctx, text) {
    if(!text) fail('find needs some text');
    const hits = X.searchTitles(ctx.corpus, ctx.deg, text, 40);
    if(hits.length === 0) console.log('nothing contains "' + text + '"');
    hits.forEach(id => console.log('  ' + describe(ctx, id)));
}

function route(ctx, startTitle, targetTitle, flags) {
    if(!startTitle || !targetTitle) fail('route needs a start and a target');
    const start = resolve(ctx, startTitle), target = resolve(ctx, targetTitle);
    const dist = ctx.corpus.distancesTo(target);
    const back = X.distancesFrom(ctx.corpus, target)[start];

    console.log('from    ' + describe(ctx, start));
    console.log('to      ' + describe(ctx, target));
    if(dist[start] < 0) { console.log('\nno route at all'); return; }

    const ways = X.routeCounts(ctx.corpus, dist);
    const f = forgiveness(ctx, start, target, dist[start]);
    console.log('\n' + dist[start] + ' hops, ' + count(ways[start]) + ' shortest route' +
                (ways[start] === 1 ? '' : 's') + ' and ' + count(f.longer) + ' one hop longer. ' +
                'The other way round is ' + back + ' hops.\n');
    for(const r of X.sampleRoutes(ctx.corpus, dist, ways, start, int(flags, 'routes', 8))) {
        console.log('  ' + r.map(id => ctx.corpus.titles[id]).join('  →  '));
    }
}

function near(ctx, flags) {
    const hops = int(flags, 'hops', null);
    if(hops === null || (!flags.to === !flags.from)) fail('near needs --hops and one of --to or --from');
    const famous = int(flags, 'famous', 3000), limit = int(flags, 'limit', 40);
    const sort = flags.sort || 'fame';
    if(sort !== 'fame' && sort !== 'routes') fail('--sort is fame or routes, not ' + sort);
    const toward = Boolean(flags.to);
    const anchor = resolve(ctx, toward ? flags.to : flags.from);
    const dist = toward ? ctx.corpus.distancesTo(anchor) : X.distancesFrom(ctx.corpus, anchor);
    //One count from the anchor covers every article paired with it
    const walks = X.walkCounts(ctx.corpus, anchor, hops + 1, toward);
    const f = id => ({ shortest: walks[hops][id], longer: walks[hops + 1][id] });

    const hits = [];
    for(let id = 0; id < ctx.corpus.size; id++) {
        if(dist[id] === hops && ctx.rank[id] <= famous) hits.push(id);
    }
    if(sort === 'routes') {
        hits.sort((a, b) => walks[hops + 1][b] - walks[hops + 1][a] || walks[hops][b] - walks[hops][a]);
    } else {
        hits.sort((a, b) => ctx.rank[a] - ctx.rank[b]);
    }
    console.log(hits.length + ' of the ' + famous + ' most linked-to articles are ' + hops + ' hops ' +
                (toward ? 'from' : 'away from') + ' ' + describe(ctx, anchor) +
                (hits.length > limit ? '. The ' + limit + (sort === 'routes' ? ' most forgiving:' : ' best known:') : ':'));
    hits.slice(0, limit).forEach(id => console.log('  ' + describe(ctx, id) + '   ' + routes(f(id))));
}

function random(ctx, flags) {
    const hops = int(flags, 'hops', null);
    if(hops === null) fail('random needs --hops');
    const famous = Math.min(int(flags, 'famous', 3000), ctx.corpus.size);
    const wanted = int(flags, 'count', 30);
    const minRoutes = int(flags, 'min-routes', 0);
    const pool = Array.from(ctx.rank.keys()).filter(id => ctx.rank[id] <= famous);

    //One search per target finds every start at the right distance, so pick a target, then
    //one start for it, and move on: that keeps the list from being one target over and over.
    let found = 0;
    for(let tries = 0; found < wanted && tries < wanted * 20; tries++) {
        const target = pool[Math.floor(Math.random() * pool.length)];
        const dist = ctx.corpus.distancesTo(target);
        let starts = pool.filter(id => dist[id] === hops);
        if(starts.length === 0) continue;
        const walks = X.walkCounts(ctx.corpus, target, hops + 1, true);
        starts = starts.filter(id => walks[hops + 1][id] >= minRoutes);
        if(starts.length === 0) continue;
        const start = starts[Math.floor(Math.random() * starts.length)];
        console.log('  ' + ctx.corpus.titles[start] + '  →  ' + ctx.corpus.titles[target] +
                    '   (' + ctx.deg[target] + ' links in, ' +
                    routes({ shortest: walks[hops][start], longer: walks[hops + 1][start] }) + ')');
        found++;
    }
    if(found < wanted) {
        console.log('found only ' + found + '. Famous articles are rarely more than 6 hops apart, ' +
                    'so for longer routes raise --famous (the corpus has ' + ctx.corpus.size + ')' +
                    (minRoutes ? ', or lower --min-routes.' : '.'));
    }
}

function readCurated() {
    if(!fs.existsSync(CURATED)) return [];
    return JSON.parse(fs.readFileSync(CURATED, 'utf8'));
}

function add(ctx, startTitle, targetTitle, note) {
    if(!startTitle || !targetTitle) fail('add needs a start and a target');
    const start = resolve(ctx, startTitle), target = resolve(ctx, targetTitle);
    if(start === target) fail('the start and the target are the same article');
    const hops = ctx.corpus.distancesTo(target)[start];
    if(hops < 0) fail('there is no route from ' + ctx.corpus.titles[start] + ' to ' + ctx.corpus.titles[target]);

    const curated = readCurated();
    fs.mkdirSync(path.dirname(CURATED), { recursive: true });
    const entry = { start: ctx.corpus.titles[start], target: ctx.corpus.titles[target] };
    if(curated.some(p => p.start === entry.start && p.target === entry.target)) {
        fail('already curated: ' + entry.start + ' → ' + entry.target);
    }
    if(note) entry.note = note;
    curated.push(entry);
    fs.writeFileSync(CURATED, JSON.stringify(curated, null, 1) + '\n');
    console.log('added ' + entry.start + ' → ' + entry.target + ' (' + hops + ' hops, ' +
                routes(forgiveness(ctx, start, target, hops)) + '). ' +
                'Run "node stage5-emit.js puzzles" to put it in the game.');
}

function curated(ctx) {
    const list = readCurated();
    if(list.length === 0) console.log('nothing curated yet: see "add"');
    for(const p of list) {
        const start = X.findTitle(ctx.corpus, p.start), target = X.findTitle(ctx.corpus, p.target);
        let status;
        if(start === null || target === null) status = 'MISSING from this corpus';
        else {
            const hops = ctx.corpus.distancesTo(target)[start];
            status = hops + ' hops, ' + routes(forgiveness(ctx, start, target, hops)) +
                     ', target ' + ctx.deg[target] + ' links in';
        }
        console.log('  ' + p.start + '  →  ' + p.target + '   ' + status + (p.note ? '   "' + p.note + '"' : ''));
    }
}

//---- Main -----------------------------------------------------------------------------

const [command, ...rest] = process.argv.slice(2);
const { positional, flags } = parse(rest);
const commands = {
    find: ctx => find(ctx, positional.join(' ')),
    route: ctx => route(ctx, positional[0], positional[1], flags),
    near: ctx => near(ctx, flags),
    random: ctx => random(ctx, flags),
    add: ctx => add(ctx, positional[0], positional[1], positional[2]),
    curated: ctx => curated(ctx)
};
if(!commands[command]) {
    console.log(HELP);
    process.exit(command ? 1 : 0);
}
commands[command](load());
