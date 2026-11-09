'use strict';

//The desk trees. They connect to the LED port like the string does, but with ?tree=<id> on
//the URL, where the id is the last three bytes of the board's MAC. They are told their place
//among the trees connected (i<index><count>) so that they can stagger effects; the order is
//by id, so it stays the same across restarts as long as the same trees are plugged in.

const { safeSend } = require('./protocol');

const TREE_ID = /^[0-9a-z]{1,16}$/i;

//The tree id from a connection URL, or null if it is not a tree
function treeIdFromUrl(url) {
    try {
        const id = new URL(url || '/', 'http://localhost').searchParams.get('tree');
        return id !== null && TREE_ID.test(id) ? id.toLowerCase() : null;
    } catch(err) {
        return null;
    }
}

function pad2(n) {
    return String(n).padStart(2, '0');
}

class Trees {
    constructor() {
        this.sockets = new Map();   //socket -> id
    }

    add(sock, id) {
        this.sockets.set(sock, id);
        this.sendIdentities();
    }

    remove(sock) {
        if(this.sockets.delete(sock)) this.sendIdentities();
    }

    has(sock) {
        return this.sockets.has(sock);
    }

    //The ids connected, in order, with no duplicates: a tree that has rebooted may briefly
    //have two sockets, and should not take two places
    order() {
        return Array.from(new Set(this.sockets.values())).sort();
    }

    sendIdentities() {
        const order = this.order();
        const count = Math.min(order.length, 99);
        this.sockets.forEach((id, sock) => {
            const index = Math.min(order.indexOf(id), 98);
            safeSend(sock, 'i' + pad2(index) + pad2(count));
        });
    }

    broadcast(message) {
        this.sockets.forEach((id, sock) => safeSend(sock, message));
    }
}

module.exports = { Trees, treeIdFromUrl };
