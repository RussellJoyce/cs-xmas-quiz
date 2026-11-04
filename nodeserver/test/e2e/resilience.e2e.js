'use strict';

//Things going wrong during the show: the server, the app or a phone falling over mid-round.
//This is what the end-to-end rig is really for, as no one component can test it alone.

const assert = require('node:assert');
const { quizScenarios, until } = require('./rig');

const onView = (quiz, n, view) => until('phone ' + n + ' on view ' + view, async () =>
    (await quiz.phones[n].view()) === view);

quizScenarios('when things go wrong', { teams: 3 }, scenario => {

    //--- The node server restarting

    scenario('server restart: phones come back to the round with their teams', async quiz => {
        await quiz.round('text');
        const mark = quiz.wire.length;
        await quiz.restartServer();

        for(const n of [1, 2, 3]) {
            await quiz.phoneBack(n, mark);
            await onView(quiz, n, 'text');
        }
        await quiz.appResynced(mark);

        //And it is all still connected up
        await quiz.phones[1].answerText('still here');
        await until('the host to see the answer', async () =>
            (await quiz.host.read('textPanel.teamGuesses')).value.includes('still here'));
    });

    scenario('server restart: a team that was out stays out', async quiz => {
        await quiz.round('buzzers');
        await quiz.setPlaying(2, false);

        const mark = quiz.wire.length;
        await quiz.restartServer();
        await quiz.phoneBack(2, mark);
        await quiz.appResynced(mark);
        await until('phone 2 to be told it is out', async () => !(await quiz.phones[2].isOn()));

        await quiz.setPlaying(2, true);
    });

    scenario('server restart: a phone slower to return than the app still gets the round', async quiz => {
        await quiz.round('text');
        await quiz.powerPhone(2, false);

        const mark = quiz.wire.length;
        await quiz.restartServer();
        await quiz.appResynced(mark);

        const back = quiz.wire.length;
        await quiz.powerPhone(2, true);
        await quiz.phoneBack(2, back);
        await onView(quiz, 2, 'text');
    });

    scenario('server restart with the picks lost: a phone picks again and lands in the round', async quiz => {
        await quiz.round('text');
        await quiz.page.uncheck('#cfg-autopick');

        const mark = quiz.wire.length;
        await quiz.restartServer({ losePicks: true });
        await quiz.appResynced(mark);

        const one = quiz.phones[1];
        await onView(quiz, 1, 'pickteam');
        await one.teamButton(1).click();
        await onView(quiz, 1, 'text');

        //Leave the others as they were found
        for(const n of [2, 3]) {
            await onView(quiz, n, 'pickteam');
            await quiz.phones[n].teamButton(n).click();
            await onView(quiz, n, 'text');
        }
        await quiz.page.check('#cfg-autopick');
    });


    //--- A phone having trouble

    scenario('dropped connection: the phone comes back with its team, on the round', async quiz => {
        await quiz.round('multichoice');
        const mark = quiz.wire.length;
        quiz.dropPhone(1);
        await quiz.phoneBack(1, mark);
        await onView(quiz, 1, 'multi');
    });

    scenario('dropped connection: a half-typed answer survives', async quiz => {
        await quiz.round('text');
        await quiz.phones[1].textbox.fill('half an ans');

        const mark = quiz.wire.length;
        quiz.dropPhone(1);
        await quiz.phoneBack(1, mark);
        await onView(quiz, 1, 'text');

        //The server sends its state before it answers the 're', and phoneBack has seen that answer
        assert.strictEqual(await quiz.phones[1].textbox.inputValue(), 'half an ans');
    });

    scenario('dropped connection: a map pin survives, until the next question', async quiz => {
        await quiz.round('geography');
        const one = quiz.phones[1];
        await quiz.tapped(1, 'ii', one.map);
        assert.ok(await one.pin.isVisible(), 'the pin goes in');

        const mark = quiz.wire.length;
        quiz.dropPhone(1);
        await quiz.phoneBack(1, mark);
        await onView(quiz, 1, 'geo');
        assert.ok(await one.pin.isVisible(), 'the pin survives the reconnection');

        quiz.asHost('imnext-question.jpg');
        await until('a new image to clear the pin', async () => !(await one.pin.isVisible()));

        //The host restarting a question puts up the same image again, and goes through a reset
        await quiz.tapped(1, 'ii', one.map);
        assert.ok(await one.pin.isVisible(), 'the pin goes back in');
        await quiz.host.click('resetRound:');
        await until('the reset to clear the pin', async () => !(await one.pin.isVisible()));
    });

    scenario('dropped connection: a wavelength guess stays where it was', async quiz => {
        await quiz.round('wavelength');
        const one = quiz.phones[1];
        await one.tapAt(one.waveTrack, 0.75, 0.5);
        const value = await one.waveValue.textContent();

        const mark = quiz.wire.length;
        quiz.dropPhone(1);
        await quiz.phoneBack(1, mark);
        await onView(quiz, 1, 'wavelength');
        assert.strictEqual(await one.waveValue.textContent(), value);
    });

    scenario('dropped connection: a harness client off its phone display follows the round', async quiz => {
        await quiz.round('buzzers');
        await quiz.page.evaluate(() => clients[3].setDisplay(false));
        const held = () => quiz.page.evaluate(() => ({ view: clients[3].view, team: clients[3].team }));
        await until('the virtual client to take over', async () => (await held()).team == 3);

        const mark = quiz.wire.length;
        quiz.dropPhone(3);
        await quiz.host.click('tabitemText');
        await until('the round to change', () => quiz.wire.has('host→srv', 'vitext', mark));
        await quiz.page.evaluate(() => clients[3].connect());

        await until('the virtual client to be told the round', async () => (await held()).view === 'text');
        const back = quiz.wire.length;
        await quiz.page.evaluate(() => clients[3].setDisplay(true));
        await quiz.phoneBack(3, back);
    });

    scenario('reload: same team, same round, and still out if it was out', async quiz => {
        await quiz.round('buzzers');
        await quiz.setPlaying(3, false);

        const mark = quiz.wire.length;
        await quiz.reloadPhone(3);
        await quiz.phoneBack(3, mark);
        await until('phone 3 to still be out', async () => !(await quiz.phones[3].isOn()));

        await quiz.setPlaying(3, true);
    });

    scenario('reload: a phone in a higher/lower round says higher and lower', async quiz => {
        await quiz.round('trueFalse');
        const one = quiz.phones[1];
        await quiz.host.setToggle('trueFalsePanel.modeToggle', false);
        await until('the phone to say HIGHER', async () => (await one.higher.textContent()) === 'HIGHER');

        try {
            const mark = quiz.wire.length;
            await quiz.reloadPhone(1);
            await quiz.phoneBack(1, mark);
            await onView(quiz, 1, 'higherlower');
            await until('the reloaded phone to say HIGHER', async () => (await one.higher.textContent()) === 'HIGHER', 3000);
        } finally {
            await quiz.host.setToggle('trueFalsePanel.modeToggle', true);
        }
    });

    scenario('reload: a multiple choice answer already given is still lit', async quiz => {
        await quiz.round('multichoice');
        await quiz.host.setToggle('multiChoicePanel.sounds', false);
        await quiz.host.click('multiChoicePanel.startButton');
        const one = quiz.phones[1];
        await quiz.tapped(1, 'mc', one.tile(2));
        await until('tile 2 lit', () => one.hasClass(one.tile(2), 'multiSelected'));

        try {
            const mark = quiz.wire.length;
            await quiz.reloadPhone(1);
            await quiz.phoneBack(1, mark);
            await onView(quiz, 1, 'multi');
            await until('tile 2 lit again', () => one.hasClass(one.tile(2), 'multiSelected'), 3000);
        } finally {
            await quiz.host.click('multiChoicePanel.startButton');
        }
    });

    scenario('dropped connection: a multiple choice answer already given is still lit', async quiz => {
        await quiz.round('multichoice');
        await quiz.host.setToggle('multiChoicePanel.sounds', false);
        await quiz.host.click('multiChoicePanel.startButton');
        const one = quiz.phones[1];
        await quiz.tapped(1, 'mc', one.tile(3));
        await until('tile 3 lit', () => one.hasClass(one.tile(3), 'multiSelected'));

        const mark = quiz.wire.length;
        quiz.dropPhone(1);
        await quiz.phoneBack(1, mark);
        await until('tile 3 lit again', () => one.hasClass(one.tile(3), 'multiSelected'), 3000);

        await quiz.host.click('multiChoicePanel.startButton');
    });

    scenario('reload: the next question does not bring back the last answer', async quiz => {
        await quiz.round('multichoice');
        await quiz.host.setToggle('multiChoicePanel.sounds', false);
        await quiz.host.click('multiChoicePanel.startButton');
        const one = quiz.phones[1];
        await quiz.tapped(1, 'mc', one.tile(2));
        await until('tile 2 lit', () => one.hasClass(one.tile(2), 'multiSelected'));
        await quiz.host.click('multiChoicePanel.startButton'); //Stop
        await quiz.host.click('multiChoicePanel.startButton'); //The next question
        await quiz.host.settled();

        const mark = quiz.wire.length;
        await quiz.reloadPhone(1);
        await quiz.phoneBack(1, mark);
        await onView(quiz, 1, 'multi');
        assert.ok(!(await one.hasClass(one.tile(2), 'multiSelected')), 'the old tile is out');

        await quiz.host.click('multiChoicePanel.startButton');
    });

    scenario('reload after a server restart: the phone still says higher and lower', async quiz => {
        await quiz.round('trueFalse');
        const one = quiz.phones[1];
        await quiz.host.setToggle('trueFalsePanel.modeToggle', false);
        await until('the phone to say HIGHER', async () => (await one.higher.textContent()) === 'HIGHER');

        try {
            const restart = quiz.wire.length;
            await quiz.restartServer();
            await quiz.phoneBack(1, restart);
            await quiz.appResynced(restart);

            const mark = quiz.wire.length;
            await quiz.reloadPhone(1);
            await quiz.phoneBack(1, mark);
            await until('the reloaded phone to say HIGHER', async () => (await one.higher.textContent()) === 'HIGHER', 3000);
        } finally {
            await quiz.host.setToggle('trueFalsePanel.modeToggle', true);
        }
    });

    scenario("the host's Resync All puts a reloaded phone right", async quiz => {
        await quiz.round('trueFalse');
        const one = quiz.phones[1];
        await quiz.host.setToggle('trueFalsePanel.modeToggle', false);
        await until('the phone to say HIGHER', async () => (await one.higher.textContent()) === 'HIGHER');

        const mark = quiz.wire.length;
        await quiz.reloadPhone(1);
        await quiz.phoneBack(1, mark);

        await quiz.host.click('tabitemDisconnect');
        await quiz.host.setToggle('resyncModeBtn', true);
        await quiz.host.click('disconnectAllButton');
        await until('the phone to say HIGHER again', async () => (await one.higher.textContent()) === 'HIGHER');

        await quiz.host.setToggle('resyncModeBtn', false);
        await quiz.host.click('tabitemtruefalse');
        await quiz.host.setToggle('trueFalsePanel.modeToggle', true);
    });


    //--- The host doing it on purpose

    scenario('disconnect all: every phone returns to the picker, and a team can only be held once', async quiz => {
        await quiz.round('buzzers');
        //The box is only read as a phone connects, so its say on these has already been had
        await quiz.page.uncheck('#cfg-autopick');
        await quiz.page.evaluate(() => clients.forEach(c => { if(c) c.autopickPending = false; }));
        await quiz.host.click('tabitemDisconnect');

        await quiz.host.click('disconnectAllButton');
        assert.strictEqual((await quiz.host.read('disconnectAllButton')).title, 'Sure?');
        await quiz.host.click('disconnectAllButton');

        for(const n of [1, 2, 3]) await onView(quiz, n, 'pickteam');

        const [, one, two, three] = quiz.phones;
        await one.teamButton(1).click();
        await onView(quiz, 1, 'buzzer');
        await two.teamButton(1).click();
        await until('phone 2 to be refused', async () =>
            (await two.frame.locator('#teamtitle').textContent()).includes('already taken'));
        assert.strictEqual(await two.view(), 'pickteam');

        await two.teamButton(2).click();
        await three.teamButton(3).click();
        await onView(quiz, 2, 'buzzer');
        await onView(quiz, 3, 'buzzer');

        await quiz.page.check('#cfg-autopick');
        await quiz.host.click('tabitemBuzzers');
    });


    //--- The app crashing

    scenario('app restart: phones follow it back to the start, and buzzing works', async quiz => {
        await quiz.round('text');
        const mark = quiz.wire.length;
        await quiz.restartApp();
        await quiz.appResynced(mark);

        for(const n of [1, 2, 3]) await onView(quiz, n, 'buzzer');

        await quiz.round('buzzers');
        await quiz.host.setToggle('buzzerSounds', false);
        await quiz.tapped(2, 'zz', quiz.phones[2].buzzer);
        assert.deepStrictEqual(await quiz.host.read('quizDisplay.buzzerScene.buzzes'), [1]);
    });
});
