var WebSocket = require('ws');
var server = new WebSocket('ws://localhost:8091');

//var setGridSimple = { cmd: "set",
//                      grid: "   EJPP  ,   WILD  ,   IENR  ,   OYNR  "};

var setGridSimple = { cmd: "set",
                      grid: "CHRISTMAS,QUIZISTHE,BEST EVER,INDAWORLD"};

//var setGridSimple = { cmd: "set",
//                      grid: "💩🎅💩🎅💩🎅💩,💩🎅💩🎅💩🎅💩,💩🎅💩🎅💩🎅💩,💩🎅💩🎅💩🎅💩"};


server.on('open', function open() {
    server.send("viboggle");
    server.send("br");
    server.send("bg"+JSON.stringify(setGridSimple));
});

server.on('message', function(data, flags) {
    console.log("server: %s", data);
    if(data.slice(0,2) == "ii") {
        server.send("of1");
    }
});
