'use strict';

//The connecting wall, whose phones keep more state than any other round's.

const assert = require('node:assert');
const { quizScenarios, until } = require('./rig');
const { WALL } = require('./fixtures');

//Picks four words. The phone sends them as the fourth goes in.
async function pick(quiz, n, words) {
    for(const word of words) await quiz.phones[n].press(quiz.phones[n].wallTile(word));
}

const status = async quiz => (await quiz.host.read('onlyConnectPanel.statusText')).value;
const statusSays = (quiz, what) => until('the host to see "' + what + '"', async () => (await status(quiz)).includes(what));

quizScenarios('only connect', { teams: 3 }, scenario => {

    scenario('nothing is on the wall until the host starts it', async quiz => {
        await quiz.round('onlyConnect');
        assert.strictEqual(await quiz.phones[1].wallTile('apple').count(), 0);
        await quiz.host.click('onlyConnectPanel.startButton');
        await until('the words', async () => (await quiz.phones[1].wallTile('apple').count()) === 1);
        await until('the same words on phone 2', async () => (await quiz.phones[2].wallTile('zinc').count()) === 1);
    });

    scenario('a wrong guess costs a mark and clears itself, on that phone alone', async quiz => {
        await pick(quiz, 1, ['apple', 'pear', 'red', 'blue']);
        await statusSays(quiz, 'Team 1: 0 found, 1 wrong');
        await until('the crosses', async () => (await quiz.phones[1].wallTileCount('wallWrong')) === 4);
        assert.strictEqual(await quiz.phones[2].wallTileCount('wallWrong'), 0);
        await until('the crosses to go', async () => (await quiz.phones[1].wallTileCount('wallWrong')) === 0, 3000);
        assert.strictEqual(await quiz.phones[1].wallTile('apple').count(), 1, 'the word is back');
    });

    scenario('three groups found gives away the fourth, and finishes the team', async quiz => {
        await pick(quiz, 1, WALL.fruit);
        await statusSays(quiz, 'Team 1: 1 found, 1 wrong');
        await until('four solved', async () => (await quiz.phones[1].wallTileCount('wallSolved')) === 4);
        assert.strictEqual(await quiz.phones[2].wallTileCount('wallSolved'), 0, 'only for that team');

        await pick(quiz, 1, WALL.colour);
        await until('eight solved', async () => (await quiz.phones[1].wallTileCount('wallSolved')) === 8);
        await pick(quiz, 1, WALL.metal);
        await until('the whole wall solved', async () => (await quiz.phones[1].wallTileCount('wallSolved')) === 16);
        await statusSays(quiz, 'Team 1: 4 found, 1 wrong');
        assert.match(await status(quiz), /Team 1: 4 found, 1 wrong, .*\(1st\)/);
    });

    scenario('stopping the wall freezes the phones still playing', async quiz => {
        const two = quiz.phones[2];
        await quiz.host.click('onlyConnectPanel.startButton');
        await until('phone 2 to freeze', async () => (await two.wallTileCount('buttonOff')) === 16);

        await two.press(two.wallTile('cat'));
        assert.strictEqual(await two.wallTileCount('multiSelected'), 0, 'a frozen tile cannot be picked');
    });

    scenario('dropped connection: what was found survives, and what was missed is caught up', async quiz => {
        await quiz.round('onlyConnect');
        await quiz.host.click('onlyConnectPanel.startButton');
        const one = quiz.phones[1];
        await until('the words', async () => (await one.wallTile('apple').count()) === 1);
        await pick(quiz, 1, WALL.pet);
        await until('four solved', async () => (await one.wallTileCount('wallSolved')) === 4);

        //The wall ends while this phone cannot hear about it
        const mark = quiz.wire.length;
        quiz.dropPhone(1);
        await quiz.host.click('onlyConnectPanel.startButton');
        assert.ok(!(await one.wallTileCount('buttonOff')), 'has not heard yet');

        await quiz.phoneBack(1, mark);
        await until('the phone to catch up with the freeze', async () => (await one.wallTileCount('buttonOff')) === 12);
        assert.strictEqual(await one.wallTileCount('wallSolved'), 4);
    });

    scenario('reload: the wall comes back with what the team found', async quiz => {
        await quiz.round('onlyConnect');
        await quiz.host.click('onlyConnectPanel.startButton');
        const two = quiz.phones[2];
        await until('the words', async () => (await two.wallTile('apple').count()) === 1);
        await pick(quiz, 2, WALL.metal);
        await until('four solved', async () => (await two.wallTileCount('wallSolved')) === 4);

        const mark = quiz.wire.length;
        await quiz.reloadPhone(2);
        await quiz.phoneBack(2, mark);
        await until('the wall back', async () => (await two.wallTileCount('wallSolved')) === 4);
        assert.strictEqual(await two.wallTile('apple').count(), 1);

        await pick(quiz, 2, WALL.pet);
        await statusSays(quiz, 'Team 2: 2 found');
        await quiz.host.click('onlyConnectPanel.startButton');
    });
});
