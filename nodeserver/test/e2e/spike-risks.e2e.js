'use strict';

//Not a test of the quiz. An experiment to answer whether SpriteKit keeps running when the
//display window cannot be seen, as that decides whether the suite can run behind other
//windows. It reports rather than asserts, and goes once the answer is known.

const { test, before, after } = require('node:test');
const { buildApp, startQuiz } = require('./rig');

let quiz;
before(async () => {
    buildApp();
    quiz = await startQuiz({ teams: 1 });
    await quiz.host.click('tabitemBuzzers');
    await new Promise(resolve => setTimeout(resolve, 1500)); //The round's transition
});
after(async () => { if(quiz) await quiz.close(); });

async function measure(label) {
    await new Promise(resolve => setTimeout(resolve, 1500)); //Let the window server catch up
    const status = await quiz.host.window('status');
    const ticks = [];
    for(let i = 0; i < 3; i++) ticks.push(await quiz.host.renderTick(4000));
    process.stderr.write('RISK ' + label.padEnd(12) + ' ' + JSON.stringify(status) +
                         ' 0.2s action took: ' + JSON.stringify(ticks) + '\n');
}

test('SpriteKit under different kinds of invisibility', async () => {
    await measure('baseline');
    for(const action of ['cover', 'minimise', 'hide']) {
        await quiz.host.window(action);
        await measure(action);
        await quiz.host.window('show');
        await measure('after ' + action);
    }
});
