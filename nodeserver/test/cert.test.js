'use strict';

//The startup certificate check. The wording matters as much as the arithmetic: an expired
//certificate presents as "the wifi is broken" on the night, so the message has to be
//unmissable and has to say what to do about it.

const { test, describe } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const os = require('os');

const { certStatus, certMessages, logCertStatus, defaultConfig, CERT_WARN_DAYS } = require('../server');
const { muteLogs } = require('./helpers');

const DAY_MS = 24 * 60 * 60 * 1000;
function statusInDays(days) {
    return { subject: 'CN=christmasquiz.win',
             validTo: new Date(Date.now() + days * DAY_MS),
             days: days };
}

describe('certificate messages', () => {
    test('an expired certificate says so, for how long, and how to fix it', () => {
        const lines = certMessages(statusInDays(-71));
        assert.match(lines[0], /CERTIFICATE EXPIRED 71 days ago/);
        assert.ok(lines.some(l => l.includes('./renew-cert.sh')), 'tells you the command');
        assert.ok(lines.some(l => /network fault|refuse to connect/.test(l)),
            'explains how it will present, since it does not look like a cert problem');
    });

    test('an expiry today is treated as expiring, not as still valid', () => {
        assert.match(certMessages(statusInDays(0))[0], /expires in 0 days/);
    });

    test('a certificate inside the warning window warns', () => {
        const lines = certMessages(statusInDays(CERT_WARN_DAYS - 1));
        assert.match(lines[0], /Certificate expires in/);
        assert.ok(lines.some(l => l.includes('./renew-cert.sh')));
    });

    test('a healthy certificate reports quietly, with no stars', () => {
        const lines = certMessages(statusInDays(CERT_WARN_DAYS + 1));
        assert.strictEqual(lines.length, 1);
        assert.match(lines[0], /valid for another \d+ days/);
        assert.ok(!lines[0].includes('***'), 'no alarm for a healthy certificate');
    });

    test('the boundary day warns rather than reassures', () => {
        assert.match(certMessages(statusInDays(CERT_WARN_DAYS))[0], /expires in/);
    });

    test('every message names a date, so it can be checked by eye', () => {
        [-71, 0, 5, 400].forEach(d => {
            assert.ok(certMessages(statusInDays(d)).join(' ').match(/\d{4}-\d{2}-\d{2}/),
                'no date in the message for ' + d + ' days');
        });
    });

    test('no certificate configured is stated, not warned about', () => {
        const lines = certMessages(null);
        assert.strictEqual(lines.length, 1);
        assert.ok(!lines[0].includes('***'));
    });

    test('an unreadable certificate is reported with the reason', () => {
        const lines = certMessages({ error: 'ENOENT: no such file' });
        assert.match(lines[0], /could not be read \(ENOENT/);
        assert.ok(lines.some(l => l.includes('wss')), 'says what it breaks');
    });
});

describe('reading the certificate', () => {
    test('no certs configured gives null rather than throwing', () => {
        assert.strictEqual(certStatus(null), null);
    });

    test('a missing file is reported, not thrown', () => {
        //It must never be the reason the server fails to start.
        const status = certStatus({ cert: '/nonexistent/nope.pem' });
        assert.ok(status.error, 'got ' + JSON.stringify(status));
    });

    test('a file that is not a certificate is reported, not thrown', () => {
        const junk = path.join(os.tmpdir(), 'quiz-not-a-cert-' + process.pid + '.pem');
        fs.writeFileSync(junk, 'this is not a certificate\n');
        try {
            const status = certStatus({ cert: junk });
            assert.ok(status.error, 'got ' + JSON.stringify(status));
        } finally {
            fs.unlinkSync(junk);
        }
    });

    test('logCertStatus survives a broken certificate', () => {
        const unmute = muteLogs();
        try {
            assert.ok(certStatus({ cert: '/nonexistent/nope.pem' }).error);
            logCertStatus({ cert: '/nonexistent/nope.pem' });   //must not throw
            logCertStatus(null);
        } finally {
            unmute();
        }
    });
});

//These need the real certificates, which are not in the repository.
function realCert() {
    const cfg = defaultConfig();
    return path.resolve(__dirname, '..', cfg.certs.cert);
}

describe('the real certificate', { skip: fs.existsSync(realCert()) ? false : 'no certificates in certs/live' }, () => {
    test('parses, and the day count agrees with the expiry date', () => {
        const status = certStatus({ cert: realCert() });
        assert.ok(!status.error, 'error: ' + status.error);
        assert.ok(status.validTo instanceof Date);
        assert.ok(!isNaN(status.validTo.getTime()));
        assert.strictEqual(status.days,
            Math.floor((status.validTo.getTime() - Date.now()) / DAY_MS));
    });

    test('the leaf is taken from the fullchain, not the CA', () => {
        //A fullchain holds the leaf first, then the issuers, which expire much later.
        //Reporting an issuer's expiry would be reassuring and wrong.
        const status = certStatus({ cert: realCert() });
        assert.match(status.subject, /christmasquiz\.win/);
    });
});
