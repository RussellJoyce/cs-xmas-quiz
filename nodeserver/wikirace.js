'use strict';

//The wikirace round: the corpus the teams browse, and the state of a race in progress.
//Built by tools/wiki into nodeserver/static/wiki. See docs/wikirace.md.

const fs = require('fs');
const path = require('path');
const log = require('./log');

//---------------------------------------------------------------------------------------
// The corpus
//---------------------------------------------------------------------------------------

//Articles are integer ids. The link graph is compressed sparse row: `offsets[i]` to
//`offsets[i+1]` is the slice of `targets` holding everything article i links to
class WikiCorpus {

    constructor(data) {
        this.titles = data.titles;
        this.slugs = data.slugs || [];
        this.shard = data.shard || 1000;
        this.offsets = data.offsets;
        this.targets = data.targets;
        this.size = this.titles.length;
    }

    static load(dir) {
        const indexFile = path.join(dir, 'index.json');
        const graphFile = path.join(dir, 'graph.bin');
        if(!fs.existsSync(indexFile) || !fs.existsSync(graphFile)) {
            return null;
        }

        const index = JSON.parse(fs.readFileSync(indexFile, 'utf8'));
        const raw = fs.readFileSync(graphFile);
        const header = new Int32Array(raw.buffer, raw.byteOffset, 2);
        const n = header[0], m = header[1];

        if(n !== index.titles.length) {
            throw new Error('wiki corpus is inconsistent: graph.bin has ' + n +
                            ' articles, index.json has ' + index.titles.length);
        }

        return new WikiCorpus({
            titles: index.titles,
            slugs: index.slugs,
            shard: index.shard,
            offsets: new Int32Array(raw.buffer, raw.byteOffset + 8, n + 1),
            targets: new Int32Array(raw.buffer, raw.byteOffset + 8 + (n + 1) * 4, m)
        });
    }

    has(id) {
        return Number.isInteger(id) && id >= 0 && id < this.size;
    }

    title(id) {
        return this.has(id) ? this.titles[id] : '?';
    }

    //Everything article `id` links to.
    outlinks(id) {
        if(!this.has(id)) return new Int32Array(0);
        return this.targets.subarray(this.offsets[id], this.offsets[id + 1]);
    }

    isLinked(from, to) {
        if(!this.has(from) || !this.has(to)) return false;
        const end = this.offsets[from + 1];
        for(let p = this.offsets[from]; p < end; p++) {
            if(this.targets[p] === to) return true;
        }
        return false;
    }

    //The graph with every link turned around, so that a search can run backwards from the target
    reverse() {
        if(this._reverse) return this._reverse;
        const n = this.size, m = this.targets.length;
        const indeg = new Int32Array(n);
        for(let i = 0; i < m; i++) indeg[this.targets[i]]++;
        const offsets = new Int32Array(n + 1);
        for(let i = 0; i < n; i++) offsets[i + 1] = offsets[i] + indeg[i];
        const targets = new Int32Array(m);
        const cursor = Int32Array.from(offsets.subarray(0, n));
        for(let v = 0; v < n; v++) {
            for(let p = this.offsets[v]; p < this.offsets[v + 1]; p++) {
                targets[cursor[this.targets[p]]++] = v;
            }
        }
        this._reverse = { offsets, targets };
        return this._reverse;
    }

    //How many links every article in the corpus is from `target`.
    //Unreachable articles come back as -1
    distancesTo(target) {
        const n = this.size;
        const dist = new Int32Array(n).fill(-1);
        if(!this.has(target)) return dist;

        const rev = this.reverse();
        const queue = new Int32Array(n);
        let head = 0, tail = 0;
        dist[target] = 0;
        queue[tail++] = target;
        while(head < tail) {
            const v = queue[head++];
            for(let p = rev.offsets[v]; p < rev.offsets[v + 1]; p++) {
                const w = rev.targets[p];
                if(dist[w] < 0) { dist[w] = dist[v] + 1; queue[tail++] = w; }
            }
        }
        return dist;
    }

}

//---------------------------------------------------------------------------------------
// A race
//---------------------------------------------------------------------------------------

const REFUSED = {
    NO_RACE: 'no race is running',
    FINISHED: 'already arrived',
    UNKNOWN: 'no such article',
    NOT_LINKED: 'not a link on that page'
};

