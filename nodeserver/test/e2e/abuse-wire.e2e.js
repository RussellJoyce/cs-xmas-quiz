'use strict';

//Messages for a round that is not the one on show, and a server and an app that disagree
//about how many teams there are. The first happens to a phone that has fallen behind, and
//the second to a host who starts the quiz with fewer teams than config.json.

const assert = require('node:assert');
const { quizScenarios, until } = require('./rig');

//One of everything a phone can send, as team `n`
const EVERYTHING = n => ['zz' + n, 'hi' + n, 'lo' + n, 'tt' + n + ',words', 'tt' + n + ',42', 'wv' + n + ',50',
                         'mc' + n + ',1', 'cg' + n + ',1,2,3,4', 'cr' + n, 'ii' + n + ',50,50'];

quizScenarios('messages for the wrong round', { teams: 3 }, scenario => {

    scenario('nothing a phone sends disturbs a round it is not in', async quiz => {
        await quiz.allPlaying();
        await quiz.round('scores');

        const leds = quiz.leds.length;
        const mark = quiz.wire.length;
        for(const message of EVERYTHING(1)) await quiz.rawFrom(1, message);

        assert.deepStrictEqual(quiz.leds.slice(leds).filter(m => !m.startsWith('n')), [], 'the LEDs reacted');
        const replies = quiz.wire.slice(mark).filter(w => w.dir === 'host→srv' && /^(to|ms|hh|hl)/.test(w.msg));
        assert.deepStrictEqual(replies.map(w => w.msg), [], 'a phone was told something');
    });

    scenario('leaving true/false during a question closes it', async quiz => {
        await quiz.allPlaying();
        await quiz.round('trueFalse');
        await quiz.host.setToggle('trueFalsePanel.soundsToggle', false);
        await quiz.host.click('trueFalsePanel.startWithoutTimer:');
        await quiz.round('buzzers');

        const mark = quiz.wire.length;
        await quiz.rawFrom(1, 'hi1');
        assert.ok(!quiz.wire.has('host→srv', 'hh1', mark), 'an answer was accepted from another round');
    });

    scenario('leaving multiple choice during a question closes it', async quiz => {
        await quiz.allPlaying();
        await quiz.round('multichoice');
        await quiz.host.setToggle('multiChoicePanel.sounds', false);
        await quiz.host.click('multiChoicePanel.startButton');
        await quiz.round('buzzers');

        const mark = quiz.wire.length;
        await quiz.rawFrom(1, 'mc1,1');
        assert.ok(!quiz.wire.slice(mark).some(w => w.msg.startsWith('ms')), 'an answer was accepted from another round');
    });

    scenario('a text answer goes nowhere outside the text rounds', async quiz => {
        await quiz.allPlaying();
        await quiz.round('text');
        await quiz.round('buzzers');
        await quiz.rawFrom(1, 'tt1,stray');
        await quiz.round('text');
        assert.strictEqual((await quiz.host.read('textPanel.teamGuesses')).value, '');
    });

    scenario('a phone cannot answer as another team', async quiz => {
        await quiz.allPlaying();
        await quiz.round('buzzers');
        await quiz.rawFrom(1, 'zz2');
        assert.deepStrictEqual(await quiz.host.read('quizDisplay.buzzerScene.buzzes'), []);
    });

    scenario('a message of nothing but noise does no harm', async quiz => {
        for(const noise of ['z', '', 'zz', 'zz0', 'zz-1', 'zz1.5', 'qq', '\u0000\u0000', '🎄🎄', 'zz1,'.repeat(100)]) {
            await quiz.phones[1].frame.locator('body').evaluate((_, m) => ws.send(m), noise);
        }
        await quiz.host.settled();
        await quiz.host.scene();
    });
});


//The server has five teams, and the app only three: phones 4 and 5 are real, and unknown to it
quizScenarios('more teams on the server than in the app', { teams: 5, appTeams: 3 }, scenario => {

    for(const round of ['buzzers', 'trueFalse', 'multichoice', 'text', 'numbers', 'pointless',
                        'wavelength', 'geography', 'onlyConnect']) {
        scenario(round + ': a team the app does not know about does no harm', async quiz => {
            await quiz.allPlaying();
            await quiz.round(round);
            for(const message of EVERYTHING(5)) await quiz.rawFrom(5, message);
            await quiz.host.scene();
        });
    }

    scenario('wikirace: the standings for teams the app does not know about', async quiz => {
        await quiz.allPlaying();
        await quiz.round('wikirace');
        await quiz.host.click('wikiRacePanel.startButton');
        await until('phone 5 on the race', async () => (await quiz.phones[5].articleTitle.textContent()) === 'Start Line');
        await quiz.phones[5].press(quiz.phones[5].link('Middle Ground'));
        await until('the move', () => quiz.wire.some(w => w.msg.startsWith('wp5,')));
        await quiz.host.click('wikiRacePanel.endButton');
        await until('the standings', () => quiz.wire.some(w => w.msg.startsWith('wd5,')));
        await quiz.host.settled();
        await quiz.host.scene();
    });

    scenario('the host resync goes no further than the teams it has', async quiz => {
        await quiz.allPlaying();
        await quiz.round('buzzers');
        await quiz.host.click('tabitemDisconnect');
        await quiz.host.setToggle('resyncModeBtn', true);
        const mark = quiz.wire.length;
        await quiz.host.click('disconnectAllButton');
        await quiz.host.setToggle('resyncModeBtn', false);
        await quiz.host.click('tabitemBuzzers');
        assert.ok(quiz.wire.slice(mark).some(w => w.msg.startsWith('to3,')));
        assert.ok(!quiz.wire.slice(mark).some(w => w.msg.startsWith('to4,')));
    });
});
