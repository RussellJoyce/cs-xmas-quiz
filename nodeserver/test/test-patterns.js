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
//  wave,<n>            a wavelength guess, 1-99                 wv<team>,<n>
//  wave,random         a wavelength guess somewhere random      wv<team>,<n>
//  choice,<n>          a multiple choice option, 1-6            mc<team>,<n>
//  choice,random       whichever options the grid has           mc<team>,<n>
//  wiki,short,<n>      walk to n links from the target          wl<team>,<article>...
//  wiki,stray,<n>      n moves away from the ideal route        wl<team>,<article>...
//  wiki,back           step back one article                    wb<team>
//  pick[,<team>]       claim a team, defaulting to the client   pt<team>
//  ping                the 5s keepalive, sent early            pi
//  connect             open the socket
//  disconnect          close the socket
//  raw,<message>       sent exactly as written, for testing rubbish input
//
//Lines with no explicit wait between them are sent back to back in the same tick, which is
//what makes the buzzer races below a real race rather than a queue.
//
//WIKIRACE
//
//The wiki actions are the exception to that. A move has to be a link the server agrees is
//on the page the team is standing on, so a walk sends one move per confirmation rather
//than all of them at once: always leave a wait after one. They also read the corpus over
//HTTP, so this page must be served from the quiz server, not opened off the disk.
//
//"short" is written as the distance left rather than the distance travelled, because that
//is the number the quiz software ranks on: it colours the team(s) that stopped closest to
//the target and then the next closest. So "wiki,short,1" is a team that came within one
//link of the target and "wiki,short,0" is one that arrived, whichever puzzle is running.
//The corpus only holds 3- and 4-hop puzzles, so anything beyond "short,3" needs a 4-hop
//question; a pattern that asks for more than the route holds says so and does nothing.

