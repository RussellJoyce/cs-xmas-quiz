'use strict';

/*
The wikirace client.

A single page that never navigates. Clicking a link asks the server for permission and
renders whatever it authorises, so the URL never changes, the browser's Back button is not
a way out of the round, and the team's history lives on the server where it can be scored.

It shares the buzzer's connection and its socket protocol, and swaps places with the
buzzer page when the round starts and ends. The two are never open at once: the server
keys a client by address and keeps a single socket per client, so a second tab would
quietly displace the first one's connection.
*/

var articleEl = document.getElementById("article");
var titleEl = document.getElementById("title");
var pageEl = document.getElementById("page");
var targetEl = document.getElementById("target");
var hopsEl = document.getElementById("hops");
var clockEl = document.getElementById("clock");
var hereEl = document.getElementById("here");
var backEl = document.getElementById("back");
var curtainEl = document.getElementById("curtain");
var curtainIcon = document.getElementById("curtainIcon");
var curtainText = document.getElementById("curtainText");
var curtainSub = document.getElementById("curtainSub");
var toastEl = document.getElementById("toast");

var ws = null;
var myid = 0;

//How the article files are sharded. Read from the corpus rather than hardcoded, so a
//rebuild that changes it does not silently 404 every article.
var shard = 1000;

var racing = false;      //a race is running and we may still move
var targetId = -1;
var currentId = -1;
var hops = 0;
var startedAt = 0;
var clockTimer = null;

//Articles already fetched. A team goes back and forth over the same few pages constantly,
//and re-fetching makes the round feel sluggish for no reason.
var cache = {};

//A move we have sent and not yet heard back about. Until the server answers, another tap
//must not queue a second move: the first one may be refused, and the second would then be
//judged against the wrong page.
var awaiting = false;

//Which article render is the current one. Fetches are asynchronous, so two of them can be
//in flight at once (a fast Back on top of a slow article, say) and they can land in either
//order. Without this the older response would overwrite the newer one and leave the team
//looking at a page the server does not think it is on, with every visible link refused.
var renderSeq = 0;


/*---------------------------------------------------------------------------------------
  Connection
---------------------------------------------------------------------------------------*/

function connect() {
    ws = new WebSocket(QuizConnection.url());

    ws.onopen = function() {
        //Ask who we are. If a race is running the server follows up with the race and the
        //article we were last on, so a phone that slept comes back where it left off.
        ws.send('re');
    };

    ws.onmessage = function(event) {
        var data = String(event.data);
        switch(data.slice(0, 2)) {
            case "ok":
                myid = parseInt(data.slice(2), 10);
                //If a race were running the server would have followed this with a "wr".
                //Nothing arriving means the host has not started one yet.
                if(!racing) waiting();
                break;

            case "vi":
            case "vs":
                //The round has moved on. This page only exists for the wikirace, so
                //anything else means going back to the buzzer.
                if(data.slice(2) !== "wikirace") {
                    QuizConnection.go("/");
                }
                break;

            case "wr":
                startRace(data.slice(2));
                break;

            case "pb":
                break;   //pong

            case "wg": {
                //Authorised. This is the only thing that ever changes what is on screen,
                //and the hop count comes with it: the client never counts its own taps,
                //so a refused move and a mid-race reconnect both stay honest.
                awaiting = false;
                var parts = data.slice(2).split(",");
                setHops(parseInt(parts[1], 10));
                showArticle(parseInt(parts[0], 10));
                break;
            }

            case "wx":
                //Refused. Should be rare: it means this page is showing something the
                //server does not think we are on.
                awaiting = false;
                toast("That is not a link on this page");
                break;

            case "wf":
                arrived();
                break;

            case "we":
                timeUp();
                break;

            case "px":
                //We do not hold a team, so we have no business being here.
                QuizConnection.go("/");
                break;
        }
    };

    ws.onclose = function() {
        ws = null;
        racing = false;
        curtain("🤒", "Lost the connection", "Trying again…");
        setTimeout(connect, 1000);
    };

    ws.onerror = function() {
        if(ws) ws.close();
    };
}

function send(message) {
    if(ws && ws.readyState === WebSocket.OPEN) ws.send(message);
}


/*---------------------------------------------------------------------------------------
  The race
---------------------------------------------------------------------------------------*/

//"wr<startId>,<targetId>,<startTitle>|<targetTitle>"
//
//The titles are pipe-separated and last because article titles contain commas
//("Washington, D.C.") and cannot contain a pipe.
function startRace(payload) {
    var comma1 = payload.indexOf(",");
    var comma2 = payload.indexOf(",", comma1 + 1);
    if(comma1 < 0 || comma2 < 0) return;

    var start = parseInt(payload.slice(0, comma1), 10);
    targetId = parseInt(payload.slice(comma1 + 1, comma2), 10);
    var titles = payload.slice(comma2 + 1).split("|");

    targetEl.textContent = titles[1] || ("#" + targetId);

    //This only sets up the race. The server always follows it with a "wg" — the start
    //article at the beginning, or wherever the team actually is on a resync — and that is
    //the single thing that decides which page is on screen.
    racing = true;
    awaiting = false;

    if(!clockTimer) {
        startedAt = Date.now();
        clockTimer = setInterval(tickClock, 1000);
        tickClock();
    }
}

function setHops(n) {
    hops = (n >= 0) ? n : 0;
    hopsEl.textContent = hops;
}

function waiting() {
    curtainEl.classList.remove("won");
    curtain("⏳", "Ready", "Waiting for the race to start.");
}

