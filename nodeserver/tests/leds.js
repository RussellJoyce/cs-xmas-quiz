var WebSocket = require('ws');
var server = new WebSocket('ws://localhost:8091');

server.on('open', function open() {
    var command = {cmd: "setanimation", animation: "rainbow"}

    server.send("le"+JSON.stringify(command));
     
});
