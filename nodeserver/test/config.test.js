'use strict';

//Deployment settings come from config.json. The point of the file is that the server and
//the certbot scripts cannot disagree about which domain is in play, so these check that
//everything downstream really is derived from it rather than hardcoded alongside it.

const { test, describe, afterEach } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');

const { loadDeploymentConfig, validateDeploymentConfig, defaultConfig,
        REQUIRED_PORTS, CONFIG_FILE } = require('../server');

//A config known to be good, for tests that spoil one field at a time.
function goodConfig() {
    return JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
}

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
    test('is committed and holds every setting', () => {
        //It has no defaults behind it, so a checkout without this file cannot start.
        const file = goodConfig();
        assert.ok(file.domain, 'no domain in config.json');
        assert.ok(file.hostAddress, 'no hostAddress in config.json');
        assert.ok(Number.isInteger(file.numTeams), 'no numTeams in config.json');
        REQUIRED_PORTS.forEach(name =>
            assert.ok(Number.isInteger(file.ports[name]), 'no ports.' + name + ' in config.json'));
    });

    test('the real file passes its own validation', () => {
        validateDeploymentConfig(goodConfig());
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
            { domain: file.domain, hostAddress: file.hostAddress,
              ports: file.ports, numTeams: file.numTeams });
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


describe('config validation', () => {
    //Checked against made-up configs, so the real config.json is never written to --
    //test files run in parallel and one of them starts real servers.
    function spoil(change) {
        const file = goodConfig();
        change(file);
        return () => validateDeploymentConfig(file, 'test config');
    }

    test('a missing domain is refused by name', () => {
        assert.throws(spoil(f => delete f.domain), /has no "domain"/);
    });

    test('a missing hostAddress is refused by name', () => {
        assert.throws(spoil(f => delete f.hostAddress), /has no "hostAddress"/);
    });

    test('a missing ports block is refused', () => {
        assert.throws(spoil(f => delete f.ports), /has no "ports"/);
    });

    REQUIRED_PORTS.forEach(name => {
        test('a missing ports.' + name + ' is refused, naming the key', () => {
            assert.throws(spoil(f => delete f.ports[name]),
                new RegExp('ports\\.' + name));
        });
    });

    test('a port that is not a number is refused', () => {
        assert.throws(spoil(f => { f.ports.server = "8091"; }), /integer 0-65535/);
    });

    test('a port out of range is refused at both ends', () => {
        assert.throws(spoil(f => { f.ports.server = -1; }), /integer 0-65535/);
        assert.throws(spoil(f => { f.ports.server = 70000; }), /integer 0-65535/);
    });

    test('a fractional port is refused', () => {
        assert.throws(spoil(f => { f.ports.server = 8091.5; }), /integer 0-65535/);
    });

    test('port 0 is allowed, because the tests use it for ephemeral ports', () => {
        const cfg = spoil(f => { f.ports.server = 0; })();
        assert.strictEqual(cfg.ports.server, 0);
    });

    test('two servers on one port is refused, naming both', () => {
        //Otherwise this surfaces as EADDRINUSE from whichever lost the race.
        assert.throws(spoil(f => { f.ports.leds = f.ports.server; }), err => {
            assert.match(err.message, /uses port \d+ for both/);
            assert.match(err.message, /"server"/, 'names the first: ' + err.message);
            assert.match(err.message, /"leds"/, 'names the second: ' + err.message);
            return true;
        });
    });

    test('several ephemeral ports do not count as a clash', () => {
        const cfg = spoil(f => { f.ports.server = 0; f.ports.leds = 0; f.ports.clientWs = 0; })();
        assert.strictEqual(cfg.ports.leds, 0);
    });

    test('numTeams must be a whole number of at least one', () => {
        [undefined, 0, -3, 2.5, "14", null].forEach(bad => {
            assert.throws(spoil(f => { f.numTeams = bad; }), /"numTeams"/,
                JSON.stringify(bad) + ' should not be a valid numTeams');
        });
    });
});

describe('what the ports and team count feed', () => {
    test('every port reaches the server config under its own name', () => {
        const file = goodConfig();
        const cfg = defaultConfig();
        assert.strictEqual(cfg.clientWssPort, file.ports.clientWss);
        assert.strictEqual(cfg.clientWsPort, file.ports.clientWs);
        assert.strictEqual(cfg.serverPort, file.ports.server);
        assert.strictEqual(cfg.ledsPort, file.ports.leds);
        assert.strictEqual(cfg.httpPort, file.ports.http);
        assert.strictEqual(cfg.httpsPort, file.ports.https);
        assert.strictEqual(cfg.dnsPort, file.ports.dns);
    });

    test('numTeams reaches the server config', () => {
        assert.strictEqual(defaultConfig().numTeams, goodConfig().numTeams);
    });

    test('overrides still beat the file, so tests can ask for ephemeral ports', () => {
        const cfg = defaultConfig({ serverPort: 0, numTeams: 4 });
        assert.strictEqual(cfg.serverPort, 0);
        assert.strictEqual(cfg.numTeams, 4);
    });

    test('the ports the phones and the quiz software use are all distinct', () => {
        const cfg = defaultConfig();
        const used = [cfg.clientWssPort, cfg.clientWsPort, cfg.serverPort, cfg.ledsPort,
                      cfg.httpPort, cfg.httpsPort, cfg.dnsPort];
        assert.strictEqual(new Set(used).size, used.length, 'duplicate port in ' + used);
    });
});
