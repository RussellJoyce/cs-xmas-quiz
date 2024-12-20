var buzzer = document.getElementById("buzzer");
var geoimg = document.getElementById("geoimg");
var geomark = document.getElementById("geomark");
var textbox = document.getElementById("textbox");
var textenterbutton = document.getElementById("textenterbutton");
var textform = document.getElementById("textform");
var higherlower = document.getElementById("higherlower");
var higher = document.getElementById("higher");
var lower = document.getElementById("lower");


var ws;
var myid = 0;

//Remembers the last view that we were set to, in the event that we are disconnected
//This also therefore sets the initial view
var lastview = "buzzer";


/*
When we connect to the server we set up a websocket with the appropriate handlers.
*/
function connect() {
    //The server opens the client websocket port on 8090
    ws = new WebSocket("wss://" + location.hostname + ":8090");

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
            case "pb":
                console.log("Ping back");
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
        return false;
    }

    if(myid > 0 && myid <= 99) {
        ws.send('tt' + myid + "," + textbox.value);
    }
    textbox.style.animationName = "textboxpulse";
    removeTextmodeHandlers();
    
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
    console.log("ping...");
    ws.send("pi");
}, 10000) //ten seconds


connect();
