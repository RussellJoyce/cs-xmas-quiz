'use strict';

//The categories round: a board of blank slots that the host fills as teams give right answers,
//a strip of wrong guesses typed in by the host, and a buzz stack for who answers next.

const assert = require('node:assert');
const { quizScenarios, until } = require('./rig');
const { CATEGORIES } = require('./fixtures');

const SCENE = 'quizDisplay.categoriesScene';
const shown = quiz => quiz.host.visibleText();
const seen = (quiz, what) => until('"' + what + '" on screen', async () => (await shown(quiz)).includes(what));
const gone = (quiz, what) => until('"' + what + '" off the screen', async () => !(await shown(quiz)).includes(what));
const answerIndex = name => CATEGORIES.answers.indexOf(name);
const mark = (quiz, name) => quiz.host.click('categoriesPanel.answerButtons.' + answerIndex(name));
const wrong = (quiz, text) => quiz.host.set('categoriesPanel.wrongGuessField', text);
const buzz = (quiz, team) => quiz.tapped(team, 'zz', quiz.phones[team].buzzer);

async function begin(quiz, file = CATEGORIES.file) {
    await quiz.host.set('categoriesPanel.questionSelector', file);
    await quiz.round('categories');
}

quizScenarios('categories', { teams: 3 }, scenario => {

    scenario('the board starts blank, and gives nothing away', async quiz => {
        await begin(quiz);
        await seen(quiz, CATEGORIES.heading);
        await seen(quiz, CATEGORIES.subheading);
        await seen(quiz, '0 / 30');
        const text = await shown(quiz);
        for(const answer of CATEGORIES.answers) assert.ok(!text.includes(answer), answer + ' is hidden');
        assert.deepStrictEqual(await quiz.host.offScreen(), []);
    });

    scenario('marking an answer puts it on the board, and unmarking takes it off', async quiz => {
        await begin(quiz);
        await mark(quiz, 'Bosnia and Herzegovina');
        await seen(quiz, 'Bosnia and Herzegovina');
        await seen(quiz, '1 / 30');
        assert.ok(!(await shown(quiz)).includes('Albania'), 'only the one marked');

        await mark(quiz, 'Bosnia and Herzegovina');
        await gone(quiz, 'Bosnia and Herzegovina');
        await seen(quiz, '0 / 30');
    });

    scenario('the board fills in the order answers are found, not the alphabet', async quiz => {
        await begin(quiz);
        const onBoard = async () => (await shown(quiz)).filter(t => CATEGORIES.answers.includes(t));
        for(const name of ['Vatican City', 'Albania', 'Malta']) await mark(quiz, name);
        await until('three on the board', async () => (await onBoard()).length === 3);
        assert.deepStrictEqual(await onBoard(), ['Vatican City', 'Albania', 'Malta']);

        //Taking one away closes the gap
        await mark(quiz, 'Vatican City');
        await until('two on the board', async () => (await onBoard()).length === 2);
        assert.deepStrictEqual(await onBoard(), ['Albania', 'Malta']);

        //The missed ones follow on after
        await quiz.host.click('categoriesPanel.revealToggled:');
        await until('all thirty', async () => (await onBoard()).length === 30);
        assert.deepStrictEqual((await onBoard()).slice(0, 3), ['Albania', 'Malta', 'Andorra']);
    });

    scenario('a wrong guess goes on the strip, once, and the host can take it off', async quiz => {
        await begin(quiz);
        await wrong(quiz, 'Narnia');
        await seen(quiz, '✗ Narnia');
        await wrong(quiz, 'narnia ');
        assert.deepStrictEqual(await quiz.host.read(SCENE + '.wrongGuesses'), ['Narnia'], 'a repeat is ignored');

        await wrong(quiz, 'Atlantis');
        await quiz.host.click('categoriesPanel.removeWrongGuess:#0');
        await gone(quiz, '✗ Narnia');
        assert.ok((await shown(quiz)).includes('✗ Atlantis'));
    });

    scenario('a right answer typed in as wrong is marked right instead', async quiz => {
        await begin(quiz);
        await wrong(quiz, 'san marino');
        await seen(quiz, 'San Marino');
        assert.deepStrictEqual(await quiz.host.read(SCENE + '.wrongGuesses'), []);
        assert.strictEqual((await quiz.host.read('categoriesPanel.answerButtons.' + answerIndex('San Marino'))).on, true,
                           'ticked on the panel too');
    });

    scenario('reveal shows what was missed, and can be undone', async quiz => {
        await begin(quiz);
        await mark(quiz, 'France');
        await quiz.host.click('categoriesPanel.revealToggled:');
        await seen(quiz, 'Vatican City');
        await until('every answer', async () => {
            const text = await shown(quiz);
            return CATEGORIES.answers.every(a => text.includes(a));
        });
        assert.deepStrictEqual(await quiz.host.offScreen(), [], 'a full board fits');

        await quiz.host.click('categoriesPanel.revealToggled:');
        await gone(quiz, 'Vatican City');
        assert.ok((await shown(quiz)).includes('France'), 'the found answer stays');
    });

    scenario('a full strip of wrong guesses still fits', async quiz => {
        await begin(quiz);
        for(let i = 1; i <= 25; i++) await wrong(quiz, 'Not a country number ' + i);
        await seen(quiz, '✗ Not a country number 25');
        assert.deepStrictEqual(await quiz.host.offScreen(), []);
    });

    scenario('buzzes stack in order, and clearing lets everyone buzz again', async quiz => {
        await begin(quiz);
        await buzz(quiz, 3);
        await buzz(quiz, 1);
        await buzz(quiz, 3);
        assert.deepStrictEqual(await quiz.host.read(SCENE + '.buzzes'), [2, 0], 'a second buzz from team 3 is ignored');
        await seen(quiz, 'Team 3');

        await quiz.host.click('categoriesPanel.clearBuzzes:');
        assert.deepStrictEqual(await quiz.host.read(SCENE + '.buzzes'), []);
        await gone(quiz, 'Team 3');
        await buzz(quiz, 3);
        assert.deepStrictEqual(await quiz.host.read(SCENE + '.buzzes'), [2]);
    });

    scenario('a team knocked out cannot buzz', async quiz => {
        await begin(quiz);
        await quiz.setPlaying(2, false);
        await buzz(quiz, 2);
        await buzz(quiz, 1);
        assert.deepStrictEqual(await quiz.host.read(SCENE + '.buzzes'), [0]);
        await quiz.setPlaying(2, true);
    });

    scenario('changing question clears the board, the strip and the buzzes', async quiz => {
        await begin(quiz);
        await mark(quiz, 'Malta');
        await wrong(quiz, 'Narnia');
        await buzz(quiz, 1);
        await seen(quiz, 'Malta');

        await quiz.host.set('categoriesPanel.questionSelector', '2-fruit.txt');
        await seen(quiz, '0 / 3');
        await gone(quiz, 'Malta');
        await gone(quiz, '✗ Narnia');
        assert.deepStrictEqual(await quiz.host.read(SCENE + '.buzzes'), []);
        assert.strictEqual((await quiz.host.read('categoriesPanel.answerButtons.0')).title, 'apple');
    });

    scenario('reset clears the marks but keeps the question', async quiz => {
        await begin(quiz);
        await mark(quiz, 'Malta');
        await seen(quiz, 'Malta');
        await quiz.host.click('resetRound:');
        await gone(quiz, 'Malta');
        await seen(quiz, CATEGORIES.heading);
        assert.strictEqual((await quiz.host.read('categoriesPanel.answerButtons.' + answerIndex('Malta'))).on, false);
    });
});
