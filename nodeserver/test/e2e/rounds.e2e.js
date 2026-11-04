'use strict';

//The rounds where a team's answer has to go out to the display and come back to the phone.

const assert = require('node:assert');
const { quizScenarios, until } = require('./rig');

const seen = (quiz, what) => until('"' + what + '" on screen', async () =>
    (await quiz.host.visibleText()).includes(what));

const panelText = async (quiz, path) => (await quiz.host.read(path)).value;

const reachedHost = (quiz, n, code) => until('team ' + n + "'s " + code + ' to reach the app', async () => {
    if(!quiz.wire.some(w => w.dir === 'T' + n + '→srv' && w.msg.startsWith(code))) return false;
    await quiz.host.settled();
    return true;
});

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

        await quiz.host.click('textPanel.showGuesses:');
        await seen(quiz, 'york, england');
    });

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


    //--- Numbers

    scenario('numbers: guesses are ranked against the answer, and shown in two steps', async quiz => {
        await quiz.round('numbers');
        const [, one, two, three] = quiz.phones;
        await quiz.host.set('numbersPanel.actualAnswer', '50');

        await one.answerText('40');
        await two.answerText('60');
        await three.answerText('90');
        await until('the ranking on the host', async () => {
            const text = await panelText(quiz, 'numbersPanel.teamGuesses');
            return /🟢 Team 1: 40 +\(off by 10\)/.test(text) && /🟢 Team 2: 60/.test(text) && /Team 3: 90 +\(off by 40\)/.test(text);
        });
        for(const n of [40, 60, 90]) {
            assert.ok(!(await quiz.host.visibleText()).includes(String(n)), n + ' is still hidden');
        }

        await quiz.host.click('numbersPanel.showAnswers:');
        await seen(quiz, '40');
        await seen(quiz, '90');
        assert.strictEqual(await quiz.host.read('quizDisplay.numbersScene.scored'), false);

        await quiz.host.click('numbersPanel.showAnswers:');
        await until('the round to be scored', () => quiz.host.read('quizDisplay.numbersScene.scored'));
    });

    scenario('numbers: a late guess is turned away', async quiz => {
        await quiz.round('numbers');
        await quiz.host.click('numbersPanel.showAnswers:');
        await quiz.phones[1].textbox.fill('7');
        await quiz.tapped(1, 'tt', quiz.phones[1].enter);
        assert.strictEqual(await panelText(quiz, 'numbersPanel.teamGuesses'), '');
    });


    //--- Pointless

    scenario('pointless: answers are scored however they were typed, and revealed by the host', async quiz => {
        await quiz.round('pointless');
        const [, one, two, three] = quiz.phones;

        await one.answerText('KIWI ');
        await two.answerText('apple');
        await three.answerText('banana');
        await until('all three to be in', async () =>
            (await quiz.host.read('quizDisplay.pointlessScene.teamGuesses')).every(g => g !== null));

        assert.deepStrictEqual(await quiz.host.read('quizDisplay.pointlessScene.teamScores'), [3, 40, null]);
        assert.ok(!(await quiz.host.visibleText()).includes('banana'), 'still hidden');

        await quiz.host.click('pointlessPanel.showAnswers:');
        await seen(quiz, 'banana');

        //Too late now
        await one.textbox.fill('quince');
        await quiz.tapped(1, 'tt', one.enter);
        assert.deepStrictEqual(await quiz.host.read('quizDisplay.pointlessScene.teamScores'), [3, 40, null]);

        await quiz.host.click('pointlessPanel.runScoring:');
        assert.strictEqual(await quiz.host.read('quizDisplay.pointlessScene.lowestScoreThisRound'), 3);
    });


    //--- Wavelength

    scenario('wavelength: guesses from the bar are scored against the roll, closest first', async quiz => {
        await quiz.round('wavelength');
        const [, one, two, three] = quiz.phones;

        await one.tapAt(one.waveTrack, 0.25, 0.5);
        await two.tapAt(two.waveTrack, 0.5, 0.5);
        await three.tapAt(three.waveTrack, 0.75, 0.5);

        const shown = [Number(await one.waveValue.textContent()), Number(await two.waveValue.textContent()),
                       Number(await three.waveValue.textContent())];
        assert.ok(Math.abs(shown[0] - 25) <= 2 && Math.abs(shown[2] - 75) <= 2, 'the taps landed: ' + shown);

        await until('the host to have all three', async () => {
            const text = await panelText(quiz, 'wavelengthPanel.teamGuesses');
            return shown.every((v, i) => text.includes('Team ' + (i + 1) + ': ' + v));
        });

        await quiz.host.click('wavelengthPanel.rollButton');
        await quiz.host.click('wavelengthPanel.rollButton');
        const target = Number(await panelText(quiz, 'wavelengthPanel.number'));
        assert.ok(target >= 1 && target <= 99, 'rolled ' + target);

        await quiz.host.click('wavelengthPanel.reveal:');

        //Too late to move now. The sweep needs the guesses to hold still.
        await one.tapAt(one.waveTrack, 0.9, 0.5);
        await reachedHost(quiz, 1, 'wv');
        const guesses = await quiz.host.read('quizDisplay.wavelengthScene.teamGuesses');
        assert.deepStrictEqual(guesses, shown, 'a guess moved after the reveal');

        //The first press runs the sweep, which takes as long as the roll is high, and a press
        //during it is ignored. It is the one after that which scores.
        await quiz.host.click('wavelengthPanel.score:');
        const text = await until('the placings', async () => {
            await quiz.host.click('wavelengthPanel.score:');
            const t = await panelText(quiz, 'wavelengthPanel.teamGuesses');
            return t.includes('out by') ? t : false;
        }, 15000);

        const outBy = [...text.matchAll(/out by (\d+)/g)].map(m => Number(m[1]));
        assert.strictEqual(outBy.length, 3, text);
        assert.deepStrictEqual(outBy, [...outBy].sort((a, b) => a - b), 'closest first: ' + text);
        assert.strictEqual(outBy[0], Math.min(...shown.map(v => Math.abs(v - target))), text);
    });


    //--- Geography

    scenario('geography: a tap lands where it was tapped, and the closest team wins', async quiz => {
        await quiz.round('geography');
        const [, one, two] = quiz.phones;

        await quiz.host.set('geographyPanel.questionSelector', 'geo1.jpg');
        await quiz.host.click('geographyPanel.startQuestion:');
        await until('the phone to show the image', async () =>
            (await one.map.evaluate(el => el.style.backgroundImage)).includes('geo1.jpg'));

        await one.tapAt(one.map, 0.25, 0.5);
        await two.tapAt(two.map, 0.8, 0.8);
        await reachedHost(quiz, 2, 'ii');

        const sent = n => quiz.wire.filter(w => w.dir === 'T' + n + '→srv' && w.msg.startsWith('ii')).pop().msg;
        const [, x, y] = sent(1).split(',').map(Number);
        assert.ok(Math.abs(x - 25) <= 1 && Math.abs(y - 50) <= 1, 'team 1 sent ' + sent(1));
        assert.deepStrictEqual(await quiz.host.read('quizDisplay.geographyScene.teamguesses.0'), { x, y });

        //The pin is what tells a team that it has answered, and where
        const map = await one.map.boundingBox();
        const pin = await one.pin.boundingBox();
        const pinX = (pin.x + pin.width / 2 - map.x) / map.width;
        const pinY = (pin.y + pin.height / 2 - map.y) / map.height;
        assert.ok(Math.abs(pinX - 0.25) < 0.03 && Math.abs(pinY - 0.5) < 0.03,
                  'the pin is at ' + pinX.toFixed(2) + ',' + pinY.toFixed(2) + ', not 0.25,0.50');

        await quiz.host.set('geographyPanel.answerX', '30');
        await quiz.host.set('geographyPanel.answerY', '50');
        await quiz.host.click('geographyPanel.showWinner:');
        await seen(quiz, 'The answer is...');

        //Worst first, for the suspense
        await quiz.host.click('geographyPanel.showWinner:');
        await quiz.host.click('geographyPanel.showWinner:');
        await until('the standings', async () => {
            const text = (await quiz.host.visibleText()).join('\n');
            return /Team 2\n.*Team 1 ⭐️/.test(text);
        }, 3000);
    });
});
