//Test patterns for multi-client.html: canned sequences of client messages that can be fired
//at the server to exercise it and the quiz software.
//
//This is a .js file rather than a .txt one only so that multi-client.html can be opened
//straight off the disk: a file:// page is allowed to load a script, but not to fetch a file.
//Everything inside the backticks is plain text in the format below.
//
//FORMAT
//
//  # a comment, ignored
//  :Name of the pattern        starts a new pattern; everything after it belongs to it
//  <who>,<action>[,args]       one message from one or more clients
//  wait <ms>                   pause before the next line
//
//  <who> is a client number (1), a range (1-4), or * for every client on the grid.
//  Client N is the cell labelled "Client N", which with auto-pick holds team N.
//
//ACTIONS
//
//  buzz                buzz in                                 zz<team>
//  hi                  higher / true                           hi<team>
//  lo                  lower / false                           lo<team>
//  text,<answer>       a written answer (commas are kept)      tt<team>,<answer>
//  geo,<x>,<y>         a map pin, 0-100 each                    ii<team>,<x>,<y>
//  geo,random          a map pin somewhere random               ii<team>,<x>,<y>
//  pick[,<team>]       claim a team, defaulting to the client   pt<team>
//  ping                the 5s keepalive, sent early            pi
//  connect             open the socket
//  disconnect          close the socket
//  raw,<message>       sent exactly as written, for testing rubbish input
//
//Lines with no explicit wait between them are sent back to back in the same tick, which is
//what makes the buzzer races below a real race rather than a queue.

window.TEST_PATTERNS = String.raw`

# ---------------------------------------------------------------- buzzers

:3 Buzzes
1,buzz
2,buzz
3,buzz

:Buzzer race (everyone at once)
*,buzz

:Buzzer race with a clear winner
2,buzz
wait 300
1,buzz
3,buzz

:Buzz storm (three rounds)
*,buzz
wait 1000
*,buzz
wait 1000
*,buzz

:Repeat buzzing from one client
1,buzz
1,buzz
1,buzz
1,buzz
1,buzz

# ---------------------------------------------------------------- written answers

:Text guesses
1,text,hello
5,text,anotheranswer

:Everyone answers
*,text,the answer is definitely this one

:Awkward text answers
1,text,comma, separated, answer
2,text,<script>alert(1)</script>
3,text,   spaces before the answer
4,text,a very long answer that goes on and on and on and should still arrive at the quiz software in one piece

:Answer then change your mind
1,text,first thought
wait 800
1,text,second thought
wait 800
1,text,final answer

# ---------------------------------------------------------------- higher/lower and true/false

:Split vote
1,hi
2,lo
3,hi
4,lo

:Everyone says higher
*,hi

:Flip-flopping
1,hi
wait 400
1,lo
wait 400
1,hi
wait 400
1,lo

# ---------------------------------------------------------------- geography

:Geography scatter
*,geo,random

:Geography corners
1,geo,0,0
2,geo,100,0
3,geo,0,100
4,geo,100,100

:Geography drag (one client moving its pin)
1,geo,10,10
wait 200
1,geo,30,25
wait 200
1,geo,55,40
wait 200
1,geo,70,65

# ---------------------------------------------------------------- connection handling

:Reconnect drill (client 1 drops and comes back)
1,disconnect
wait 2000
1,connect
wait 1500
1,buzz

:Everyone drops and comes back
*,disconnect
wait 3000
*,connect
wait 2000
*,buzz

:Ping flood
*,ping
*,ping
*,ping
*,ping

# ---------------------------------------------------------------- misbehaving clients

:Team steal (2 tries to become team 1)
2,pick,1
wait 500
2,buzz

:Claim a team that does not exist
1,raw,pt0
1,raw,pt99
1,raw,ptbanana

:Buzz on behalf of someone else
1,raw,zz99
1,raw,zz
2,raw,zz1

:Rubbish input
1,raw,x
1,raw,
1,raw,????
1,raw,tt
1,raw,ii1,notanumber,notanumber

`;
