'use strict';

//The wikirace, on its own page, against the small corpus in fixtures.js.

const assert = require('node:assert');
const { quizScenarios, until } = require('./rig');
const { WIKI } = require('./fixtures');

const [START, MIDDLE, FINISH, DETOUR] = WIKI.titles;

const onArticle = (phone, title) => until('the phone on ' + title, async () => (await phone.articleTitle.textContent()) === title);

//The server is the only thing that moves a team, so wait for it to say so
async function follow(phone, title) {
    await phone.link(title).click();
    await onArticle(phone, title);
}

quizScenarios('wikirace', { teams: 3 }, scenario => {

    scenario('every phone goes to the race page and starts on the same article', async quiz => {
        await quiz.round('wikirace');
        await quiz.host.setToggle('wikiRacePanel.showDistances', false);
        await quiz.host.click('wikiRacePanel.startButton');
        for(const n of [1, 2, 3]) await onArticle(quiz.phones[n], START);
        assert.ok(!(await quiz.host.read('wikiRacePanel.revealButton')).enabled, 'nothing to reveal yet');
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
        await two.back.click();
        await onArticle(two, START);
        await follow(two, DETOUR);
    });

    scenario('reload: a team lands back on its article with its route intact', async quiz => {
        const two = quiz.phones[2];
        const hops = await two.hops.textContent();

        const mark = quiz.wire.length;
        await quiz.reloadPhone(2);
        await quiz.phoneReconnected(2, mark);
        await until('the race page again', async () => (await two.article.count()) === 1);
        await onArticle(two, DETOUR);
        assert.strictEqual(await two.hops.textContent(), hops);

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

        assert.strictEqual((await quiz.host.read('quizDisplay.wikiRaceScene.raceStandings')).length, 3);
    });

    scenario('once the race is over the host can press reveal', async quiz => {
        assert.strictEqual(await quiz.host.read('quizDisplay.wikiRaceScene.showDistance'), false);
        assert.ok((await quiz.host.read('wikiRacePanel.revealButton')).enabled);
        await quiz.host.click('wikiRacePanel.revealButton');
        assert.strictEqual(await quiz.host.read('quizDisplay.wikiRaceScene.showDistance'), true);
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
    });

    scenario('leaving the round takes every phone back to the buzzer', async quiz => {
        await quiz.round('buzzers');
        for(const n of [1, 2, 3]) {
            await until('phone ' + n + ' to hold its team', async () =>
                (await quiz.phones[n].buzzer.textContent()) === 'TEAM ' + n);
        }
    });
});
