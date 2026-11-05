'use strict';

//Trying to break the logic of the other rounds. As abuse-answers: each scenario says what
//ought to happen, not what the code happens to do.

const assert = require('node:assert');
const { quizScenarios, until } = require('./rig');
const { WALL, WIKI } = require('./fixtures');

const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
const panel = async (quiz, path) => (await quiz.host.read(path)).value;
const showing = async (quiz, what) => (await quiz.host.visibleText()).join('\n').includes(what);
const seen = (quiz, what) => until('"' + what + '" on screen', () => showing(quiz, what));

async function begin(quiz, round) {
    await quiz.allPlaying();
    await quiz.round(round);
}

const BUZZER = 'quizDisplay.buzzerScene';
const WAVE = 'quizDisplay.wavelengthScene';
const GEO = 'quizDisplay.geographyScene';

quizScenarios('trying to break the buzzer', { teams: 7 }, scenario => {
    const buzzes = quiz => quiz.host.read(BUZZER + '.buzzes');
    const buzz = (quiz, n) => quiz.tapped(n, 'zz', quiz.phones[n].buzzer);

    async function buzzers(quiz, queue) {
        await begin(quiz, 'buzzers');
        await quiz.host.setToggle('buzzerSounds', false);
        await quiz.host.setToggle('buzzerQueueMode', queue);
    }

    scenario('buzzing twice only counts once', async quiz => {
        await buzzers(quiz, true);
        await buzz(quiz, 1);
        await buzz(quiz, 1);
        await buzz(quiz, 2);
        await buzz(quiz, 1);
        assert.deepStrictEqual(await buzzes(quiz), [0, 1]);
    });

    scenario('the queue stops at five, and the sixth is told nothing has gone wrong', async quiz => {
        await buzzers(quiz, true);
        for(const n of [1, 2, 3, 4, 5, 6]) await buzz(quiz, n);
        assert.deepStrictEqual(await buzzes(quiz), [0, 1, 2, 3, 4]);
    });

    scenario('next team, past the end of the queue and with nobody in it', async quiz => {
        await buzzers(quiz, true);
        await quiz.host.click('buzzerPanel.nextTeam:');

        await buzz(quiz, 1);
        await buzz(quiz, 2);
        for(let i = 0; i < 4; i++) await quiz.host.click('buzzerPanel.nextTeam:');

        //And somebody joining after that
        await buzz(quiz, 3);
        await quiz.host.click('buzzerPanel.nextTeam:');
        assert.deepStrictEqual(await buzzes(quiz), [0, 1, 2]);
    });

    scenario('stopping everybody and starting them again keeps who was out', async quiz => {
        await buzzers(quiz, false);
        await quiz.setPlaying(1, false);

        await quiz.host.click('disableAllBuzzers:');
        await until('everybody to go grey', async () => {
            for(const n of [1, 2, 3]) if(await quiz.phones[n].isOn()) return false;
            return true;
        });
        await buzz(quiz, 2);
        assert.deepStrictEqual(await buzzes(quiz), []);

        await quiz.host.click('disableAllBuzzers:');
        await until('team 2 to come back', () => quiz.phones[2].isOn());
        assert.strictEqual(await quiz.phones[1].isOn(), false, 'team 1 came back with them');
        await buzz(quiz, 1);
        assert.deepStrictEqual(await buzzes(quiz), []);
    });

    scenario('a virtual buzz cannot be fired for a team that is out', async quiz => {
        await buzzers(quiz, false);
        await quiz.setPlaying(1, false);
        await quiz.host.setToggle('virtualBuzzersBtn', true);
        await quiz.host.click('buzzerButton1');
        assert.deepStrictEqual(await buzzes(quiz), []);
        assert.strictEqual((await quiz.host.read('buzzerButton1')).on, true, 'still shown as out');
    });

    scenario('a countdown from nothing does not run for ever', async quiz => {
        await buzzers(quiz, false);
        await quiz.host.set('buzzerPanel.timerSeconds', '0');
        await quiz.host.click('buzzerPanel.startTimer:');
        await pause(2200);
        const time = await quiz.host.read(BUZZER + '.time');
        await quiz.host.click('buzzerPanel.stopTimer:');
        assert.ok(time >= 0, 'the clock has reached ' + time);
    });

    scenario('a countdown that is not a number is ignored', async quiz => {
        await buzzers(quiz, false);
        const before = await quiz.host.read(BUZZER + '.time');
        await quiz.host.set('buzzerPanel.timerSeconds', 'soon');
        await quiz.host.click('buzzerPanel.startTimer:');
        await pause(1300);
        assert.strictEqual(await quiz.host.read(BUZZER + '.time'), before);
    });

    scenario('once a countdown has finished, a buzz has the LEDs again', async quiz => {
        await buzzers(quiz, false);
        await quiz.host.set('buzzerPanel.timerSeconds', '1');
        await quiz.host.click('buzzerPanel.startTimer:');
        await until('the countdown to finish', async () => (await quiz.host.read(BUZZER + '.time')) === 0, 4000);

        const before = quiz.leds.length;
        await buzz(quiz, 4);
        await until('the LED buzz', () => quiz.leds.slice(before).includes('b03'));
    });
});


