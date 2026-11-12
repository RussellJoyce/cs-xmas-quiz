#ifndef NET_H_
#define NET_H_

// WiFi and websocket transport shared by the LED string and the trees. Commands arrive on
// the websocket client's task and are queued; net_tick() hands each one to a handler from
// the caller's loop().

typedef void (*net_command_handler)(char *data, int length);

// Connect to the first network in credentials.h that answers, then open the websocket.
// `query`, if not NULL, is added to the websocket URI's query string (e.g. "tree=d62534"),
// which is how the server tells a tree from the string.
void net_begin(const char *hostname, const char *query);

// Reconnect if WiFi has dropped, then pass every queued command to `handler`.
void net_tick(net_command_handler handler);

void net_print_details();

// The host part of the websocket URI in use, e.g. "192.168.1.2": the quiz server, as reached
// from this network. False if there is no URI yet or the host does not fit in `len`.
bool net_server_host(char *buf, int len);

#endif
