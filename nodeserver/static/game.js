var buzzer = document.getElementById("buzzer");
var geoimg = document.getElementById("geoimg");
var geomark = document.getElementById("geomark");
var textbox = document.getElementById("textbox");
var textenterbutton = document.getElementById("textenterbutton");
var textform = document.getElementById("textform");
var higherlower = document.getElementById("higherlower");
var higher = document.getElementById("higher");
var lower = document.getElementById("lower");
var wavetrack = document.getElementById("wavetrack");
var wavehandle = document.getElementById("wavehandle");
var wavevalue = document.getElementById("wavevalue");
var multigrid = document.getElementById("multigrid");
var wallgrid = document.getElementById("wallgrid");


var ws;
var myid = 0;

//Whether the buttons are currently live, so that tiles built later start in the right state
var buttonsOn = true;

//Remembers the last view that we were set to, in the event that we are disconnected
//This also therefore sets the initial view
var lastview = "buzzer";


/*
When we connect to the server we set up a websocket with the appropriate handlers.
*/
function connect() {
    //The server opens the client websocket port on 8090 (wss)
    ws = new WebSocket(QuizConnection.url());

    //When the test harness is showing this page, it drives the team through our socket.
    try {
        if(window.parent !== window && window.parent.quizPhoneSocket) {
            window.parent.quizPhoneSocket(window, ws);
        }
    } catch(err) {}

    ws.onopen = function(event) {
        //We we have connected, ask which team we are
        ws.send('re');
        console.log("(Re)connected. Setting view to " + lastview);
        setView(lastview);
    };

    ws.onmessage = function (event) {
        //Messages from the server:
        switch(event.data.slice(0,2)) {
            case "ok":
                //We are told what team we are
                myid = event.data.slice(2);
                buzzer.innerHTML = "TEAM " + myid;
                console.log("Server gave us ID " + myid);
                //Repaint out of the "no connection" grey, but into whatever state we were
                //last told to be in. Being given our ID back does not re-enable us.
                toggleState(buttonsOn);
                break;
            case "px":
                //The team we reqested wasn't available
                document.getElementById("teamtitle").innerHTML = "<span class=\"error\">Team already taken</span> <hr>";
                setTimeout(function(){document.getElementById("teamtitle").innerHTML = "Please select your team <hr>" }, 2000);
                break;
            case "on":
                toggleState(true);
                console.log("button on");
                break;
            case "of":
                toggleState(false);
                console.log("button off");
                break;
            case "vi":
                //Set our view, clearing whatever we were part way through answering.
                console.log("Server requests setting view: " + event.data.slice(2));
                applyView(event.data.slice(2));
                break;
            case "vs":
                //Put us on a view only if we are not already there
                if(event.data.slice(2) == lastview) {
                    console.log("Already on view " + lastview + ", ignoring the resync");
                } else {
                    console.log("Resync moves us from " + lastview + " to " + event.data.slice(2));
                    applyView(event.data.slice(2));
                }
                break;
            case "im":
                //Set the geo image
                console.log("Setting geo image: " + event.data.slice(2));
                //A new image is a new question, so the old guess goes, but a team that is
                //out stays out.
                geomark.style.display = "none";
                geoimg.style.backgroundImage = "url('geography/" + encodeURIComponent(event.data.slice(2)) + "')";
                break;
            case "mo":
                //Build the multiple choice grid: "mo<options>,<style>"
                console.log("Setting multiple choice options: " + event.data.slice(2));
                setMultiOptions(event.data.slice(2));
                break;
            case "ms":
                //Our selection was accepted, so light up that tile
                setMultiSelection(parseInt(event.data.slice(2), 10));
                break;
            case "hh":
                //Add class .higherLowerSelected to the higher button
                console.log("Higher was accepted by server");
                document.getElementById("higher").classList.add("higherLowerSelected");
                document.getElementById("lower").classList.remove("higherLowerSelected");
                break;
            case "hl":
                //Add class .higherLowerSelected to the lower button
                console.log("Lower was accepted by server");
                document.getElementById("lower").classList.add("higherLowerSelected");
                document.getElementById("higher").classList.remove("higherLowerSelected");
                break;
            case "hn":
                //Reset selection
                document.getElementById("higher").classList.remove("higherLowerSelected");
                document.getElementById("lower").classList.remove("higherLowerSelected");
                break;
            case "h1":
                document.getElementById("higher").innerHTML = "<span>HIGHER</span>";
                document.getElementById("lower").innerHTML = "<span>LOWER</span>";
                break;
            case "h2":
                document.getElementById("higher").innerHTML = "<span>TRUE</span>";
                document.getElementById("lower").innerHTML = "<span>FALSE</span>";
                break;
            case "cw":
                //The connecting wall, in the order the main screen shows it: "cw<word>|<word>|..."
                setWall(event.data.slice(2));
                break;
            case "cs":
                //One of our guesses was a group
                wallResult(event.data.slice(2), true);
                break;
            case "cx":
                //One of our guesses was not a group
                wallResult(event.data.slice(2), false);
                break;
            case "cf":
                //Time is up on the wall
                freezeWall();
                break;
            case "pb":
                //Pong from the server
                break;
        }
    }

    ws.onclose = connectionLost;

    ws.onerror = function(event) {
        /* If the websocker errors then disconnect, which will fire the ws.onclose handler. */
        ws.close()
    }
}

