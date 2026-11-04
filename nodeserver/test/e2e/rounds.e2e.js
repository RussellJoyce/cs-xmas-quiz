'use strict';

//The rounds where a team's answer has to go out to the display and come back to the phone.

const assert = require('node:assert');
const { quizScenarios, until } = require('./rig');

const seen = (quiz, what) => until('"' + what + '" on screen', async () =>
    (await quiz.host.visibleText()).includes(what));

const panelText = async (quiz, path) => (await quiz.host.read(path)).value;

quizScenarios('answer rounds', { teams: 3 }, scenario => {

    //--- Text

    scenario('text: an answer stays hidden from the audience until the host reveals it', async quiz => {
        await quiz.round('text');
        await quiz.phones[1].answerText('paris');

        await until('the host to see the answer', async () =>
            (await panelText(quiz, 'textPanel.teamGuesses')).includes('Team 1: paris'));
        await until('the LED pulse for team 1', () => quiz.leds.includes('q00'));
        assert.ok(!(await quiz.host.visibleText()).includes('paris'), 'still hidden');

        await quiz.host.click('textPanel.showGuesses:');
        await seen(quiz, 'paris');
    });

    scenario('text: once revealed, a late answer is turned away', async quiz => {
        await quiz.round('text');
        await quiz.host.click('textPanel.showGuesses:');
        await quiz.phones[2].textbox.fill('rome');
        await quiz.tapped(2, 'tt', quiz.phones[2].enter);

        assert.ok(!(await panelText(quiz, 'textPanel.teamGuesses')).includes('rome'));
    });

    scenario('text: an answer containing a comma arrives whole', async quiz => {
        await quiz.round('text');
        await quiz.phones[1].textbox.fill('york, england');
        await quiz.tapped(1, 'tt', quiz.phones[1].enter);

        assert.match(await panelText(quiz, 'textPanel.teamGuesses'), /Team 1: york, england/);
    }, { todo: 'QuizMessage cuts a "tt" at the first comma, see QuizProtocol.swift' });

    scenario('text: a team that is out loses the box', async quiz => {
        await quiz.round('text');
        await quiz.setPlaying(3, false);
        assert.ok(await quiz.phones[3].textbox.isDisabled());
        assert.ok(!(await quiz.phones[1].textbox.isDisabled()));

        await quiz.setPlaying(3, true);
        assert.ok(!(await quiz.phones[3].textbox.isDisabled()));
    });


    //--- True or false

    scenario('true/false: answers count only while the question is running', async quiz => {
        await quiz.round('trueFalse');
        await quiz.host.setToggle('trueFalsePanel.soundsToggle', false);
        const [, one, two] = quiz.phones;

        await quiz.tapped(1, 'hi', one.higher);
        assert.ok(!(await one.hasClass(one.higher, 'higherLowerSelected')), 'too early, so not lit');

        await quiz.host.click('trueFalsePanel.startWithoutTimer:');
        await quiz.tapped(1, 'hi', one.higher);
        await quiz.tapped(2, 'lo', two.lower);
        await until('team 1 lit', () => one.hasClass(one.higher, 'higherLowerSelected'));
        await until('team 2 lit', () => two.hasClass(two.lower, 'higherLowerSelected'));

        await quiz.host.click('trueFalsePanel.startWithoutTimer:'); //The same button stops it
        await seen(quiz, 'Team 1: TRUE');
        await seen(quiz, 'Team 2: FALSE');
        await seen(quiz, 'Team 3 no guess');

        await quiz.host.click('trueFalsePanel.answerTrue:');
        assert.deepStrictEqual(await quiz.host.read('quizDisplay.truefalseScene.teamEnabled'),
                               [true, false, false]);
    });

    scenario('true/false: switching to higher/lower relabels the phones and the reveal', async quiz => {
        await quiz.round('trueFalse');
        const [, one] = quiz.phones;
        await quiz.host.setToggle('trueFalsePanel.modeToggle', false);
        await until('the phone to say HIGHER', async () => (await one.higher.textContent()) === 'HIGHER');

        await quiz.host.click('trueFalsePanel.startWithoutTimer:');
        await quiz.tapped(1, 'hi', one.higher);
        await quiz.host.click('trueFalsePanel.startWithoutTimer:');
        await seen(quiz, 'Team 1: HIGHER');

        await quiz.host.setToggle('trueFalsePanel.modeToggle', true);
        await until('the phone to say TRUE', async () => (await one.higher.textContent()) === 'TRUE');
    });


    //--- Multiple choice

    scenario('multiple choice: the host sets the number of tiles on every phone', async quiz => {
        await quiz.round('multichoice');
        await quiz.host.set('multiChoicePanel.optionsStepper', 6);
        for(const n of [1, 2, 3]) {
            await until('phone ' + n + ' to have 6 tiles', async () => (await quiz.phones[n].tiles()) === 6);
        }
        await quiz.host.set('multiChoicePanel.optionsStepper', 4);
        await until('phone 1 to have 4 tiles', async () => (await quiz.phones[1].tiles()) === 4);
    });

    scenario('multiple choice: a question from start to answer', async quiz => {
        await quiz.round('multichoice');
        await quiz.host.setToggle('multiChoicePanel.sounds', false);
        const [, one, two] = quiz.phones;

        await quiz.tapped(1, 'mc', one.tile(1));
        assert.ok(!(await one.hasClass(one.tile(1), 'multiSelected')), 'too early, so not lit');

        await quiz.host.click('multiChoicePanel.startButton');
        await quiz.tapped(1, 'mc', one.tile(2));
        await quiz.tapped(2, 'mc', two.tile(3));
        await until('team 1 tile 2 lit', () => one.hasClass(one.tile(2), 'multiSelected'));
        await until('team 2 tile 3 lit', () => two.hasClass(two.tile(3), 'multiSelected'));
        assert.match(await panelText(quiz, 'multiChoicePanel.teamGuesses'), /Team 1: B\nTeam 2: C/);

        //A team can change its mind while the clock runs
        await quiz.tapped(1, 'mc', one.tile(3));
        await until('team 1 tile 3 lit', () => one.hasClass(one.tile(3), 'multiSelected'));
        assert.ok(!(await one.hasClass(one.tile(2), 'multiSelected')), 'tile 2 goes out');

        await quiz.host.click('multiChoicePanel.answer3');
        await seen(quiz, '1: C');
        await seen(quiz, '2: C');
        await seen(quiz, '3: –');
    });
});
