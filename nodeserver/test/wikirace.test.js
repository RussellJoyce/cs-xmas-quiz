'use strict';

const { test, describe, beforeEach } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');

const { WikiCorpus, WikiRace, REFUSED } = require('../wikirace');

//A hand-built corpus, small enough to reason about completely.
//
//   0 Start ──► 1 Middle ──► 2 Target
//   │            ▲             │
//   └──► 3 Detour┘             └──► 0
//
//Every article can reach every other, which is what the real corpus guarantees by being
//pruned to a strongly connected component.
function tinyCorpus() {
    const links = [
        [1, 3],   //0 Start  -> Middle, Detour
        [2],      //1 Middle -> Target
        [0],      //2 Target -> Start
        [1]       //3 Detour -> Middle
    ];
    const offsets = new Int32Array(links.length + 1);
    links.forEach((row, i) => { offsets[i + 1] = offsets[i] + row.length; });
    const targets = Int32Array.from(links.flat());
    return new WikiCorpus({
        titles: ['Start', 'Middle', 'Target', 'Detour'],
        slugs: ['Start', 'Middle', 'Target', 'Detour'],
        offsets: offsets,
        targets: targets
    });
}

describe('the corpus', () => {
    const corpus = tinyCorpus();

    test('knows which articles exist', () => {
        assert.ok(corpus.has(0));
        assert.ok(corpus.has(3));
        assert.ok(!corpus.has(4));
        assert.ok(!corpus.has(-1));
        //A non-integer id is what a malformed client message produces
        assert.ok(!corpus.has(NaN));
        assert.ok(!corpus.has(1.5));
    });

    test('reports an article links', () => {
        assert.deepStrictEqual(Array.from(corpus.outlinks(0)), [1, 3]);
        assert.deepStrictEqual(Array.from(corpus.outlinks(1)), [2]);
    });

    test('an unknown article has no links rather than throwing', () => {
        assert.strictEqual(corpus.outlinks(99).length, 0);
    });

    test('isLinked follows the graph, both what is there and what is not', () => {
        assert.ok(corpus.isLinked(0, 1));
        assert.ok(corpus.isLinked(0, 3));
        //The whole point: Start does not link to Target, however much a client insists.
        assert.ok(!corpus.isLinked(0, 2));
        assert.ok(!corpus.isLinked(0, 99));
    });

    test('distances are measured towards the target, not away from it', () => {
        //Distance TO article 2: Middle is 1 away, Start and Detour are 2.
        const dist = corpus.distancesTo(2);
        assert.strictEqual(dist[2], 0);
        assert.strictEqual(dist[1], 1);
        assert.strictEqual(dist[0], 2);
        assert.strictEqual(dist[3], 2);
    });
});

describe('loading a corpus from disk', () => {
    test('a directory with no corpus in it is null, not an error', () => {
        //The corpus is gitignored, so this is the normal state of a fresh clone.
        assert.strictEqual(WikiCorpus.load(path.join(os.tmpdir(), 'definitely-not-a-corpus')), null);
    });

    test('an index and a graph that disagree are rejected loudly', () => {
        //Half a rebuild would otherwise produce a corpus that mostly works and
        //occasionally sends a team to the wrong article.
        const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'wiki-'));
        fs.writeFileSync(path.join(dir, 'index.json'),
                         JSON.stringify({ titles: ['A', 'B', 'C'], slugs: ['A', 'B', 'C'] }));
        //A graph claiming two articles against the index's three
        const header = new Int32Array([2, 0]);
        const offsets = new Int32Array(3);
        fs.writeFileSync(path.join(dir, 'graph.bin'),
                         Buffer.concat([Buffer.from(header.buffer), Buffer.from(offsets.buffer)]));
        assert.throws(() => WikiCorpus.load(dir), /inconsistent/);
    });
});