window.TEST_PATTERNS = String.raw`

# ---------------------------------------------------------------- buzzers

:Buzz - 3 Buzzes
1,buzz
2,buzz
3,buzz

:Buzz - Everyone at once
*,buzz

:Buzz - Race with a clear winner (T2)
2,buzz
wait 300
1,buzz
3,buzz

:Buzz - Three buzz storms
*,buzz
wait 1000
*,buzz
wait 1000
*,buzz

:Buzz - Repeat buzzing from one client
1,buzz
1,buzz
1,buzz
1,buzz
1,buzz

# ---------------------------------------------------------------- written answers

:Text - Guesses
1,text,hello
2,text,hello
3,text,something
4,text,somethingelse
5,text,anotheranswer
6,text,a bit of a longer one

:Text - Everyone answers
*,text,the answer is definitely this one

:Text - Awkward text answers
1,text,comma, separated, answer
2,text,<script>alert(1)</script>
3,text,   spaces before the answer
4,text,a very long answer that goes on and on and on and should still arrive at the quiz software in one piece

:Text - Answer then change your mind
1,text,first thought
wait 800
1,text,second thought
wait 800
1,text,final answer


:Number - Guesses
1,text,1
2,text,2
3,text,3
4,text,4
5,text,50
6,text,50
7,text,50

# ---------------------------------------------------------------- higher/lower and true/false

:HiLo - Split vote
1,hi
2,lo
3,hi
4,lo

:HiLo - Everyone says higher
*,hi

:HiLo - T1 change mind
1,hi
wait 400
1,lo
wait 400
1,hi
wait 400
1,lo

# ---------------------------------------------------------------- geography

:Geo - Scatter
*,geo,random

:Geo - 4 Corners
1,geo,0,0
2,geo,100,0
3,geo,0,100
4,geo,100,100

:Geo - One client moving its pin
1,geo,10,10
wait 200
1,geo,30,25
wait 200
1,geo,55,40
wait 200
1,geo,70,65

# ---------------------------------------------------------- multiple choice

:Choice - Everyone picks something
*,choice,random

:Choice - A clean split across four options
1,choice,1
2,choice,2
3,choice,3
4,choice,4
5,choice,1
6,choice,2
7,choice,3
8,choice,4

:Choice - Unanimous
*,choice,3

:Choice - Changing their minds, which is allowed until time runs out
*,choice,1
wait 300
*,choice,4
wait 300
*,choice,2

:Choice - Two teams never answer
1,choice,2
2,choice,2
4,choice,3
5,choice,1
6,choice,4
7,choice,2
8,choice,3

:Choice - Everything at once, for the six-option grid
*,choice,random
wait 100
*,choice,random
wait 100
*,choice,random

# ---------------------------------------------------------------- wavelength

:Wave - Scatter
*,wave,random

:Wave - Spread across the bar
1,wave,1
2,wave,15
3,wave,30
4,wave,45
5,wave,60
6,wave,75
7,wave,99

:Wave - Everyone clustered on one number
*,wave,50

:Wave - Tight cluster, every team within 3
1,wave,49
2,wave,49
3,wave,50
4,wave,50
5,wave,50
6,wave,51
7,wave,51
8,wave,52
9,wave,52
10,wave,48
11,wave,48
12,wave,49
13,wave,51
14,wave,50

:Wave - Jammed against both ends
1,wave,1
2,wave,1
3,wave,2
4,wave,2
5,wave,3
6,wave,3
7,wave,4
8,wave,99
9,wave,99
10,wave,98
11,wave,98
12,wave,97
13,wave,97
14,wave,96

:Wave - Neighbours, for marker stacking
1,wave,48
2,wave,49
3,wave,50
4,wave,51
5,wave,52

:Wave - Neighbours 2, for marker stacking
1,wave,48
2,wave,49
3,wave,50
4,wave,51
5,wave,52
6,wave,48
7,wave,49
8,wave,50
9,wave,51
10,wave,52

:Wave - One client dragging its handle
1,wave,10
wait 120
1,wave,25
wait 120
1,wave,44
wait 120
1,wave,63
wait 120
1,wave,80

:Wave - Everyone fidgeting
*,wave,random
wait 500
*,wave,random
wait 500
*,wave,random
wait 500
*,wave,random

:Wave - Out of range guesses
1,raw,wv1,0
2,raw,wv2,100
3,raw,wv3,-5
4,raw,wv4,banana
5,raw,wv5

# ---------------------------------------------------------------- wikirace
# Run these with a race started from the quiz software. "short,n" leaves a team exactly n
# links from the target, so each pattern below sets up a known finishing order and the
# highlights on the display can be read straight off the comments.
# End the race from the quiz software afterwards: the colours only appear once the
# standings come back.

:Wiki - Clear podium, a winner and two near misses
# T1 green, T2 blue (closest), T3 bronze (2nd closest), T4 plain
1,wiki,short,0
2,wiki,short,1
3,wiki,short,2
4,wiki,short,3
wait 3000

:Wiki - Two teams tie for closest
# T2 and T3 both blue; T4 is bronze, not third place
1,wiki,short,0
2,wiki,short,1
3,wiki,short,1
4,wiki,short,2
wait 3000

:Wiki - Three teams tie for second closest
# T1 blue on its own, T2-T4 all bronze
1,wiki,short,1
2,wiki,short,2
3,wiki,short,2
4,wiki,short,2
wait 3000

:Wiki - Nobody arrives
# Highlights with no green anywhere: T1 blue, T2-T3 bronze, T4-T5 plain
1,wiki,short,1
2,wiki,short,2
3,wiki,short,2
4,wiki,short,3
5,wiki,short,3
wait 3000

:Wiki - Everybody arrives
# No highlights at all, because there is nobody left to be closest
*,wiki,short,0
wait 4000

:Wiki - Idle teams are not "closest"
# Only T2 is highlighted. T3-T8 never moved, so although they are all the same distance
# from the target as each other, none of them should be coloured in.
1,wiki,short,0
2,wiki,short,1
wait 3000

:Wiki - Moved, then came back to the start
# T3 wanders off and returns to where it began. It did play, so it stays in the running
# even though it ends up on the start article alongside the teams that never moved.
1,wiki,short,0
2,wiki,short,2
wait 2000
3,wiki,stray,1
wait 1500
3,wiki,back
wait 2000

:Wiki - Teams going the wrong way
# T3-T5 end up an unknown distance out, and should not displace T2 or T1
1,wiki,short,0
2,wiki,short,1
wait 2000
3,wiki,stray,2
4,wiki,stray,2
5,wiki,stray,3
wait 4000

:Wiki - A near miss beaten at the last moment
# T2 sits one short while T3 goes all the way, so the closest-loser colour has to move to
# T4 when the standings arrive rather than staying where it first looked like landing.
2,wiki,short,1
3,wiki,short,2
4,wiki,short,2
wait 3000
3,wiki,short,0
wait 2000

:Wiki - Full grid, every band at once
# Fourteen teams spread across arrived / 1 short / 2 short / 3 short / never moved, which
# is also the test that the display copes with fourteen standings arriving in one burst.
1,wiki,short,0
2,wiki,short,0
3,wiki,short,1
4,wiki,short,1
5,wiki,short,1
6,wiki,short,2
7,wiki,short,2
8,wiki,short,3
9,wiki,short,3
wait 4000
10,wiki,stray,2
11,wiki,stray,2
wait 4000

:Wiki - One team walking the whole way, slowly
# For watching the per-move blop, the box emphasis and the article titles shrinking to fit
1,wiki,short,3
wait 1500
1,wiki,short,2
wait 1500
1,wiki,short,1
wait 1500
1,wiki,short,0
wait 2000

:Wiki - Awkward moves
# Nonsense the server should refuse without the race or the client falling over
1,raw,wl1,999999
2,raw,wl2,-1
3,raw,wl3,notanumber
4,raw,wl99,5
5,raw,wb99
6,raw,wl6
wait 1000

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
