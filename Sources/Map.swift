//
//  Map2.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-17.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

public struct Map<Key: Comparable, Value>: SortedAssociativeCollectionType {
    // Typealiases

    internal typealias Summary = EmptySummary<Key>
    internal typealias TreeKey = StoredKey<Summary>
    internal typealias Tree = RedBlackTree<TreeKey, Value>
    internal typealias Handle = Tree.Handle

    public typealias Index = MapIndex<Key, Value>
    public typealias Generator = MapGenerator<Key, Value>
    public typealias Element = (Key, Value)

    // Stored properties

    internal private(set) var tree: Tree

    // Initalizer 

    public init() {
        self.tree = Tree()
    }

    // Properties

    public var startIndex: Index {
        return Index(tree: tree, handle: tree.leftmost)
    }

    public var endIndex: Index {
        return Index(tree: tree, handle: nil)
    }

    public var count: Int {
        return tree.count
    }

    // Subscripts

    public subscript(index: Index) -> Element {
        let (key, payload) = tree.elementAt(index.handle!)
        return (key.head, payload)
    }

    public subscript(key: Key) -> Value? {
        get {
            guard let handle = tree.find(TreeKey(key)) else { return nil }
            return tree.payloadAt(handle)
        }
        set(value) {
            if let value = value {
                tree.setPayloadOf(TreeKey(key), to: value)
            }
            else if let handle = tree.find(TreeKey(key)) {
                tree.remove(handle)
            }
        }
    }

    // Methods

    public func generate() -> Generator {
        return Generator(tree: tree)
    }

    public func indexForKey(key: Key) -> Index? {
        guard let handle = tree.find(TreeKey(key)) else { return nil }
        return Index(tree: tree, handle: handle)
    }

    // Mutators

    public mutating func reserveCapacity(minimumCapacity: Int) {
        tree.reserveCapacity(minimumCapacity)
    }

    public mutating func updateValue(value: Value, forKey key: Key) -> Value? {
        return tree.setPayloadOf(TreeKey(key), to: value).1
    }

    public mutating func removeAtIndex(index: Index) -> (Key, Value) {
        let handle = index.handle!
        let key = tree.headAt(handle)
        let value = tree.remove(handle)
        return (key, value)
    }

    public mutating func removeValueForKey(key: Key) -> Value? {
        guard let handle = tree.find(TreeKey(key)) else { return nil }
        return tree.remove(handle)
    }

    public mutating func removeAll() {
        tree = Tree()
    }
}

public struct MapIndex<Key: Comparable, Value>: BidirectionalIndexType {
    private typealias Summary = EmptySummary<Key>
    private typealias TreeKey = StoredKey<Summary>
    private typealias Tree = RedBlackTree<TreeKey, Value>
    private typealias Handle = Tree.Handle

    private let tree: Tree
    private let handle: Handle?

    private init(tree: Tree, handle: Handle?) {
        self.tree = tree
        self.handle = handle
    }

    public func successor() -> MapIndex<Key, Value> {
        return MapIndex(tree: tree, handle: tree.successor(handle!))
    }

    public func predecessor() -> MapIndex<Key, Value> {
        return MapIndex(tree: tree, handle: tree.predecessor(handle!))
    }
}

public func ==<Key: Comparable, Value>(a: MapIndex<Key, Value>, b: MapIndex<Key, Value>) -> Bool {
    return a.handle == b.handle
}

public struct MapGenerator<Key: Comparable, Value>: GeneratorType {
    public typealias Element = (Key, Value)

    private typealias Summary = EmptySummary<Key>
    private typealias TreeKey = StoredKey<Summary>
    private typealias Tree = RedBlackTree<TreeKey, Value>
    private typealias Handle = Tree.Handle

    private let tree: Tree
    private var handle: Handle?

    private init(tree: Tree) {
        self.tree = tree
        self.handle = tree.leftmost
    }

    private init(tree: Tree, handle: Handle?) {
        self.tree = tree
        self.handle = handle
    }

    public mutating func next() -> Element? {
        guard let handle = handle else { return nil }
        self.handle = tree.successor(handle)
        let (key, payload) = tree.elementAt(handle)
        return (key.head, payload)
    }
}

