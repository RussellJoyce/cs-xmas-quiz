'use strict';

//Turns a ZIM article's full MediaWiki HTML into the article for the round
//
// Strips references, citations, bibliographies, navboxes, infoboxes, in order to make the round sensible
// Strips tables, images, edit links, styles and scripts to make it renderable on a phone

const { parse } = require('node-html-parser');
const { hrefToPath } = require('./zim');

const DROP_SECTIONS = new Set([
    'References', 'Notes', 'Citations', 'Footnotes', 'Sources', 'Bibliography',
    'Further_reading', 'External_links', 'Works_cited', 'Explanatory_notes',
    'General_sources', 'Cited_works', 'Notes_and_references', 'References_and_notes'
]);

const DROP_SELECTORS = [
    'style', 'script', 'noscript',
    'sup.reference',            //the [1] [2] markers
    '.mw-references-wrap', '.reflist', 'ol.references',
    '.citation', '.cs1', '.cs2',  //citation templates, wherever they sit outside a reflist
    '.navbox', '.navbox-styles', '.vertical-navbox', '.sistersitebox', '.side-box',
    '.mw-editsection', '.metadata', '.ambox', '.hatnote', '.thumb', '.gallery',
    'figure', 'img', 'audio', 'video',
    '.shortdescription', '.mw-empty-elt', '.noprint', '.mw-kartographer-map'
];

const INFOBOX_SELECTORS = ['.infobox', '.infobox_v2', '.sidebar'];

function dropSections(root, ids) {
    const headings = root.querySelectorAll('div.mw-heading');

    //Collected before removing anything: removing as we iterate would invalidate the list.
    const doomed = [];
    for(const wrapper of headings) {
        const h = wrapper.querySelector('h1, h2, h3, h4, h5, h6');
        if(!h) continue;
        const id = h.getAttribute('id');
        if(id && ids.has(id)) {
            doomed.push({ wrapper, level: parseInt(h.tagName.slice(1), 10) });
        }
    }

    for(const { wrapper, level } of doomed) {
        const parent = wrapper.parentNode;
        if(!parent) continue;
        const siblings = parent.childNodes;
        let i = siblings.indexOf(wrapper);
        if(i < 0) continue;

        const toRemove = [wrapper];
        for(let j = i + 1; j < siblings.length; j++) {
            const node = siblings[j];
            //Stop at the next heading at this level or shallower; deeper subsections
            //belong to the section being removed and go with it.
            if(node.tagName === 'DIV' && node.classList && node.classList.contains('mw-heading')) {
                const h = node.querySelector('h1, h2, h3, h4, h5, h6');
                if(h && parseInt(h.tagName.slice(1), 10) <= level) break;
            }
            toRemove.push(node);
        }
        toRemove.forEach(node => node.remove());
    }
}

//Rewrites every surviving anchor.
function rewriteLinks(root, canonical) {
    const links = [];
    for(const a of root.querySelectorAll('a')) {
        const target = canonical(hrefToPath(a.getAttribute('href')));
        if(target === null) {
            //Replace the anchor with its own text, so the sentence still reads properly.
            a.replaceWith(a.innerHTML);
            continue;
        }
        a.setAttribute('data-s', target);
        a.removeAttribute('href');
        a.removeAttribute('title');
        a.removeAttribute('class');
        a.removeAttribute('rel');
        links.push(target);
    }
    return links;
}

//Attributes we do not want reaching the phone
function stripAttributes(root) {
    for(const el of root.querySelectorAll('*')) {
        for(const name of Object.keys(el.attributes)) {
            if(/^on/i.test(name)) el.removeAttribute(name);
        }
        if(el.tagName === 'A') continue; //already handled, and data-s must survive
        el.removeAttribute('id');
        el.removeAttribute('style');
        el.removeAttribute('class');
        el.removeAttribute('about');
        el.removeAttribute('typeof');
        el.removeAttribute('data-mw');
    }
}

//html    the article's full HTML from the ZIM
//canonical(path) -> shipped path, or null if the link leaves the corpus
//options.keepInfoboxes   include infoboxes (denser graph, easier round)
//options.maxChars        truncate the body, dropping whole trailing children
function renderArticle(html, canonical, options) {
    const opts = options || {};
    const root = parse(html, { blockTextElements: { script: false, noscript: false, style: false } });

    const body = root.querySelector('#mw-content-text .mw-parser-output')
              || root.querySelector('.mw-parser-output')
              || root.querySelector('#mw-content-text');
    if(!body) return null;

    const selectors = opts.keepInfoboxes ? DROP_SELECTORS : DROP_SELECTORS.concat(INFOBOX_SELECTORS);
    for(const selector of selectors) {
        for(const el of body.querySelectorAll(selector)) el.remove();
    }
    if(!opts.keepInfoboxes) {
        for(const el of body.querySelectorAll('table')) el.remove();
    }

    dropSections(body, DROP_SECTIONS);

    //Truncation happens before links are collected
    if(opts.maxChars && body.innerHTML.length > opts.maxChars) {
        let total = 0;
        const keep = [];
        for(const node of body.childNodes) {
            const len = node.toString().length;
            if(total + len > opts.maxChars && keep.length > 0) break;
            keep.push(node);
            total += len;
        }
        body.set_content(keep);
    }

    const links = rewriteLinks(body, canonical);
    stripAttributes(body);

    return {
        html: body.innerHTML.replace(/\s+/g, ' ').trim(),
        links: links,
        outlinks: [...new Set(links)]
    };
}

module.exports = { renderArticle, DROP_SECTIONS, DROP_SELECTORS, INFOBOX_SELECTORS };
