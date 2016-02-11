//
//  Map.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-17.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// An ordered mapping from comparable keys to arbitrary values. 
/// Works like `Dictionary`, but provides a well-defined ordering for its elements.
///
/// `Map` stores its elements in an in-memory b-tree. 
/// Lookup, insertion and removal of individual elements have logarithmic complexity.
public struct Map<Key: Comparable, Value> {
    // Typealiases
    internal typealias Node = BTreeNode<Key, Value>

    // Stored properties

    /// The root node.
    internal private(set) var root: Node

    // Initalizer 

    /// Initialize an empty map.
    public init() {
        self.root = Node()
    }
}

//MARK: Uniqueness

extension Map {
    /// True iff this map holds the only reference to its root node.
    private var isUnique: Bool {
        mutating get { return isUniquelyReferenced(&root) }
    }

    /// Ensure that this map holds the only reference to its root node, cloning it when necessary.
    private mutating func makeUnique() {
        guard !isUnique else { return }
        root = root.clone()
    }
}

//MARK: CollectionType

extension Map: CollectionType {
    public typealias Index = BTreeIndex<Key, Value>
    public typealias Generator = BTreeGenerator<Key, Value>
    public typealias Element = (Key, Value)

    public var startIndex: Index {
        return root.startIndex
    }

    public var endIndex: Index {
        return root.endIndex
    }

    /// The number of (key, value) pairs in this map.
    ///
    /// - Complexity: O(1)
    public var count: Int {
        return root.count
    }

    /// True iff this collection has no elements.
    public var isEmpty: Bool {
        return count == 0
    }

    /// Returns the (key, value) pair at the given index.
    ///
    /// - Requires: `index` originated from an unmutated copy of this map.
    /// - Complexity: O(1)
    public subscript(index: Index) -> Element {
        return root[index]
    }

    /// Return a generator over all (key, value) pairs in this map, in ascending key order.
    @warn_unused_result
    public func generate() -> Generator {
        return root.generate()
    }
}

//MARK: Algorithms

extension Map {
    /// Call `body` on each element in `self` in ascending key order.
    ///
    /// - Complexity: O(`count`)
    public func forEach(@noescape body: (Element) throws -> ()) rethrows {
        try root.forEach(body)
    }

    /// Return an `Array` containing the results of mapping `transform` over all elements in `self`.
    /// The elements are transformed in ascending key order.
    ///
    /// - Complexity: O(`count`)
    @warn_unused_result
    public func map<T>(@noescape transform: (Element) throws -> T) rethrows -> [T] {
        var result: [T] = []
        result.reserveCapacity(self.count)
        try self.forEach {
            result.append(try transform($0))
        }
        return result
    }

    @warn_unused_result
    public func flatMap<S : SequenceType>(transform: (Element) throws -> S) rethrows -> [S.Generator.Element] {
        var result: [S.Generator.Element] = []
        try self.forEach { element in
            result.appendContentsOf(try transform(element))
        }
        return result
    }

    @warn_unused_result
    public func flatMap<T>(@noescape transform: (Element) throws -> T?) rethrows -> [T] {
        var result: [T] = []
        try self.forEach { element in
            if let t = try transform(element) {
                result.append(t)
            }
        }
        return result
    }

    @warn_unused_result
    public func reduce<T>(initial: T, @noescape combine: (T, Element) throws -> T) rethrows -> T {
        var result = initial
        try self.forEach {
            result = try combine(result, $0)
        }
        return result
    }
}

//MARK: Dictionary methods

extension Map {

    /// A collection containing just the keys in this map, in ascending order.
    public var keys: LazyMapCollection<Map<Key, Value>, Key> {
        return self.lazy.map { $0.0 }
    }

    /// A collection containing just the values in this map, in order of ascending keys.
    public var values: LazyMapCollection<Map<Key, Value>, Value> {
        return self.lazy.map { $0.1 }
    }

    /// Provides access to the value for a given key. Nonexistent values are represented as `nil`.
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

    /// Returns the index for the given key, or `nil` if the key is not present in this map.
    @warn_unused_result
    public func indexForKey(key: Key) -> Index? {
        return root.indexOf(key)
    }

    /// Update the value stored in the map for the given key, or, if they key does not exist, add a new key-value pair to the map.
    /// Returns the value that was replaced, or `nil` if a new key-value pair was added.
    ///
    /// This method invalidates all existing indexes into `self`.
    ///
    /// - Complexity: O(log(`count`))
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

    /// Remove the key-value pair at `index` from this map.
    ///
    /// This method invalidates all existing indexes into `self`.
    ///
    /// - Complexity: O(log(`count`))
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

    /// Remove a given key and the associated value from this map.
    /// Returns the value that was removed, or `nil` if the key was not present in the map.
    ///
    /// This method invalidates all existing indexes into `self`.
    ///
    /// - Complexity: O(log(`count`))
    public mutating func removeValueForKey(key: Key) -> Value? {
        makeUnique()
        let result = removeValueForKey(key, under: root)
        if root.keys.isEmpty && root.children.count == 1 {
            root = root.children[0]
        }
        return result
    }

    /// Remove all elements from this map.
    ///
    /// This method invalidates all existing indexes into `self`.
    ///
    /// - Complexity: O(`count`)
    public mutating func removeAll() {
        root = Node()
    }
}

extension Map: DictionaryLiteralConvertible {
    /// Initialize a new map from the given elements.
    public init(dictionaryLiteral elements: (Key, Value)...) {
        self.init()
        for (key, value) in elements {
            self[key] = value
        }
    }
}

extension Map: CustomStringConvertible {
    /// A textual representation of this map.
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
    /// A textual representation of this map, suitable for debugging.
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

