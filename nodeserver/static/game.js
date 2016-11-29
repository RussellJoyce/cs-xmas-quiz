var buzzer = document.getElementById("buzzer");
var geoimg = document.getElementById("geoimg");


var ws;
var myid = 0;

var word = "";

function boggleLetterEV(event) {
  //is the cell clickable at all?
  var boggleLetter = event.target;
  if (boggleLetter.className.indexOf("isEmpty")!==-1) return; //no, it's empty
  if (boggleLetter.className.indexOf("isSelected")!==-1) return; //no, it's already clicked

  //is the cell valid to be clicked next (adjacent to previous click)


  //Ok, let's do it.
  boggleLetter.className += " isSelected";
  word += boggleLetter.innerHTML;
  console.log(word);
}

function boggleSetGrid(grid) {

  var pgrid=grid.split(",");

  //Clear last word
  //Clear score
  //Set all button contents
  //Clear current word

  for (var x=1; x<=9; x++) {
    for (var y=1; y<=4; y++) {
      var boggleLetter = document.getElementById("boggleLetter-"+x+"x"+y);
      var gridLetter = pgrid[y-1][x-1];

      boggleLetter.innerHTML = gridLetter;
      if (gridLetter == ' ') {
        if (boggleLetter.className.indexOf("isEmpty")==-1) boggleLetter.className+=" isEmpty";
      } else {
        boggleLetter.className = boggleLetter.className.replace("isEmpty", "");
      }

      boggleLetter.removeEventListener('mousedown', boggleLetterEV);
      boggleLetter.addEventListener('mousedown', boggleLetterEV);

    }
  }

  //disable all input

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
                console.log("Setting view: " + event.data.slice(2));
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
                  case "setGrid":
                    boggleSetGrid(payload.grid);
                    break;
                }
                break;
        }
    }

    ws.onclose = function(event) {
        console.log("Disconnected");
        buzzer.innerHTML = "NO CONNECTION";
        buzzer.className = "theButton buttonOff";
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
buzzer.addEventListener('mousedown', function(event) {
    if(myid > 0 && myid <= 10) { //Valid team ids are 1 to 10
        ws.send('zz' + myid);
    }
});


//When the image is clicked send the coords to the server
geoimg.addEventListener('mousedown', function(event) {
    var rect = geoimg.getBoundingClientRect();
    var x = (event.clientX - rect.left) / rect.width * 100;
    var y = (event.clientY - rect.top) / rect.height * 100;
    ws.send('ii' + myid + "," + Math.round(x) + "," + Math.round(y));
});


boggleSetGrid("         ,         ,         ,         ");
boggleSetGrid("   EBSA  ,   OTLV  ,   TEET  ,   STMN  ");

setView('boggle');
connect();
