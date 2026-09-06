'use strict';

//Stage 1: give every article an integer id, and work out where every redirect lands.
//Writes corpus/build/{articles.json, redirects.json}

const fs = require('fs');
const path = require('path');
const { openArchive, resolveRedirect, progress } = require('./lib/zim');

const BUILD = path.join(__dirname, 'corpus', 'build');

function main() {
    fs.mkdirSync(BUILD, { recursive: true });
    const archive = openArchive(process.argv[2]);
    console.log('reading ' + archive.filename);
    console.log(archive.allEntryCount.toLocaleString() + ' entries, ' +
                archive.articleCount.toLocaleString() + ' front articles, ' +
                archive.mediaCount.toLocaleString() + ' media\n');

    const slugs = [];
    const titles = [];
    const idOf = new Map();
    const pending = [];
    let media = 0, n = 0;

    console.log('indexing');
    const p1 = progress('entries', 200000);
    for(const entry of archive.iterByPath()) {
        p1.tick(++n);

        if(entry.isRedirect) {
            //Resolved below, once every article has an id to point at.
            pending.push(entry);
            continue;
        }

        //Only process text/html
        let mime;
        try {
            mime = entry.getItem(false).mimetype;
        } catch(err) {
            continue;
        }
        if(mime !== 'text/html') { media++; continue; }

        idOf.set(entry.path, slugs.length);
        titles.push(entry.title);
        slugs.push(entry.path);
    }
    p1.done(n);
    console.log('  articles      ' + slugs.length.toLocaleString());
    console.log('  non-html      ' + media.toLocaleString());
    console.log('  redirects     ' + pending.length.toLocaleString());

    console.log('\nresolving redirects');
    const redirectTo = new Map();
    let broken = 0, m = 0;
    const p2 = progress('redirects', 200000);
    for(const entry of pending) {
        p2.tick(++m);
        const target = resolveRedirect(entry);
        if(!target) { broken++; continue; }
        const id = idOf.get(target.path);
        if(id === undefined) { broken++; continue; } //lands on media, or on nothing
        redirectTo.set(entry.path, id);
    }
    p2.done(m);
    console.log('  resolved      ' + redirectTo.size.toLocaleString());
    console.log('  unresolvable  ' + broken.toLocaleString());

    fs.writeFileSync(path.join(BUILD, 'articles.json'), JSON.stringify({ slugs, titles }));
    fs.writeFileSync(path.join(BUILD, 'redirects.json'), JSON.stringify(Object.fromEntries(redirectTo)));
    console.log('\nwrote ' + BUILD);
}

main();
