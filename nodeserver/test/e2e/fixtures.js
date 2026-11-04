'use strict';

//Builds a throwaway quiz root: a few questions of each kind and a tiny wiki corpus. Written
//out at run time rather than kept in git so that the corpus's binary file can stay in step
//with the format here, and so the tests can read the answers straight out of this file.

const fs = require('fs');
const path = require('path');

const STATIC = path.resolve(__dirname, '../../static');

const POINTLESS = { title: 'Name a fruit', answers: { apple: 40, kiwi: 3, quince: 0 } };

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

    titles.forEach((title, id) => {
        const body = links[id].map(to => '<a data-s="' + to + '">' + titles[to] + '</a>').join(' and ');
        write(path.join(dir, 'a', String(Math.floor(id / shard)), id + '.json'),
              JSON.stringify({ t: title, h: '<p>' + title + ' leads to ' + body + '.</p>' }));
    });

    write(path.join(dir, 'puzzles.json'), JSON.stringify([{
        start: 0, target: 2, startTitle: titles[0], targetTitle: titles[2], hops: 2,
        route: [titles[0], titles[1], titles[2]], routeIds: [0, 1, 2]
    }]));
}

function writeFixtures(root) {
    write(path.join(root, 'Questions/Pointless/1-fruit.txt'),
          POINTLESS.title + '\n' +
          Object.entries(POINTLESS.answers).map(([a, score]) => a + ',' + score).join('\n') + '\n');

    write(path.join(root, 'Questions/OnlyConnect/1-wall.txt'),
          Object.entries(WALL).map(([name, clues]) => name + ': ' + clues.join(', ')).join('\n') + '\n');

    fs.mkdirSync(path.join(root, 'Questions/Unique'), { recursive: true });
    fs.mkdirSync(path.join(root, 'Questions/Music'), { recursive: true });

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

module.exports = { writeFixtures, POINTLESS, WALL, WIKI };
