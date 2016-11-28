var buzzer = document.getElementById("buzzer");
var ws;
var myid = 0;


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
                buzzer.className = "theButton buttonOn";
                break;
            case "on":
                //Buzzer turned on
                buzzer.className = "theButton buttonOn";
                console.log("button on");
                break;
            case "of":
                //Buzzer turned off
                buzzer.className = "theButton buttonOff";
                console.log("button off");
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


//When the buzzer is clicked, send a message to the server
buzzer.addEventListener('click', function(event) {
    if(myid > 0 && myid <= 10) { //Valid team ids are 1 to 10
        ws.send('zz');
    }
});

connect();
