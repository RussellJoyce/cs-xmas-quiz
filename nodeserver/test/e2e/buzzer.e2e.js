'use strict';

//The buzzer round, all the way round: a tap on a phone reaches the audience's screen and the
//LEDs, and the host's buttons reach the phones.

const assert = require('node:assert');
const { quizScenarios, until } = require('./rig');

const buzzes = quiz => quiz.host.read('quizDisplay.buzzerScene.buzzes');
const buzz = (quiz, team) => quiz.tapped(team, 'zz', quiz.phones[team].buzzer);

quizScenarios('buzzers', {
    teams: 3,
    setUp: async quiz => {
        await quiz.round('buzzers');
        await quiz.host.setToggle('buzzerSounds', false); //Nobody needs an air horn every run
    }
}, scenario => {

    scenario('a phone buzzing puts its team on the screen and the LEDs', async quiz => {
        await quiz.host.setToggle('buzzerQueueMode', false);
        await buzz(quiz, 2);

        assert.deepStrictEqual(await buzzes(quiz), [1]);
        await until('"Team 2" on screen', async () => (await quiz.host.visibleText()).includes('Team 2'));
        await until('the LED buzz for team 2', () => quiz.leds.includes('b01'));
    });

    scenario('with queue mode off, a slower phone does not take the buzz', async quiz => {
        await buzz(quiz, 3);

        assert.deepStrictEqual(await buzzes(quiz), [1]);
        assert.ok(!(await quiz.host.visibleText()).includes('Team 3'));
    });

    scenario('the host pressing reset clears the screen', async quiz => {
        await quiz.host.click('resetRound:');

        await until('the team to leave the screen', async () =>
            !(await quiz.host.visibleText()).includes('Team 2'));
        assert.deepStrictEqual(await buzzes(quiz), []);
    });

    scenario('with queue mode on, slower phones queue up in order', async quiz => {
        await quiz.host.setToggle('buzzerQueueMode', true);
        await buzz(quiz, 3);
        await buzz(quiz, 1);

        assert.deepStrictEqual(await buzzes(quiz), [2, 0]);
        await until('both teams on screen', async () => {
            const text = await quiz.host.visibleText();
            return text.includes('Team 3') && text.includes('Team 1');
        });

        await quiz.host.click('resetRound:');
        await quiz.host.setToggle('buzzerQueueMode', false);
    });

    scenario('the host knocking a team out greys its phone and ignores its buzz', async quiz => {
        await quiz.setPlaying(1, false);
        assert.ok(await quiz.phones[2].isOn(), 'phone 2 is unaffected');

        await buzz(quiz, 1);
        assert.deepStrictEqual(await buzzes(quiz), []);

        await quiz.setPlaying(1, true);
        await buzz(quiz, 1);
        assert.deepStrictEqual(await buzzes(quiz), [0]);
    });

    scenario('next team moves the LEDs down the queue', async quiz => {
        await quiz.host.click('resetRound:');
        await quiz.host.setToggle('buzzerQueueMode', true);
        await buzz(quiz, 3);
        await buzz(quiz, 1);

        const before = quiz.leds.length;
        await quiz.host.click('buzzerPanel.nextTeam:');
        await until('the LEDs to show team 1', () => quiz.leds.slice(before).includes('t00'));

        await quiz.host.click('resetRound:');
        await quiz.host.setToggle('buzzerQueueMode', false);
    });

    scenario('a buzz during a countdown leaves the LEDs alone, and the clock runs', async quiz => {
        await quiz.host.click('resetRound:');
        await quiz.host.set('buzzerPanel.timerSeconds', '30');
        await quiz.host.click('buzzerPanel.startTimer:');

        const before = quiz.leds.length;
        await buzz(quiz, 2);
        assert.deepStrictEqual(await buzzes(quiz), [1]);
        await until('the clock to run', async () => (await quiz.host.read('quizDisplay.buzzerScene.time')) < 30);
        await quiz.host.settled();
        assert.ok(!quiz.leds.slice(before).some(m => m.startsWith('b')), 'LEDs got: ' + quiz.leds.slice(before));

        await quiz.host.click('buzzerPanel.stopTimer:');
        await quiz.host.click('resetRound:');
    });

    scenario("the host's virtual buzzers work without a phone", async quiz => {
        await quiz.host.click('resetRound:');
        await quiz.host.setToggle('virtualBuzzersBtn', true);
        await quiz.host.click('buzzerButton3');
        assert.deepStrictEqual(await buzzes(quiz), [2]);
        await quiz.host.click('resetRound:');
    });
});
