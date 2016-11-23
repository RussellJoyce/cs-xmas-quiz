var WebSocket = require('ws');
var ws = new WebSocket('ws://localhost:8080');

ws.on('open', function open() {
 	ws.send('abcdef');
});

ws.on('message', function(data, flags) {
	console.log("client: %s", data);
});
