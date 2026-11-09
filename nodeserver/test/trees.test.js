'use strict';

const { test, describe } = require('node:test');
const assert = require('node:assert');

const { Trees, treeIdFromUrl } = require('../trees');
const { FakeSocket } = require('./helpers');

describe('treeIdFromUrl', () => {
    test('reads the id from the query, lower-cased', () => {
        assert.strictEqual(treeIdFromUrl('/?tree=D62534'), 'd62534');
    });

    test('the string, which sends no query, is not a tree', () => {
        assert.strictEqual(treeIdFromUrl('/'), null);
        assert.strictEqual(treeIdFromUrl(undefined), null);
    });

    test('an id that is empty, too long or not alphanumeric is refused', () => {
        assert.strictEqual(treeIdFromUrl('/?tree='), null);
        assert.strictEqual(treeIdFromUrl('/?tree=' + 'a'.repeat(17)), null);
        assert.strictEqual(treeIdFromUrl('/?tree=d6%2025'), null);
    });
});

describe('Trees', () => {
    test('a lone tree is told it is number 0 of 1', () => {
        const trees = new Trees();
        const a = new FakeSocket('a');
        trees.add(a, 'd62534');
        assert.deepStrictEqual(a.drain(), ['i0001']);
    });

    test('trees are numbered by id, whatever order they connect in, and all are told when one joins', () => {
        const trees = new Trees();
        const a = new FakeSocket('a'), b = new FakeSocket('b'), c = new FakeSocket('c');
        trees.add(c, 'cc0000');
        trees.add(a, 'aa0000');
        [a, c].forEach(s => s.drain());
        trees.add(b, 'bb0000');
        assert.deepStrictEqual(a.drain(), ['i0003']);
        assert.deepStrictEqual(b.drain(), ['i0103']);
        assert.deepStrictEqual(c.drain(), ['i0203']);
    });

    test('the others are renumbered when a tree leaves', () => {
        const trees = new Trees();
        const a = new FakeSocket('a'), b = new FakeSocket('b'), c = new FakeSocket('c');
        trees.add(a, 'aa0000');
        trees.add(b, 'bb0000');
        trees.add(c, 'cc0000');
        [a, b, c].forEach(s => s.drain());
        trees.remove(b);
        assert.deepStrictEqual(a.drain(), ['i0002']);
        assert.deepStrictEqual(c.drain(), ['i0102']);
        assert.ok(!trees.has(b));
    });

    test('a rebooted tree with its old socket still open takes one place, not two', () => {
        const trees = new Trees();
        const old = new FakeSocket('old'), fresh = new FakeSocket('new'), other = new FakeSocket('other');
        trees.add(old, 'aa0000');
        trees.add(other, 'bb0000');
        trees.add(fresh, 'aa0000');
        assert.deepStrictEqual(trees.order(), ['aa0000', 'bb0000']);
        assert.deepStrictEqual(fresh.drain(), ['i0002']);
        assert.deepStrictEqual(other.drain().pop(), 'i0102');
    });

    test('removing a socket that was never added sends nothing', () => {
        const trees = new Trees();
        const a = new FakeSocket('a');
        trees.add(a, 'aa0000');
        a.drain();
        trees.remove(new FakeSocket('stranger'));
        assert.deepStrictEqual(a.drain(), []);
    });

    test('broadcast reaches every tree and survives a dead socket', () => {
        const trees = new Trees();
        const a = new FakeSocket('a'), b = new FakeSocket('b');
        trees.add(a, 'aa0000');
        trees.add(b, 'bb0000');
        [a, b].forEach(s => s.drain());
        a.close();
        trees.broadcast('b03');
        assert.deepStrictEqual(a.drain(), []);
        assert.deepStrictEqual(b.drain(), ['b03']);
    });
});
