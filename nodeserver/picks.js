'use strict';

//Which client holds which team, kept on disk so that a server that restarts mid-quiz gives
//every phone its team back rather than sending them all to the team picker.
//
//The file is a snapshot, rewritten whole on every change. Teams are picked and released a
//handful of times a night, so there is no point in anything cleverer.

const fs = require('fs');
const path = require('path');

//A quiz night is a few hours. Anything older is from another night, and handing out its
//teams would give some phone that happens to have been leased the same address a team it
//never picked.
const MAX_AGE_MS = 6 * 60 * 60 * 1000;

class PickStore {
    constructor(file) {
        this.file = file;
    }

    //Returns { picks: {key: team}, savedAt: Date } or null if there is nothing to restore.
    //Throws if the file exists but cannot be used, having moved it aside so that the next
    //save does not destroy the evidence.
    load() {
        let text;
        try {
            text = fs.readFileSync(this.file, 'utf8');
        } catch(err) {
            if(err.code === 'ENOENT') return null;
            throw err;
        }

        let saved;
        try {
            saved = JSON.parse(text);
            if(!saved || typeof saved.picks !== 'object' || Array.isArray(saved.picks) ||
               !Number.isFinite(saved.savedAt)) {
                throw new Error('not a picks file');
            }
        } catch(err) {
            const aside = this.file + '.bad';
            try { fs.renameSync(this.file, aside); } catch(e) {}
            throw new Error(err.message + ', moved aside to ' + aside);
        }

        const savedAt = new Date(saved.savedAt);
        if(Date.now() - saved.savedAt > MAX_AGE_MS) {
            return { picks: {}, savedAt: savedAt, stale: true };
        }
        return { picks: saved.picks, savedAt: savedAt, stale: false };
    }

    //Written to a temporary file and renamed over the old one, so a crash part way through
    //leaves the previous snapshot rather than half of a new one.
    save(picks) {
        const tmp = this.file + '.tmp';
        fs.mkdirSync(path.dirname(this.file), { recursive: true });
        const fd = fs.openSync(tmp, 'w');
        try {
            fs.writeSync(fd, JSON.stringify({ savedAt: Date.now(), picks: picks }, null, 1));
            fs.fsyncSync(fd);
        } finally {
            fs.closeSync(fd);
        }
        fs.renameSync(tmp, this.file);
    }
}

module.exports = { PickStore, MAX_AGE_MS };
