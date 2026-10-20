'use strict';

//Where a client should connect, and who it should say it is.
//Overrides come from the query string:
//    vcid    key this client on IP + this id rather than on IP alone, so that several
//            clients from one machine are several buttons instead of one. The server only
//            honours it when it was started with --dev.
//    port    the client websocket port
//    host    the machine running the quiz server, when it is not the one we were served from

var QuizConnection = (function() {

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
    var port = /^[0-9]{1,5}$/.test(queryParam("port")) ? queryParam("port") : "8090";
    var host = queryParam("host") || location.hostname || "localhost";

    var PING_MS = 5000;     //The server answers every "pi" with "pb"
    var SILENCE_MS = 12000; //So this much silence is two missed pongs

    //Stops a socket from reporting anything further and lets it go. close() on a connection
    //that is already dead can take minutes to fire onclose, so nothing waits for it.
    function abandon(sock) {
        sock.onopen = sock.onmessage = sock.onclose = sock.onerror = null;
        try { sock.close(); } catch(err) {}
    }

    /*
    A phone that roams, sleeps or loses the wifi for a moment can leave its socket "OPEN"
    long after the connection underneath has gone, and anything sent then is silently lost.
    This pings, and if the server goes quiet (or a connection attempt hangs) it abandons
    the socket and calls `dead`, which should do whatever the page's onclose does.
    `current` returns the page's socket, or null between connections.
    */
    function keepAlive(current, dead) {
        var watched = null;
        var lastHeard = 0;

        function heard() {
            lastHeard = Date.now();
        }

        function check() {
            var sock = current();
            if(!sock) return;
            if(sock !== watched) {
                //A new connection: its clock starts from when it was first seen
                watched = sock;
                heard();
                sock.addEventListener("message", heard);
                return;
            }
            if(Date.now() - lastHeard > SILENCE_MS) {
                console.log("Nothing from the server for " + (Date.now() - lastHeard) + "ms, reconnecting");
                watched = null;
                abandon(sock);
                dead();
            }
        }

        setInterval(function() {
            var sock = current();
            if(sock && sock.readyState === WebSocket.OPEN) sock.send("pi");
        }, PING_MS);
        setInterval(check, 1000);

        //Timers barely run while a phone is asleep, so check the moment it wakes rather
        //than waiting for the next tick
        document.addEventListener("visibilitychange", function() {
            if(document.visibilityState === "visible") check();
        });
        window.addEventListener("pageshow", check);
    }

    return {
        queryParam: queryParam,
        vcid: vcid,
        keepAlive: keepAlive,

        //The websocket URL, carrying the vcid so the server keys us correctly.
        url: function() {
            return "wss://" + host + ":" + port + (vcid ? "/?vcid=" + encodeURIComponent(vcid) : "");
        },
        go: function(path) {
            location.replace(path + location.search);
        }
    };
})();
