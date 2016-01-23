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
    internal typealias Tree = BTree<Key, Value>

    public typealias Index = TreeIndex<Key, Value>
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
        return tree.startIndex
    }

    public var endIndex: Index {
        return tree.endIndex
    }

    public var count: Int {
        return tree.count
    }

    // Subscripts

    public subscript(index: Index) -> Element {
        return tree[index]
    }

    public subscript(key: Key) -> Value? {
        get {
            return tree.payloadOf(key)
        }
        set(value) {
            if let value = value {
                tree.set(key, to: value)
            }
            else {
                tree.remove(key)
            }
        }
    }

    // Methods

    public func generate() -> Generator {
        return Generator(tree.generate())
    }

    public func _copyToNativeArrayBuffer() -> _ContiguousArrayBuffer<Element> {
        // The comment in BTree._copyToNativeArrayBuffer explains what this is.
        return tree._copyToNativeArrayBuffer()
    }

    public func indexForKey(key: Key) -> Index? {
        guard let i = tree.indexOf(key) else { return nil }
        return Index(i)
    }

    // Mutators

    public mutating func updateValue(value: Value, forKey key: Key) -> Value? {
        return tree.set(key, to: value)
    }

    public mutating func removeAtIndex(index: Index) -> (Key, Value) {
        return tree.removeAt(index)
    }

    public mutating func removeValueForKey(key: Key) -> Value? {
        return tree.remove(key)
    }

    public mutating func removeAll() {
        tree = Tree()
    }
}

public struct MapGenerator<Key: Comparable, Value>: GeneratorType {
    public typealias Element = (Key, Value)

    private var generator: BTreeGenerator<Key, Value>

    private init(_ generator: BTreeGenerator<Key, Value>) {
        self.generator = generator
    }

    public mutating func next() -> Element? {
        return generator.next()
    }
}

