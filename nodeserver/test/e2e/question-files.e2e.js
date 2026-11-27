'use strict';

//Question files as a Windows editor might save them: CRLF line endings, a byte order mark,
//UTF-16 (Notepad's "Unicode", Excel's "Unicode Text"), or Windows-1252 (an older editor, or
//Word's "Plain Text"). Each round that reads a file should read the same question from all
//of them, accents and curly quotes included.

const assert = require('node:assert');
const { quizScenarios, until } = require('./rig');
const { ENCODINGS, ENCODED } = require('./fixtures');

quizScenarios('question files saved on Windows', { teams: 3 }, scenario => {

    for(const encoding of ENCODINGS) {
        const file = ENCODED.file(encoding);

        scenario(encoding + ': the text round reads the right answers', async quiz => {
            await quiz.host.set('textPanel.uniqueFile', file);
            assert.deepStrictEqual(await quiz.host.read('quizDisplay.textScene.uniques'), ENCODED.unique.uniques);
        });

        scenario(encoding + ': categories reads the heading and the answers', async quiz => {
            await quiz.host.set('categoriesPanel.questionSelector', file);
            const scene = 'quizDisplay.categoriesScene.';
            assert.deepStrictEqual({
                heading: await quiz.host.read(scene + 'heading'),
                subheading: await quiz.host.read(scene + 'subheading'),
                answers: await quiz.host.read(scene + 'answers')
            }, {
                heading: ENCODED.categories.heading,
                subheading: ENCODED.categories.subheading,
                answers: ENCODED.categories.answers
            });
        });

        scenario(encoding + ': pointless reads the question and its scores', async quiz => {
            await quiz.host.set('pointlessPanel.questionSelector', file);
            const scene = 'quizDisplay.pointlessScene.';
            assert.strictEqual(await quiz.host.read(scene + 'questionTitle'), ENCODED.pointless.title);
            assert.deepStrictEqual(await quiz.host.read(scene + 'answers'),
                                   [{ 0: 'latte', 1: 10 }, { 0: 'café au lait', 1: 3 }]);
        });

        scenario(encoding + ': only connect reads the wall', async quiz => {
            await quiz.host.set('onlyConnectPanel.questionSelector', file);
            const group = 'quizDisplay.onlyConnectScene.wall.groups.0.';
            assert.deepStrictEqual(await quiz.host.read(group + 'clues'), ENCODED.wall.clues);
            assert.strictEqual(await quiz.host.read(group + 'connection'), ENCODED.wall.connection);
        });
    }

    //The whole way through, from a phone, with the file Notepad would save
    scenario('utf16le: teams typing the right answers get their stars', async quiz => {
        await quiz.allPlaying();
        await quiz.round('text');
        await quiz.host.set('textPanel.uniqueFile', ENCODED.file('utf16le'));
        await quiz.phones[1].answerText('paris');
        await quiz.phones[2].answerText('York');
        await quiz.phones[3].answerText('café');
        await until('all three', async () =>
            (await quiz.host.read('textPanel.teamGuesses')).value.split('\n').length === 3);
        await quiz.host.click('textPanel.showGuesses:');
        await quiz.host.click('textPanel.scoreUnique:');
        assert.strictEqual((await quiz.host.read('quizDisplay.textScene.emitters')).length, 3);
    });
});
