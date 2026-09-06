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

    return {
        queryParam: queryParam,
        vcid: vcid,

        //The websocket URL, carrying the vcid so the server keys us correctly.
        url: function() {
            return "wss://" + host + ":" + port + (vcid ? "/?vcid=" + encodeURIComponent(vcid) : "");
        },
        go: function(path) {
            location.replace(path + location.search);
        }
    };
})();