class WikiRace {

    constructor(corpus, numTeams) {
        this.corpus = corpus;
        this.numTeams = numTeams;
        this.running = false;
        this.start = -1;
        this.target = -1;
        this.startedAt = 0;
        this.distances = null;
        this.teams = {};
    }

    awayFrom(id) {
        if(!this.distances || !this.corpus.has(id)) return -1;
        return this.distances[id];
    }

    //Fresh state for one team. 1-based
    static blank(start) {
        return {
            route: [start],   //the path from the start to where they are now; Back pops it
            trail: [start],   //every article visited, including ones backed out of
            finishedAt: 0
        };
    }

    begin(start, target) {
        if(!this.corpus.has(start) || !this.corpus.has(target)) {
            return false;
        }
        this.running = true;
        this.start = start;
        this.target = target;
        this.startedAt = Date.now();
        this.distances = this.corpus.distancesTo(target);
        this.teams = {};
        for(let team = 1; team <= this.numTeams; team++) {
            this.teams[team] = WikiRace.blank(start);
        }
        return true;
    }

    end() {
        this.running = false;
    }

    stateOf(team) {
        return this.teams[team] || null;
    }

    positionOf(team) {
        const state = this.teams[team];
        return state ? state.route[state.route.length - 1] : -1;
    }

    hopsOf(team) {
        const state = this.teams[team];
        return state ? state.route.length - 1 : 0;
    }

    hasFinished(team) {
        const state = this.teams[team];
        return Boolean(state && state.finishedAt);
    }

    //A team clicking a link. Returns {ok: true, ...} or {ok: false, reason}.
    move(team, to) {
        if(!this.running) return { ok: false, reason: REFUSED.NO_RACE };
        const state = this.teams[team];
        if(!state) return { ok: false, reason: REFUSED.NO_RACE };
        if(state.finishedAt) return { ok: false, reason: REFUSED.FINISHED };
        if(!this.corpus.has(to)) return { ok: false, reason: REFUSED.UNKNOWN };

        const from = state.route[state.route.length - 1];
        if(!this.corpus.isLinked(from, to)) {
            return { ok: false, reason: REFUSED.NOT_LINKED };
        }

        state.route.push(to);
        state.trail.push(to);

        const arrived = (to === this.target);
        if(arrived) state.finishedAt = Date.now();

        return {
            ok: true,
            to: to,
            hops: state.route.length - 1,
            away: this.awayFrom(to),
            arrived: arrived,
            seconds: arrived ? Math.round((state.finishedAt - this.startedAt) / 1000) : 0
        };
    }

    //Back one step. Free, but recorded.
    back(team) {
        if(!this.running) return { ok: false, reason: REFUSED.NO_RACE };
        const state = this.teams[team];
        if(!state) return { ok: false, reason: REFUSED.NO_RACE };
        if(state.finishedAt) return { ok: false, reason: REFUSED.FINISHED };
        if(state.route.length < 2) {
            return { ok: false, reason: 'already at the start' };
        }

        state.route.pop();
        const to = state.route[state.route.length - 1];
        state.trail.push(to);
        return { ok: true, to: to, hops: state.route.length - 1,
                 away: this.awayFrom(to), arrived: false, seconds: 0 };
    }

    //Final standings, for the reveal and for scoring.
    standings() {
        //Already computed at the start of the race.
        const dist = this.distances || this.corpus.distancesTo(this.target);
        const rows = [];
        for(let team = 1; team <= this.numTeams; team++) {
            const state = this.teams[team];
            if(!state) continue;
            const at = state.route[state.route.length - 1];
            rows.push({
                team: team,
                finished: Boolean(state.finishedAt),
                seconds: state.finishedAt ? Math.round((state.finishedAt - this.startedAt) / 1000) : 0,
                hops: state.route.length - 1,
                at: at,
                title: this.corpus.title(at),
                away: state.finishedAt ? 0 : dist[at],
                trail: state.trail.slice()
            });
        }
        rows.sort(function(a, b) {
            if(a.finished !== b.finished) return a.finished ? -1 : 1;
            if(a.finished) return a.seconds - b.seconds;
            if(a.away !== b.away) return a.away - b.away;
            return a.hops - b.hops;
        });
        return rows;
    }
}

module.exports = { WikiCorpus, WikiRace, REFUSED };
