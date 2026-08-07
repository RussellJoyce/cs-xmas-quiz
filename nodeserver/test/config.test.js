'use strict';

//Deployment settings come from config.json. The point of the file is that the server and
//the certbot scripts cannot disagree about which domain is in play, so these check that
//everything downstream really is derived from it rather than hardcoded alongside it.

const { test, describe, afterEach } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');

const { loadDeploymentConfig, defaultConfig, CONFIG_FILE } = require('../server');

//Environment overrides are process-wide, so put them back after each test.
const savedEnv = { QUIZ_DOMAIN: process.env.QUIZ_DOMAIN,
                   QUIZ_HOST_ADDRESS: process.env.QUIZ_HOST_ADDRESS };
afterEach(() => {
    ['QUIZ_DOMAIN', 'QUIZ_HOST_ADDRESS'].forEach(k => {
        if(savedEnv[k] === undefined) delete process.env[k];
        else process.env[k] = savedEnv[k];
    });
});

describe('config.json', () => {
    test('is committed and holds both settings', () => {
        //It has no defaults behind it, so a checkout without this file cannot start.
        const file = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
        assert.ok(file.domain, 'no domain in config.json');
        assert.ok(file.hostAddress, 'no hostAddress in config.json');
    });

    test('lives next to server.js, not wherever the server was started from', () => {
        //Cert paths are still relative to the working directory, but the config must not be.
        assert.strictEqual(CONFIG_FILE, path.join(__dirname, '..', 'config.json'));
    });

    test('is what loadDeploymentConfig returns', () => {
        const file = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
        delete process.env.QUIZ_DOMAIN;
        delete process.env.QUIZ_HOST_ADDRESS;
        assert.deepStrictEqual(loadDeploymentConfig(),
            { domain: file.domain, hostAddress: file.hostAddress });
    });
});

describe('environment overrides', () => {
    test('QUIZ_DOMAIN wins over the file', () => {
        process.env.QUIZ_DOMAIN = 'spare-laptop.test';
        assert.strictEqual(loadDeploymentConfig().domain, 'spare-laptop.test');
    });

    test('QUIZ_HOST_ADDRESS wins over the file', () => {
        process.env.QUIZ_HOST_ADDRESS = '10.9.8.7';
        assert.strictEqual(loadDeploymentConfig().hostAddress, '10.9.8.7');
    });

    test('overriding one leaves the other alone', () => {
        const file = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
        process.env.QUIZ_DOMAIN = 'spare-laptop.test';
        delete process.env.QUIZ_HOST_ADDRESS;
        assert.strictEqual(loadDeploymentConfig().hostAddress, file.hostAddress);
    });
});

describe('what the domain feeds', () => {
    test('the DNS record answers with the configured domain and address', () => {
        process.env.QUIZ_DOMAIN = 'somewhere.test';
        process.env.QUIZ_HOST_ADDRESS = '10.1.2.3';
        const cfg = defaultConfig();
        assert.strictEqual(cfg.dnsHostname, 'somewhere.test');
        assert.strictEqual(cfg.hostAddress, '10.1.2.3');
    });

    test('the certificate paths follow the domain', () => {
        //The whole reason renew-cert.sh reads the same file: certbot writes into a
        //directory named after the domain, and the server looks for it there.
        process.env.QUIZ_DOMAIN = 'somewhere.test';
        const cfg = defaultConfig();
        assert.strictEqual(cfg.certs.cert, 'certs/live/somewhere.test/fullchain.pem');
        assert.strictEqual(cfg.certs.key, 'certs/live/somewhere.test/privkey.pem');
    });

    test('an explicit certs override still wins, so tests can run without TLS', () => {
        assert.strictEqual(defaultConfig({ certs: null }).certs, null);
    });
});

describe('the certbot scripts read the same file', () => {
    //If these drift, certbot writes the certificate to a directory the server never looks
    //in, and the failure only shows up as phones refusing to connect.
    const scripts = [
        { path: path.join(__dirname, '..', 'renew-cert.sh'), name: 'renew-cert.sh' },
        { path: path.join(__dirname, '..', 'certs', 'fetch.sh'), name: 'certs/fetch.sh' }
    ];

    scripts.forEach(script => {
        const present = fs.existsSync(script.path);
        test(script.name + ' takes its domain from config.json',
             { skip: present ? false : 'not present in this checkout' }, () => {
            const text = fs.readFileSync(script.path, 'utf8');
            assert.match(text, /config\.json/,
                script.name + ' does not mention config.json');
            assert.ok(!/-d\s+[a-z0-9.-]+\.[a-z]{2,}/i.test(text),
                script.name + ' still passes a literal domain to certbot');
        });
    });
});