quizScenarios('trying to break the other rounds', { teams: 3 }, scenario => {

    //--- Wavelength

    async function wavelength(quiz, guesses) {
        await begin(quiz, 'wavelength');
        for(const [n, f] of Object.entries(guesses)) {
            await quiz.phones[n].tapAt(quiz.phones[n].waveTrack, f, 0.5);
            await until('team ' + n + "'s guess", async () =>
                ((await quiz.host.read(WAVE + '.teamGuesses'))[n - 1]) !== null);
        }
    }
    async function roll(quiz) {
        await quiz.host.click('wavelengthPanel.rollButton');
        await quiz.host.click('wavelengthPanel.rollButton');
    }
    async function scored(quiz) {
        await quiz.host.click('wavelengthPanel.score:');
        await until('the scoring', async () => {
            await quiz.host.click('wavelengthPanel.score:');
            return quiz.host.read(WAVE + '.scored');
        }, 15000);
    }

    scenario('wavelength: a value off the bar is refused', async quiz => {
        await wavelength(quiz, {});
        for(const bad of ['wv1,0', 'wv1,100', 'wv1,-5', 'wv1,abc', 'wv1,']) await quiz.rawFrom(1, bad);
        assert.strictEqual((await quiz.host.read(WAVE + '.teamGuesses'))[0], null);
    });

    scenario('wavelength: scoring needs a roll', async quiz => {
        await wavelength(quiz, { 1: 0.5 });
        await quiz.host.click('wavelengthPanel.score:');
        assert.strictEqual(await quiz.host.read(WAVE + '.swept'), false);

        //Nor one still spinning
        await quiz.host.click('wavelengthPanel.rollButton');
        await quiz.host.click('wavelengthPanel.score:');
        assert.strictEqual(await quiz.host.read(WAVE + '.swept'), false);
        await quiz.host.click('wavelengthPanel.rollButton');
    });

    scenario('wavelength: a team switched off is not placed', async quiz => {
        await wavelength(quiz, { 1: 0.25, 2: 0.75 });
        await quiz.setPlaying(1, false);
        await roll(quiz);
        await quiz.host.click('wavelengthPanel.reveal:');
        await scored(quiz);
        const list = await panel(quiz, 'wavelengthPanel.teamGuesses');
        assert.doesNotMatch(list, /Team 1/, list);
        assert.match(list, /Team 2/, list);
    });

    scenario('wavelength: nobody guessing at all', async quiz => {
        await wavelength(quiz, {});
        await roll(quiz);
        await quiz.host.click('wavelengthPanel.reveal:');
        await scored(quiz);
    });

    scenario('wavelength: a reset during the sweep puts everything back', async quiz => {
        await wavelength(quiz, { 1: 0.5 });
        await roll(quiz);
        await quiz.host.click('wavelengthPanel.score:');
        assert.strictEqual(await quiz.host.read(WAVE + '.swept'), true);

        await quiz.host.click('resetRound:');
        assert.strictEqual(await quiz.host.read(WAVE + '.swept'), false);
        assert.ok((await quiz.host.read('wavelengthPanel.rollButton')).enabled);
        await pause(1000);

        //And the next go is a clean one
        await quiz.phones[2].tapAt(quiz.phones[2].waveTrack, 0.5, 0.5);
        await until("team 2's guess", async () => (await quiz.host.read(WAVE + '.teamGuesses'))[1] !== null);
        assert.strictEqual((await quiz.host.read(WAVE + '.teamGuesses'))[0], null);
        await roll(quiz);
        await scored(quiz);
    });


    //--- Geography

    async function geography(quiz, taps) {
        await begin(quiz, 'geography');
        await quiz.host.set('geographyPanel.questionSelector', 'geo1.jpg');
        await quiz.host.click('geographyPanel.startQuestion:');
        await until('the image', async () =>
            (await quiz.phones[1].map.evaluate(el => el.style.backgroundImage)).includes('geo1.jpg'));
        for(const [n, [x, y]] of Object.entries(taps)) {
            await quiz.phones[n].tapAt(quiz.phones[n].map, x, y);
            await until('team ' + n + "'s pin", () => quiz.wire.some(w => w.dir === 'T' + n + '→srv' && w.msg.startsWith('ii')));
        }
        await quiz.host.settled();
    }
    async function answer(quiz, x, y) {
        await quiz.host.set('geographyPanel.answerX', String(x));
        await quiz.host.set('geographyPanel.answerY', String(y));
        await quiz.host.click('geographyPanel.showWinner:');
    }

    scenario('geography: an answer off the map is refused', async quiz => {
        await geography(quiz, { 1: [0.5, 0.5] });
        await answer(quiz, 150, 50);
        assert.strictEqual(await quiz.host.read(GEO + '.answering'), false);
    });

    scenario('geography: nobody guessing at all', async quiz => {
        await geography(quiz, {});
        await answer(quiz, 50, 50);
        await seen(quiz, 'The answer is...');
        await quiz.host.click('geographyPanel.showWinner:');
        await quiz.host.click('geographyPanel.showWinner:');
    });

    scenario('geography: a team switched off is not placed', async quiz => {
        await geography(quiz, { 1: [0.5, 0.5], 2: [0.1, 0.1] });
        await quiz.setPlaying(1, false);
        await answer(quiz, 50, 50);
        for(let i = 0; i < 3; i++) await quiz.host.click('geographyPanel.showWinner:');
        await seen(quiz, 'Team 2');
        assert.ok(!(await showing(quiz, 'Team 1')), 'it is in the standings');
    });

    scenario('geography: once the answer is up, a guess is too late', async quiz => {
        await geography(quiz, { 1: [0.5, 0.5] });
        await answer(quiz, 50, 50);
        const before = await quiz.host.read(GEO + '.teamguesses.0');
        await quiz.phones[1].tapAt(quiz.phones[1].map, 0.1, 0.1);
        await quiz.rawFrom(1, 'ii1,1,1');
        assert.deepStrictEqual(await quiz.host.read(GEO + '.teamguesses.0'), before);
    });

    scenario('geography: a guess off the map from a phone does not count', async quiz => {
        await geography(quiz, {});
        for(const bad of ['ii1,500,500', 'ii1,-1,50', 'ii1,abc,1', 'ii1,1']) await quiz.rawFrom(1, bad);
        assert.strictEqual((await quiz.host.read(GEO + '.teamguesses'))[0], null);
    }, { todo: 'Only the page clamps the coordinates, so neither the server nor the app checks them' });

    scenario('geography: a new question forgets the last one', async quiz => {
        await geography(quiz, { 1: [0.5, 0.5] });
        await answer(quiz, 50, 50);
        await quiz.host.click('geographyPanel.showWinner:');
        await seen(quiz, 'Team 1');

        await quiz.host.click('geographyPanel.startQuestion:');
        assert.strictEqual(await quiz.host.read(GEO + '.answering'), false);
        assert.strictEqual((await quiz.host.read(GEO + '.teamguesses'))[0], null);
        assert.ok(!(await showing(quiz, 'Team 1 ')), 'the standings are still up');
    });


    //--- Only Connect

    const status = quiz => panel(quiz, 'onlyConnectPanel.statusText');

    async function wall(quiz) {
        await begin(quiz, 'onlyConnect');
        await quiz.host.click('onlyConnectPanel.startButton');
        await until('the words', async () => (await quiz.phones[1].wallTile('apple').count()) === 1);
    }
    async function pick(quiz, n, words) {
        for(const word of words) await quiz.phones[n].wallTile(word).click();
    }

    scenario('only connect: nonsense from a phone costs it nothing', async quiz => {
        await wall(quiz);
        for(const bad of ['cg1,1,1,1,1', 'cg1,0,1,2,3', 'cg1,1,2,3,99', 'cg1,1,2,3', 'cg1,1,2,3,4,5', 'cg1,a,b,c,d', 'cg1']) {
            await quiz.rawFrom(1, bad);
        }
        assert.match(await status(quiz), /Team 1: 0 found, 0 wrong/);
        await quiz.host.click('onlyConnectPanel.startButton');
    });

    scenario('only connect: a group already found cannot be used against a team', async quiz => {
        await wall(quiz);
        await pick(quiz, 1, WALL.fruit);
        await until('one found', async () => /Team 1: 1 found, 0 wrong/.test(await status(quiz)));

        //Its tiles again, whichever way they are mixed
        const position = word => quiz.phones[1].frame.locator('.wallTile').evaluateAll(
            (tiles, w) => tiles.findIndex(t => t.textContent === w) + 1, word);
        const fruit = await Promise.all(WALL.fruit.map(position));
        const colour = await Promise.all(WALL.colour.map(position));
        await quiz.rawFrom(1, 'cg1,' + fruit.join(','));
        await quiz.rawFrom(1, 'cg1,' + [fruit[0], colour[0], colour[1], colour[2]].join(','));
        assert.match(await status(quiz), /Team 1: 1 found, 0 wrong/);
        await quiz.host.click('onlyConnectPanel.startButton');
    });

    scenario('only connect: a team switched off cannot play', async quiz => {
        await wall(quiz);
        await quiz.setPlaying(2, false);
        await pick(quiz, 2, WALL.fruit);
        await pause(300);
        assert.match(await status(quiz), /Team 2: 0 found, 0 wrong/);
        await quiz.setPlaying(2, true);
        await quiz.host.click('onlyConnectPanel.startButton');
    });

    scenario('only connect: the wall ends by itself when every team is done', async quiz => {
        await wall(quiz);
        await quiz.setPlaying(3, false);
        for(const n of [1, 2]) {
            await pick(quiz, n, WALL.fruit);
            await until('one group', async () => (await quiz.phones[n].wallTileCount('wallSolved')) === 4);
            await pick(quiz, n, WALL.colour);
            await until('two groups', async () => (await quiz.phones[n].wallTileCount('wallSolved')) === 8);
            await pick(quiz, n, WALL.metal);
            await until('the wall', async () => (await quiz.phones[n].wallTileCount('wallSolved')) === 16);
        }
        await until('the wall to end', async () => (await quiz.host.read('onlyConnectPanel.startButton')).title === 'Finished');
    });

    scenario('only connect: switching off the last team still playing ends the wall', async quiz => {
        await wall(quiz);
        await quiz.setPlaying(3, false);
        await quiz.setPlaying(2, false);
        await pick(quiz, 1, WALL.fruit);
        await until('one group', async () => (await quiz.phones[1].wallTileCount('wallSolved')) === 4);
        await pick(quiz, 1, WALL.colour);
        await until('two groups', async () => (await quiz.phones[1].wallTileCount('wallSolved')) === 8);

        //Team 1 finishes, then team 2 is back, and is switched off again
        await quiz.setPlaying(2, true);
        await pick(quiz, 1, WALL.metal);
        await until('the wall', async () => (await quiz.phones[1].wallTileCount('wallSolved')) === 16);
        await quiz.setPlaying(2, false);
        await until('the wall to end', async () => (await quiz.host.read('onlyConnectPanel.startButton')).title === 'Finished', 3000);
    }, { todo: 'everyoneFinished is only looked at after a guess' });

    scenario('only connect: a reset takes the wall off every phone', async quiz => {
        await wall(quiz);
        await pick(quiz, 1, WALL.pet);
        await until('one group', async () => (await quiz.phones[1].wallTileCount('wallSolved')) === 4);
        await quiz.host.click('resetRound:');
        await until('the wall to go', async () => (await quiz.phones[1].wallTile('apple').count()) === 0);
        assert.strictEqual(await quiz.phones[1].wallTileCount('wallSolved'), 0);
        await quiz.rawFrom(1, 'cg1,1,2,3,4');
        assert.match(await status(quiz), /Team 1: 0 found, 0 wrong/);
    });

    scenario('only connect: reveal runs out, and cannot be pressed too early', async quiz => {
        await begin(quiz, 'onlyConnect');
        assert.strictEqual((await quiz.host.read('onlyConnectPanel.revealButton')).enabled, false);
        await quiz.host.click('onlyConnectPanel.startButton');
        await until('reveal to be offered', async () => (await quiz.host.read('onlyConnectPanel.revealButton')).enabled);
        for(let i = 0; i < 5; i++) await quiz.host.click('onlyConnectPanel.revealButton');
        assert.strictEqual((await quiz.host.read('onlyConnectPanel.revealButton')).enabled, false);
        await until('the phones to freeze', async () => (await quiz.phones[1].wallTileCount('buttonOff')) === 16);
    });


    //--- Wikirace

    const [START, MIDDLE, FINISH, DETOUR] = WIKI.titles;
    const on = (phone, title) => until('the phone on ' + title, async () => (await phone.articleTitle.textContent()) === title);

    async function race(quiz) {
        await begin(quiz, 'wikirace');
        await quiz.host.click('wikiRacePanel.startButton');
        await on(quiz.phones[1], START);
    }

    scenario('wikirace: a phone cannot walk where the links do not go', async quiz => {
        await race(quiz);
        const mark = quiz.wire.length;
        for(const bad of ['wl1,2', 'wl1,99', 'wl1,-1', 'wl1,abc', 'wl1,', 'wb1']) await quiz.rawFrom(1, bad);
        assert.ok(!quiz.wire.slice(mark).some(w => w.msg.startsWith('wp')), 'a move was reported');
        assert.strictEqual(await quiz.phones[1].articleTitle.textContent(), START);
    });

    scenario('wikirace: a phone cannot move another team', async quiz => {
        await race(quiz);
        const mark = quiz.wire.length;
        await quiz.rawFrom(1, 'wl2,1');
        await quiz.rawFrom(1, 'wb2');
        assert.ok(!quiz.wire.slice(mark).some(w => w.msg.startsWith('wp')), 'a move was reported');
    });

    scenario('wikirace: a team that has arrived can go no further', async quiz => {
        await race(quiz);
        const one = quiz.phones[1];
        await one.link(MIDDLE).click();
        await on(one, MIDDLE);
        await one.link(FINISH).click();
        await until('the arrival', () => quiz.wire.some(w => w.msg.startsWith('ww1,')));

        const mark = quiz.wire.length;
        await quiz.rawFrom(1, 'wl1,0');
        await quiz.rawFrom(1, 'wb1');
        assert.ok(!quiz.wire.slice(mark).some(w => w.msg.startsWith('wp')), 'a move was reported');
    });

    scenario('wikirace: a team switched off is not celebrated', async quiz => {
        await race(quiz);
        await quiz.setPlaying(2, false);
        const ledsBefore = quiz.leds.length;
        const two = quiz.phones[2];
        await two.link(MIDDLE).click();
        await on(two, MIDDLE);
        await two.link(FINISH).click();
        await until('the arrival', () => quiz.wire.some(w => w.msg.startsWith('ww2,')));
        await quiz.host.settled();
        assert.deepStrictEqual(quiz.leds.slice(ledsBefore), [], 'the LEDs reacted');
        await quiz.setPlaying(2, true);
    });

    scenario('wikirace: a new race starts everybody again', async quiz => {
        await race(quiz);
        const one = quiz.phones[1];
        await one.link(MIDDLE).click();
        await on(one, MIDDLE);
        await one.link(FINISH).click();
        await until('the arrival', () => quiz.wire.some(w => w.msg.startsWith('ww1,')));

        await quiz.host.click('wikiRacePanel.startButton');
        await on(one, START);
        assert.strictEqual(await one.frame.locator('#curtain').evaluate(c => c.classList.contains('hidden')), true,
                           'the celebration is still up');
        await one.link(DETOUR).click();
        await on(one, DETOUR);
        assert.strictEqual(await one.hops.textContent(), '1');
        await quiz.host.click('wikiRacePanel.endButton');
    });


    //--- Scores

    const output = quiz => panel(quiz, 'scoresPanel.output');
    async function scores(quiz, text) {
        await begin(quiz, 'scores');
        await quiz.host.set('scoresPanel.scoreText', text);
        await quiz.host.click('scoresPanel.parseAndReset:');
    }

    scenario('scores: a line that is not a score is reported and nothing is shown', async quiz => {
        await scores(quiz, '1,10\nfirst,second\n');
        assert.match(await output(quiz), /Error/);
        await quiz.host.click('scoresPanel.showNext:');
        await pause(300);
        assert.ok(!(await showing(quiz, 'Team 1')));
    });

    scenario('scores: a failed parse does not leave the previous scores ready to reveal', async quiz => {
        await scores(quiz, '1,10\n');
        assert.match(await output(quiz), /Team 1 \(10\)/);

        await quiz.host.set('scoresPanel.scoreText', '1,10\nfirst,second\n');
        await quiz.host.click('scoresPanel.parseAndReset:');
        assert.match(await output(quiz), /Error/);

        await quiz.host.click('scoresPanel.showNext:');
        await pause(300);
        assert.ok(!(await showing(quiz, 'Team 1')));
    });

    scenario('scores: a team that does not exist is refused', async quiz => {
        await scores(quiz, '1,10\n99,20\n');
        assert.match(await output(quiz), /Error/);
        assert.doesNotMatch(await output(quiz), /Team 99/, 'it is in the running order');
    });

    scenario('scores: team nought is refused', async quiz => {
        await scores(quiz, '0,10\n1,20\n');
        assert.match(await output(quiz), /Error/);
        assert.doesNotMatch(await output(quiz), /Team 0/, 'it is in the running order');
    });

    scenario('scores: a team listed twice is refused', async quiz => {
        await scores(quiz, '1,10\n1,20\n2,5\n');
        assert.match(await output(quiz), /Error/);
        const lines = (await output(quiz)).split('\n').filter(l => l.includes('Team 1 '));
        assert.ok(lines.length < 2, await output(quiz));
    });

    scenario('scores: everybody on minus one still comes first', async quiz => {
        await scores(quiz, '1,-1\n2,-1\n');
        assert.strictEqual(await output(quiz), '1: Team 1 (-1)\n1: Team 2 (-1)');
    });

    scenario('scores: a top score of minus one comes first', async quiz => {
        await scores(quiz, '1,-1\n2,-3\n');
        assert.strictEqual(await output(quiz), '2: Team 2 (-3)\n1: Team 1 (-1)');
    });

    scenario('scores: a team marked x, or with no line at all, is left out', async quiz => {
        await scores(quiz, '1,10\n2,x\n\n');
        const text = await output(quiz);
        assert.doesNotMatch(text, /Error|Team 2|Team 3/, text);
        assert.match(text, /Team 1 \(10\)/, text);
    });

    scenario('scores: a line that is not a team and a score or x is refused', async quiz => {
        await begin(quiz, 'scores');
        for(const bad of ['2,', '2', '2,10,5', '2,,10', '2,10 5', 'hello', '2,y']) {
            await quiz.host.set('scoresPanel.scoreText', `1,10\n${bad}\n`);
            await quiz.host.click('scoresPanel.parseAndReset:');
            assert.match(await output(quiz), /Error/, `'${bad}' was accepted`);
        }
    });

    scenario('scores: a team cannot be both marked x and given a score', async quiz => {
        await scores(quiz, '1,x\n1,10\n');
        assert.match(await output(quiz), /Error/);
    });

    scenario('scores: a space or a tab separates a team from its score as well as a comma', async quiz => {
        await scores(quiz, '1 10\n2\t20\n3, 30\n');
        const text = await output(quiz);
        assert.match(text, /Team 1 \(10\)/, text);
        assert.match(text, /Team 2 \(20\)/, text);
        assert.match(text, /Team 3 \(30\)/, text);
    });

    scenario('scores: next, past the end and with nothing typed', async quiz => {
        await begin(quiz, 'scores');
        await quiz.host.click('scoresPanel.showNext:');

        await scores(quiz, '1,10\n');
        for(let i = 0; i < 3; i++) await quiz.host.click('scoresPanel.showNext:');
        await quiz.host.scene();
    });
});
