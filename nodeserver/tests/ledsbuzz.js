var WebSocket = require('ws');
var server = new WebSocket('ws://localhost:8091');

server.on('open', function open() {
    var command = {
        cmd: "buzz", 
        r: 255,
        g: 0,
        b: 0,
    }
    server.send("le"+JSON.stringify(command));
});
