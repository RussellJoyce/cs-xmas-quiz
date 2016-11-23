var WebSocket = require('ws');

var clients = []

for(i = 0; i < 15; i++) {
    var client = new WebSocket('ws://localhost:8090');
    client.on('open', function open() {
    	try {
        	client.send('re');
        } catch(err) {
        	console.log(err);
        }
    });

    client.on('message', function(data, flags) {
        console.log("client: %s", data);
    });

    clients.push(client);
}
