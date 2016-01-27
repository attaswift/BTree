//
//  Map.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-17.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

public struct Map<Key: Comparable, Value>: SortedAssociativeCollectionType {
    // Typealiases
    internal typealias Node = BTreeNode<Key, Value>

    public typealias Index = BTreeIndex<Key, Value>
    public typealias Generator = BTreeGenerator<Key, Value>
    public typealias Element = (Key, Value)

    // Stored properties

    internal private(set) var root: Node

    // Initalizer 
    public init() {
        self.root = Node()
    }

    // Uniqueness

    private var isUnique: Bool {
        mutating get { return isUniquelyReferenced(&root) }
    }

    private mutating func makeUnique() {
        guard !isUnique else { return }
        root = root.clone()
    }

    // Properties
    public var startIndex: Index {
        return root.startIndex
    }

    public var endIndex: Index {
        return root.endIndex
    }

    public var count: Int {
        return root.count
    }

    // Subscripts

    public subscript(index: Index) -> Element {
        return root[index]
    }

    public subscript(key: Key) -> Value? {
        get {
            return root.payloadOf(key)
        }
        set(value) {
            makeUnique()
            if let value = value {
                root.set(key, to: value)
            }
            else {
                self.removeValueForKey(key)
            }
        }
    }

    // Methods

    public func generate() -> Generator {
        return root.generate()
    }

    public func indexForKey(key: Key) -> Index? {
        return root.indexOf(key)
    }

    // Mutators

    public mutating func updateValue(value: Value, forKey key: Key) -> Value? {
        makeUnique()
        return root.set(key, to: value)
    }

    public mutating func removeAtIndex(index: Index) -> (Key, Value) {
        makeUnique()
        return root.removeAt(index)
    }

    public mutating func removeValueForKey(key: Key) -> Value? {
        makeUnique()
        return root.remove(key)
    }

    public mutating func removeAll() {
        root = Node()
    }
}
