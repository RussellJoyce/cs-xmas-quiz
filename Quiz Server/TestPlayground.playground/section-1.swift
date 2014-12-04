// Playground - noun: a place where people can play

import Cocoa

protocol TreeLike {}
enum Tree:TreeLike {
    case Empty
    case Leaf(Int)
    case Node(TreeLike, TreeLike)
}

let a = Tree.Node(Tree.Node(Tree.Leaf(1), Tree.Leaf(2)), Tree.Leaf(3))

func sum (tree: Tree) -> Int {
    switch tree {
    case .Empty:
        return 0
    case let .Leaf(a):
        return a
    case let .Node(l, r):
        return sum(l as Tree) + sum(r as Tree)
    }
}

sum(a)