//From onclose, or from the keepalive when a connection has died without closing
function connectionLost() {
    setView("buzzer");
    console.log("Disconnected");
    buzzer.innerHTML = "🤕 NO CONNECTION 🤒";
    buzzer.className = "theButton buttonOff view";
    ws = null;

    /* Attempt to reconnect every second */
    setTimeout(function() {
        console.log("Retry...");
        connect();
    }, 1000)
}


/*
Move to a new view, resetting everything
*/
function applyView(view) {
    lastview = view;

    //Per-question state that a view change always clears, whether or not we can answer.
    geomark.style.display = "none";

    if(view == "wikirace") {
        QuizConnection.go("/wikirace/");
        return;
    }

    if(view == "onlyconnect") {
        setView("onlyconnect");
        requestWall();
        toggleState(buttonsOn);
        return;
    }

    if(view == "text" || view == "numbers") {
        setView("text");
        textbox.type = (view == "numbers") ? "number" : "text";
        textbox.focus();
        removeTextmodeHandlers();
        textbox.value = "";
    } else if(view == "wavelength") {
        setView("wavelength");
        setWavelength(50, false);
    } else {
        setView(view);
    }

    //Last, so that it also catches a multiple choice grid built by an 'mo' that arrived
    //before this view change. Whether we can answer belongs to the team, not to the
    //question, so it survives moving between views.
    toggleState(buttonsOn);
}


function toggleState(on) {
    buttonsOn = on;

    if(on) {
        buzzer.className = "view theButton buttonOn";
        geoimg.className = "";
        higher.className = "higherLowerButton buttonOn";
        lower.className = "higherLowerButton buttonOn";

        //Coming back with an answer already typed keeps the Enter button lit for it.
        textbox.disabled = false;
        if(textbox.value !== "") {
            addTextmodeHandlers();
        }
    } else {
        buzzer.className = "view theButton buttonOff";
        geoimg.className = "imageDisabled";
        higher.className = "higherLowerButton buttonOff";
        lower.className = "higherLowerButton buttonOff";

        //Greys the box and, on a phone, puts the keyboard away, which is the clearest
        //signal there is that this team is not answering this one.
        textbox.disabled = true;
        removeTextmodeHandlers();
    }

    //The multiple choice tiles are built on the fly, and a selected one carries .multiSelected
    //on top of its on/off class, so they are toggled rather than rewritten.
    for(var i = 0; i < multiButtons.length; i++) {
        multiButtons[i].classList.toggle("buttonOn", on);
        multiButtons[i].classList.toggle("buttonOff", !on);
    }

    renderWall();
}


