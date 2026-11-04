'use strict';

//The buzzer round, all the way round: a tap on a phone reaches the audience's screen and the
//LEDs, and the host's buttons reach the phones.

const { test, describe, before, after } = require('node:test');
const assert = require('node:assert');
const os = require('os');
const path = require('path');
const { buildApp, startQuiz, until } = require('./rig');

describe('buzzers', () => {
    let quiz;

    before(async () => {
        buildApp();
        quiz = await startQuiz({ teams: 3 });

        await quiz.host.click('tabitemBuzzers');
        await until('the buzzer scene', async () => (await quiz.host.scene()).scene === 'BuzzerScene');

        //Nobody needs an air horn going off every time the tests run
        if((await quiz.host.read('buzzerSounds')).on) await quiz.host.click('buzzerSounds');
    });

    after(async () => {
        if(quiz) await quiz.close();
    });

    //What a failure needs in order to be understood: the conversation, and the picture.
    async function explain(body) {
        try {
            await body();
        } catch(err) {
            const shot = path.join(os.tmpdir(), 'quiz-e2e-failure.png');
            await quiz.host.screenshot(shot).catch(() => {});
            //A new error, because node:test prints an AssertionError's diff and not its message
            throw new Error(err.message + '\n\nWire:\n' + quiz.wire.dump() + '\n\nScreenshot: ' + shot,
                            { cause: err });
        }
    }

    const buzzes = () => quiz.host.read('quizDisplay.buzzerScene.buzzes');

    async function setQueueMode(on) {
        if((await quiz.host.read('buzzerQueueMode')).on !== on) await quiz.host.click('buzzerQueueMode');
    }

    //A real tap, and so also a check that nothing is covering the button
    async function buzz(team) {
        const seen = quiz.wire.filter(w => w.msg === 'zz' + team).length;
        await quiz.phones[team].buzzer.click();
        await until('team ' + team + "'s buzz to reach the server", () =>
            quiz.wire.filter(w => w.msg === 'zz' + team).length > seen);
        await quiz.host.settled();
    }

    test('a phone buzzing puts its team on the screen and the LEDs', () => explain(async () => {
        await setQueueMode(false);
        await buzz(2);

        assert.deepStrictEqual(await buzzes(), [1]);
        await until('"Team 2" on screen', async () => (await quiz.host.visibleText()).includes('Team 2'));
        await until('the LED buzz for team 2', () => quiz.leds.includes('b01'));
    }));

    test('with queue mode off, a slower phone does not take the buzz', () => explain(async () => {
        await buzz(3);

        assert.deepStrictEqual(await buzzes(), [1]);
        assert.ok(!(await quiz.host.visibleText()).includes('Team 3'));
    }));

    test('the host pressing reset clears the screen', () => explain(async () => {
        await quiz.host.click('resetRound:');

        await until('the team to leave the screen', async () =>
            !(await quiz.host.visibleText()).includes('Team 2'));
        assert.deepStrictEqual(await buzzes(), []);
    }));

    test('with queue mode on, slower phones queue up in order', () => explain(async () => {
        await setQueueMode(true);
        await buzz(3);
        await buzz(1);

        assert.deepStrictEqual(await buzzes(), [2, 0]);
        await until('both teams on screen', async () => {
            const text = await quiz.host.visibleText();
            return text.includes('Team 3') && text.includes('Team 1');
        });

        await quiz.host.click('resetRound:');
        await setQueueMode(false);
    }));

    test('the host knocking a team out greys its phone and ignores its buzz', () => explain(async () => {
        assert.ok(await quiz.phones[1].isOn(), 'phone 1 starts on');

        //The numbered buttons fire virtual buzzes until this is switched over
        if((await quiz.host.read('virtualBuzzersBtn')).on) await quiz.host.click('virtualBuzzersBtn');
        await quiz.host.click('buzzerButton1');

        await until('phone 1 to go grey', async () => !(await quiz.phones[1].isOn()));
        assert.ok(await quiz.phones[2].isOn(), 'phone 2 is unaffected');

        await buzz(1);
        assert.deepStrictEqual(await buzzes(), []);
    }));

    test('no phone page threw an error', () => {
        assert.deepStrictEqual(quiz.pageErrors, []);
    });
});
