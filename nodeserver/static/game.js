var buzzer = document.getElementById("buzzer");
var geoimg = document.getElementById("geoimg");
var geomark = document.getElementById("geomark");

var ws;
var myid = 0;

//Remembers the last view that we were set to, in the event that we are disconnected
//This also therefore sets the initial view
var lastview = "buzzer";

var boggleLastSelected = null;

function boggleLetterEV(event) {
    //is the cell clickable at all?
    var boggleLetter = event.target;
    if (boggleLetter.className.indexOf("isEmpty")!==-1) return; //no, it's empty
    if (boggleLetter.className.indexOf("isSelected")!==-1) return; //no, it's already clicked

    var attemptCoord = boggleLetter.id.split("-")[1].split("x").map(function(n) {return parseInt(n)});

    //is the cell valid to be clicked next (adjacent to previous click)
    if (boggleLastSelected) { //(if nothing is selected then it's always 'ok')
        for (var dim=0; dim<=1; dim++) {
            if (attemptCoord[dim]==boggleLastSelected[dim]-1 ||
                attemptCoord[dim]==boggleLastSelected[dim] ||
                attemptCoord[dim]==boggleLastSelected[dim]+1 ) {
                //ok. This is an acceptable variance in this dimension
            } else {
                //BOOO NOT COOL. DISQUALIFIED
                return;
            }
        }
    } else {
        //If there was nothing selected currently, clear the boggleWord as it might be showing the status of the previous submission.
        boggleWord.innerHTML = "";
        boggleSubmitStatus.innerHTML = "";
    }

    //Ok, let's do it.
    boggleLetter.className += " isSelected";
    boggleLastSelected = attemptCoord;

    boggleWord.innerHTML+=boggleLetter.innerHTML;
}

var boggleCurrentGrid = null;

function boggleSetGrid(grid) {
    boggleCurrentGrid=grid.split(",");

    //Clear current word
    boggleWord.innerHTML = "";
    boggleSubmitStatus.innerHTML = "";

    //Clear score
    boggleScore.innerHTML = "0";

    boggleResetGrid();

    boggleDisable();
}

function boggleResetGrid() {
    //clear the last-selected recorder.
    boggleLastSelected = null;

    //Set all button contents
    for (var x=1; x<=9; x++) {
        for (var y=1; y<=4; y++) {
            var boggleLetter = document.getElementById("boggleLetter-"+x+"x"+y);
            var gridLetter = boggleCurrentGrid[y-1][x-1];

            boggleLetter.innerHTML = gridLetter;
            if (gridLetter == ' ') {
                if (boggleLetter.className.indexOf("isEmpty")==-1) boggleLetter.className+=" isEmpty";
            } else {
                boggleLetter.className = boggleLetter.className.replace("isEmpty", "");
            }

            boggleLetter.className = boggleLetter.className.replace("isSelected", "");

            boggleLetter.removeEventListener('mousedown', boggleLetterEV);
            boggleLetter.addEventListener('mousedown', boggleLetterEV);
        }
    }
}

function boggleDisable() {

}

function boggleEnable() {

}

/*
When we connect to the server we set up a websocket with the appropriate handlers.
*/
function connect() {
    //The server opens the client websocket port on 8090
    ws = new WebSocket("ws://" + location.hostname + ":8090");

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
                myid = event.data[2];
                buzzer.innerHTML = "TEAM " + myid;
                console.log("Server gave us ID " + myid);
                toggleState(true);
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
                setView(event.data.slice(2));
                break;
            case "im":
                //Set the geo image
                console.log("Setting geo image: " + event.data.slice(2));
                toggleState(true);
                geoimg.src = "images/" + event.data.slice(2);
                break;
            case "bg":
                //Boggle stuff
                var payload = JSON.parse(event.data.slice(2));
                switch (payload.cmd) {
                    case "set":
                        boggleSetGrid(payload.grid);
                        break;
                    case "good":
                        boggleScore.innerHTML = payload.score;
                        boggleWord.innerHTML = '<span class="boggleCorrect">'+boggleWord.innerHTML+'<span>';
                        boggleSubmitStatus.innerHTML = "✅🎉";
                        boggleResetGrid();
                        break;
                    case "bad":
                        boggleWord.innerHTML = '<span class="boggleIncorrect">'+boggleWord.innerHTML+'<span>';
                        boggleSubmitStatus.innerHTML = "📖❌😨"
                        boggleResetGrid();
                        break;
                    case "duplicate":
                        boggleWord.innerHTML = '<span class="boggleDuplicate">'+boggleWord.innerHTML+'<span>';
                        boggleSubmitStatus.innerHTML = "📖🔁"
                        boggleResetGrid();
                        break;
                }
                break;
            case "pb":
                console.log("Ping back");
                break;
        }
    }

    ws.onclose = function(event) {
        setView("buzzer");
        console.log("Disconnected");
        buzzer.innerHTML = "NO CONNECTION";
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

document.ontouchmove = function(event){
    event.preventDefault();
}


function toggleState(on) {
    if(on) {
        buzzer.className = "view theButton buttonOn";
        geoimg.className = "";
        boggleEnable();
        geomark.style.display = "none";
    } else {
        buzzer.className = "view theButton buttonOff";
        geoimg.className = "imageDisabled";
        boggleDisable();
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


//When the buzzer is clicked, send a message to the server
function buzzhandler(event) {
    if(myid > 0 && myid <= 10) { //Valid team ids are 1 to 10
        ws.send('zz' + myid);
    }
}
/*
 * So 'touchstart' is the better event to use on iOS because it will fire even if the user is "gesturing".
 * However it is not supported on IE, of course. We shouldn't add both, so this detects whether touchstart is
 * available and if not resorts to mousedown, which on IE actually behaves better than on iOS for touch events.
*/
if ('ontouchstart' in document.documentElement) {
    buzzer.addEventListener('touchstart', buzzhandler);
} else {
    buzzer.addEventListener('mousedown', buzzhandler);
}

//When the image is clicked send the coords to the server
geoimg.addEventListener('mousedown', function(event) {
    var rect = geoimg.getBoundingClientRect();
    var x = (event.clientX - rect.left) / rect.width * 100;
    var y = (event.clientY - rect.top) / rect.height * 100;

    geomark.style.top = (event.clientY - rect.top) - 30;
    geomark.style.left = (event.clientX - rect.left) - 30;
    geomark.style.display = "block";

    ws.send('ii' + myid + "," + Math.round(x) + "," + Math.round(y));
});

boggleCancel.addEventListener('mousedown', function(event) {
    //Clear current word
    boggleWord.innerHTML = "";
    boggleSubmitStatus.innerHTML = "";
    boggleResetGrid();
});

boggleSubmit.addEventListener('mousedown', function(event) {
    if (boggleWord.innerHTML!="" && boggleSubmitStatus.innerHTML=="") {
        ws.send("bw"+boggleWord.innerHTML);
        boggleSubmitStatus.innerHTML = "⌛️";
    }
});

boggleSetGrid("         ,         ,         ,         ");
boggleSetGrid("   EBSA  ,   OTLV  ,   TEET  ,   STMN  ");

//Set up a periodic timer to keep the connection to the client alive
//client -> "pi" -> server. server -> "pb" -> client
setInterval(function() {
    console.log("ping...");
    ws.send("pi");
}, 10000) //ten seconds


connect();
