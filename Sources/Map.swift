//
//  Map.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-14.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

private struct MapValue<Key: Comparable, Value>: RedBlackValue {
    var key: Key
    var value: Value

    init(key: Key, value: Value) {
        self.key = key
        self.value = value
    }

    func key(@noescape left: Void->MapValue<Key, Value>?) -> Key {
        return key
    }

    func compare(key: Key, @noescape left: Void->MapValue<Key, Value>?, insert: Bool) -> RedBlackComparisonResult<Key> {
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

    mutating func fixup(@noescape left: Void->MapValue<Key, Value>?, @noescape right: Void->MapValue<Key, Value>?) -> Bool {
        return false
    }
}

public struct MapIndex<Key: Comparable, Value>: BidirectionalIndexType, Comparable {
    private typealias TreeValue = MapValue<Key, Value>
    private typealias Tree = RedBlackTree<TreeValue>

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
public func < <Key: Comparable, Value>(a: MapIndex<Key, Value>, b: MapIndex<Key, Value>) -> Bool {
    return a.index < b.index
}

public struct MapGenerator<Key: Comparable, Value>: GeneratorType {
    public typealias Element = (Key, Value)

    private typealias TreeValue = MapValue<Key, Value>
    private typealias Tree = RedBlackTree<TreeValue>

    private let tree: Tree
    private var index: Index?

    private init(tree: Tree) {
        self.tree = tree
        self.index = tree.first
    }

    private init(tree: Tree, index: Index?) {
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

public struct Map<Key: Comparable, Value>: CollectionType {
    public typealias Index = MapIndex<Key, Value>
    public typealias Generator = MapGenerator<Key, Value>
    public typealias Element = (Key, Value)

    private typealias TreeValue = MapValue<Key, Value>
    private typealias Tree = RedBlackTree<TreeValue>

    private var tree: Tree

    // Initializers.

    public init() {
        self.tree = Tree()
    }

    public init(_ elements: Map<Key, Value>) {
        self.tree = elements.tree
    }

    public init<S: SequenceType where S.Generator.Element == Element>(_ elements: S) {
        self.tree = Tree()
        for (key, value) in elements {
            self[key] = value
        }
    }

    // Variables.

    public var startIndex: Index {
        return Index(tree: tree, index: tree.first)
    }
    
    public var endIndex: Index {
        return Index(tree: tree, index: nil)
    }

    public var count: Int {
        return tree.count
    }

    public var isEmpty: Bool {
        return tree.count == 0
    }

    public var keys: LazyMapCollection<Map<Key, Value>, Key> {
        return LazyMapCollection(self) { (key, value) in key }
    }

    public var values: LazyMapCollection<Map<Key, Value>, Value> {
        return LazyMapCollection(self) { (key, value) in value }
    }
    
    public var first: Element? {
        guard let first = tree.first else { return nil }
        let mv = tree[first]
        return (mv.key, mv.value)
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
                tree.replace(i, with: MapValue(key: key, value: value))
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
            tree.replace(index, with: MapValue(key: key, value: value))
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

    public mutating func removeAll() {
        tree = Tree()
    }
}

extension Map: DictionaryLiteralConvertible {
    public init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(elements)
    }
}

extension Map: CustomStringConvertible {
    public var description: String {
        let contents = self.map { (key, value) -> String in
            let ks = String(key)
            let vs = String(value)
            return "\(ks): \(vs)"
        }
        return "[" + contents.joinWithSeparator(", ") + "]"
    }
}

extension Map: CustomDebugStringConvertible {
    public var debugDescription: String {
        let contents = self.map { (key, value) -> String in
            let ks = String(reflecting: key)
            let vs = String(reflecting: value)
            return "\(ks): \(vs)"
        }
        return "[" + contents.joinWithSeparator(", ") + "]"
    }
}

@warn_unused_result
public func ==<Key: Comparable, Value: Equatable>(a: Map<Key, Value>, b: Map<Key, Value>) -> Bool {
    guard a.count == b.count else { return false }
    return a.elementsEqual(b, isEquivalent: { ae, be in ae.0 == be.0 && ae.1 == be.1 })
}

@warn_unused_result
public func !=<Key: Comparable, Value: Equatable>(a: Map<Key, Value>, b: Map<Key, Value>) -> Bool {
    return !(a == b)
}
