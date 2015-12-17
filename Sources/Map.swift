//
//  Map.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-14.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

internal struct MapValue<_Key: Comparable, Value>: RedBlackValue {
    typealias Key = _Key
    typealias State = Void

    var key: Key
    var value: Value

    init(key: Key, value: Value) {
        self.key = key
        self.value = value
    }

    func compare(key: Key, children: StateAccessor<MapValue<Key, Value>>, insert: Bool) -> RedBlackComparisonResult<Key> {
        if key == self.key {
            return .Found
        }
        else if key < self.key {
            return .Descend(.Left, with: key)
        }
        else {
            return .Descend(.Right, with: key)
        }
    }
}

public struct MapIndex<Key: Comparable, Value>: BidirectionalIndexType {
    internal typealias TreeValue = MapValue<Key, Value>
    internal typealias Tree = RedBlackTree<TreeValue>
    internal typealias Index = Tree.Index
    internal typealias Slot = Tree.Slot

    private let tree: Tree
    private let index: Index?

    private init(tree: Tree, index: Index?) {
        self.tree = tree
        self.index = index
    }

    public func successor() -> MapIndex<Key, Value> {
        return MapIndex(tree: tree, index: tree.successor(index!))
    }

    public func predecessor() -> MapIndex<Key, Value> {
        return MapIndex(tree: tree, index: tree.predecessor(index!))
    }
}

public func ==<Key: Comparable, Value>(a: MapIndex<Key, Value>, b: MapIndex<Key, Value>) -> Bool {
    return a.index == b.index
}

public struct MapGenerator<Key: Comparable, Value>: GeneratorType {
    public typealias Element = (Key, Value)

    private typealias TreeValue = MapValue<Key, Value>
    private typealias Tree = RedBlackTree<TreeValue>

    private let tree: Tree
    private var index: Tree.Index?

    private init(tree: Tree) {
        self.tree = tree
        self.index = tree.firstIndex
    }

    private init(tree: Tree, index: Tree.Index?) {
        self.tree = tree
        self.index = index
    }

    public mutating func next() -> Element? {
        guard let index = index else { return nil }
        self.index = tree.successor(index)
        let mv = tree[index]
        return (mv.key, mv.value)
    }
}

public struct Map<Key: Comparable, Value>: SortedAssociativeCollectionType {
    public typealias Index = MapIndex<Key, Value>
    public typealias Generator = MapGenerator<Key, Value>
    public typealias Element = (Key, Value)

    internal typealias TreeValue = MapValue<Key, Value>
    internal typealias Tree = RedBlackTree<TreeValue>
    internal typealias Slot = Tree.Slot

    internal private(set) var tree: Tree

    // Initializers.

    public init() {
        self.tree = Tree()
    }

    // Variables.

    public var startIndex: Index {
        return Index(tree: tree, index: tree.firstIndex)
    }
    
    public var endIndex: Index {
        return Index(tree: tree, index: nil)
    }

    public var count: Int {
        return tree.count
    }

    public subscript(index: Index) -> Element {
        let value = tree[index.index!]
        return (value.key, value.value)
    }

    public subscript(key: Key) -> Value? {
        get {
            guard let index = tree.find(key) else { return nil }
            return tree[index].value
        }
        set(newValue) {
            let (index, slot) = tree.insertionSlotFor(key)
            switch (index, newValue) {
            case (nil, nil):
                return
            case (.Some(let i), nil):
                tree.remove(i)
            case (nil, .Some(let value)):
                tree.insert(MapValue(key: key, value: value), into: slot)
            case (.Some(let i), .Some(let value)):
                tree[i] = MapValue(key: key, value: value)
            }
        }
    }

    // Methods.

    public func generate() -> Generator {
        return Generator(tree: tree)
    }

    public func indexForKey(key: Key) -> Index? {
        guard let i = tree.find(key) else { return nil }
        return Index(tree: tree, index: i)
    }

    public mutating func updateValue(value: Value, forKey key: Key) -> Value?
    {
        let (index, slot) = tree.insertionSlotFor(key)
        if let index = index {
            let old = tree[index].value
            tree[index] = MapValue(key: key, value: value)
            return old
        }
        else {
            tree.insert(MapValue(key: key, value: value), into: slot)
            return nil
        }
    }

    public mutating func removeAtIndex(index: Index) -> (Key, Value) {
        let mv = tree[index.index!]
        tree.remove(index.index!)
        return (mv.key, mv.value)
    }

    public mutating func removeValueForKey(key: Key) -> Value? {
        guard let index = tree.find(key) else { return nil }
        return tree.remove(index).value
    }

    public mutating func removeAll() {
        tree = Tree()
    }
}