function tickClock() {
    var secs = Math.floor((Date.now() - startedAt) / 1000);
    clockEl.textContent = Math.floor(secs / 60) + ":" + (secs % 60 < 10 ? "0" : "") + (secs % 60);
}

function stopClock() {
    if(clockTimer) { clearInterval(clockTimer); clockTimer = null; }
}

function arrived() {
    racing = false;
    stopClock();
    curtainEl.classList.add("won");
    curtain("🎉", "You made it!", "In " + hops + " hop" + (hops === 1 ? "" : "s") +
                                  " and " + clockEl.textContent + ".");
}

function timeUp() {
    if(!racing) return;   //already arrived; leave the celebration up
    racing = false;
    stopClock();
    curtain("⏱", "Time!", "You got as far as " + (titleEl.textContent || "the start") + ".");
}


/*---------------------------------------------------------------------------------------
  Articles
---------------------------------------------------------------------------------------*/

function articleUrl(id) {
    return "/wiki/a/" + Math.floor(id / shard) + "/" + id + ".json";
}

function showArticle(id) {
    var seq = ++renderSeq;

    if(cache[id]) {
        render(id, cache[id]);
        return;
    }
    curtain("📖", "Loading…", "");
    fetch(articleUrl(id))
        .then(function(r) {
            if(!r.ok) throw new Error("HTTP " + r.status);
            return r.json();
        })
        .then(function(article) {
            cache[id] = article;
            //Something newer was asked for while this was in flight. Caching it is still
            //worth doing; putting it on screen is not.
            if(seq !== renderSeq) return;
            render(id, article);
        })
        .catch(function(err) {
            if(seq !== renderSeq) return;
            //A missing article is a broken corpus, and there is nothing the team can do
            //about it, so say so plainly rather than leaving a blank page.
            curtain("😵", "Could not load that page", String(err.message));
        });
}

function render(id, article) {
    currentId = id;
    titleEl.textContent = article.t;
    //The HTML comes from our own build, which strips scripts, styles, event handlers and
    //everything else that is not text and links. See tools/wiki/lib/render.js.
    articleEl.innerHTML = article.h;
    hereEl.textContent = article.t;
    pageEl.scrollTop = 0;
    if(racing) hideCurtain();
}


/*---------------------------------------------------------------------------------------
  Input
---------------------------------------------------------------------------------------*/

//One delegated handler rather than one per link: an article has up to 633 of them.
articleEl.addEventListener("click", function(event) {
    if(!racing || awaiting || !myid) return;

    var link = event.target.closest("a[data-s]");
    if(!link) return;
    event.preventDefault();

    var to = parseInt(link.getAttribute("data-s"), 10);
    if(!(to >= 0)) return;

    //Nothing changes here but the fact that we are waiting. The screen and the hop
    //count only move when the server says so.
    awaiting = true;
    send("wl" + myid + "," + to);
});

function goBack() {
    if(!racing || awaiting || !myid) return;
    if(hops <= 0) return;

    awaiting = true;
    send("wb" + myid);
}

backEl.addEventListener("click", goBack);

/*
The phone's own back gesture.

Leaving this alone meant a swipe took the team out of the round entirely, back to the
buzzer, which bounced them straight here again — and every one of those round trips is a
resync. Swallowing it instead, and treating it as the round's own Back, is both what the
team meant by the gesture and one fewer way to fall out of the race. The host decides when
anyone leaves the round; the client is sent back to the buzzer when they do.

A sentinel history entry is pushed so that there is always something for the gesture to
consume, and pushed again each time one is used up.
*/
history.pushState({ wikirace: true }, "", location.href);
window.addEventListener("popstate", function() {
    history.pushState({ wikirace: true }, "", location.href);
    goBack();
});

//iOS fires a synthetic click 300ms after a touch and will happily double-fire on a
//double tap. The buzzer page suppresses the same thing.
document.addEventListener("touchend", function(event) {
    var now = Date.now();
    if(now - lastTouchEnd <= 400) event.preventDefault();
    lastTouchEnd = now;
}, false);
var lastTouchEnd = 0;

document.addEventListener("gesturestart", function(e) { e.preventDefault(); });


/*---------------------------------------------------------------------------------------
  Chrome
---------------------------------------------------------------------------------------*/

function curtain(icon, text, sub) {
    curtainIcon.textContent = icon;
    curtainText.textContent = text;
    curtainSub.textContent = sub || "";
    curtainEl.classList.remove("hidden");
}

function hideCurtain() {
    curtainEl.classList.add("hidden");
}

var toastTimer = null;
function toast(message) {
    toastEl.textContent = message;
    toastEl.classList.add("show");
    if(toastTimer) clearTimeout(toastTimer);
    toastTimer = setTimeout(function() { toastEl.classList.remove("show"); }, 1800);
}


/*---------------------------------------------------------------------------------------
  Start
---------------------------------------------------------------------------------------*/

curtain("🌐", "Connecting…", "");

//How the corpus is laid out. Without it we cannot fetch anything, so the race waits.
fetch("/wiki/meta.json")
    .then(function(r) { return r.json(); })
    .then(function(meta) {
        shard = meta.shard || shard;
        connect();
    })
    .catch(function() {
        curtain("😵", "No corpus", "The quiz server has no wiki corpus built.");
    });

//Same keepalive as the buzzer: the server tracks who is alive by these.
setInterval(function() {
    if(ws && ws.readyState === WebSocket.OPEN) ws.send("pi");
}, 5000);
