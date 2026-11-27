'use strict';

//Builds a throwaway quiz root: a few questions of each kind and a tiny wiki corpus. Written
//out at run time rather than kept in git so that the corpus's binary file can stay in step
//with the format here, and so the tests can read the answers straight out of this file.

const fs = require('fs');
const path = require('path');

const STATIC = path.resolve(__dirname, '../../static');

const POINTLESS = { title: 'Name a fruit', answers: { apple: 40, kiwi: 3, quince: 0 } };

//The text round's unique answers. One is a real place far longer than most answers, and is
//the longest a team may type.
const UNIQUE = ['paris', 'rome', 'york', 'llanfairpwllgwyngyllgogerychwyrndrobwllllantysiliogogogoch'];

//Thirty answers, some long, as the real ones have, so that a full board has to fit. Written
//as markdown with bullets, which the round must strip.
const CATEGORIES = {
    file: '1-countries.md',
    heading: 'European countries',
    subheading: 'any country with land in Europe',
    answers: ['Albania', 'Andorra', 'Austria', 'Belgium', 'Bosnia and Herzegovina', 'Bulgaria', 'Croatia',
              'Czech Republic', 'Denmark', 'Estonia', 'Finland', 'France', 'Germany', 'Greece', 'Hungary',
              'Iceland', 'Ireland', 'Italy', 'Latvia', 'Liechtenstein', 'Lithuania', 'Luxembourg', 'Malta',
              'Netherlands', 'North Macedonia', 'Norway', 'Poland', 'Portugal', 'San Marino', 'Vatican City']
};

//Four groups of four, and a word in none of them would be no use to anybody
const WALL = {
    fruit:   ['apple', 'pear', 'plum', 'fig'],
    colour:  ['red', 'blue', 'green', 'pink'],
    metal:   ['iron', 'tin', 'lead', 'zinc'],
    pet:     ['cat', 'dog', 'hamster', 'gerbil']
};

//   0 Start Line ──► 1 Middle Ground ──► 2 The Finish, Indeed ──► 0
//   └──► 3 Detour ──► 1
//
//The target has a comma in its title because real ones do, and the wire has to cope.
const WIKI = {
    titles: ['Start Line', 'Middle Ground', 'The Finish, Indeed', 'Detour'],
    links: [[1, 3], [2], [0], [1]]
};

function write(file, content) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, content);
}

function writeWiki(dir) {
    const { titles, links } = WIKI;
    const shard = 1000;

    write(path.join(dir, 'meta.json'), JSON.stringify({ shard, articles: titles.length, built: 'fixture' }));
    write(path.join(dir, 'index.json'), JSON.stringify({ titles, slugs: titles, shard }));

    //Two header ints, then the offsets, then the targets: see WikiCorpus.load
    const targets = links.flat();
    const graph = [titles.length, targets.length];
    let at = 0;
    graph.push(0);
    links.forEach(row => { at += row.length; graph.push(at); });
    graph.push(...targets);
    write(path.join(dir, 'graph.bin'), Buffer.from(Int32Array.from(graph).buffer));

    //The start is long, with its links well down it, so that there is a place on the page for Back to return to
    const filler = '<p>Nothing to follow in this paragraph, just words to scroll past on the way down.</p>'.repeat(40);

    titles.forEach((title, id) => {
        const body = links[id].map(to => '<a data-s="' + to + '">' + titles[to] + '</a>').join(' and ');
        write(path.join(dir, 'a', String(Math.floor(id / shard)), id + '.json'),
              JSON.stringify({ t: title, h: (id === 0 ? filler : '') + '<p>' + title + ' leads to ' + body + '.</p>' }));
    });

    write(path.join(dir, 'puzzles.json'), JSON.stringify([{
        start: 0, target: 2, startTitle: titles[0], targetTitle: titles[2], hops: 2,
        route: [titles[0], titles[1], titles[2]], routeIds: [0, 1, 2],
        routeCount: 1, moreRoutes: [], moreRouteIds: [], note: 'A note for the host'
    }, {
        //Only for the host panel's list of routes: this graph has no pair with two shortest
        //routes, so the extra ones here are not real
        start: 3, target: 2, startTitle: titles[3], targetTitle: titles[2], hops: 2,
        route: [titles[3], titles[1], titles[2]], routeIds: [3, 1, 2],
        routeCount: 2500000, moreRoutes: [['X', 'Y', 'Z'], ['P', 'Q', 'R']], moreRouteIds: [[9, 9, 9], [9, 9, 9]]
    }]));
}

//A mono 16-bit WAV of silence. The app is muted in the tests, but it still has to play.
function silentWav(seconds, rate = 8000) {
    const data = seconds * rate * 2;
    const wav = Buffer.alloc(44 + data);
    wav.write('RIFF', 0); wav.writeUInt32LE(36 + data, 4); wav.write('WAVE', 8);
    wav.write('fmt ', 12); wav.writeUInt32LE(16, 16); wav.writeUInt16LE(1, 20); wav.writeUInt16LE(1, 22);
    wav.writeUInt32LE(rate, 24); wav.writeUInt32LE(rate * 2, 28); wav.writeUInt16LE(2, 32); wav.writeUInt16LE(16, 34);
    wav.write('data', 36); wav.writeUInt32LE(data, 40);
    return wav;
}

