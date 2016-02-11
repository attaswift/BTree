//
//  Map.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-17.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// A tree-based mapping from `Key` to `Value` instances.
/// Also a collection of key-value pairs with a well-defined ordering.
public struct Map<Key: Comparable, Value>: OrderedAssociativeCollectionType {
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
            if let value = value {
                updateValue(value, forKey: key)
            }
            else {
                removeValueForKey(key)
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

    public func forEach(@noescape body: (Element) throws -> ()) rethrows {
        try root.forEach(body)
    }

    public func map<T>(@noescape transform: (Element) throws -> T) rethrows -> [T] {
        var result: [T] = []
        result.reserveCapacity(self.count)
        try self.forEach {
            result.append(try transform($0))
        }
        return result
    }

    public func flatMap<S : SequenceType>(transform: (Element) throws -> S) rethrows -> [S.Generator.Element] {
        var result: [S.Generator.Element] = []
        try self.forEach { element in
            result.appendContentsOf(try transform(element))
        }
        return result
    }

    public func flatMap<T>(@noescape transform: (Element) throws -> T?) rethrows -> [T] {
        var result: [T] = []
        try self.forEach { element in
            if let t = try transform(element) {
                result.append(t)
            }
        }
        return result
    }

    public func reduce<T>(initial: T, @noescape combine: (T, Element) throws -> T) rethrows -> T {
        var result = initial
        try self.forEach {
            result = try combine(result, $0)
        }
        return result
    }

    // Mutators

    public mutating func updateValue(value: Value, forKey key: Key) -> Value? {
        makeUnique()
        var replaced = false
        var result: Value? = nil
        var splinter: BTreeSplinter<Key, Value>? = nil
        root.editAtKey(key) { node, slot, match in
            if replaced {
                return
            }
            if match {
                result = node.payloads[slot]
                node.payloads[slot] = value
                replaced = true
                return
            }
            if node.isLeaf {
                node.keys.insert(key, atIndex: slot)
                node.payloads.insert(value, atIndex: slot)
                node.count += 1
                if node.isTooLarge {
                    splinter = node.split()
                }
            }
            else {
                node.count += 1
                if let s = splinter {
                    node.keys.insert(s.separator.0, atIndex: slot)
                    node.payloads.insert(s.separator.1, atIndex: slot)
                    node.children.insert(s.node, atIndex: slot + 1)
                    splinter = (node.isTooLarge ? node.split() : nil)
                }
            }
        }
        if let s = splinter {
            root = BTreeNode(order: root.order, keys: [s.separator.0], payloads: [s.separator.1], children: [root, s.node])
        }
        return result
    }

    public mutating func removeAtIndex(index: Index) -> (Key, Value) {
        let key = self[index].0
        makeUnique()
        return (key, self.removeValueForKey(key)!)
    }

    internal mutating func removeValueForKey(key: Key, under top: Node) -> Value? {
        var found: Bool = false
        var result: Value? = nil
        top.editAtKey(key) { node, slot, match in
            if node.isLeaf {
                assert(!found)
                if !match { return }
                found = true
                node.keys.removeAtIndex(slot)
                result = node.payloads.removeAtIndex(slot)
                node.count -= 1
                return
            }

            if match {
                assert(!found)
                // For internal nodes, we move the previous item in place of the removed one,
                // and remove its original slot instead. (The previous item is always in a leaf node.)
                result = node.payloads[slot]
                node.makeChildUnique(slot)
                let previousKey = node.children[slot].maxKey()!
                let previousPayload = removeValueForKey(previousKey, under: node.children[slot])!
                node.keys[slot] = previousKey
                node.payloads[slot] = previousPayload
                found = true
            }
            if found {
                node.count -= 1
                if node.children[slot].isTooSmall {
                    node.fixDeficiency(slot)
                }
            }
        }
        return result
    }

    public mutating func removeValueForKey(key: Key) -> Value? {
        makeUnique()
        let result = removeValueForKey(key, under: root)
        if root.keys.isEmpty && root.children.count == 1 {
            root = root.children[0]
        }
        return result
    }

    public mutating func removeAll() {
        root = Node()
    }
}