function setView(id) {
    var view = document.getElementById(id);
    if(!view) {
        console.log("No such view '" + id + "' in this page, ignoring");
        return;
    }

    var elements = document.getElementsByClassName('view')
    for (var i = 0; i < elements.length; i++){
        elements[i].style.display = 'none';
    }
    view.style.display = 'flex';

    if(id == "onlyconnect") {
        fitWall();
    }
}



/*
 * So 'touchstart' is the better event to use on iOS because it will fire even if the user is "gesturing".
 * However it is not supported on IE, of course. We shouldn't add both, so this detects whether touchstart is
 * available and if not resorts to mousedown, which on IE actually behaves better than on iOS for touch events.
*/
var eventtouse = "";
if ('ontouchstart' in document.documentElement) {
    eventtouse = 'touchstart';
} else {
    eventtouse = 'mousedown';
}

buzzer.addEventListener(eventtouse, function(event) {
    if(myid > 0 && myid <= 99) {
        ws.send('zz' + myid);
    }
});

higher.addEventListener(eventtouse, function(event) {
    if(myid > 0 && myid <= 99) {
        ws.send('hi' + myid);
    }
});

lower.addEventListener(eventtouse, function(event) {
    if(myid > 0 && myid <= 99) {
        ws.send('lo' + myid);
    }
});


/*
The Enter button is the feedback for the text rounds: dark until there is something to
send, lit once there is. A team that is out gets it taken away again, along with the box.
*/
function addTextmodeHandlers() {
    textenterbutton.addEventListener(eventtouse, textboxhandler);
    textform.addEventListener("onsubmit", textboxhandler);
    textform.addEventListener("submit", textboxhandler);
    textenterbutton.className = "smallButton smallButtonOn";
}

function removeTextmodeHandlers() {
    textenterbutton.removeEventListener(eventtouse, textboxhandler);
    textform.removeEventListener("onsubmit", textboxhandler);
    textform.removeEventListener("submit", textboxhandler);
    textenterbutton.className = "smallButton buttonOff";
}

function textboxhandler(event) {
    if(lastview == "numbers" && !(/^\d+$/.test(textbox.value))) {
        console.log("Invalid number format")

        document.getElementById("textenterbutton").innerHTML = "❌ Numbers Only 😵";
        setTimeout(function(){document.getElementById("textenterbutton").innerHTML = "Enter" }, 2000);

        return false;
    }

    if(myid > 0 && myid <= 99) {
        ws.send('tt' + myid + "," + textbox.value);
    }
    textbox.style.animationName = "textboxpulse";
    //removeTextmodeHandlers();

    return false //Prevent submission (and therefore a page reload)
}

textform.addEventListener("input", function() {
    addTextmodeHandlers();
});

textbox.addEventListener("webkitAnimationEnd", function() {
    textbox.style.animationName = "";
});


Number.prototype.clamp = function(min, max) {
  return Math.min(Math.max(this, min), max);
};

//When the image is clicked send the coords to the server
geoimg.addEventListener(eventtouse, function(event) {
    var rect = geoimg.getBoundingClientRect();

    if(eventtouse == 'mousedown') {
        tx = event.clientX;
        ty = event.clientY;
    } else {
        tx = event.touches[0].pageX;
        ty = event.touches[0].pageY;
    }

    var x = (tx - rect.left) / rect.width * 100;
    var y = (ty - rect.top) / rect.height * 100;
    geomark.style.left = (tx - rect.left) - 25; //div is 50x50
    geomark.style.top = (ty - rect.top) - 25;

    geomark.style.display = "block";

    x = x.clamp(0, 100);
    y = y.clamp(0, 100);

    ws.send('ii' + myid + "," + Math.round(x) + "," + Math.round(y));
});


/*
Wavelength: a bar running from 1 at the left end to 99 at the right.
*/
var WAVE_MIN = 1;
var WAVE_MAX = 99;
var WAVE_SEND_INTERVAL = 100; //Smallest gap between two 'wv' messages, in ms

