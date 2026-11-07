'use strict';

//The music and video round: one list of tracks, and Play, Pause and Stop acting on whichever
//is loaded. A buzz has to stop the right thing, whatever was loaded before.

const assert = require('node:assert');
const { quizScenarios, until } = require('./rig');

const buzzes = quiz => quiz.host.read('quizDisplay.musicScene.buzzes');
const buzz = (quiz, team) => quiz.tapped(team, 'zz', quiz.phones[team].buzzer);
const status = async quiz => (await quiz.host.read('musicPanel.trackStatus')).value;
const loaded = async quiz => (await quiz.host.read('quizDisplay.musicScene.track')).replace(/\(.*/s, '');
const buttonSays = (quiz, title) =>
    until('the button to say ' + title, async () => (await quiz.host.read('musicPanel.playPauseButton')).title === title);
const statusShows = (quiz, text) =>
    until('the status to say ' + text, async () => (await status(quiz)).includes(text));

//Any video node in the scene, however deep
const videoOnScreen = async quiz => {
    const find = node => node.type === 'SKVideoNode' || (node.children || []).some(find);
    return find((await quiz.host.scene()).nodes);
};

quizScenarios('music', {
    teams: 3,
    setUp: async quiz => {
        await quiz.round('music');
    }
}, scenario => {

    scenario('the first track is loaded and ready, with only its own options live', async quiz => {
        assert.strictEqual((await quiz.host.read('musicPanel.trackList')).title, '1-song.wav');
        assert.strictEqual(await loaded(quiz), 'audio');
        await statusShows(quiz, '■ At start · audio');
        assert.strictEqual((await quiz.host.read('buzzcocksMode')).enabled, true);
        assert.strictEqual((await quiz.host.read('blankVideo')).enabled, false);
        assert.strictEqual(await videoOnScreen(quiz), false);
    });

    scenario('nobody can buzz until the host presses Play', async quiz => {
        await buzz(quiz, 1);
        assert.deepStrictEqual(await buzzes(quiz), []);
    });

    scenario('the one button pauses and resumes', async quiz => {
        await quiz.host.click('musicPanel.playPause:');
        await statusShows(quiz, '▶ Playing');
        await buttonSays(quiz, 'Pause');
        await quiz.host.click('musicPanel.playPause:');
        await statusShows(quiz, '❚❚ Paused');
        await buttonSays(quiz, 'Play');
    });

    scenario('a buzz during audio pauses it and shows the team', async quiz => {
        await quiz.host.click('musicPanel.playPause:');
        await statusShows(quiz, '▶ Playing');

        await buttonSays(quiz, 'Pause');

        await buzz(quiz, 2);
        assert.deepStrictEqual(await buzzes(quiz), [1]);
        await statusShows(quiz, '❚❚ Paused');
        await buttonSays(quiz, 'Play');
        await until('"Team 2" on screen', async () => (await quiz.host.visibleText()).includes('Team 2'));
    });

    scenario('Stop goes back to the start and leaves the buzz on screen', async quiz => {
        await quiz.host.click('musicPanel.stop:');
        await statusShows(quiz, '■ At start');
        assert.deepStrictEqual(await buzzes(quiz), [1]);
        assert.ok((await quiz.host.visibleText()).includes('Team 2'));
    });

    scenario('Play clears the buzzes and lets everyone buzz again', async quiz => {
        await quiz.host.click('musicPanel.playPause:');
        await statusShows(quiz, '▶ Playing');
        assert.deepStrictEqual(await buzzes(quiz), []);

        await buzz(quiz, 2);
        assert.deepStrictEqual(await buzzes(quiz), [1]);
    });

    scenario('highlight next team is only available when someone is queued behind', async quiz => {
        const nextTeamLive = async () => (await quiz.host.read('musicPanel.nextTeamButton')).enabled;
        assert.deepStrictEqual(await buzzes(quiz), [1]);
        await until('next team to be greyed out', async () => !(await nextTeamLive()));

        await buzz(quiz, 3);
        assert.deepStrictEqual(await buzzes(quiz), [1, 2]);
        await until('next team to be available', nextTeamLive);

        await quiz.host.click('musicPanel.nextTeam:');
        assert.strictEqual(await nextTeamLive(), false);
    });

    scenario('reset clears the buzzes and goes back to the start, keeping the track', async quiz => {
        await quiz.host.click('resetRound:');
        await until('the buzzes to clear', async () => (await buzzes(quiz)).length === 0);
        assert.strictEqual(await loaded(quiz), 'audio');
        await statusShows(quiz, '■ At start');
    });

    scenario('Play after a pause carries on from where it was', async quiz => {
        await quiz.host.click('musicPanel.playPause:');
        await until('the track to get going', async () => /· 0:0[1-9] \//.test(await status(quiz)));
        await quiz.host.click('musicPanel.playPause:');
        await statusShows(quiz, '❚❚ Paused');
        const pausedAt = (await status(quiz)).match(/· (\d+:\d\d) \//)[1];

        await quiz.host.click('musicPanel.playPause:');
        await statusShows(quiz, '▶ Playing');
        assert.notStrictEqual((await status(quiz)).match(/· (\d+:\d\d) \//)[1], '0:00', 'resumed from ' + pausedAt);
        await quiz.host.click('musicPanel.playPause:');
    });

    scenario('Next loads the video, clears the buzzes and swaps the options over', async quiz => {
        await quiz.host.click('musicPanel.playPause:');
        await buzz(quiz, 3);
        assert.deepStrictEqual(await buzzes(quiz), [2]);

        await quiz.host.click('musicPanel.nextTrack:');
        assert.strictEqual((await quiz.host.read('musicPanel.trackList')).title, '2-clip.mp4');
        assert.strictEqual(await loaded(quiz), 'video');
        assert.deepStrictEqual(await buzzes(quiz), []);
        await statusShows(quiz, '■ At start · video');
        assert.strictEqual((await quiz.host.read('buzzcocksMode')).enabled, false);
        assert.strictEqual((await quiz.host.read('blankVideo')).enabled, true);
        assert.strictEqual(await videoOnScreen(quiz), true);
    });

    scenario('a buzz during the video pauses it, and Stop goes back to the start', async quiz => {
        await quiz.host.click('musicPanel.playPause:');
        await statusShows(quiz, '▶ Playing · video');
        //AVPlayer starts in its own time, and a pause at exactly 0:00 is rightly "At start"
        await until('the video to get going', async () => /· 0:0[1-9] \//.test(await status(quiz)));

        await buzz(quiz, 1);
        assert.deepStrictEqual(await buzzes(quiz), [0]);
        await statusShows(quiz, '❚❚ Paused');

        await quiz.host.click('musicPanel.stop:');
        await statusShows(quiz, '■ At start');
        assert.deepStrictEqual(await buzzes(quiz), [0]);
    });

    scenario('going back to audio from a video removes the video, and a buzz stops the music', async quiz => {
        await quiz.host.set('musicPanel.chooseTrack:', '1-song.wav');
        assert.strictEqual(await loaded(quiz), 'audio');
        assert.strictEqual(await videoOnScreen(quiz), false);

        await quiz.host.click('musicPanel.playPause:');
        await statusShows(quiz, '▶ Playing · audio');
        await buzz(quiz, 3);
        assert.deepStrictEqual(await buzzes(quiz), [2]);
        await statusShows(quiz, '❚❚ Paused');
    });

    scenario('Next is greyed out on the last track', async quiz => {
        await quiz.host.set('musicPanel.chooseTrack:', '3-song.wav');
        assert.strictEqual((await quiz.host.read('musicPanel.nextTrackButton')).enabled, false);
        await quiz.host.set('musicPanel.chooseTrack:', '2-clip.mp4');
        assert.strictEqual((await quiz.host.read('musicPanel.nextTrackButton')).enabled, true);
    });

    scenario('leaving the round pauses the track', async quiz => {
        await quiz.host.click('musicPanel.playPause:');
        await statusShows(quiz, '▶ Playing');
        await quiz.round('buzzers');
        await statusShows(quiz, '❚❚ Paused');
    });
});
