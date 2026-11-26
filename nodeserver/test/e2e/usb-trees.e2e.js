'use strict';

//The desk trees on USB serial, driven by the app directly (TreeLink.swift). treesim stands in
//for three trees, each with a pty for its USB port; their websockets go nowhere, so every
//command they get came over USB.

const assert = require('node:assert');
const { quizScenarios, until } = require('./rig');

const IDS = ['510001', '510002', '510003'];

quizScenarios('desk trees on USB', { teams: 3, usbTrees: 3 }, scenario => {

    const claimed = quiz => quiz.host.read('socket.trees.claimed');
    const last = (list, prefix) => list.filter(c => c.startsWith(prefix)).pop();

    scenario('the app claims every tree and tells each its place', async quiz => {
        await until('all three claimed', async () =>
            JSON.stringify(await claimed(quiz)) === JSON.stringify(IDS));
        for(let n = 0; n < 3; n++) {
            await until('tree ' + n + ' told it is ' + n + ' of 3', () =>
                last(quiz.usb.received(n), 'i') === 'i' + String(n).padStart(2, '0') + '03');
            const got = quiz.usb.received(n);
            assert.ok(got.includes('h'), 'tree ' + n + ' was sent the hello');
            //The state a newly claimed tree needs: an animation, the team count, a brightness
            assert.ok(got.some(c => /^a\d\d$/.test(c)), 'tree ' + n + ' was given an animation: ' + got);
            assert.ok(got.includes('n03'), 'tree ' + n + ' was given the team count: ' + got);
            assert.ok(got.some(c => /^g\d{3}$/.test(c)), 'tree ' + n + ' was given a brightness: ' + got);
        }
        //A claimed tree has turned its WiFi off
        const said = n => quiz.usb.log.filter(e => e.tree === n).map(e => e.line);
        for(let n = 0; n < 3; n++) assert.ok(said(n).includes('Serial host'), 'tree ' + n + ' left WiFi');
    });

    scenario('tree commands reach the trees with the node server down', async quiz => {
        await until('all three claimed', async () => (await claimed(quiz)).length === 3);
        await quiz.round('idleSnow');
        await quiz.host.click('tabitemQuizAdmin');
        await quiz.withoutServer(async () => {
            const since = quiz.usb.log.length;
            await quiz.host.click('quizAdminPanel.treeAnimationChosen:#3');
            await quiz.host.set('quizAdminPanel.treeBrightnessSlider', 40);
            for(let n = 0; n < 3; n++) {
                await until('candle on tree ' + n, () => quiz.usb.received(n, since).includes('a03'));
                await until('brightness 40 on tree ' + n, () => quiz.usb.received(n, since).includes('g040'));
            }
        });
    });

    scenario('a tree that restarts is given its place and the state again', async quiz => {
        await until('all three claimed', async () => (await claimed(quiz)).length === 3);
        await quiz.round('idleSnow');
        await quiz.host.click('tabitemQuizAdmin');
        await quiz.host.set('quizAdminPanel.treeBrightnessSlider', 60);
        await until('brightness 60 on tree 1', () => quiz.usb.received(1).includes('g060'));

        const since = quiz.usb.log.length;
        await quiz.usb.restart(1);
        //The next hello finds it, as its first answer since starting says "Serial host"
        await until('tree 1 claimed again', () =>
            quiz.usb.log.slice(since).some(e => e.tree === 1 && e.line === 'Serial host'));
        await until('tree 1 given its place again', () => quiz.usb.received(1, since).includes('i0103'));
        await until('tree 1 given the brightness again', () => quiz.usb.received(1, since).includes('g060'));
        assert.ok(quiz.usb.received(1, since).includes('n03'), 'and the team count');
        assert.deepStrictEqual(await claimed(quiz), IDS, 'still three trees, not four');
    });

    scenario('a buzz reaches every tree', async quiz => {
        await until('all three claimed', async () => (await claimed(quiz)).length === 3);
        await quiz.round('buzzers');
        const since = quiz.usb.log.length;
        await quiz.tapped(2, 'zz', quiz.phones[2].buzzer);
        for(let n = 0; n < 3; n++) {
            await until('team 2 buzz on tree ' + n, () => quiz.usb.received(n, since).includes('b01'));
        }
    });
});
