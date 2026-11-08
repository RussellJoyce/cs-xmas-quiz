'use strict';

//Every round with all fourteen teams, as on the night. The other files use three or so, which
//says nothing about the fourteenth box on the screen, two-digit team numbers on the wire, or
//team 1 being confused with team 11. Each team gives an answer of its own, so that a mix-up
//between teams shows.

const assert = require('node:assert');
const { quizScenarios, until } = require('./rig');
const { WALL, WIKI } = require('./fixtures');

const TEAMS = 14;
const ALL = Array.from({ length: TEAMS }, (_, i) => i + 1);

const panel = async (quiz, path) => (await quiz.host.read(path)).value;
const text = async quiz => (await quiz.host.visibleText()).join('\n');
const seen = (quiz, what) => until('"' + what + '" on screen', async () =>
    (await quiz.host.visibleText()).includes(what));
const seenAll = (quiz, what, list) => until(what + ' on screen', async () => {
    const shown = await quiz.host.visibleText();
    return list.every(t => shown.includes(t));
});

//Nothing the audience should see has been pushed off the edge
async function fits(quiz, when) {
    assert.deepStrictEqual(await quiz.host.offScreen(), [], 'off the screen ' + when);
}

async function begin(quiz, round) {
    await quiz.allPlaying();
    await quiz.round(round);
}

