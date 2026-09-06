'use strict';

// Drops navigation pages, then takes the top N by in-degree.
//Reads corpus/build/{articles.json, indegree.bin, real.bin}. Writes corpus/build/selected.json.

const fs = require('fs');
const path = require('path');

const BUILD = path.join(__dirname, 'corpus', 'build');
const TARGET = parseInt(process.env.QUIZ_CANDIDATES || '30000', 10);

//Each rule names itself so the run can report what it removed and roughly why
const REJECT = [
    ['list',          /^(List|Lists|Index|Outline|Timeline|Glossary|Comparison|Bibliography|Filmography|Discography)_of_/i],
    ['disambig',      /_\((disambiguation|surname|given_name|name)\)$/i],
    //Three digits and up: "0" and "12" are articles about the numbers, not about years.
    ['year',          /^\d{3,4}(_(BC|AD|BCE|CE))?$/],
    ['year_in',       /^\d{1,4}(_(BC|AD))?_(in|at)_/i],
    ['decade',        /^\d{2,4}s(_(BC|AD))?$/],
    //Anchored, or it eats "20th_Century_Studios".
    ['century',       /^\d{1,2}(st|nd|rd|th)_(century|millennium)(_(BC|AD|BCE|CE))?$/i],
    //Days are 1-31, or "May_68" (the 1968 protests) reads as a date and is thrown away.
    ['calendar_date', /^(3[01]|[12][0-9]|[1-9])_(January|February|March|April|May|June|July|August|September|October|November|December)$/i],
    ['calendar_date', /^(January|February|March|April|May|June|July|August|September|October|November|December)_(3[01]|[12][0-9]|[1-9])$/i],
    ['iso_like',      /^\d{4}[-–]\d{2,4}$/],
    ['meta',          /^(Portal|Category|Template|Help|Wikipedia|File|Draft|Module|MediaWiki|Special|Talk):/i],
    ['election',      /^\d{4}_[A-Z].*_(election|elections)$/i],
    ['sports_season', /^\d{4}([-–]\d{2,4})?_(in_)?[A-Z].*_(season|Olympics|World_Cup|Championship|Championships)$/i],
    //Titles that are almost all punctuation or a single character are entries like "!"
    ['not_a_subject', /^[^A-Za-z0-9]{1,3}$/]
];

function rejectionFor(slug) {
    for(const [name, re] of REJECT) {
        if(re.test(slug)) return name;
    }
    return null;
}

function main() {
    const { slugs, titles } = JSON.parse(fs.readFileSync(path.join(BUILD, 'articles.json'), 'utf8'));
    const raw = fs.readFileSync(path.join(BUILD, 'indegree.bin'));
    const indegree = new Int32Array(raw.buffer, raw.byteOffset, raw.length / 4);
    const isStub = new Uint8Array(fs.readFileSync(path.join(BUILD, 'real.bin')));

    if(indegree.length !== slugs.length) {
        throw new Error('indegree.bin has ' + indegree.length + ' entries but articles.json has ' + slugs.length);
    }
    let real = 0;
    for(let i = 0; i < isStub.length; i++) if(!isStub[i]) real++;
    console.log(slugs.length.toLocaleString() + ' article entries, of which ' +
                real.toLocaleString() + ' are real and ' +
                (slugs.length - real).toLocaleString() + ' are placeholders\n');

    //---- Filter -----------------------------------------------------------------------

    const dropped = {};
    const examples = {};
    const kept = [];

    for(let id = 0; id < slugs.length; id++) {
        if(isStub[id]) continue; //not an article at all, so not a candidate
        const why = rejectionFor(slugs[id]);
        if(why) {
            dropped[why] = (dropped[why] || 0) + 1;
            //Keep the highest in-degree example of each rule
            if(!examples[why] || indegree[id] > indegree[examples[why]]) examples[why] = id;
            continue;
        }
        kept.push(id);
    }

    console.log('dropped as navigation rather than subject matter:');
    Object.entries(dropped).sort((a, b) => b[1] - a[1]).forEach(([why, n]) => {
        const eg = examples[why];
        console.log('  ' + why.padEnd(15) + String(n).padStart(7) +
                    '   e.g. ' + slugs[eg] + ' (in-degree ' + indegree[eg] + ')');
    });
    console.log('  ' + 'TOTAL'.padEnd(15) + String(real - kept.length).padStart(7));
    console.log('\nsurviving: ' + kept.length.toLocaleString());

    //---- Rank and take ----------------------------------------------------------------

    kept.sort((a, b) => indegree[b] - indegree[a]);
    const selected = kept.slice(0, TARGET);

    console.log('selected:  ' + selected.length.toLocaleString() +
                ' (in-degree ' + indegree[selected[selected.length - 1]] +
                ' and above)\n');

    console.log('top 30 selected:');
    selected.slice(0, 30).forEach((id, i) =>
        console.log('  ' + String(i + 1).padStart(3) + '  ' + String(indegree[id]).padStart(6) + '  ' + slugs[id]));

    console.log('\nlast 15 selected (the cut line):');
    selected.slice(-15).forEach(id =>
        console.log('        ' + String(indegree[id]).padStart(6) + '  ' + slugs[id]));

    fs.writeFileSync(path.join(BUILD, 'selected.json'), JSON.stringify({
        ids: selected,
        slugs: selected.map(id => slugs[id]),
        titles: selected.map(id => titles[id]),
        indegree: selected.map(id => indegree[id])
    }));
    console.log('\nwrote ' + path.join(BUILD, 'selected.json'));
}

main();
