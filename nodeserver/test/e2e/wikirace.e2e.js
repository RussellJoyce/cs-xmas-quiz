'use strict';

//The wikirace, on its own page, against the small corpus in fixtures.js.

const assert = require('node:assert');
const { quizScenarios, until } = require('./rig');
const { WIKI } = require('./fixtures');

const [START, MIDDLE, FINISH, DETOUR] = WIKI.titles;

const onArticle = (phone, title) => until('the phone on ' + title, async () => (await phone.articleTitle.textContent()) === title);

//The server is the only thing that moves a team, so wait for it to say so
async function follow(phone, title) {
    await phone.press(phone.link(title));
    await onArticle(phone, title);
}

quizScenarios('wikirace', { teams: 3 }, scenario => {

    scenario('the host sees the note and the shortest routes of the chosen puzzle', async quiz => {
        await quiz.round('wikirace');
        const routes = async () => (await quiz.host.read('wikiRacePanel.bestRouteText')).value;
        const arrow = '  →  ';
        assert.strictEqual(await routes(), 'A note for the host\n\n' + [START, MIDDLE, FINISH].join(' → '));
        assert.strictEqual((await quiz.host.read('wikiRacePanel.questionSelector')).title,
                           START + arrow + FINISH + '   (2 hops)');

        await quiz.host.set('wikiRacePanel.questionSelector', DETOUR + arrow + FINISH + '   (2 hops)');
        assert.strictEqual(await routes(), '2.5 million shortest routes of 2 hops. 3 of them:\n\n' +
                           [DETOUR, MIDDLE, FINISH].join(' → ') + '\n\nX → Y → Z\n\nP → Q → R');
        await quiz.host.set('wikiRacePanel.questionSelector', START + arrow + FINISH + '   (2 hops)');
    });

    scenario('Show Route puts the race on the display and tells nobody else', async quiz => {
        const mark = quiz.wire.length;
        await quiz.host.click('wikiRacePanel.showButton');
        assert.strictEqual(await quiz.host.read('quizDisplay.wikiRaceScene.startTitle'), START);
        assert.strictEqual(await quiz.host.read('quizDisplay.wikiRaceScene.targetTitle'), FINISH);
        await quiz.host.settled();
        assert.ok(!quiz.wire.some((w, i) => i >= mark && w.dir === 'host→srv' && w.msg.startsWith('wr')), 'the race was started');
    });

    scenario('every phone goes to the race page and starts on the same article', async quiz => {
        await quiz.host.setToggle('wikiRacePanel.showDistances', false);
        await quiz.host.click('wikiRacePanel.startButton');
        for(const n of [1, 2, 3]) await onArticle(quiz.phones[n], START);
        //How far there is still to go is what the team sees, not the hops or the time
        assert.strictEqual(await quiz.phones[1].away.textContent(), '2');
        assert.strictEqual(await quiz.phones[1].frame.locator('#awayLabel').textContent(), 'hops away');
        assert.ok(!(await quiz.host.read('wikiRacePanel.revealButton')).enabled, 'nothing to reveal yet');
        assert.ok(!(await quiz.host.read('wikiRacePanel.startButton')).enabled, 'a race can be started over the top of this one');
        assert.ok(!(await quiz.host.read('wikiRacePanel.showButton')).enabled, 'the display can be wiped mid-race');
    });

    scenario('a move is reported to the host, comma in the title and all', async quiz => {
        const one = quiz.phones[1];
        await follow(one, MIDDLE);
        await until('the report of the move', () => quiz.wire.has('srv→servers', 'wp1,1,1,' + MIDDLE));

        await follow(one, FINISH);
        await until('the report of the arrival', () => quiz.wire.some(w => w.msg.startsWith('ww1,2,')));
        assert.ok(quiz.wire.has('srv→servers', 'wp1,2,0,' + FINISH));
    });

    scenario('going back is a move, and goes on the record', async quiz => {
        const two = quiz.phones[2];
        await follow(two, DETOUR);
        await two.press(two.back);
        await onArticle(two, START);
        await follow(two, DETOUR);
    });

    scenario('reload: a team lands back on its article with its route intact', async quiz => {
        const two = quiz.phones[2];
        assert.strictEqual(await two.away.textContent(), '2');

        const mark = quiz.wire.length;
        await quiz.reloadPhone(2);
        await quiz.phoneReconnected(2, mark);
        await until('the race page again', async () => (await two.article.count()) === 1);
        await onArticle(two, DETOUR);
        assert.strictEqual(await two.away.textContent(), '2');

        await follow(two, MIDDLE);
    });

    scenario('dropped connection: the same', async quiz => {
        const two = quiz.phones[2];
        const mark = quiz.wire.length;
        quiz.dropPhone(2);
        await quiz.phoneReconnected(2, mark);
        await onArticle(two, MIDDLE);
    });

    scenario('ending the race gives the host the standings and every trail', async quiz => {
        await quiz.host.click('wikiRacePanel.endButton');

        //First home, then the rest by how close they got
        await until('the standings', () =>
            quiz.wire.some(w => w.msg.startsWith('wd1,1,1,')) &&
            quiz.wire.some(w => w.msg.startsWith('wd2,2,0,')) &&
            quiz.wire.some(w => w.msg.startsWith('wd3,3,0,')));
        await until('the trail', () => quiz.wire.has('srv→servers', 'wt1,' + [START, MIDDLE, FINISH].join('|')));
        await quiz.host.settled();
        assert.ok((await quiz.host.read('wikiRacePanel.startButton')).enabled, 'no next race');
        assert.ok((await quiz.host.read('wikiRacePanel.showButton')).enabled, 'no next route to show');

        assert.strictEqual((await quiz.host.read('quizDisplay.wikiRaceScene.raceStandings')).length, 3);
    });

    scenario('once the race is over the host can press reveal', async quiz => {
        assert.strictEqual(await quiz.host.read('quizDisplay.wikiRaceScene.showDistance'), false);
        assert.ok((await quiz.host.read('wikiRacePanel.revealButton')).enabled);
        await quiz.host.click('wikiRacePanel.revealButton');
        assert.strictEqual(await quiz.host.read('quizDisplay.wikiRaceScene.showDistance'), true);
        assert.deepStrictEqual(await quiz.host.read('quizDisplay.wikiRaceScene.revealedOrder'), [0, 1, 2]);
        await until('the boxes named by team', async () => {
            const shown = await quiz.host.visibleText();
            return ['Team 1', 'Team 2', 'Team 3'].every(t => shown.includes(t)) && !shown.includes('1.');
        });
    });

    scenario('a move after the race is refused', async quiz => {
        const two = quiz.phones[2];
        //Under the curtain now, so nothing a team could tap. A script can reach it, and the
        //page should still decline to send anything.
        assert.match(await two.frame.locator('#curtainText').textContent(), /Time/);
        const moves = quiz.wire.filter(w => w.dir === 'T2→srv' && w.msg.startsWith('wl')).length;
        await two.link(FINISH).evaluate(link => link.click());
        await quiz.host.settled();
        assert.strictEqual(quiz.wire.filter(w => w.dir === 'T2→srv' && w.msg.startsWith('wl')).length, moves);
        assert.strictEqual(await two.articleTitle.textContent(), MIDDLE);
    });

    scenario('a reset before the race ends leaves nothing to reveal', async quiz => {
        await quiz.round('wikirace');
        await quiz.host.click('wikiRacePanel.startButton');
        await onArticle(quiz.phones[1], START);

        const mark = quiz.wire.length;
        await quiz.host.click('resetRound:');
        await until('the standings the reset causes', () =>
            quiz.wire.slice(mark).some(w => w.msg.startsWith('wd')));
        await quiz.host.settled();
        assert.ok(!(await quiz.host.read('wikiRacePanel.revealButton')).enabled);
        //And the phones are ready for the next race, not told that time was called on this one
        for(const n of [1, 2, 3]) {
            await until('phone ' + n + ' to be ready', async () =>
                (await quiz.phones[n].frame.locator('#curtainText').textContent()) === 'Ready');
        }
    });

    scenario('leaving the round takes every phone back to the buzzer', async quiz => {
        await quiz.round('buzzers');
        for(const n of [1, 2, 3]) {
            await until('phone ' + n + ' to hold its team', async () =>
                (await quiz.phones[n].buzzer.textContent()) === 'TEAM ' + n);
        }
    });

    scenario('the back gesture onto an old buzzer page during a race goes straight back to it', async quiz => {
        //What the phone's back gesture can land on: a buzzer page out of the back-forward
        //cache, frozen just as it left for the race. Its lastview still says "wikirace" and
        //its socket is long dead. The browser cannot be made to do this on demand, so phone
        //3's buzzer is put in exactly that state by hand.
        const three = quiz.phones[3];
        await three.buzzer.evaluate(() => {
            lastview = 'wikirace';
            ws.onopen = ws.onmessage = ws.onclose = ws.onerror = null;
            ws.close();
        });
        await quiz.round('wikirace', [1, 2]);
        await quiz.host.click('wikiRacePanel.startButton');
        await onArticle(quiz.phones[1], START);

        //And then the browser brings it back
        await three.buzzer.evaluate(() => window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true })));
        await onArticle(three, START);
        await quiz.host.click('wikiRacePanel.endButton');
    });

    scenario('the harness patterns can walk a phone along the route', async quiz => {
        //test-patterns.js drives teams through the harness, which borrows each phone's
        //socket. It has to keep hold of it when the phone moves to the race page.
        await quiz.host.click('wikiRacePanel.startButton');
        for(const n of [1, 2, 3]) await onArticle(quiz.phones[n], START);
        await until('the harness to know the race', () => quiz.page.evaluate(() => clients[3].race !== null));

        //What the pattern line "3,wiki,short,1" does
        assert.strictEqual(await quiz.page.evaluate(() => clients[3].walkShort(1)), null);
        await onArticle(quiz.phones[3], MIDDLE);
        assert.strictEqual(await quiz.phones[3].away.textContent(), '1');

        assert.strictEqual(await quiz.page.evaluate(() => clients[3].walkShort(0)), null);
        await until('the arrival', () => quiz.wire.some(w => w.msg.startsWith('ww3,2,')));
        await quiz.host.click('wikiRacePanel.endButton');
    });
});
