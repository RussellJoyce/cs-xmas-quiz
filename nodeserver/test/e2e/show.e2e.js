'use strict';

//The rounds that are more the host's than the teams': the timer and the scores.

const assert = require('node:assert');
const { quizScenarios, until } = require('./rig');

quizScenarios('host rounds', { teams: 3 }, scenario => {

    scenario('snow: the LED animation chosen is played, and again on coming back', async quiz => {
        const lastAnimation = () => quiz.leds.filter(m => m.startsWith('a')).pop();
        const chosen = () => quiz.host.read('quizDisplay.snowIdleScene.ledAnimation');

        let before = quiz.leds.length;
        await quiz.round('idleSnow');
        await until('Megamas on the LEDs', () => quiz.leds.slice(before).includes('a01'));
        assert.strictEqual(await chosen(), 'megamas', 'Megamas is the default');

        await quiz.host.click('snowIdlePanel.ledAnimationChosen:#4');
        await until('Embers on the LEDs', () => lastAnimation() === 'a04');
        await quiz.host.click('snowIdlePanel.ledAnimationChosen:#5');
        await until('Old Lights on the LEDs', () => lastAnimation() === 'a05');

        await quiz.round('buzzers');
        before = quiz.leds.length;
        await quiz.round('idleSnow');
        await until('Old Lights again', () => quiz.leds.slice(before).includes('a05'));
        assert.strictEqual(await chosen(), 'oldLights');
    });

    scenario('snow: the LED animation survives coming back from the music round', async quiz => {
        const lastAnimation = () => quiz.leds.filter(m => m.startsWith('a')).pop();
        await quiz.round('idleSnow');
        await quiz.host.click('snowIdlePanel.ledAnimationChosen:#1');
        await quiz.round('music');
        //Let its transition finish, or going back cuts it short and tears down at once
        await new Promise(resolve => setTimeout(resolve, 1500));
        await quiz.round('idleSnow');
        await until('Megamas on the LEDs', () => lastAnimation() === 'a01');

        //The music round is torn down once the 1s transition ends, after the snow has
        //set the LEDs, so anything it sends then would land on top
        await new Promise(resolve => setTimeout(resolve, 2000));
        assert.strictEqual(lastAnimation(), 'a01');
    });

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
