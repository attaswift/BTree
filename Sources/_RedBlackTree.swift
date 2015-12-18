//
//  RedBlackTree.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-17.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

public struct RedBlackIndex<Key: Comparable, Value>: Equatable {
    private typealias _Value = RedBlackValue<Key, Value>
    private typealias _Node = BinaryTreeNode<_Value>
    private typealias _Index = BinaryTreeIndex<RBPayload<_Value>>

    private let _index: _Index

    private init(_ index: _Index) {
        self._index = index
    }
}
func ==<Key: Comparable, Value>(a: RedBlackIndex<Key, Value>, b: RedBlackIndex<Key, Value>) {
    return a._index == b._index
}

public struct RedBlackNode<Key: Comparable, Value> {
    public typealias Index = RedBlackIndex<Key, Value>
    private typealias _Value = RedBlackValue<Key, Value>
    private typealias _Node = BinaryTreeNode<RBPayload<_Value>>

    private var _node: _Node

    private init(_ node: _Node) {
        self._node = node
    }

    public var parent: Index? {
        guard let p = _node.parent else { return nil }
        return Index(p)
    }
    public var left: Index? {
        guard let l = _node.left else { return nil }
        return Index(l)
    }
    public var right: Index? {
        guard let r = _node.right else { return nil }
        return Index(r)
    }

    public var key: Key {
        return _node.payload.value.key
    }

    public var value: Value {
        get { return _node.payload.value.value }
        set { _node.payload.value.value = newValue }
    }
}

internal struct RedBlackValue<_Key: Comparable, Value>: RBValue {
    typealias Key = _Key
    typealias State = Void

    private let key: Key
    private var value: Value

    func compare(key: Key, children: StateAccessor<RedBlackValue<Key, Value>>, insert: Bool) -> RBComparisonResult<Key> {
        if key < self.key {
            return .Descend(.Left, with: key)
        }
        else if key > self.key {
            return .Descend(.Right, with: key)
        }
        else if insert {
            return .Descend(.Right, with: key)
        }
        else {
            return .Found
        }
    }
}

/// A Red-Black tree implementation that allows duplicate keys.
public struct RedBlackTree<Key: Comparable, Value> {
    public typealias Index = RedBlackIndex<Key, Value>
    public typealias Node = RedBlackNode<Key, Value>

    private typealias _Value = RedBlackValue<Key, Value>
    private typealias _Payload = RBPayload<_Value>
    private typealias _Index = BinaryTreeIndex<_Payload>
    private typealias _Node = BinaryTreeNode<_Payload>
    private typealias _Slot = BinaryTreeSlot<_Payload>
    private typealias _Tree = RBTree<_Value>

    private var tree: _Tree

    public init() {
        self.tree = _Tree()
    }

    private func wrap(index: _Index) -> Index {
        return Index(index)
    }
    private func wrap(index: _Index?) -> Index? {
        guard let index = index else { return nil }
        return Index(index)
    }
    private func wrap(node: _Node) -> Node {
        return Node(node)
    }
    private func wrap(node: _Node?) -> Node? {
        guard let node = node else { return nil }
        return Node(node)
    }

    public var root: Index? {
        return wrap(tree.root)
    }

    public var first: Index? {
        return wrap(tree.firstIndex)
    }

    public var last: Index? {
        return wrap(tree.lastIndex)
    }

    public subscript(index: Index) -> Node {
        get {
            return wrap(tree[index._index])
        }
        set(node) {
            tree[index._index] = node._node
        }
    }

    /// Returns the topmost node with a key equal to `key`, or nil if there is no such node.
    /// - Note: All nodes matching `key` are in the subtree rooted at the returned index; but the top node may not be the first, nor the last.
    /// - SeeAlso: `floor`, `ceiling`, `findFirst`, `findLast`
    public func find(key: Key) -> Index? {
        return wrap(tree.find(key))
    }

    /// Returns the first node with a key equal to `key`, or nil if the tree contains no such node.
    public func findFirst(key: Key) -> Index? {
        guard let floor = floor(key) else { return nil }
        guard case .Found = tree.compare(floor._index, key: key, insert: false) else { return nil }
        return floor
    }

    /// Returns the last node with a key equal to `key`, or nil if the tree contains no such node.
    public func findLast(key: Key) -> Index? {
        guard let floor = ceiling(key) else { return nil }
        guard case .Found = tree.compare(floor._index, key: key, insert: false) else { return nil }
        return floor
    }

    public func findLastIndexBelow(key: Key) -> Index? {

    }

    public func findFirstIndexAfter(key: Key) -> Index? {
        
    }

    private func compare(a: Key, b: Key) -> NodeMatchingResult {
        if a < b { return .Before }
        if a > b { return .After }
        return .Same
    }

    public mutating func merge<S: SequenceType where S.Generator.Element == (Key, Value)>(elements: S) {
        var fastPath = false
        var precedingIndex: _Index? = nil
        var succeedingKey: Key? = nil
        for (key, value) in elements {
            if fastPath && succeedingKey != nil && key >= succeedingKey {
                fastPath = false
            }
            if !fastPath {
                precedingIndex = self.tree.lastIndexBeforeOrMatching { v in self.compare(v.key, b: key) }
                succeedingKey = self.tree[precedingIndex.flatMap(self.tree.successor) ?? self.tree.firstIndex]?.key
                fastPath = true
            }
            precedingIndex = self.insert(key, value: value, following: precedingIndex)
        }
    }


    /// Returns the index of the last node that has a key less than or equal to `key`, or nil if there is no such node.
    /// - Note: If there are multiple nodes in the tree matching `key`, the floor may be higher than the ceiling.
    public func floor(key: Key) -> Index? {
        return wrap(tree.floor(key))
    }

    /// Returns the index of the first node that has a key greater than or equal to `key`, or nil if there is no such node.
    /// - Note: If there are multiple nodes in the tree matching `key`, the ceiling may be lower than the floor.
    public func ceiling(key: Key) -> Index? {
        return wrap(tree.ceiling(key))
    }

    /// Insert a new value into this red-black tree with the given key.
    /// - Parameter hint: The floor of the key if known, or nil. When given, the insertion will be slightly faster.
    /// - Warning: It is a serious error to set hint to a non-nil value that is not the floor of the key.
    ///   In unoptimized builds, this will lead to a fatal error. In optimized builds, the tree will become broken and
    ///   subsequent operations may return out-of-order values or signal a fatal error.
    public mutating func insert(key: Key, value: Value) -> Index {
        self.tree.insert(RedBlackValue(key: key, value: value), into: self.tree.insertionSlotFor(key))
    }

    private mutating func insert(key: Key, value: Value, after: _Index?) -> _Index {
        let slot: _Slot
        if let after = after {
            let n = tree[after]
            if let right = n.right {
                slot = .Toward(.Left, under: tree.minimumUnder(right))
            }
            else {
                slot = .Toward(.Right, under: after)
            }
            return tree.insert(_Value(key: key, value: value), into: slot)
        }
        else {
            return self.insert(key: Key, value: Value, before: tree.firstIndex)
        }
    }

    public mutating func remove(index: Index) -> Index? {

    }
}