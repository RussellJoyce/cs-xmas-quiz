# Wikirace corpus tools

Turns a Kiwix ZIM into the offline article corpus the wikirace round is played on.

    curl -LO https://download.kiwix.org/zim/wikipedia/wikipedia_en_top_nopic_2026-06.zim

    npm install
    node stage0-check.js
    node stage1-index.js
    node stage2-graph.js
    node stage3-select.js
    node stage4-prune.js
    node stage5-emit.js
    node verify.js

| | | |
|---|---|---|
| `stage1-index.js` | 4s | Gives every article an integer id and resolves redirects. |
| `stage2-graph.js` | 5 min | Renders every article and builds the link graph of the rendered bodies. |
| `stage3-select.js` | 2s | Drops navigation pages, then takes the top N by in-degree. |
| `stage4-prune.js` | 5s | Keeps the largest strongly connected component. |
| `stage5-emit.js` | 3 min | Writes the article files, index, graph and puzzle candidates into `nodeserver/static/wiki/`. |
| `verify.js` | 2s | End-to-end validation. |

`node stage5-emit.js puzzles` regenerates just `puzzles.json`, which is quick.

Articles are cut to their first 1000 words, at a paragraph boundary, so nothing in the round is a
wall of text. The cut happens before links are collected, so the graph only has links a team can
actually see. Set `QUIZ_MAX_WORDS` to change it (`0` ships whole articles); stages 2 and 5 must
agree, so rerun from stage 2 after changing it.

Each puzzle carries the shortest route from its start to its target, as `route` (titles, so
the file reads on its own) and `routeIds` (article ids). That line depends only on the corpus
and the two endpoints — nothing about a race in progress can change it — so it is worked out
here rather than at run time, and whoever picks a question can see what it should have taken.

Most pairs have many equally short routes; this records the first one the walk finds, so it is
*a* shortest route rather than *the* one. `verify.js` checks every recorded route is walkable
through the shipped article files and that nothing shorter exists.

## Output

`nodeserver/static/wiki/`, around 260 MB:

    a/<id/1000>/<id>.json    {t: title, h: html, l: [linked id, ...]}
    index.json               titles and slugs by id
    graph.bin                CSR adjacency for the server's move validation
    puzzles.json             candidate start/target pairs, each with its ideal line