var waveValue = 50;
var waveDragging = false;
var waveLastSent = 0;
var waveFlushTimer = null;

function setWavelength(value, send) {
    waveValue = Math.round(Math.min(WAVE_MAX, Math.max(WAVE_MIN, value)));
    wavehandle.style.left = ((waveValue - WAVE_MIN) / (WAVE_MAX - WAVE_MIN) * 100) + "%";
    wavevalue.innerHTML = waveValue;

    if(send) {
        sendWavelength(false);
    }
}

/*
A drag across the bar produces far more values than are worth sending, so they are throttled.
Whatever is swallowed is caught by a trailing timer, and `force` (the end of a drag) ignores
the throttle outright, so the value the finger comes to rest on is always the one the quiz
software ends up with.
*/
function sendWavelength(force) {
    if(!(myid > 0 && myid <= 99) || !ws || ws.readyState !== WebSocket.OPEN) {
        return;
    }

    var now = Date.now();
    var wait = WAVE_SEND_INTERVAL - (now - waveLastSent);

    if(force || wait <= 0) {
        if(waveFlushTimer) {
            clearTimeout(waveFlushTimer);
            waveFlushTimer = null;
        }
        waveLastSent = now;
        ws.send('wv' + myid + "," + waveValue);
    } else if(!waveFlushTimer) {
        waveFlushTimer = setTimeout(function() {
            waveFlushTimer = null;
            sendWavelength(true);
        }, wait);
    }
}

function waveValueFromX(clientX) {
    var rect = wavetrack.getBoundingClientRect();
    return WAVE_MIN + ((clientX - rect.left) / rect.width) * (WAVE_MAX - WAVE_MIN);
}

function wavePointerX(event) {
    if(event.touches && event.touches.length > 0) {
        return event.touches[0].clientX;
    }
    if(event.changedTouches && event.changedTouches.length > 0) {
        return event.changedTouches[0].clientX;
    }
    return event.clientX;
}

function waveStart(event) {
    waveDragging = true;
    setWavelength(waveValueFromX(wavePointerX(event)), true);
    event.preventDefault();
}

function waveMove(event) {
    if(!waveDragging) {
        return;
    }
    setWavelength(waveValueFromX(wavePointerX(event)), true);
    event.preventDefault();
}

function waveEnd(event) {
    if(!waveDragging) {
        return;
    }
    waveDragging = false;
    sendWavelength(true);
}

wavetrack.addEventListener('touchstart', waveStart);
wavetrack.addEventListener('touchmove', waveMove);
wavetrack.addEventListener('touchend', waveEnd);
wavetrack.addEventListener('touchcancel', waveEnd);
wavetrack.addEventListener('mousedown', waveStart);
document.addEventListener('mousemove', waveMove);
document.addEventListener('mouseup', waveEnd);


/*
Multiple choice: a grid of 2 to 6 tiles, labelled either A, B, C... or 1, 2, 3...
The quiz software decides how many there are and sends "mo<options>,<style>" whenever it
changes, which is also how a selection gets cleared for a new question.
*/
var MULTI_MIN = 2;
var MULTI_MAX = 6;

var multiCount = 0;
var multiButtons = [];

function multiColumns(count) {
    return count <= 3 ? count : 2;
}

function multiFontSize(columns, rows) {
    return "min(" + (80 / rows * 0.55).toFixed(2) + "vh, " + (80 / columns * 0.70).toFixed(2) + "vw)";
}

function multiLabel(index, style) {
    //index is 1-based, as it is on the wire
    return (style === "A") ? String.fromCharCode(64 + index) : String(index);
}

