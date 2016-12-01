var WebSocketServer = require('ws').Server;
var connect = require('connect');
var serveStatic = require('serve-static');

//Bits for the boglord
var enGB = require('dictionary-en-gb');
var nodehun = require('nodehun');
var _ = require('lodash');

//dictionary used by boggle:
var dict;

var clients = {};

wclient = new WebSocketServer({ port: 8090 });
wserver = new WebSocketServer({ port: 8091 });
wleds = new WebSocketServer({ port: 8092 });

var wordScores = [0,0,0,1,1,2,3,5,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11];

function boggleTestWord(word, client) {
  console.log(client.words);
  if (client.words[word]) {
    //duplicate!
    client.sock.send("bg"+JSON.stringify({cmd: "duplicate"}));
  } else {
    dict.isCorrect(word, function(err, isInDict, word) {
      if (err) console.log(err);
      if (isInDict) {
        var wordscore = wordScores[word.length];
        client.boggleScore+=wordscore;
        client.sock.send("bg"+JSON.stringify({cmd: "good", score: client.boggleScore}));
        client.words[word] = true;
        boggleDigest();
      } else {
        client.sock.send("bg"+JSON.stringify({cmd: "bad", score: 10}));
      }
    });
  }
}

function boggleReset() {
    console.log("Resetting Boggle");
    _.forEach(clients, c => {
        c.words = {};
        c.boggleScore = 0;
    });
}

function boggleDigest() {
  var summary = {};
  for (var i=0; i<clients.length; i++) {
    summary[i] = clients[i].boggleScore;
  }
  try {
    controllerWs.send("bs"+JSON.stringify(summary));
  } catch (e) {
    console.log(e);
  }
}


function getClientByID(id) {
    for(var c in clients) {
        if(clients[c].hasOwnProperty("id")) {
            if(clients[c].id == id) {
                return clients[c];
            }
        }
    }
    return null;
}

function getUnusedClientID() {
    var id = 1;
    while(getClientByID(id)) {
        id++;
    }
    return id;
}

var controllerWs;

wserver.on('connection', function(ws) {
    console.log("Quiz software connected")
    controllerWs = ws;
    ws.send('connected');

    ws.on('message', function incoming(message) {
        //Messages from the quiz software to the clients
        try {
            if(message.length >= 2) { //All valid messages are 2 or more characters long
                switch(message.slice(0,2)) {
                    case "on":
                        if(id = parseInt(message[2])) {
                            if(c = getClientByID(id)) {
                                console.log("On: " + id);
                                c.sock.send("on");
                            } //else client not connected
                        }
                        break;
                    case "of":
                        if(id = parseInt(message[2])) {
                            if(c = getClientByID(id)) {
                                console.log("Off: " + id);
                                c.sock.send("of");
                            } //else client not connected
                        }
                        break;
                    case "br":
                        boggleReset();
                        break;
                    case "le":
                        console.log("To LEDs: " + message);
                        wleds.clients.forEach(function each(c) {
                            c.send(message);
                        });
                    default:
                        //Else just forward it on to all clients
                        console.log("To all: " + message);
                        wclient.clients.forEach(function each(c) {
                            c.send(message);
                        });
                        break;
                }
            }
        } catch(err) {
            console.log("ERROR: " + err.message + " handling message from quiz software to client");
        }
    });
});

wclient.on('connection', function connection(ws) {
    //Clients are identified by their IP address (meaning multiple browsers on the same device are the same "button")
    var client = ws.upgradeReq.connection.remoteAddress;

    if(clients.hasOwnProperty(client)) {
        //Client already connected before, so has an ID, but this is a different socket.
        console.log("Client reconnected: " + client);
        clients[client].sock = ws;
    } else {
        //New client
        console.log("New client connected: " + client);
        id = getUnusedClientID();
        clients[client] = {id: id,
                           sock: ws,
                           words: {},
                           boggleScore: 0};
    }

    ws.on('message', function incoming(message) {
        //Messages from the clients to the quiz software
        try {
            if(message.length >= 2) {
                switch(message.slice(0,2)) {
                    case "re":
                        //Client wants an ID
                        ws.send('ok' + clients[client].id);
                        break;
                    case "bw": //boggle words
                      boggleTestWord(message.slice(2), clients[client]);
                      break;
                    default:
                        //Else just forward it on
                        console.log("Client: " + message);
                        wserver.clients.forEach(function each(c) {
                            c.send(message);
                        });
                        break;
                }
            }
        } catch(err) {
            console.log("ERROR: " + err.message + " handling message from client");
        }
    });
});


enGB(function (err, result) {
    if (err) throw err;

    dict = new nodehun(result.aff,result.dic);
    console.log("Dictionary loaded!");
    connect().use(serveStatic(__dirname+'/static')).listen(8080, function(){
        console.log('Quiz Server running on 8080...');
    });

});