//One question for each round that reads a file, saved each of the ways a Windows editor might
//save it. Each has accents and curly quotes, which only a file read the right way gets right.
//`file` is the name of each version, one per encoding.
const ENCODINGS = ['crlf-bom', 'utf16le', 'utf16be', 'cp1252'];
const ENCODED = {
    file: encoding => '5-' + encoding + '.txt',
    unique: { text: 'paris\nrome\n\u201cyork\u201d\ncaf\u00e9\n', uniques: ['paris', 'rome', 'york', 'caf\u00e9'] },
    categories: {
        text: '# Caf\u00e9s d\u2019Europe - the ones you\u2019d visit\n\n- Caf\u00e9 \u201cCentral\u201d\n- Caff\u00e8 Florian\n',
        heading: 'Caf\u00e9s d\u2019Europe', subheading: 'the ones you\u2019d visit',
        answers: ['Caf\u00e9 \u201cCentral\u201d', 'Caff\u00e8 Florian']
    },
    pointless: { text: 'Name a caf\u00e9 drink\nlatte,10\ncaf\u00e9 au lait,3\n', title: 'Name a caf\u00e9 drink' },
    wall: {
        text: 'Caf\u00e9 \u201cdrinks\u201d: caf\u00e9, th\u00e9, latte, mocha\n' +
              ['colour', 'metal', 'pet'].map(name => name + ': ' + WALL[name].join(', ')).join('\n') + '\n',
        clues: ['caf\u00e9', 'th\u00e9', 'latte', 'mocha'], connection: 'Caf\u00e9 \u201cdrinks\u201d'
    }
};

//The bytes a Windows editor would write for `text`, with its CRLF line endings
function encode(text, encoding) {
    const crlf = text.replace(/\n/g, '\r\n');
    switch(encoding) {
    case 'crlf-bom': return Buffer.concat([Buffer.from([0xEF, 0xBB, 0xBF]), Buffer.from(crlf, 'utf8')]);
    case 'utf16le': return Buffer.concat([Buffer.from([0xFF, 0xFE]), Buffer.from(crlf, 'utf16le')]);
    case 'utf16be': return Buffer.concat([Buffer.from([0xFE, 0xFF]), Buffer.from(crlf, 'utf16le').swap16()]);
    case 'cp1252': {
        //Latin-1, apart from the quotes and dashes Windows put where Latin-1 has controls
        const extra = { '\u2018': 0x91, '\u2019': 0x92, '\u201c': 0x93, '\u201d': 0x94, '\u2013': 0x96, '\u2014': 0x97 };
        return Buffer.from([...crlf].map(c => {
            if(extra[c]) return extra[c];
            if(c.charCodeAt(0) > 0xFF) throw new Error('not in Windows-1252: ' + c);
            return c.charCodeAt(0);
        }));
    }
    }
    throw new Error('no such encoding: ' + encoding);
}

function writeFixtures(root) {
    for(const encoding of ENCODINGS) {
        const file = ENCODED.file(encoding);
        write(path.join(root, 'Questions/Unique', file), encode(ENCODED.unique.text, encoding));
        write(path.join(root, 'Questions/Categories', file), encode(ENCODED.categories.text, encoding));
        write(path.join(root, 'Questions/Pointless', file), encode(ENCODED.pointless.text, encoding));
        write(path.join(root, 'Questions/OnlyConnect', file), encode(ENCODED.wall.text, encoding));
    }

    write(path.join(root, 'Questions/Pointless/1-fruit.txt'),
          POINTLESS.title + '\n' +
          Object.entries(POINTLESS.answers).map(([a, score]) => a + ',' + score).join('\n') + '\n');

    //Shares an answer with the first question, at a different score
    write(path.join(root, 'Questions/Pointless/2-green.txt'), 'Name something green\nkiwi,5\nlime,1\n');

    write(path.join(root, 'Questions/Unique/1-cities.txt'), UNIQUE.join('\n') + '\n');

    write(path.join(root, 'Questions/Categories', CATEGORIES.file),
          '# ' + CATEGORIES.heading + ' - ' + CATEGORIES.subheading + '\n\n' +
          CATEGORIES.answers.map(a => '- ' + a).join('\n') + '\n');
    write(path.join(root, 'Questions/Categories/2-fruit.txt'), 'Fruit\napple\npear\nplum\n');

    write(path.join(root, 'Questions/OnlyConnect/1-wall.txt'),
          Object.entries(WALL).map(([name, clues]) => name + ': ' + clues.join(', ')).join('\n') + '\n');

    //Audio and video interleaved, as the music round lists them together in name order
    const music = path.join(root, 'Questions/Music');
    fs.mkdirSync(music, { recursive: true });
    fs.writeFileSync(path.join(music, '1-song.wav'), silentWav(20));
    fs.copyFileSync(path.join(__dirname, 'media/clip.mp4'), path.join(music, '2-clip.mp4'));
    fs.writeFileSync(path.join(music, '3-song.wav'), silentWav(20));

    //The phones are served the real pages, with the corpus swapped for this one. The app reads
    //the same folder, as it does in the real checkout.
    const served = path.join(root, 'nodeserver/static');
    fs.mkdirSync(served, { recursive: true });
    for(const entry of fs.readdirSync(STATIC)) {
        if(entry !== 'wiki') fs.symlinkSync(path.join(STATIC, entry), path.join(served, entry));
    }
    writeWiki(path.join(served, 'wiki'));

    return { staticDir: served, wikiDir: path.join(served, 'wiki') };
}

module.exports = { writeFixtures, ENCODINGS, ENCODED, UNIQUE, POINTLESS, CATEGORIES, WALL, WIKI };
