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

        describe('are scored on the closest a team ever got', () => {
            //A clock the test moves by hand, so that "first" is not left to chance
            let clock;
            beforeEach(() => {
                clock = 1000;
                race = new WikiRace(corpus, 3);
                race.now = () => clock;
                race.begin(0, 2);
            });

            test('not where it ended up', () => {
                race.move(1, 1);      //Middle, one away...
                clock += 5000;
                race.back(1);         //...then back to Start, two away
                race.move(2, 3);      //Detour, two away, and stays there
                const rows = race.standings();
                assert.strictEqual(rows[0].team, 1);
                assert.strictEqual(rows[0].away, 1);
                assert.strictEqual(rows[0].at, 0, 'but it is reported as ending up at the start');
            });

            test('with a tie going to whoever got there first', () => {
                clock += 3000;
                race.move(2, 1);      //team 2 at Middle after 3s
                clock += 4000;
                race.move(1, 1);      //team 1 at Middle after 7s
                const rows = race.standings();
                assert.deepStrictEqual(rows.slice(0, 2).map(r => [r.team, r.away, r.seconds]),
                                       [[2, 1, 3], [1, 1, 7]]);
            });

            test('by the time it first got there, not the last', () => {
                clock += 2000;
                race.move(1, 1);      //Middle at 2s
                race.back(1);
                clock += 1000;
                race.move(2, 1);      //team 2 to Middle at 3s
                clock += 6000;
                race.move(1, 1);      //team 1 back to Middle at 9s
                const rows = race.standings();
                assert.deepStrictEqual(rows.slice(0, 2).map(r => [r.team, r.seconds]), [[1, 2], [2, 3]]);
            });

            test('only to the millisecond, beyond the whole seconds reported', () => {
                clock += 2400;
                race.move(3, 1);
                clock += 300;          //2.7s, which also rounds to 3
                race.move(1, 1);
                const rows = race.standings();
                assert.deepStrictEqual(rows.slice(0, 2).map(r => r.team), [3, 1]);
            });

            test('arriving is getting to nothing away, and the first to arrive wins', () => {
                clock += 1000;
                race.move(1, 1);
                clock += 1000;
                race.move(1, 2);      //team 1 arrives at 2s
                race.move(2, 1);
                clock += 1000;
                race.move(2, 2);      //team 2 arrives at 3s
                const rows = race.standings();
                assert.deepStrictEqual(rows.map(r => [r.team, r.finished, r.away, r.seconds]),
                                       [[1, true, 0, 2], [2, true, 0, 3], [3, false, 2, 0]]);
            });

            test('a team that never got closer than the start is there at no time at all', () => {
                clock += 4000;
                race.move(1, 3);      //Detour is no closer than Start
                const row = race.standings().find(r => r.team === 1);
                assert.strictEqual(row.away, 2);
                assert.strictEqual(row.seconds, 0);
            });
        });

        test('report where each team actually ended up', () => {
            race.move(1, 3);
            const row = race.standings().find(r => r.team === 1);
            assert.strictEqual(row.at, 3);
            assert.strictEqual(row.title, 'Detour');
        });
    });
});
