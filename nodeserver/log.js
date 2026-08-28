'use strict';

//Log output for the quiz server.
//
//Endpoints are: "quiz" (the quiz software), "leds", "all" (every buzzer client), "srv"
//(this server), "boot" (startup), "T7" (the client holding team 7)
//and "c3" (a client that has not claimed a team yet).
//
//Levels are ERROR, WARN, INFO and DEBUG, chosen with the QUIZ_LOG environment variable
//(default INFO).

const LEVELS = { error: 0, warn: 1, info: 2, debug: 3 };
const LEVEL_NAMES = ['ERROR', 'WARN ', 'INFO ', 'DEBUG'];
const LEVEL_COLOURS = ['\u001b[31m', '\u001b[33m', '', '\u001b[2m'];
const RESET = '\u001b[0m';

const CODES = {
    //Quiz software to a client
    on: 'buzzer on',      of: 'buzzer off',
    hh: 'higher accepted', hl: 'lower accepted', hn: 'clear higher/lower',
    ha: 'clear all higher/lower',
    h1: 'label higher/lower', h2: 'label true/false',
    vi: 'view',           im: 'geography image',
    mo: 'multiple choice options', ms: 'multiple choice accepted',
    ok: 'team confirmed', px: 'team refused',
    di: 'release team',   pb: 'pong',

    //Quiz software to this server
    le: 'led',            ls: 'list teams',

    //This server to the quiz software
    lr: 'team list',

    //A client to this server or the quiz software
    pt: 'pick team',      re: 'resume',        pi: 'ping',
    zz: 'buzz',           hi: 'higher',        lo: 'lower',
    tt: 'text answer',    ii: 'map guess',
    wv: 'wavelength guess', mc: 'multiple choice'
};

//How wide each column is. Names longer than this push the line out rather than being
//truncated, which is the right way round: an ugly line beats a misleading one.
const SRC_WIDTH = 6;
const DST_WIDTH = 5;

let threshold = LEVELS.info;
let sink = consoleSink;
let clock = Date.now;
let colour = Boolean(process.stdout.isTTY) && !process.env.NO_COLOR;

function consoleSink(level, line) {
    //Errors and warnings are the ones you want to keep when redirecting.
    if(level <= LEVELS.warn) console.error(line); else console.log(line);
}

function pad(text, width) {
    const s = text || '';
    return s.length >= width ? s : s + ' '.repeat(width - s.length);
}

function two(n) { return n < 10 ? '0' + n : String(n); }
function three(n) { return n < 10 ? '00' + n : (n < 100 ? '0' + n : String(n)); }

function stamp(t) {
    const d = new Date(t);
    //return two(d.getHours()) + ':' + two(d.getMinutes()) + ':' + two(d.getSeconds()) + '.' + three(d.getMilliseconds());
    return two(d.getHours()) + ':' + two(d.getMinutes()) + ':' + two(d.getSeconds());
}

//Turns a whole protocol message into "meaning payload", e.g. "vibuzzer" -> "view buzzer".
function describe(message) {
    const text = message === null || message === undefined ? '' : String(message);
    const name = CODES[text.slice(0, 2)];
    if(!name) return "unrecognised '" + text + "'";
    const rest = text.slice(2);
    return rest ? name + ' ' + rest : name;
}

function format(level, src, dst, code, detail) {
    //INFO has no colour of its own, so it must not pick up a reset either.
    const tint = colour ? LEVEL_COLOURS[level] : '';
    const name = tint ? tint + LEVEL_NAMES[level] + RESET : LEVEL_NAMES[level];
    //A message with no destination (a connection, a startup line) leaves the arrow off
    //but keeps the column, so everything still lines up.
    const route = pad(src, SRC_WIDTH) + (dst ? ' → ' : '   ') + pad(dst, DST_WIDTH);
    const line = stamp(clock()) + ' ' + name + ' ' + route + ' ' + pad(code, 2) + '  ' + (detail || '');
    return line.replace(/\s+$/, '');
}

function emit(level, src, dst, code, detail) {
    if(level > threshold) return;
    sink(level, format(level, src, dst, code, detail));
}

const log = {
    error: (src, dst, code, detail) => emit(LEVELS.error, src, dst, code, detail),
    warn:  (src, dst, code, detail) => emit(LEVELS.warn,  src, dst, code, detail),
    info:  (src, dst, code, detail) => emit(LEVELS.info,  src, dst, code, detail),
    debug: (src, dst, code, detail) => emit(LEVELS.debug, src, dst, code, detail),

    //Startup and shutdown lines, which have no route.
    boot: (detail) => emit(LEVELS.info, 'boot', null, null, detail),
    //Startup lines that are a problem, e.g. an expired certificate.
    bootError: (detail) => emit(LEVELS.error, 'boot', null, null, detail),

    describe: describe,

    //Returns the previous setting in every case, so a caller can put it back.
    setLevel: function(name) {
        const was = LEVEL_NAMES[threshold].trim().toLowerCase();
        const wanted = LEVELS[String(name || '').toLowerCase()];
        if(wanted !== undefined) threshold = wanted;
        return was;
    },

    //Tests capture the output rather than silencing it, so they can assert on it.
    setSink: function(fn) { const was = sink; sink = fn || consoleSink; return was; },
    setClock: function(fn) { const was = clock; clock = fn || Date.now; return was; },
    setColour: function(on) { const was = colour; colour = Boolean(on); return was; },

    LEVELS: LEVELS,
    CODES: CODES
};


if(process.env.QUIZ_LOG) log.setLevel(process.env.QUIZ_LOG);

module.exports = log;
