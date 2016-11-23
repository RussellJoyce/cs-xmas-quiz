var WebSocket = require('ws');
var client = new WebSocket('ws://localhost:8090');
var server = new WebSocket('ws://localhost:8091');

server.on('open', function open() {
    //Send nonsense messages
    for(i = 0; i < 5; i++) {
        server.send('abcdef');
        server.send('');
        server.send(NaN);
    }

    //Ons and Offs
    for(i = 0; i < 5; i++) {
        server.send('on');
        server.send('on234');
        server.send('');
        server.send('on1');
        server.send('on2');
        server.send('onX');
    }
});

server.on('message', function(data, flags) {
    console.log("server: %s", data);
});
