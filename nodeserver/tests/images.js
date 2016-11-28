var WebSocket = require('ws');
var server = new WebSocket('ws://localhost:8091');

server.on('open', function open() {
    server.send("vigeo");
    server.send("imtestimage2.png");
});

server.on('message', function(data, flags) {
    console.log("server: %s", data);
});