//Takes the payload of an "mo" message: "<options>,<style>"
function setMultiOptions(payload) {
    var parts = payload.split(",");
    var count = parseInt(parts[0], 10);
    var style = (parts[1] === "A") ? "A" : "1";

    if(!(count >= MULTI_MIN && count <= MULTI_MAX)) {
        console.log("Ignoring a multiple choice grid of " + parts[0] + " options");
        return;
    }

    var columns = multiColumns(count);
    var rows = Math.ceil(count / columns);
    multigrid.style.gridTemplateColumns = "repeat(" + columns + ", 1fr)";
    multigrid.style.gridTemplateRows = "repeat(" + rows + ", 1fr)";
    multigrid.style.fontSize = multiFontSize(columns, rows);

    multigrid.innerHTML = "";
    multiButtons = [];
    multiCount = count;

    for(var i = 1; i <= count; i++) {
        var tile = document.createElement("div");
        tile.className = "multiButton " + (buttonsOn ? "buttonOn" : "buttonOff");
        tile.id = "multibutton" + i;
        tile.innerHTML = multiLabel(i, style);
        tile.addEventListener(eventtouse, multiPressHandler(i));
        multigrid.appendChild(tile);
        multiButtons.push(tile);
    }
}

function multiPressHandler(option) {
    return function() {
        if(myid > 0 && myid <= 99) {
            ws.send("mc" + myid + "," + option);
        }
    };
}

function setMultiSelection(option) {
    for(var i = 0; i < multiButtons.length; i++) {
        if(i + 1 === option) {
            multiButtons[i].classList.add("multiSelected");
        } else {
            multiButtons[i].classList.remove("multiSelected");
        }
    }
}


/*
The connecting wall: sixteen tiles in the same fixed order as the main screen. Pick four and
they are sent to the quiz software, which answers "cs" (a group, which then stays green) or
"cx" (not a group, shown as crosses for a moment). Positions are 1-based on the wire.
*/
var WALL_SIZE = 16;
var WALL_WRONG_MS = 1000;   //How long the crosses stay up
var WALL_PENDING_MS = 4000; //How long to wait for a verdict before asking again
var WALL_MAX_FONT = 48;
var WALL_MIN_FONT = 8;

var wallWords = [];         //Empty until the quiz software starts the wall
var wallTiles = [];
var wallSolved = {};        //position → true
var wallSelected = [];      //positions, in the order they were picked
var wallWrong = {};         //position → true, while the crosses are showing
var wallPending = false;
var wallFrozen = false;
var wallWrongTimer = null;
var wallPendingTimer = null;

function requestWall() {
    if(myid > 0 && myid <= 99 && ws && ws.readyState === WebSocket.OPEN) {
        ws.send("cr" + myid);
    }
}

function clearWallTimers() {
    if(wallWrongTimer) clearTimeout(wallWrongTimer);
    if(wallPendingTimer) clearTimeout(wallPendingTimer);
    wallWrongTimer = null;
    wallPendingTimer = null;
}

//A new wall, or a blank one if the payload is empty. Either way, everything we had goes.
function setWall(payload) {
    clearWallTimers();
    wallWords = payload === "" ? [] : payload.split("|");
    wallSolved = {};
    wallSelected = [];
    wallWrong = {};
    wallPending = false;
    wallFrozen = false;

    wallgrid.innerHTML = "";
    wallTiles = [];
    for(var pos = 1; pos <= WALL_SIZE; pos++) {
        var tile = document.createElement("div");
        tile.addEventListener(eventtouse, wallPressHandler(pos));
        wallgrid.appendChild(tile);
        wallTiles.push(tile);
    }
    renderWall();
    fitWall();
}

function wallPositions(payload) {
    return payload.split(",").map(function(p) { return parseInt(p, 10); })
                  .filter(function(p) { return p >= 1 && p <= WALL_SIZE; });
}

function wallResult(payload, correct) {
    var positions = wallPositions(payload);
    if(correct) {
        positions.forEach(function(p) { wallSolved[p] = true; });
        //The quiz software also solves the last group by itself, which may not be the
        //one we have pending, so only a verdict on what we actually picked clears it.
        if(wallPending && positions.some(function(p) { return wallSelected.indexOf(p) >= 0; })) {
            endPending();
        }
        wallSelected = wallSelected.filter(function(p) { return !wallSolved[p]; });
    } else {
        endPending();
        positions.forEach(function(p) { wallWrong[p] = true; });
        if(wallWrongTimer) clearTimeout(wallWrongTimer);
        wallWrongTimer = setTimeout(function() {
            wallWrongTimer = null;
            wallWrong = {};
            renderWall();
            fitWall();
        }, WALL_WRONG_MS);
    }
    renderWall();
    fitWall();
}

