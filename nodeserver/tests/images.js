var WebSocket = require('ws');
var server = new WebSocket('ws://localhost:8091');

if(typeof process.argv[2] == 'undefined') {
    console.log("Provide the view to test");
    process.exit(-1);
}

if(process.argv[2] == 'geo' && typeof process.argv[3] == 'undefined') {
    console.log("Provide the image to test");
    process.exit(-1);
}

var view = process.argv[2]

server.on('open', function open() {
    server.send("vi" + view);
    if(view == "geo") {
        server.send("im" + process.argv[3]);
    }    
});

server.on('message', function(data, flags) {
    console.log("server: %s", data);
});

