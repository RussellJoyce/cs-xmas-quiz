var WebSocket = require('ws');
var client = new WebSocket('wss://localhost:8090');

client.on('open', function open() {
    //Send nonsense messages 
    for(i = 0; i < 5; i++) {
        client.send('abcdef');
        client.send('');
        client.send(NaN);
    }

    //Request IDs
    for(i = 0; i < 5; i++)
        client.send('re');

    //Buzz with extra data
    for(i = 0; i < 5; i++) {
        client.send('zzzzzzz');
        client.send('zz5');
    }
});

client.on('message', function(data, flags) {
    console.log("client: %s", data);
});
