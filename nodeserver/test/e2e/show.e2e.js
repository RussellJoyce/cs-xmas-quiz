'use strict';

//The rounds that are more the host's than the teams': the timer and the scores.

const assert = require('node:assert');
const { quizScenarios, until } = require('./rig');

quizScenarios('host rounds', { teams: 3 }, scenario => {

    scenario('timer: runs, stops, counts answers, and a reset puts it all back', async quiz => {
        await quiz.round('timer');
        const time = () => quiz.host.read('quizDisplay.timerScene.time');
        assert.strictEqual(await time(), 60);

        await quiz.host.click('timerPanel.start:');
        await until('the clock to run', async () => (await time()) < 60);
        await quiz.host.click('timerPanel.stop:');
        const stopped = await time();
        await new Promise(resolve => setTimeout(resolve, 1500));
        assert.strictEqual(await time(), stopped, 'the clock stopped');

        await quiz.host.click('timerPanel.increment:');
        await quiz.host.click('timerPanel.increment:');
        await quiz.host.click('timerPanel.decrement:');
        assert.strictEqual(await quiz.host.read('quizDisplay.timerScene.correct'), 1);

        await quiz.host.click('resetRound:');
        assert.strictEqual(await time(), 60);
        assert.strictEqual(await quiz.host.read('quizDisplay.timerScene.correct'), 0);
    });

    scenario('scores: typed in by the host, revealed lowest first, with draws sharing a rank', async quiz => {
        await quiz.round('scores');
        await quiz.host.click('scoresPanel.initText:');
        assert.strictEqual((await quiz.host.read('scoresPanel.scoreText')).value, '1,x\n2,x\n3,x\n');

        await quiz.host.set('scoresPanel.scoreText', '1,10\n2,30\n3,30\n');
        await quiz.host.click('scoresPanel.parseAndReset:');
        assert.strictEqual((await quiz.host.read('scoresPanel.output')).value,
                           '3: Team 1 (10)\n1: Team 2 (30)\n1: Team 3 (30)');

        const before = quiz.leds.length;
        await quiz.host.click('scoresPanel.showNext:');
        await until('team 1 on the LEDs', () => quiz.leds.slice(before).includes('b00'));
        await quiz.host.click('scoresPanel.showNext:');
        await quiz.host.click('scoresPanel.showNext:');
        await until('team 3 on the LEDs', () => quiz.leds.slice(before).includes('b02'));

        //They fade in
        await until('all three on screen', async () => {
            const text = (await quiz.host.visibleText()).join('\n');
            return ['Team 1', 'Team 2', 'Team 3'].every(team => text.includes(team));
        }, 3000);
    });
});