function endPending() {
    if(wallPendingTimer) clearTimeout(wallPendingTimer);
    wallPendingTimer = null;
    wallPending = false;
    wallSelected = [];
}

function freezeWall() {
    endPending();
    wallFrozen = true;
    renderWall();
}

function wallLive() {
    return buttonsOn && !wallFrozen && wallWords.length === WALL_SIZE;
}

function wallPressHandler(pos) {
    return function() {
        if(!wallLive() || wallPending || wallSolved[pos] || wallWrongTimer) {
            return;
        }
        var at = wallSelected.indexOf(pos);
        if(at >= 0) {
            wallSelected.splice(at, 1);
        } else {
            wallSelected.push(pos);
        }

        if(wallSelected.length === 4) {
            wallPending = true;
            ws.send("cg" + myid + "," + wallSelected.join(","));
            //A verdict that never arrives (a dropped connection). give up and ask for the whole wall again.
            wallPendingTimer = setTimeout(function() {
                wallPendingTimer = null;
                endPending();
                renderWall();
                requestWall();
            }, WALL_PENDING_MS);
        }
        renderWall();
    };
}

function renderWall() {
    var live = wallLive();
    for(var i = 0; i < wallTiles.length; i++) {
        var pos = i + 1;
        var tile = wallTiles[i];
        var cls = "wallTile";
        if(wallSolved[pos]) {
            cls += " wallSolved";
        } else if(wallWrong[pos]) {
            cls += " wallWrong";
        } else {
            cls += live ? " buttonOn" : " buttonOff";
            if(wallSelected.indexOf(pos) >= 0) {
                cls += " multiSelected" + (wallPending ? " wallPending" : "");
            }
        }
        tile.className = cls;
        var text = wallWrong[pos] ? "❌" : (wallWords[i] || "");
        if(tile.textContent !== text) {
            tile.textContent = text;
        }
    }
}

//Gives every tile the largest font its word fits at. Needs the view on screen, as a hidden tile has no size.
function fitWall() {
    if(wallgrid.offsetWidth === 0) {
        return;
    }
    for(var i = 0; i < wallTiles.length; i++) {
        var tile = wallTiles[i];
        var lo = WALL_MIN_FONT, hi = WALL_MAX_FONT;
        while(lo < hi) {
            var mid = Math.ceil((lo + hi) / 2);
            tile.style.fontSize = mid + "px";
            if(tile.scrollWidth > tile.clientWidth || tile.scrollHeight > tile.clientHeight) {
                hi = mid - 1;
            } else {
                lo = mid;
            }
        }
        tile.style.fontSize = lo + "px";
    }
}

window.addEventListener("resize", fitWall);

setWall("");


//Attach a hander to each team pick handler
var teambuttons = document.getElementsByClassName("teamButton");
for(var i = 0; i < teambuttons.length; i++) {
    teambuttons[i].addEventListener(eventtouse, function() {
        ws.send("pt" + this.id.slice(10));
    })
}


//Prevent iOS gestures (pinch to zoom etc.)
//iOS 10 no longer allows meta tags to prevent zooming :/
document.addEventListener('gesturestart', function (e) {
    e.preventDefault();
});

//This little awful is to turn "double clicks" into single clicks
var lastTouchEnd = 0;
document.addEventListener('touchend', function (event) {
    var now = (new Date()).getTime();
    if (now - lastTouchEnd <= 500) {
        event.preventDefault();
    }
    lastTouchEnd = now;
}, false);


//Keep the connection alive, and notice when it has died
//client -> "pi" -> server. server -> "pb" -> client
QuizConnection.keepAlive(function() { return ws; }, connectionLost);


connect();
