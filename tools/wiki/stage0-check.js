'use strict';

//look at the ZIM before writing anything that depends on its shape
//generates a bunch of stats and samples to help decide what stage 3 has to strip

const { openArchive } = require('./lib/zim');

const archive = openArchive(process.argv[2]);

function heading(s) {
    console.log('\n' + s);
    console.log('-'.repeat(s.length));
}

heading('Archive');
console.log('file                ' + archive.filename);
console.log('size                ' + archive.filesize);
console.log('uuid                ' + archive.uuid);
console.log('allEntryCount       ' + archive.allEntryCount);
console.log('entryCount          ' + archive.entryCount);
console.log('articleCount        ' + archive.articleCount);
console.log('mediaCount          ' + archive.mediaCount);
console.log('newNamespaceScheme  ' + archive.hasNewNamespaceScheme);
console.log('hasFulltextIndex    ' + archive.hasFulltextIndex());
console.log('hasTitleIndex       ' + archive.hasTitleIndex());
console.log('mainEntry           ' + archive.mainEntry.path);

heading('Metadata');
for(const key of archive.metadataKeys) {
    let value = '';
    try {
        value = archive.getMetadata(key);
    } catch(err) {
        value = '<' + err.message + '>';
    }
    //Illustrations are binary and long
    if(value.length > 120) value = value.slice(0, 120) + '…';
    console.log(key.padEnd(20) + value.replace(/\n/g, ' '));
}

//A sample of paths, so we can see the namespaces in use and how many entries are articles
heading('First 30 entries by path');
let shown = 0;
for(const entry of archive.iterByPath()) {
    console.log((entry.isRedirect ? 'R ' : '  ') + entry.path.padEnd(50) + entry.title);
    if(++shown >= 30) break;
}

heading('Namespace histogram over the first 20000 entries');
const namespaces = {};
let redirects = 0;
let counted = 0;
for(const entry of archive.iterByPath()) {
    const ns = entry.path.includes('/') ? entry.path.slice(0, entry.path.indexOf('/')) : '<root>';
    namespaces[ns] = (namespaces[ns] || 0) + 1;
    if(entry.isRedirect) redirects++;
    if(++counted >= 20000) break;
}
Object.entries(namespaces)
    .sort((a, b) => b[1] - a[1])
    .forEach(([ns, n]) => console.log(ns.padEnd(20) + n));
console.log('(redirects among those: ' + redirects + ')');

function sampleArticle(path) {
    heading('Sample article: ' + path);
    if(!archive.hasEntryByPath(path)) {
        console.log('not present by path; trying by title');
        if(!archive.hasEntryByTitle(path)) {
            console.log('not present by title either');
            return;
        }
    }
    const entry = archive.hasEntryByPath(path) ? archive.getEntryByPath(path) : archive.getEntryByTitle(path);
    console.log('path       ' + entry.path);
    console.log('title      ' + entry.title);
    console.log('isRedirect ' + entry.isRedirect);

    const item = entry.getItem(true);
    console.log('mimetype   ' + item.mimetype);
    console.log('size       ' + item.size);

    const html = item.data.toString();

    const hrefs = [...html.matchAll(/<a\b[^>]*?href="([^"]*)"/gi)].map(m => m[1]);
    console.log('links      ' + hrefs.length + ' total, ' + new Set(hrefs).size + ' distinct');

    const shapes = {};
    for(const href of hrefs) {
        let shape;
        if(href.startsWith('#')) shape = 'fragment';
        else if(/^[a-z]+:/i.test(href)) shape = 'absolute (' + href.slice(0, href.indexOf(':')) + ':)';
        else if(href.startsWith('../')) shape = '../ relative';
        else if(href.startsWith('/')) shape = 'root relative';
        else shape = 'bare relative';
        shapes[shape] = (shapes[shape] || 0) + 1;
    }
    console.log('href shapes:');
    Object.entries(shapes).sort((a, b) => b[1] - a[1])
        .forEach(([shape, n]) => console.log('  ' + shape.padEnd(24) + n));

    console.log('first 15 hrefs:');
    hrefs.slice(0, 15).forEach(h => console.log('  ' + h));

    //The tags an article is built from decide what stage 3 has to strip.
    const classes = {};
    for(const m of html.matchAll(/class="([^"]*)"/g)) {
        for(const cls of m[1].split(/\s+/)) {
            if(cls) classes[cls] = (classes[cls] || 0) + 1;
        }
    }
    console.log('top 25 classes:');
    Object.entries(classes).sort((a, b) => b[1] - a[1]).slice(0, 25)
        .forEach(([cls, n]) => console.log('  ' + cls.padEnd(30) + n));

    console.log('first 1200 characters of the body:');
    console.log(html.slice(0, 1200));
}

sampleArticle(process.argv[3] || 'Christmas');
