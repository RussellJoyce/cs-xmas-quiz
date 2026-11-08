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
| `stage5-emit.js` | 3 min | Writes the article files, index, graph and the curated puzzles into `nodeserver/static/wiki/`. |
| `verify.js` | 2s | End-to-end validation. |

`node stage5-emit.js puzzles` regenerates just `puzzles.json` from `puzzles.curated.json`, which is quick.

Articles are cut to their first 1000 words, at a paragraph boundary, so nothing in the round is a
wall of text. The cut happens before links are collected, so the graph only has links a team can
actually see. Set `QUIZ_MAX_WORDS` to change it (`0` ships whole articles); stages 2 and 5 must
agree, so rerun from stage 2 after changing it.

Each puzzle carries the shortest route from its start to its target, as `route` (titles, so
the file reads on its own) and `routeIds` (article ids). That line depends only on the corpus
and the two endpoints — nothing about a race in progress can change it — so it is worked out
here rather than at run time, and whoever picks a question can see what it should have taken.

Most pairs have many equally short routes. Besides the first one the walk finds, each puzzle
records `routeCount` (how many there are) and up to four more chosen at random from all of them,
as `moreRoutes` and `moreRouteIds`. The sampling is seeded by the pair, so a rebuild picks the
same ones. The host's panel lists them all. `verify.js` checks every recorded route is walkable
through the shipped article files and that nothing shorter exists.

## Choosing puzzles

Every puzzle is picked by hand: nothing is generated. `explore.js` is for finding them, on
the shipped corpus, so its distances are the ones the game enforces.

    node explore.js find pope                  exact titles, most linked-to first
    node explore.js route Scallop "Cyndi Lauper"   distance, route count, sample routes
    node explore.js near --to Cat --hops 5     well-known starts 5 hops from Cat
    node explore.js near --from York --hops 5 --sort routes   the most forgiving first
    node explore.js random --hops 7 --famous 15000   random pairs to browse
    node explore.js random --hops 5 --min-routes 5000   ...leaving out the frustrating ones
    node explore.js add Scallop "Cyndi Lauper" "Shellfish to synth-pop"
    node explore.js curated                    what has been picked, checked against this corpus

`add` writes to `puzzles.curated.json`, which is checked in and keyed by title so it survives
a rebuild. To change the list by hand, edit that file, never `puzzles.json`.
`node stage5-emit.js puzzles` turns it into `puzzles.json`, in the same order, and the host's
picker shows the note above the routes. A
curated pair whose title is missing from a rebuilt corpus is reported and left out.

Every listing shows how forgiving a pair is as "routes": "6 / 204" means 6 shortest routes
and 204 one hop longer. Teams seldom find a shortest route, so the second number is the better
guide to whether a race will frustrate. Both are exact: for a pair d apart a walk of d or d+1
links cannot visit an article twice, so counting walks, which is cheap, counts routes.

Two more things worth knowing when picking. Famous articles are rarely more than 6 hops apart, so
longer routes need an obscure end (raise `--famous`). And a target with only ten or so links in
is hard to find at all, however many routes lead to it.

## Output

`nodeserver/static/wiki/`, around 260 MB:

    a/<id/1000>/<id>.json    {t: title, h: html, l: [linked id, ...]}
    index.json               titles and slugs by id
    graph.bin                CSR adjacency for the server's move validation
    puzzles.json             candidate start/target pairs, each with its ideal line
