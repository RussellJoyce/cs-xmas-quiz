'use strict';

//The tree firmware server, over real HTTP on an ephemeral port, serving from a temporary
//folder. Requests carry the headers the Arduino core's HTTPUpdate sends.

const { test, describe, before, after, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');
const http = require('http');
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');

const { createFirmwareServer, treeIdFromMac } = require('../firmware');
const { captureLogs } = require('./helpers');

const IMAGE = Buffer.from('not really firmware, but bytes all the same\n'.repeat(100));
const IMAGE_MD5 = crypto.createHash('md5').update(IMAGE).digest('hex');
const MAC = '10:00:3B:D6:25:34';

let dir, server, port, logs;

before(async () => {
    dir = fs.mkdtempSync(path.join(os.tmpdir(), 'quiz-firmware-'));
    fs.writeFileSync(path.join(dir, 'tree-esp32c3.bin'), IMAGE);
    server = createFirmwareServer(dir);
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    port = server.address().port;
});

after(() => {
    server.closeAllConnections();
    server.close();
    fs.rmSync(dir, { recursive: true, force: true });
});

beforeEach(() => { logs = captureLogs(); });
afterEach(() => logs.stop());

function get(url, headers, method) {
    return new Promise((resolve, reject) => {
        const req = http.request({ host: '127.0.0.1', port, path: url, method: method || 'GET',
                                   headers: Object.assign({ 'x-ESP32-STA-MAC': MAC }, headers) }, res => {
            const chunks = [];
            res.on('data', c => chunks.push(c));
            res.on('end', () => resolve({ status: res.statusCode, headers: res.headers,
                                          body: Buffer.concat(chunks) }));
        });
        req.on('error', reject);
        req.end();
    });
}

describe('the firmware server', () => {
    test('sends the image for the chip asked for, with its MD5 for HTTPUpdate to check', async () => {
        const res = await get('/firmware/tree-esp32c3.bin', { 'x-ESP32-sketch-md5': 'f'.repeat(32) });
        assert.strictEqual(res.status, 200);
        assert.ok(res.body.equals(IMAGE));
        assert.strictEqual(res.headers['content-length'], String(IMAGE.length));
        assert.strictEqual(res.headers['x-md5'], IMAGE_MD5);
        assert.ok(logs.some(l => /tree d62534 .*firmware: sending tree-esp32c3/.test(l.line)),
                  'the log names the tree by its MAC');
    });

    test('a tree already running that image is told 304 and sent nothing', async () => {
        const res = await get('/firmware/tree-esp32c3.bin', { 'x-ESP32-sketch-md5': IMAGE_MD5.toUpperCase() });
        assert.strictEqual(res.status, 304);
        assert.strictEqual(res.body.length, 0);
    });

    test('a chip with no image is 404', async () => {
        const res = await get('/firmware/tree-esp32c6.bin');
        assert.strictEqual(res.status, 404);
        assert.ok(logs.some(l => /no tree-esp32c6.bin/.test(l.line)));
    });

    test('nothing outside the tree images is served', async () => {
        fs.writeFileSync(path.join(dir, 'secret.bin'), 'secret');
        for(const url of ['/firmware/secret.bin', '/firmware/../firmware/tree-esp32c3.bin',
                          '/firmware/tree-esp32c3.bin.tmp', '/firmware/tree-esp32c3.bin?x=1',
                          '/firmware/%2e%2e%2fsecret.bin', '/', '/firmware/']) {
            const res = await get(url);
            assert.strictEqual(res.status, 404, url);
        }
    });

    test('only GET', async () => {
        const res = await get('/firmware/tree-esp32c3.bin', {}, 'POST');
        assert.strictEqual(res.status, 404);
    });

    test('a new image is picked up without a restart', async () => {
        const newer = Buffer.from('a newer build');
        fs.writeFileSync(path.join(dir, 'tree-esp32c3.bin'), newer);
        try {
            const res = await get('/firmware/tree-esp32c3.bin', { 'x-ESP32-sketch-md5': IMAGE_MD5 });
            assert.strictEqual(res.status, 200, 'the old image is no longer current');
            assert.ok(res.body.equals(newer));
        } finally {
            fs.writeFileSync(path.join(dir, 'tree-esp32c3.bin'), IMAGE);
        }
    });
});

describe('treeIdFromMac', () => {
    test('is the last three bytes, as the tree uses for its id', () => {
        assert.strictEqual(treeIdFromMac('10:00:3B:D6:25:34'), 'd62534');
    });

    test('is null when there is no usable MAC', () => {
        assert.strictEqual(treeIdFromMac(undefined), null);
        assert.strictEqual(treeIdFromMac('nonsense'), null);
    });
});
