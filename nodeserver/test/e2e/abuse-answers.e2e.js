'use strict';

//Trying to break the logic of the rounds where teams answer a question: answers at the wrong
//moment, teams that are out or switched off, and hosts pressing things out of order. Each
//scenario says what ought to happen, not what the code happens to do.

const assert = require('node:assert');
const { quizScenarios, until } = require('./rig');

const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
const panel = async (quiz, path) => (await quiz.host.read(path)).value;
const showing = async (quiz, what) => (await quiz.host.visibleText()).join('\n').includes(what);
const seen = (quiz, what) => until('"' + what + '" on screen', () => showing(quiz, what));

async function begin(quiz, round) {
    await quiz.allPlaying();
    await quiz.round(round);
}

const TF = 'quizDisplay.truefalseScene';
const MC = 'quizDisplay.multiChoiceScene';
const POINTLESS = 'quizDisplay.pointlessScene';
const NUMBERS = 'quizDisplay.numbersScene';

quizScenarios('trying to break the answer rounds', { teams: 3 }, scenario => {

    //--- True or false: who is still in

    async function trueFalse(quiz) {
        await begin(quiz, 'trueFalse');
        await quiz.host.setToggle('trueFalsePanel.soundsToggle', false);
    }
    const startTF = quiz => quiz.host.click('trueFalsePanel.startWithoutTimer:');
    const stopTF = quiz => quiz.host.click('trueFalsePanel.startWithoutTimer:');
    const say = (quiz, n, truth) => truth
        ? quiz.tapped(n, 'hi', quiz.phones[n].higher)
        : quiz.tapped(n, 'lo', quiz.phones[n].lower);

    //One question that team 2 gets wrong and team 1 gets right, which team 3 sits out
    async function knockOutTeam2(quiz) {
        await startTF(quiz);
        await say(quiz, 1, true);
        await say(quiz, 2, false);
        await stopTF(quiz);
        await quiz.host.click('trueFalsePanel.answerTrue:');
        assert.deepStrictEqual(await quiz.host.read(TF + '.teamEnabled'), [true, false, false]);
    }

    scenario('true/false: a team that is out cannot guess its way back in', async quiz => {
        await trueFalse(quiz);
        await knockOutTeam2(quiz);

        await startTF(quiz);
        await say(quiz, 1, true);
        await say(quiz, 2, true);
        await stopTF(quiz);
        await quiz.host.click('trueFalsePanel.answerTrue:');

        assert.deepStrictEqual(await quiz.host.read(TF + '.teamEnabled'), [true, false, false]);
    });

    scenario("true/false: a team that is out is not told its answer was accepted", async quiz => {
        await trueFalse(quiz);
        await knockOutTeam2(quiz);

        await startTF(quiz);
        const mark = quiz.wire.length;
        await say(quiz, 2, true);
        assert.ok(!quiz.wire.has('host→srv', 'hh2', mark), 'phone 2 was lit up');
        assert.strictEqual(await quiz.phones[2].hasClass(quiz.phones[2].higher, 'higherLowerSelected'), false);
        await stopTF(quiz);
    });

    scenario('true/false: being switched off and on again does not undo being out', async quiz => {
        await trueFalse(quiz);
        await knockOutTeam2(quiz);

        await quiz.setPlaying(2, false);
        await quiz.setPlaying(2, true);
        assert.deepStrictEqual(await quiz.host.read(TF + '.teamEnabled'), [true, false, false]);

        await startTF(quiz);
        await say(quiz, 2, true);
        await stopTF(quiz);
        await seen(quiz, 'Team 2 OUT');
    });

    scenario('true/false: a team switched off is not judged, and its guess does not count', async quiz => {
        await trueFalse(quiz);
        await quiz.setPlaying(2, false);
        await startTF(quiz);
        await say(quiz, 1, true);
        await say(quiz, 2, true);
        assert.strictEqual((await quiz.host.read(TF + '.teamGuesses'))[1], null);
        await stopTF(quiz);
        await quiz.host.click('trueFalsePanel.answerTrue:');
        assert.strictEqual((await quiz.host.read(TF + '.teamEnabled'))[1], true, 'not put out by sitting it out');
    });

    scenario('true/false: a guess made before being switched off does not carry it through', async quiz => {
        await trueFalse(quiz);
        await startTF(quiz);
        await say(quiz, 2, false);
        await quiz.setPlaying(2, false);
        await stopTF(quiz);
        await seen(quiz, 'Team 1 no guess');
        assert.ok(!(await showing(quiz, 'Team 2: FALSE')), 'a switched-off team has its answer shown');
    });


    //--- True or false: timing

    scenario('true/false: the clock running out ends the question', async quiz => {
        await trueFalse(quiz);
        await quiz.host.click('trueFalsePanel.startWithTimer:');
        await say(quiz, 1, true);
        await until('the clock to run out', async () => !(await quiz.host.read(TF + '.counting')), 8000);
        await seen(quiz, 'Team 1: TRUE');

        const mark = quiz.wire.length;
        await say(quiz, 2, true);
        assert.ok(!quiz.wire.has('host→srv', 'hh2', mark), 'a late answer was accepted');
        assert.strictEqual((await quiz.host.read(TF + '.teamGuesses'))[1], null);
    });

    scenario('true/false: stopping a timed question early stops its clock', async quiz => {
        await trueFalse(quiz);
        await quiz.host.click('trueFalsePanel.startWithTimer:');
        await stopTF(quiz);
        assert.strictEqual(await quiz.host.read(TF + '.counting'), false);

        const stoppedAt = await quiz.host.read(TF + '.time');
        await pause(2200);
        assert.strictEqual(await quiz.host.read(TF + '.time'), stoppedAt, 'the clock kept going');
    });

    scenario('true/false: a reset during a timed question stops its clock', async quiz => {
        await trueFalse(quiz);
        await quiz.host.click('trueFalsePanel.startWithTimer:');
        await quiz.host.click('resetRound:');
        const stoppedAt = await quiz.host.read(TF + '.time');
        await pause(2200);
        assert.strictEqual(await quiz.host.read(TF + '.time'), stoppedAt);
        assert.strictEqual(await quiz.host.read(TF + '.counting'), false);
    });

    scenario('true/false: giving the answer ends the question, and nobody can change their mind', async quiz => {
        await trueFalse(quiz);
        await startTF(quiz);
        await say(quiz, 1, true);
        await quiz.host.click('trueFalsePanel.answerTrue:');
        assert.strictEqual(await quiz.host.read(TF + '.counting'), false);
        assert.deepStrictEqual(await quiz.host.read(TF + '.teamEnabled'), [true, false, false]);

        const mark = quiz.wire.length;
        await say(quiz, 1, false);
        await say(quiz, 2, true);
        assert.deepStrictEqual((await quiz.host.read(TF + '.teamGuesses')).slice(0, 2), [true, null]);
        assert.ok(!quiz.wire.slice(mark).some(w => /^h[hl]/.test(w.msg)), 'a late answer was accepted');
    });

    scenario('true/false: giving the answer stops a timed question too', async quiz => {
        await trueFalse(quiz);
        await quiz.host.click('trueFalsePanel.startWithTimer:');
        await say(quiz, 1, true);
        await quiz.host.click('trueFalsePanel.answerTrue:');
        assert.strictEqual(await quiz.host.read(TF + '.counting'), false);

        const stoppedAt = await quiz.host.read(TF + '.time');
        await pause(2200);
        assert.strictEqual(await quiz.host.read(TF + '.time'), stoppedAt, 'the clock kept going');
        assert.deepStrictEqual(await quiz.host.read(TF + '.teamEnabled'), [true, false, false],
                               'the clock came back and undid the judging');
    });

    scenario('true/false: an answer given with no question asked puts nobody out', async quiz => {
        await trueFalse(quiz);
        await quiz.host.click('trueFalsePanel.answerTrue:');
        assert.deepStrictEqual(await quiz.host.read(TF + '.teamEnabled'), [true, true, true]);

        //Nor straight after a reset, however many questions came before it
        await startTF(quiz);
        await stopTF(quiz);
        await quiz.host.click('resetRound:');
        await quiz.host.click('trueFalsePanel.answerFalse:');
        assert.deepStrictEqual(await quiz.host.read(TF + '.teamEnabled'), [true, true, true]);
    });

    scenario('true/false: pressing the other answer corrects a mistake', async quiz => {
        await trueFalse(quiz);
        await startTF(quiz);
        await say(quiz, 1, true);
        await say(quiz, 2, false);
        await stopTF(quiz);

        await quiz.host.click('trueFalsePanel.answerTrue:');
        assert.deepStrictEqual(await quiz.host.read(TF + '.teamEnabled'), [true, false, false]);
        await quiz.host.click('trueFalsePanel.answerFalse:');
        assert.deepStrictEqual(await quiz.host.read(TF + '.teamEnabled'), [false, true, false]);
        await quiz.host.click('trueFalsePanel.answerTrue:');
        assert.deepStrictEqual(await quiz.host.read(TF + '.teamEnabled'), [true, false, false]);
    });

    scenario('true/false: a correction cannot bring back a team out from an earlier question', async quiz => {
        await trueFalse(quiz);
        await knockOutTeam2(quiz);

        await startTF(quiz);
        await say(quiz, 1, true);
        await say(quiz, 2, false);
        await stopTF(quiz);
        await quiz.host.click('trueFalsePanel.answerFalse:');
        await quiz.host.click('trueFalsePanel.answerTrue:');
        assert.strictEqual((await quiz.host.read(TF + '.teamEnabled'))[1], false);
    });

    scenario('true/false: everybody wrong leaves a round a reset can recover', async quiz => {
        await trueFalse(quiz);
        await startTF(quiz);
        await say(quiz, 1, false);
        await stopTF(quiz);
        await quiz.host.click('trueFalsePanel.answerTrue:');
        assert.deepStrictEqual(await quiz.host.read(TF + '.teamEnabled'), [false, false, false]);

        await quiz.host.click('resetRound:');
        assert.deepStrictEqual(await quiz.host.read(TF + '.teamEnabled'), [true, true, true]);
    });


    //--- Multiple choice

    async function multiChoice(quiz) {
        await begin(quiz, 'multichoice');
        await quiz.host.setToggle('multiChoicePanel.sounds', false);
    }
    const startMC = quiz => quiz.host.click('multiChoicePanel.startButton');
    const lit = (phone, option) => phone.hasClass(phone.tile(option), 'multiSelected');

    scenario('multiple choice: an option that is not on the grid is refused', async quiz => {
        await multiChoice(quiz);
        await startMC(quiz);
        const mark = quiz.wire.length;
        for(const bad of ['mc1,5', 'mc1,0', 'mc1,-1', 'mc1,abc', 'mc1,']) await quiz.rawFrom(1, bad);
        assert.strictEqual((await quiz.host.read(MC + '.teamGuesses'))[0], null);
        assert.ok(!quiz.wire.slice(mark).some(w => w.msg.startsWith('ms')), 'a tile was lit');
        await startMC(quiz);
    });

    scenario('multiple choice: a bad option does not lose a good one already given', async quiz => {
        await multiChoice(quiz);
        await startMC(quiz);
        await quiz.tapped(1, 'mc', quiz.phones[1].tile(2));
        await quiz.rawFrom(1, 'mc1,5');
        assert.strictEqual((await quiz.host.read(MC + '.teamGuesses'))[0], 2);
        assert.ok(await lit(quiz.phones[1], 2));
        await startMC(quiz);
    });

    scenario('multiple choice: a team switched off gets no tile and no guess', async quiz => {
        await multiChoice(quiz);
        await quiz.setPlaying(2, false);
        await startMC(quiz);
        await quiz.tapped(2, 'mc', quiz.phones[2].tile(1));
        assert.strictEqual((await quiz.host.read(MC + '.teamGuesses'))[1], null);
        assert.ok(!(await lit(quiz.phones[2], 1)));
        await startMC(quiz);
    });

    scenario('multiple choice: the grid and the clock cannot change during a question', async quiz => {
        await multiChoice(quiz);
        await startMC(quiz);
        await quiz.host.set('multiChoicePanel.optionsStepper', 6);
        assert.strictEqual(await quiz.phones[1].tiles(), 4);
        assert.strictEqual(await panel(quiz, 'multiChoicePanel.optionsNumber'), '4');

        for(const time of ['time10', 'time20', 'time30']) {
            assert.strictEqual((await quiz.host.read('multiChoicePanel.' + time)).enabled, false,
                               time + ' can be pressed during a question');
        }
        await startMC(quiz);
        for(const time of ['time10', 'time20', 'time30']) {
            assert.strictEqual((await quiz.host.read('multiChoicePanel.' + time)).enabled, true,
                               time + ' is still greyed out after the question');
        }
    });

    scenario('multiple choice: the clock running out ends the question', async quiz => {
        await multiChoice(quiz);
        await quiz.host.click('multiChoicePanel.time10');
        await startMC(quiz);
        await quiz.tapped(1, 'mc', quiz.phones[1].tile(1));
        await until('the clock to run out', async () => !(await quiz.host.read(MC + '.counting')), 14000);
        assert.strictEqual((await quiz.host.read('multiChoicePanel.startButton')).title, 'Start');
        assert.strictEqual((await quiz.host.read('multiChoicePanel.time20')).enabled, true,
                           'the time buttons are still greyed out once the clock has run out');

        await quiz.tapped(2, 'mc', quiz.phones[2].tile(2));
        assert.strictEqual((await quiz.host.read(MC + '.teamGuesses'))[1], null);
        assert.ok(!(await lit(quiz.phones[2], 2)), 'a late answer lit up');
        await seen(quiz, '1: A');
    });

    scenario('multiple choice: shrinking the grid forgets answers that no longer exist', async quiz => {
        await multiChoice(quiz);
        await quiz.host.set('multiChoicePanel.optionsStepper', 6);
        await until('six tiles', async () => (await quiz.phones[1].tiles()) === 6);
        await startMC(quiz);
        await quiz.tapped(1, 'mc', quiz.phones[1].tile(6));
        await startMC(quiz);

        await quiz.host.set('multiChoicePanel.optionsStepper', 4);
        await until('four tiles', async () => (await quiz.phones[1].tiles()) === 4);
        assert.strictEqual((await quiz.host.read(MC + '.teamGuesses'))[0], null);
        assert.strictEqual(await panel(quiz, 'multiChoicePanel.teamGuesses'), '');
    });

    scenario('multiple choice: a reset during a question clears the phones as well', async quiz => {
        await multiChoice(quiz);
        await startMC(quiz);
        const one = quiz.phones[1];
        await quiz.tapped(1, 'mc', one.tile(2));
        await until('lit', () => lit(one, 2));

        await quiz.host.click('resetRound:');
        await until('the tile to go out', async () => !(await lit(one, 2)));
        assert.strictEqual(await quiz.host.read(MC + '.counting'), false);
        assert.strictEqual((await quiz.host.read(MC + '.teamGuesses'))[0], null);
    });

    scenario('multiple choice: an answer with no question asked is harmless', async quiz => {
        await multiChoice(quiz);
        await quiz.host.click('multiChoicePanel.answer2');
        await startMC(quiz);
        await quiz.tapped(1, 'mc', quiz.phones[1].tile(1));
        assert.strictEqual((await quiz.host.read(MC + '.teamGuesses'))[0], 1);
        await startMC(quiz);
    });


    //--- Text

    const guesses = quiz => panel(quiz, 'textPanel.teamGuesses');

    scenario('text: submitting nothing takes an answer back', async quiz => {
        await begin(quiz, 'text');
        const one = quiz.phones[1];
        await one.answerText('paris');
        await until('the answer', async () => (await guesses(quiz)).includes('paris'));

        await one.textbox.fill('');
        await quiz.tapped(1, 'tt', one.enter);
        assert.doesNotMatch(await guesses(quiz), /paris/);
    });

    scenario('text: a team switched off after answering is not revealed', async quiz => {
        await begin(quiz, 'text');
        await quiz.phones[1].answerText('secret');
        await quiz.phones[2].answerText('open');
        await until('both', async () => (await guesses(quiz)).includes('open') && (await guesses(quiz)).includes('secret'));

        await quiz.setPlaying(1, false);
        await quiz.host.click('textPanel.showGuesses:');
        await seen(quiz, 'open');
        assert.ok(!(await showing(quiz, 'secret')), 'its answer went up on the screen');

        await quiz.setPlaying(1, true);
        await seen(quiz, 'secret');
    });

    scenario('text: switching a team off after the reveal takes its answer down', async quiz => {
        await begin(quiz, 'text');
        await quiz.phones[1].answerText('secret');
        await until('the answer', async () => (await guesses(quiz)).includes('secret'));
        await quiz.host.click('textPanel.showGuesses:');
        await seen(quiz, 'secret');

        await quiz.setPlaying(1, false);
        await until('the answer to go', async () => !(await showing(quiz, 'secret')));
    });

    scenario('text: a reset forgets the reveal as well', async quiz => {
        await begin(quiz, 'text');
        await quiz.phones[1].answerText('secret');
        await until('the answer', async () => (await guesses(quiz)).includes('secret'));
        await quiz.host.click('textPanel.showGuesses:');
        await seen(quiz, 'secret');
        await quiz.host.click('resetRound:');

        //An answer given now is hidden again, and stays so if the team is switched off and on
        await quiz.phones[1].answerText('another');
        await until('the new answer', async () => (await guesses(quiz)).includes('another'));
        await quiz.setPlaying(1, false);
        await quiz.setPlaying(1, true);
        assert.ok(!(await showing(quiz, 'another')), 'it went up on the screen');
    });

    scenario('text: a team switched off earns no star of its own', async quiz => {
        await begin(quiz, 'text');
        await quiz.phones[1].answerText('york');
        await quiz.phones[2].answerText('rome');
        await until('both', async () => (await guesses(quiz)).split('\n').length === 2);

        await quiz.setPlaying(1, false);
        await quiz.host.click('textPanel.showGuesses:');
        await quiz.host.click('textPanel.scoreUnique:');
        assert.strictEqual((await quiz.host.read('quizDisplay.textScene.emitters')).length, 1);
    });

    scenario('text: an answer only earns the star for being unique', async quiz => {
        await begin(quiz, 'text');
        const stars = async () => (await quiz.host.read('quizDisplay.textScene.emitters')).length;

        await quiz.phones[1].answerText('Paris');
        await quiz.phones[2].answerText('paris ');
        await quiz.phones[3].answerText('rome');
        await until('all three', async () => (await guesses(quiz)).split('\n').length === 3);
        await quiz.host.click('textPanel.showGuesses:');
        await quiz.host.click('textPanel.scoreUnique:');
        assert.strictEqual(await stars(), 1, 'only rome is unique');

        await quiz.host.click('textPanel.scoreUnique:');
        assert.strictEqual(await stars(), 1, 'pressing it again adds another star');
    });

    scenario('text: a team switched off does not spoil somebody else being unique', async quiz => {
        await begin(quiz, 'text');
        await quiz.phones[1].answerText('york');
        await quiz.phones[2].answerText('york');
        await until('both', async () => (await guesses(quiz)).split('\n').length === 2);

        await quiz.setPlaying(1, false);
        await quiz.host.click('textPanel.showGuesses:');
        await quiz.host.click('textPanel.scoreUnique:');
        assert.strictEqual((await quiz.host.read('quizDisplay.textScene.emitters')).length, 1);
    });

    scenario('text: a reset forgets every answer', async quiz => {
        await begin(quiz, 'text');
        await quiz.phones[1].answerText('paris');
        await until('the answer', async () => (await guesses(quiz)).includes('paris'));
        await quiz.host.click('resetRound:');
        assert.strictEqual(await guesses(quiz), '');
        await quiz.host.click('textPanel.showGuesses:');
        assert.ok(!(await showing(quiz, 'paris')));
    });


    //--- Numbers

    async function numbers(quiz, answer, values) {
        await begin(quiz, 'numbers');
        await quiz.host.set('numbersPanel.actualAnswer', String(answer));
        for(const [n, value] of Object.entries(values)) {
            await quiz.phones[n].textbox.fill(String(value));
            await quiz.tapped(n, 'tt', quiz.phones[n].enter);
        }
    }
    const reveal = quiz => quiz.host.click('numbersPanel.showAnswers:');

    scenario('numbers: the host and the display agree once a team is switched off', async quiz => {
        await numbers(quiz, 50, { 1: 49, 2: 60, 3: 90 });
        await until('team 1 first on the list', async () =>
            /🟢 Team 1/.test(await panel(quiz, 'numbersPanel.teamGuesses')));

        await quiz.setPlaying(1, false);
        await until('the list to redraw', async () =>
            /🟢 Team 2/.test(await panel(quiz, 'numbersPanel.teamGuesses')));
        assert.doesNotMatch(await panel(quiz, 'numbersPanel.teamGuesses'), /Team 1/);

        await quiz.setPlaying(1, true);
        await until('team 1 to return', async () =>
            /🟢 Team 1/.test(await panel(quiz, 'numbersPanel.teamGuesses')));
    });

    scenario('numbers: the same with no answer typed yet', async quiz => {
        await numbers(quiz, 'none', { 1: 49, 2: 60 });
        await until('both on the list', async () => /Team 1: 49\nTeam 2: 60/.test(await panel(quiz, 'numbersPanel.teamGuesses')));
        await quiz.setPlaying(1, false);
        await until('team 1 to leave the list', async () =>
            (await panel(quiz, 'numbersPanel.teamGuesses')) === 'Team 2: 60');
    });

    scenario('numbers: everybody guessing the same does not upset the scale', async quiz => {
        await numbers(quiz, 50, { 1: 50, 2: 50, 3: 50 });
        await reveal(quiz);
        await reveal(quiz);
        await until('the round to be scored', () => quiz.host.read(NUMBERS + '.scored'));
        assert.ok(await quiz.host.read(NUMBERS + '.revealed'));
    });

    scenario('numbers: a single guess, and zero', async quiz => {
        await numbers(quiz, 0, { 2: 0 });
        await reveal(quiz);
        await reveal(quiz);
        await until('the round to be scored', () => quiz.host.read(NUMBERS + '.scored'));
    });

    scenario('numbers: nobody guessing at all', async quiz => {
        await numbers(quiz, 50, {});
        await reveal(quiz);
        await reveal(quiz);
        await reveal(quiz);
        assert.ok(await quiz.host.read(NUMBERS + '.scored'));
    });

    scenario('numbers: an answer far from every guess', async quiz => {
        await numbers(quiz, 1000000, { 1: 1, 2: 2 });
        await reveal(quiz);
        await reveal(quiz);
        await until('the answer on screen', () => showing(quiz, '1,000,000').then(found => found) , 6000).catch(() => {});
        assert.ok(await quiz.host.read(NUMBERS + '.scored'));
    });

    scenario('numbers: the largest number a phone can send', async quiz => {
        await numbers(quiz, 50, { 1: '9223372036854775807', 2: 40 });
        await reveal(quiz);
        await reveal(quiz);
        await until('the round to be scored', () => quiz.host.read(NUMBERS + '.scored'));
        await pause(2500); //The scoring animation is where this would go wrong
        await quiz.host.scene();
    });

    scenario('numbers: not a number', async quiz => {
        await numbers(quiz, 50, { 1: 40 });
        for(const bad of ['tt1,abc', 'tt1,12abc', 'tt1,', 'tt1,99999999999999999999']) await quiz.rawFrom(1, bad);
        assert.match(await panel(quiz, 'numbersPanel.teamGuesses'), /Team 1: 40/);
    });

    scenario('numbers: a reset during the scoring leaves nothing behind', async quiz => {
        await numbers(quiz, 50, { 1: 40, 2: 70 });
        await reveal(quiz);
        await reveal(quiz);
        await quiz.host.click('resetRound:');
        await pause(2500);
        assert.strictEqual(await quiz.host.read(NUMBERS + '.scored'), false);
        assert.strictEqual(await quiz.host.read(NUMBERS + '.revealed'), false);
        assert.ok(!(await showing(quiz, '40')), 'the old guesses are back');
    });


    //--- Pointless

    async function pointless(quiz, answers) {
        //Before the round is entered, as changing question sends the phones a reset of its own
        await quiz.host.click('tabitemPointless');
        await quiz.host.set('pointlessPanel.questionSelector', '1-fruit.txt');
        await begin(quiz, 'pointless');
        for(const [n, answer] of Object.entries(answers)) {
            await quiz.phones[n].textbox.fill(answer);
            await quiz.tapped(n, 'tt', quiz.phones[n].enter);
        }
    }
    const state = quiz => quiz.host.read(POINTLESS + '.gameState');

    scenario('pointless: a team switched off after answering cannot win', async quiz => {
        await pointless(quiz, { 1: 'kiwi', 2: 'apple' });
        await quiz.setPlaying(1, false);
        await quiz.host.click('pointlessPanel.showAnswers:');
        await seen(quiz, 'apple');
        assert.ok(!(await showing(quiz, 'kiwi')), 'its answer went up on the screen');
        await quiz.host.click('pointlessPanel.runScoring:');
        assert.strictEqual(await quiz.host.read(POINTLESS + '.lowestScoreThisRound'), 40);
    });

    scenario('pointless: a team switched back on has its answer and its score again', async quiz => {
        await pointless(quiz, { 1: 'kiwi', 2: 'apple' });
        await quiz.setPlaying(1, false);
        await quiz.host.click('pointlessPanel.showAnswers:');
        assert.ok(!(await showing(quiz, 'kiwi')));

        await quiz.setPlaying(1, true);
        await seen(quiz, 'kiwi');
        await quiz.host.click('pointlessPanel.runScoring:');
        assert.strictEqual(await quiz.host.read(POINTLESS + '.lowestScoreThisRound'), 3);
    });

    scenario('pointless: a team switched off before the count gets no bar and does not stop it', async quiz => {
        await pointless(quiz, { 1: 'quince', 2: 'apple' });
        await quiz.setPlaying(1, false);
        await quiz.host.click('pointlessPanel.showAnswers:');
        await quiz.host.click('pointlessPanel.runScoring:');
        await quiz.host.click('pointlessPanel.runScoring:');
        const bars = await quiz.host.read(POINTLESS + '.scoreBars');
        assert.strictEqual(bars[0], null, 'it has a bar');
        assert.notStrictEqual(bars[1], null);
        await until('the count to finish', async () => (await state(quiz)) === 'done', 10000);
    });

    scenario('pointless: a bar left over from an interrupted count does not carry on', async quiz => {
        await pointless(quiz, { 1: 'quince', 2: 'apple' });
        await quiz.host.click('pointlessPanel.showAnswers:');
        await quiz.host.click('pointlessPanel.runScoring:');
        await quiz.host.click('pointlessPanel.runScoring:');
        await quiz.host.click('resetRound:');
        assert.deepStrictEqual((await quiz.host.read(POINTLESS + '.scoreBars')).slice(0, 2), [null, null]);
    });

    scenario('pointless: changing question starts the question again, on the phones as well', async quiz => {
        await pointless(quiz, { 1: 'kiwi' });
        assert.strictEqual((await quiz.host.read(POINTLESS + '.teamScores'))[0], 3);
        const one = quiz.phones[1];
        assert.strictEqual(await one.textbox.inputValue(), 'kiwi');

        await quiz.host.set('pointlessPanel.questionSelector', '2-green.txt');
        assert.strictEqual((await quiz.host.read(POINTLESS + '.teamGuesses'))[0], null);
        assert.strictEqual((await quiz.host.read(POINTLESS + '.teamScores'))[0], null);
        await seen(quiz, 'Team 1');
        await until('the phone to clear', async () => (await one.textbox.inputValue()) === '');

        //And the same answer is judged against the new one
        await one.answerText('kiwi');
        await until('the new score', async () => (await quiz.host.read(POINTLESS + '.teamScores'))[0] === 5);
    });

    scenario('pointless: changing question during the count stops it', async quiz => {
        await pointless(quiz, { 1: 'kiwi' });
        await quiz.host.click('pointlessPanel.showAnswers:');
        await quiz.host.click('pointlessPanel.runScoring:');
        await quiz.host.click('pointlessPanel.runScoring:');
        await quiz.host.set('pointlessPanel.questionSelector', '2-green.txt');
        assert.strictEqual(await state(quiz), 'waitForAnswers');
        await pause(400);
        assert.strictEqual(await state(quiz), 'waitForAnswers', 'the count carried on');
    });

    scenario('pointless: picking the question already loaded keeps the answers', async quiz => {
        await pointless(quiz, { 1: 'kiwi' });
        await quiz.host.set('pointlessPanel.questionSelector', '1-fruit.txt');
        assert.strictEqual((await quiz.host.read(POINTLESS + '.teamScores'))[0], 3);
        assert.strictEqual((await quiz.host.read(POINTLESS + '.teamGuesses'))[0], 'kiwi');
    });

    scenario('pointless: everybody wrong still finishes', async quiz => {
        await pointless(quiz, { 1: 'bread', 2: 'cheese', 3: 'wine' });
        await quiz.host.click('pointlessPanel.showAnswers:');
        await quiz.host.click('pointlessPanel.runScoring:');
        await quiz.host.click('pointlessPanel.runScoring:');
        await until('the scoring to finish', async () => (await state(quiz)) === 'done', 3000);
    });

    scenario('pointless: nobody answering still finishes', async quiz => {
        await pointless(quiz, {});
        await quiz.host.click('pointlessPanel.showAnswers:');
        await quiz.host.click('pointlessPanel.runScoring:');
        await quiz.host.click('pointlessPanel.runScoring:');
        await until('the scoring to finish', async () => (await state(quiz)) === 'done', 3000);
    });

    scenario('pointless: scoring cannot be run before the answers are up', async quiz => {
        await pointless(quiz, { 1: 'kiwi' });
        await quiz.host.click('pointlessPanel.runScoring:');
        assert.strictEqual(await state(quiz), 'waitForAnswers');
    });

    scenario('pointless: a reset during the count puts everything back', async quiz => {
        await pointless(quiz, { 1: 'kiwi', 2: 'quince' });
        await quiz.host.click('pointlessPanel.showAnswers:');
        await quiz.host.click('pointlessPanel.runScoring:');
        await quiz.host.click('pointlessPanel.runScoring:');
        assert.strictEqual(await state(quiz), 'runPointless');

        await quiz.host.click('resetRound:');
        assert.strictEqual(await state(quiz), 'waitForAnswers');
        await pause(500);
        assert.strictEqual(await state(quiz), 'waitForAnswers', 'the count carried on');

        await quiz.phones[1].answerText('apple');
        await until('a new answer to count', async () => (await quiz.host.read(POINTLESS + '.teamScores'))[0] === 40);
    });

    scenario('pointless: a winner on zero, and a draw', async quiz => {
        await pointless(quiz, { 1: 'quince', 2: 'quince', 3: 'apple' });
        await quiz.host.click('pointlessPanel.showAnswers:');
        await quiz.host.click('pointlessPanel.runScoring:');
        assert.strictEqual(await quiz.host.read(POINTLESS + '.lowestScoreThisRound'), 0);
        await quiz.host.click('pointlessPanel.runScoring:');
        await until('the count to finish', async () => (await state(quiz)) === 'done', 15000);
    });
});
