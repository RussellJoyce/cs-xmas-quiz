#ifndef NET_H_
#define NET_H_

// WiFi and websocket transport shared by the LED string and the trees. Commands arrive on
// the websocket client's task and are queued; net_tick() hands each one to a handler from
// the caller's loop(). Nothing here blocks: joining WiFi is stepped along by net_tick(), so
// the caller's animation keeps running while it joins or rejoins.

typedef void (*net_command_handler)(char *data, int length);

// Start joining the networks in credentials.h in turn, until one answers, then open the
// websocket. Returns at once; net_tick() does the rest. `query`, if not NULL, is added to the websocket URI's query string (e.g. "tree=d62534"),
// which is how the server tells a tree from the string.
void net_begin(const char *hostname, const char *query);

// Step the join along, rejoin if WiFi has dropped, then pass every queued command to
// `handler`.
void net_tick(net_command_handler handler);

// Close the websocket and turn WiFi off, for good: nothing rejoins until net_begin() again.
// The trees do this when a computer takes them over by USB.
void net_end();

// Between net_begin() and net_end()
bool net_running();

// WiFi has been joined at least once since boot. It stays true through later drops. The
// string and the trees hold their animation still until then, so a board that cannot reach
// the network is easy to spot.
bool net_has_joined();

void net_print_details();

// The host part of the websocket URI in use, e.g. "192.168.1.2": the quiz server, as reached
// from this network. False if there is no URI yet or the host does not fit in `len`.
bool net_server_host(char *buf, int len);

#endif
