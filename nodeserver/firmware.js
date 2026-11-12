'use strict';

//Firmware for over-the-air updates of the desk trees, served over plain HTTP. The trees fetch
//it themselves when told to ("ltu" from the quiz software, which reaches them as u<port>).
//
//Images live in firmware/ as tree-<chip>.bin (tree-esp32c3.bin, tree-esp32c6.bin), put there
//by every build of quizleds/tree. A tree asks for the one for its own chip.
//
//Plain HTTP, not HTTPS: the trees would need certificate checking for TLS, which is more
//trouble than it is worth on the quiz network. Only the images in firmware/ are served.
//
//Each request carries the MD5 of the image the tree is running (x-ESP32-sketch-md5, added by
//the Arduino core's HTTPUpdate). If it matches the file, the answer is 304 and the tree stays
//as it is, so asking every tree to update only reflashes the ones that are out of date.

const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const log = require('./log');

const FIRMWARE_PATH = /^\/firmware\/(tree-esp32[a-z0-9]{1,8})\.bin$/;

//The tree id from the MAC address the request says it comes from: the last three bytes, as
//the tree uses for ?tree=. Only for the log; the image served does not depend on it.
function treeIdFromMac(mac) {
    const hex = String(mac || '').replace(/[^0-9a-f]/gi, '').toLowerCase();
    return hex.length === 12 ? hex.slice(6) : null;
}

function md5(file) {
    return crypto.createHash('md5').update(fs.readFileSync(file)).digest('hex');
}

//Handles one request. Exported apart from the server so that it can be tested with fake
//requests and a temporary folder.
function handleFirmwareRequest(dir, req, res) {
    const who = 'tree ' + (treeIdFromMac(req.headers['x-esp32-sta-mac']) || req.socket.remoteAddress);
    const match = req.method === 'GET' && FIRMWARE_PATH.exec(req.url);
    if(!match) {
        log.warn(who, null, null, 'firmware: refused ' + req.method + ' ' + req.url);
        res.writeHead(404);
        res.end();
        return;
    }

    const file = path.join(dir, match[1] + '.bin');
    let size, hash;
    try {
        size = fs.statSync(file).size;
        hash = md5(file);
    } catch(err) {
        log.warn(who, null, null, 'firmware: no ' + match[1] + '.bin to send');
        res.writeHead(404);
        res.end();
        return;
    }

    const running = String(req.headers['x-esp32-sketch-md5'] || '').toLowerCase();
    if(running === hash) {
        log.info(who, null, null, 'firmware: already running ' + match[1] + ' ' + hash.slice(0, 8));
        res.writeHead(304);
        res.end();
        return;
    }

    log.info(who, null, null, 'firmware: sending ' + match[1] + ' ' + hash.slice(0, 8) +
             ' (' + size + ' bytes), replacing ' + (running ? running.slice(0, 8) : 'unknown'));
    res.writeHead(200, { 'Content-Type': 'application/octet-stream', 'Content-Length': size,
                         'x-MD5': hash });
    const stream = fs.createReadStream(file);
    stream.on('error', function(err) {
        log.error(who, null, null, 'firmware: reading ' + file + ' failed: ' + err.message);
        res.destroy();
    });
    res.on('close', function() {
        if(!res.writableFinished) log.warn(who, null, null, 'firmware: download of ' + match[1] + ' cut short');
    });
    stream.pipe(res);
}

function createFirmwareServer(dir) {
    return http.createServer((req, res) => handleFirmwareRequest(dir, req, res));
}

module.exports = { createFirmwareServer, handleFirmwareRequest, treeIdFromMac, FIRMWARE_PATH };
