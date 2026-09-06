'use strict';

//Shared helpers for reading the wikirace source ZIM.


const path = require('path');

const DEFAULT_ZIM = path.join(__dirname, '..', 'corpus', 'wikipedia_en_top_nopic_2026-06.zim');
const MAX_REDIRECT_HOPS = 8;

function openArchive(file) {
    const { Archive } = require('@openzim/libzim');
    return new Archive(file || process.env.QUIZ_ZIM || DEFAULT_ZIM);
}

//Turns an href as written in the HTML into the entry path it refers to, or null if it is
//not a link to an article in this ZIM at all.
function hrefToPath(href) {
    if(!href) return null;
    if(href.startsWith('#')) return null;
    if(/^[a-z][a-z0-9+.-]*:/i.test(href)) return null; //scheme, so off-corpus
    if(href.startsWith('/') || href.startsWith('../') || href.startsWith('./')) return null;

    //Strip the fragment first: "Turkey#Etymology" is a link to Turkey.
    let p = href.split('#')[0].split('?')[0];
    if(!p) return null;

    try {
        p = decodeURIComponent(p);
    } catch(err) {
        return null;
    }
    return p;
}

//Parsing html with a regex, naughty but we only need to extract the hrefs from <a> tags
function extractHrefs(html) {
    const out = [];
    for(const m of html.matchAll(/<a\b[^>]*?\shref="([^"]*)"/gi)) {
        out.push(m[1]);
    }
    return out;
}

//Follows a redirect entry to the article it eventually lands on
function resolveRedirect(entry) {
    let current = entry;
    for(let hop = 0; hop < MAX_REDIRECT_HOPS; hop++) {
        if(!current.isRedirect) return current;
        try {
            current = current.redirectEntry;
        } catch(err) {
            return null;
        }
    }
    return null;
}

//Progress reporting
function progress(label, every) {
    const started = Date.now();
    let last = started;
    return {
        tick: function(n) {
            if(n % every !== 0) return;
            const now = Date.now();
            const rate = Math.round(every / ((now - last) / 1000));
            last = now;
            console.log('  ' + label + ' ' + n.toLocaleString() + '  (' + rate.toLocaleString() + '/s)');
        },
        done: function(n) {
            const secs = (Date.now() - started) / 1000;
            console.log('  ' + label + ' ' + n.toLocaleString() + ' in ' + secs.toFixed(1) + 's');
            return secs;
        }
    };
}

module.exports = { openArchive, hrefToPath, extractHrefs, resolveRedirect, progress, DEFAULT_ZIM };