quizScenarios('fourteen teams', { teams: TEAMS }, scenario => {

    //--- Buzzers

    scenario('buzzers: two-digit teams queue in order, and reach the screen and the LEDs', async quiz => {
        await begin(quiz, 'buzzers');
        await quiz.host.setToggle('buzzerSounds', false);
        await quiz.host.setToggle('buzzerQueueMode', true);

        const before = quiz.leds.length;
        for(const n of [14, 1, 11, 10, 13]) await quiz.tapped(n, 'zz', quiz.phones[n].buzzer);
        assert.deepStrictEqual(await quiz.host.read('quizDisplay.buzzerScene.buzzes'), [13, 0, 10, 9, 12]);
        await until('the LED buzz for team 14', () => quiz.leds.slice(before).includes('b13'));
        await seenAll(quiz, 'the five teams', ['Team 14', 'Team 1', 'Team 11', 'Team 10', 'Team 13']);
        await fits(quiz, 'with five queued');

        await quiz.host.click('buzzerPanel.nextTeam:');
        await until('the LEDs to move on to team 1', () => quiz.leds.slice(before).includes('t00'));

        await quiz.host.click('resetRound:');
        await quiz.host.setToggle('buzzerQueueMode', false);
    });

    scenario('buzzers: knocking out team 14 greys its phone alone', async quiz => {
        await begin(quiz, 'buzzers');
        await quiz.setPlaying(14, false);
        for(const n of ALL.slice(0, 13)) assert.ok(await quiz.phones[n].isOn(), 'phone ' + n + ' is unaffected');

        await quiz.tapped(14, 'zz', quiz.phones[14].buzzer);
        assert.deepStrictEqual(await quiz.host.read('quizDisplay.buzzerScene.buzzes'), []);

        await quiz.setPlaying(14, true);
        await quiz.tapped(14, 'zz', quiz.phones[14].buzzer);
        assert.deepStrictEqual(await quiz.host.read('quizDisplay.buzzerScene.buzzes'), [13]);
        await quiz.host.click('resetRound:');
    });


    //--- Music

    scenario('music: in buzzcocks mode every team queues, and all fourteen fit', async quiz => {
        await begin(quiz, 'music');
        await quiz.host.setToggle('buzzcocksMode', true);
        await quiz.host.click('musicPanel.playPause:');
        await until('the track to play', async () => (await panel(quiz, 'musicPanel.trackStatus')).includes('▶ Playing'));

        const order = [...ALL].reverse();
        for(const n of order) await quiz.tapped(n, 'zz', quiz.phones[n].buzzer);
        assert.deepStrictEqual(await quiz.host.read('quizDisplay.musicScene.buzzes'), order.map(n => n - 1));

        await until('every team on screen', async () => {
            const shown = await text(quiz);
            return ALL.every(n => new RegExp('Team ' + n + ' \\(').test(shown));
        });
        await fits(quiz, 'with fourteen queued');

        await quiz.host.click('musicPanel.stop:');
        await quiz.host.setToggle('buzzcocksMode', false);
    });


    //--- Text

    scenario('text: every team answers, and every answer is revealed', async quiz => {
        await begin(quiz, 'text');
        await fits(quiz, 'with the team boxes up');
        for(const n of ALL) await quiz.phones[n].answerText('city ' + n);

        await until('the host to see all fourteen', async () => {
            const guesses = await panel(quiz, 'textPanel.teamGuesses');
            return ALL.every(n => guesses.includes('Team ' + n + ': city ' + n));
        });
        assert.ok(!(await text(quiz)).includes('city'), 'still hidden');

        await quiz.host.click('textPanel.showGuesses:');
        await seenAll(quiz, 'every answer', ALL.map(n => 'city ' + n));
        await fits(quiz, 'with the answers up');
    });


    //--- True or false

    scenario('true/false: fourteen answers, revealed and marked', async quiz => {
        await begin(quiz, 'trueFalse');
        await quiz.host.setToggle('trueFalsePanel.soundsToggle', false);
        await quiz.host.setToggle('trueFalsePanel.modeToggle', true);
        await fits(quiz, 'with the team boxes up');

        //Odd teams say true, even teams false, and team 14 says nothing
        const answering = ALL.slice(0, 13);
        await quiz.host.click('trueFalsePanel.startWithoutTimer:');
        for(const n of answering) {
            const phone = quiz.phones[n];
            await quiz.tapped(n, n % 2 ? 'hi' : 'lo', n % 2 ? phone.higher : phone.lower);
        }
        await quiz.host.click('trueFalsePanel.startWithoutTimer:');

        await seenAll(quiz, 'every answer', [
            ...answering.map(n => 'Team ' + n + ': ' + (n % 2 ? 'TRUE' : 'FALSE')),
            'Team 14 no guess'
        ]);
        await fits(quiz, 'with the answers up');

        await quiz.host.click('trueFalsePanel.answerTrue:');
        assert.deepStrictEqual(await quiz.host.read('quizDisplay.truefalseScene.teamEnabled'),
                               ALL.map(n => n % 2 === 1 && n !== 14));
    });


    //--- Multiple choice

    scenario('multiple choice: fourteen answers, revealed', async quiz => {
        await begin(quiz, 'multichoice');
        await quiz.host.setToggle('multiChoicePanel.sounds', false);
        await quiz.host.set('multiChoicePanel.optionsStepper', 4);
        await fits(quiz, 'with the team boxes up');

        const tile = n => ((n - 1) % 4) + 1;
        const letter = n => 'ABCD'[tile(n) - 1];
        await quiz.host.click('multiChoicePanel.startButton');
        for(const n of ALL) await quiz.tapped(n, 'mc', quiz.phones[n].tile(tile(n)));

        assert.strictEqual(await panel(quiz, 'multiChoicePanel.teamGuesses'),
                           ALL.map(n => 'Team ' + n + ': ' + letter(n)).join('\n'));
        await until('team 14 lit', () => quiz.phones[14].hasClass(quiz.phones[14].tile(tile(14)), 'multiSelected'));

        await quiz.host.click('multiChoicePanel.answer2');
        await seenAll(quiz, 'every answer', ALL.map(n => n + ': ' + letter(n)));
        await fits(quiz, 'with the answers up');
    });


    //--- Numbers

    scenario('numbers: fourteen guesses ranked and shown', async quiz => {
        await begin(quiz, 'numbers');
        await quiz.host.set('numbersPanel.actualAnswer', '100');
        await fits(quiz, 'with the team boxes up');

        //Team n guesses 10n, so team 10 is spot on and team 1 furthest off
        for(const n of ALL) await quiz.phones[n].answerText(String(n * 10));
        await until('the ranking on the host', async () => {
            const guesses = await panel(quiz, 'numbersPanel.teamGuesses');
            return ALL.every(n => new RegExp('Team ' + n + ': ' + n * 10 + ' +\\(off by ' + Math.abs(n * 10 - 100) + '\\)').test(guesses));
        });

        await quiz.host.click('numbersPanel.showAnswers:');
        await seenAll(quiz, 'every guess', ALL.map(n => String(n * 10)));
        await fits(quiz, 'with the guesses up');
        await quiz.host.click('numbersPanel.showAnswers:');
        await until('the round to be scored', () => quiz.host.read('quizDisplay.numbersScene.scored'));
        await fits(quiz, 'once scored');
    });


    //--- Pointless

    scenario('pointless: fourteen answers scored, and all fourteen bars fit', async quiz => {
        await begin(quiz, 'pointless');
        await fits(quiz, 'with the team boxes up');

        const words = ['apple', 'kiwi', 'quince', 'banana'];
        const word = n => words[(n - 1) % words.length];
        for(const n of ALL) await quiz.phones[n].answerText(word(n));
        await until('all fourteen to be in', async () =>
            (await quiz.host.read('quizDisplay.pointlessScene.teamGuesses')).every(g => g !== null));

        const scores = { apple: 40, kiwi: 3, quince: 0, banana: null };
        assert.deepStrictEqual(await quiz.host.read('quizDisplay.pointlessScene.teamScores'),
                               ALL.map(n => scores[word(n)]));

        await quiz.host.click('pointlessPanel.showAnswers:');
        await seen(quiz, 'banana');
        await fits(quiz, 'with the answers up');
        await quiz.host.click('pointlessPanel.runScoring:');
        assert.strictEqual(await quiz.host.read('quizDisplay.pointlessScene.lowestScoreThisRound'), 0);
        await fits(quiz, 'once scored');
    });


    //--- Wavelength

    scenario('wavelength: fourteen guesses scored, closest first', async quiz => {
        await begin(quiz, 'wavelength');
        const shown = [];
        for(const n of ALL) {
            const phone = quiz.phones[n];
            await phone.tapAt(phone.waveTrack, n / (TEAMS + 1), 0.5);
            shown.push(Number(await phone.waveValue.textContent()));
        }
        await until('the host to have all fourteen', async () =>
            (await quiz.host.read('quizDisplay.wavelengthScene.teamGuesses')).every((g, i) => g === shown[i]));

        await quiz.host.click('wavelengthPanel.rollButton');
        await quiz.host.click('wavelengthPanel.rollButton');
        const target = Number(await panel(quiz, 'wavelengthPanel.number'));
        await quiz.host.click('wavelengthPanel.reveal:');
        await fits(quiz, 'with the guesses up');

        await quiz.host.click('wavelengthPanel.score:');
        const placings = await until('the placings', async () => {
            await quiz.host.click('wavelengthPanel.score:');
            const t = await panel(quiz, 'wavelengthPanel.teamGuesses');
            return t.includes('out by') ? t : false;
        }, 15000);
        const outBy = [...placings.matchAll(/out by (\d+)/g)].map(m => Number(m[1]));
        assert.strictEqual(outBy.length, TEAMS, placings);
        assert.deepStrictEqual(outBy, shown.map(v => Math.abs(v - target)).sort((a, b) => a - b), placings);
        await fits(quiz, 'once scored');
    });


    //--- Geography

    scenario('geography: fourteen pins, and the standings list every team down to the winner', async quiz => {
        await begin(quiz, 'geography');
        await quiz.host.set('geographyPanel.questionSelector', 'geo1.jpg');
        await quiz.host.click('geographyPanel.startQuestion:');
        await until('phone 14 to show the image', async () =>
            (await quiz.phones[14].map.evaluate(el => el.style.backgroundImage)).includes('geo1.jpg'));

        //Spread along the middle: team n at n/15 across, so with the answer at 52% team 8 is closest
        for(const n of ALL) await quiz.phones[n].tapAt(quiz.phones[n].map, n / (TEAMS + 1), 0.5);
        await until('all fourteen guesses', async () =>
            (await quiz.host.read('quizDisplay.geographyScene.teamguesses')).every(g => g !== null));

        await quiz.host.set('geographyPanel.answerX', '52');
        await quiz.host.set('geographyPanel.answerY', '50');
        await quiz.host.click('geographyPanel.showWinner:');
        await seen(quiz, 'The answer is...');
        for(let i = 0; i < TEAMS; i++) await quiz.host.click('geographyPanel.showWinner:');

        const standings = await until('the winner in the standings', async () => {
            const t = await text(quiz);
            return /Team 8 ⭐️/.test(t) ? t : false;
        }, 5000);
        for(const n of ALL) assert.match(standings, new RegExp(': Team ' + n + '\\b'), 'team ' + n + ' is placed');

        //The label holds all fourteen lines, but has to be tall enough to show them
        const label = await findLabel(quiz, /Team 8 ⭐️/);
        const lines = label.text.split('\n').filter(Boolean).length;
        assert.strictEqual(lines, TEAMS);
        //At 55pt a line is well over 50 high, so anything less has been cut short
        assert.ok(label.frame.height >= lines * 50,
                  'the standings are ' + Math.round(label.frame.height) + ' high for ' + lines + ' lines');
        await fits(quiz, 'with the standings up');
    });


    //--- Only connect

    scenario('only connect: every team plays its own wall, and the host sees all fourteen', async quiz => {
        await begin(quiz, 'onlyConnect');
        await quiz.host.click('onlyConnectPanel.startButton');
        for(const n of ALL) {
            await until('phone ' + n + ' to have the words', async () => (await quiz.phones[n].wallTile('apple').count()) === 1);
        }
        await fits(quiz, 'with the walls up');

        for(const n of ALL) {
            for(const word of WALL.fruit) await quiz.phones[n].press(quiz.phones[n].wallTile(word));
        }
        await until('the host to see fourteen teams with a group each', async () => {
            const status = await panel(quiz, 'onlyConnectPanel.statusText');
            return ALL.every(n => new RegExp('Team ' + n + ': 1 found').test(status));
        });

        //Team 14 finishes
        const fourteen = quiz.phones[14];
        for(const group of [WALL.colour, WALL.metal]) {
            for(const word of group) await fourteen.press(fourteen.wallTile(word));
        }
        await until('the whole wall solved on phone 14', async () => (await fourteen.wallTileCount('wallSolved')) === 16);
        assert.match(await panel(quiz, 'onlyConnectPanel.statusText'), /Team 14: 4 found, 0 wrong, .*\(1st\)/);
        assert.strictEqual(await quiz.phones[13].wallTileCount('wallSolved'), 4, 'only for that team');
        await fits(quiz, 'with a team finished');

        await quiz.host.click('onlyConnectPanel.startButton');
    });


    //--- Wikirace

    scenario('wikirace: fourteen teams race, and all fourteen are in the standings', async quiz => {
        const [START, MIDDLE, FINISH] = WIKI.titles;
        const onArticle = (n, title) => until('phone ' + n + ' on ' + title, async () =>
            (await quiz.phones[n].articleTitle.textContent()) === title);

        await begin(quiz, 'wikirace');
        await quiz.host.setToggle('wikiRacePanel.showDistances', false);
        await quiz.host.click('wikiRacePanel.startButton');
        for(const n of ALL) await onArticle(n, START);
        await fits(quiz, 'at the start');

        //Teams 10 to 14 get halfway, and 14 gets home
        for(const n of [10, 11, 12, 13, 14]) {
            await quiz.phones[n].press(quiz.phones[n].link(MIDDLE));
            await onArticle(n, MIDDLE);
        }
        await quiz.phones[14].press(quiz.phones[14].link(FINISH));
        await onArticle(14, FINISH);
        await until('the arrival', () => quiz.wire.some(w => w.msg.startsWith('ww14,2,')));

        await quiz.host.click('wikiRacePanel.endButton');
        await until('the standings for every team', () =>
            ALL.every(n => quiz.wire.some(w => w.dir === 'srv→servers' && w.msg.startsWith('wd' + n + ','))));
        assert.ok(quiz.wire.some(w => w.msg.startsWith('wd14,1,')), 'team 14 came first');
        await quiz.host.settled();
        assert.strictEqual((await quiz.host.read('quizDisplay.wikiRaceScene.raceStandings')).length, TEAMS);

        await quiz.host.click('wikiRacePanel.revealButton');

        //The boxes move into the standings: team 14 home, then 10 to 13 one away in the order
        //they got there, then the nine who never left the start
        assert.deepStrictEqual((await quiz.host.read('quizDisplay.wikiRaceScene.revealedOrder')).map(t => t + 1),
                               [14, 10, 11, 12, 13, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
        //Seven to a column, first at the top of the left one. Each box is found by its label,
        //which now names the team in words, as a bare number would read as a place.
        const where = async () => {
            const at = {};
            const walk = node => {
                const m = /^Team ([0-9]+)$/.exec(node.text || '');
                if(m && node.frame) at[m[1]] = { x: node.frame.x, y: node.frame.y };
                (node.children || []).forEach(walk);
            };
            walk((await quiz.host.scene()).nodes);
            return at;
        };
        await until('the boxes in standings order', async () => {
            const at = await where();
            const left = [14, 10, 11, 12, 13, 1, 2], right = [3, 4, 5, 6, 7, 8, 9];
            const column = list => list.every((t, i) => i === 0 || at[list[i - 1]].y > at[t].y);
            return [...left, ...right].every(t => at[t]) && column(left) && column(right) &&
                   left.every(t => right.every(u => at[t].x < at[u].x));
        });
        await fits(quiz, 'with the standings up');
        await quiz.round('buzzers');
    });


    //--- Scores

    scenario('scores: fourteen teams typed in and revealed', async quiz => {
        await begin(quiz, 'scores');
        await quiz.host.click('scoresPanel.initText:');
        assert.strictEqual((await quiz.host.read('scoresPanel.scoreText')).value, ALL.map(n => n + ',x\n').join(''));

        //Team n scores 2n, so team 14 wins and is revealed last
        await quiz.host.set('scoresPanel.scoreText', ALL.map(n => n + ',' + 2 * n + '\n').join(''));
        await quiz.host.click('scoresPanel.parseAndReset:');
        assert.strictEqual((await quiz.host.read('scoresPanel.output')).value,
                           ALL.map(n => (TEAMS + 1 - n) + ': Team ' + n + ' (' + 2 * n + ')').join('\n'));

        const before = quiz.leds.length;
        for(let i = 0; i < TEAMS; i++) await quiz.host.click('scoresPanel.showNext:');
        await until('team 14 on the LEDs', () => quiz.leds.slice(before).includes('b13'));
        //Each score comes in at the top and pushes the rest down, so the early ones are
        //meant to leave by the bottom. The last five, ending with the winner, must still show.
        const lastFive = [10, 11, 12, 13, 14];
        await until('the last five on screen', async () => {
            const shown = await text(quiz);
            return lastFive.every(n => new RegExp('Team ' + n + ': ').test(shown));
        }, 5000);
        const off = await quiz.host.offScreen();
        const where = line => line.match(/@ (-?\d+),(-?\d+)/).slice(1).map(Number);
        assert.deepStrictEqual(off.filter(line => lastFive.some(n => line.includes('Team ' + n + ':'))), [],
                               'one of the last five is off the screen');
        assert.deepStrictEqual(off.filter(line => where(line)[1] >= 0), [], 'off the screen other than by the bottom');
    });
});

//The first visible label whose text matches
async function findLabel(quiz, pattern) {
    const scene = await quiz.host.scene();
    let found = null;
    const walk = node => {
        if(found || node.hidden || node.alpha <= 0.01) return;
        if(node.text && pattern.test(node.text)) found = node;
        (node.children || []).forEach(walk);
    };
    walk(scene.nodes);
    assert.ok(found, 'no label matching ' + pattern);
    return found;
}