describe('a race', () => {
    let corpus, race;
    beforeEach(() => {
        corpus = tinyCorpus();
        race = new WikiRace(corpus, 3);
        race.begin(0, 2);
    });

    test('starts every team on the start article', () => {
        for(const team of [1, 2, 3]) {
            assert.strictEqual(race.positionOf(team), 0);
            assert.strictEqual(race.hopsOf(team), 0);
        }
    });

    test('will not begin on an article that is not in the corpus', () => {
        const bad = new WikiRace(corpus, 3);
        assert.strictEqual(bad.begin(0, 99), false);
        assert.strictEqual(bad.running, false);
    });

    test('accepts a move along a real link', () => {
        const result = race.move(1, 1);
        assert.strictEqual(result.ok, true);
        assert.strictEqual(result.hops, 1);
        assert.strictEqual(race.positionOf(1), 1);
    });

    test('REFUSES a jump to an article that is not linked from the current page', () => {
        //This is the rule the whole round rests on.
        const result = race.move(1, 2);
        assert.strictEqual(result.ok, false);
        assert.strictEqual(result.reason, REFUSED.NOT_LINKED);
        //And the team has not moved
        assert.strictEqual(race.positionOf(1), 0);
        assert.strictEqual(race.hopsOf(1), 0);
    });

    test('refuses an article that does not exist at all', () => {
        assert.strictEqual(race.move(1, 99).reason, REFUSED.UNKNOWN);
        assert.strictEqual(race.move(1, NaN).reason, REFUSED.UNKNOWN);
    });

    test('refuses any move before a race has started', () => {
        const idle = new WikiRace(corpus, 3);
        assert.strictEqual(idle.move(1, 1).reason, REFUSED.NO_RACE);
    });

    test('refuses moves once the race has been ended', () => {
        race.end();
        assert.strictEqual(race.move(1, 1).reason, REFUSED.NO_RACE);
    });

    test('notices arrival at the target', () => {
        race.move(1, 1);
        const result = race.move(1, 2);
        assert.strictEqual(result.arrived, true);
        assert.strictEqual(result.hops, 2);
        assert.ok(race.hasFinished(1));
    });

    test('a team that has arrived cannot keep going', () => {
        race.move(1, 1);
        race.move(1, 2);
        assert.strictEqual(race.move(1, 0).reason, REFUSED.FINISHED);
    });

    test('teams do not interfere with each other', () => {
        race.move(1, 1);
        race.move(2, 3);
        assert.strictEqual(race.positionOf(1), 1);
        assert.strictEqual(race.positionOf(2), 3);
        assert.strictEqual(race.positionOf(3), 0);
    });

    describe('going back', () => {
        test('returns to the previous article', () => {
            race.move(1, 3);
            const result = race.back(1);
            assert.strictEqual(result.ok, true);
            assert.strictEqual(race.positionOf(1), 0);
        });

        test('is free: it undoes the hop it is undoing', () => {
            race.move(1, 3);
            assert.strictEqual(race.hopsOf(1), 1);
            race.back(1);
            assert.strictEqual(race.hopsOf(1), 0);
        });

        test('is still recorded in the trail, so the reveal shows the dead end', () => {
            race.move(1, 3);
            race.back(1);
            race.move(1, 1);
            assert.deepStrictEqual(race.stateOf(1).trail, [0, 3, 0, 1]);
            //but the route the team actually took is the short one
            assert.deepStrictEqual(race.stateOf(1).route, [0, 1]);
        });

        test('at the start there is nothing to undo', () => {
            assert.strictEqual(race.back(1).ok, false);
            assert.strictEqual(race.positionOf(1), 0);
        });
    });

    describe('standings', () => {
        test('put teams that arrived above teams that did not', () => {
            race.move(2, 1);
            race.move(2, 2);          //team 2 arrives
            race.move(1, 3);          //team 1 wanders off
            const rows = race.standings();
            assert.strictEqual(rows[0].team, 2);
            assert.strictEqual(rows[0].finished, true);
            assert.ok(!rows[1].finished);
        });

        test('rank the unfinished by how far they still had to go', () => {
            race.move(1, 1);          //Middle: one link from the target
            race.move(2, 3);          //Detour: two links from the target
            const unfinished = race.standings().filter(r => !r.finished);
            assert.strictEqual(unfinished[0].team, 1);
            assert.strictEqual(unfinished[0].away, 1);
            assert.strictEqual(unfinished[1].away, 2);
        });

        test('report where each team actually ended up', () => {
            race.move(1, 3);
            const row = race.standings().find(r => r.team === 1);
            assert.strictEqual(row.at, 3);
            assert.strictEqual(row.title, 'Detour');
        });
    });
});
