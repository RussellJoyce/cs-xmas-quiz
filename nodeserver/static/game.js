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


var ws;
var myid = 0;

//Remembers the last view that we were set to, in the event that we are disconnected
//This also therefore sets the initial view
var lastview = "buzzer";


/*
Connection settings can be overridden from the query string, which is what harness.html uses
to run a wall of real clients from one browser.
    vcid    tells the server to key us on IP + this id rather than on IP alone, so that
            several clients from one machine are several buttons instead of one
    proto   "ws://" for a local server running without a certificate
    port    the client websocket port
    host    the machine running the quiz server, when it is not the one we were served from
*/
function queryParam(name) {
    var pairs = location.search.replace(/^\?/, "").split("&");
    for(var i = 0; i < pairs.length; i++) {
        var eq = pairs[i].indexOf("=");
        if(eq > 0 && decodeURIComponent(pairs[i].slice(0, eq)) === name) {
            return decodeURIComponent(pairs[i].slice(eq + 1));
        }
    }
    return null;
}

var vcid = queryParam("vcid");
var wsproto = (queryParam("proto") === "ws://") ? "ws://" : "wss://";
var wsport = /^[0-9]{1,5}$/.test(queryParam("port")) ? queryParam("port") : "8090";
var wshost = queryParam("host") || location.hostname || "localhost";

/*
When we connect to the server we set up a websocket with the appropriate handlers.
*/
function connect() {
    //The server opens the client websocket port on 8090 (wss) and 8093 (plain ws)
    ws = new WebSocket(wsproto + wshost + ":" + wsport + (vcid ? "/?vcid=" + encodeURIComponent(vcid) : ""));

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
                toggleState(true);
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
                //Set our view
                console.log("Server requests setting view: " + event.data.slice(2));
                lastview = event.data.slice(2);
                toggleState(true);

                if(event.data.slice(2) == "text") {
                    setView("text");
                    document.getElementById("textbox").type = "text";
                    textbox.focus();
                    removeTextmodeHandlers();
                    textbox.value = "";
                } else if(event.data.slice(2) == "numbers") {
                    setView("text");
                    document.getElementById("textbox").type = "number";
                    textbox.focus();
                    removeTextmodeHandlers();
                    textbox.value = "";
                } else if(event.data.slice(2) == "wavelength") {
                    setView("wavelength");
                    setWavelength(50, false);
                } else {
                    setView(event.data.slice(2));
                }
                break;
            case "im":
                //Set the geo image
                console.log("Setting geo image: " + event.data.slice(2));
                toggleState(true);
                geoimg.style.backgroundImage = "url(geography/" + event.data.slice(2) + ")";
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
            case "pb":
                //Pong from the server
                break;
        }
    }

    ws.onclose = function(event) {
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
    };

    ws.onerror = function(event) {
        /* If the websocker errors then disconnect, which will fire the ws.onclose handler. */
        ws.close()
    }
}


function toggleState(on) {
    if(on) {
        buzzer.className = "view theButton buttonOn";
        geoimg.className = "";
        geomark.style.display = "none";
        higher.className = "higherLowerButton buttonOn";
        lower.className = "higherLowerButton buttonOn";
    } else {
        buzzer.className = "view theButton buttonOff";
        geoimg.className = "imageDisabled";
        higher.className = "higherLowerButton buttonOff";
        lower.className = "higherLowerButton buttonOff";
    }
}


function setView(id) {
    var elements = document.getElementsByClassName('view')
    for (var i = 0; i < elements.length; i++){
        elements[i].style.display = 'none';
    }

    var view = document.getElementById(id);
    view.style.display = 'flex';
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
    textenterbutton.addEventListener(eventtouse, textboxhandler);
    textform.addEventListener("onsubmit", textboxhandler);
    textform.addEventListener("submit", textboxhandler);
    textenterbutton.className = "smallButton smallButtonOn";
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
        tile.className = "multiButton buttonOn";
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


//Set up a periodic timer to keep the connection to the client alive
//client -> "pi" -> server. server -> "pb" -> client
setInterval(function() {
    if(ws && ws.readyState === WebSocket.OPEN) {
        ws.send("pi");
    }
}, 5000) //five seconds


connect();
