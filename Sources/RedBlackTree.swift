//
//  RedBlackTree.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-14.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

private enum Color {
    case Red
    case Black
}

private struct RedBlackPayload<Value: RedBlackValue> {
    var value: Value
    var color: Color = .Black

    init(value: Value) {
        self.value = value
    }
}

internal enum RedBlackComparisonResult<Key> {
    /// The value matches the key.
    case Found
    /// The search should continue with the child towards `direction`, using the given replacement key.
    case Descend(Direction, with: Key)
}

/// The value of a node in our red-black tree holds some state that can be compared with a key to determine if the
/// value matches the key, or if not, which direction the matching should descend further.
/// This is used to implement variants of red-black trees, with different semantics for the key.
///
/// There are three implementations of this protocol:
///
/// - `MapValue` is used to implement `Map<Key, Value>`, an ordered dictionary.
/// - `ListValue` is used to implement `List<Element>, a list with logarithmic lookup/insert/remove/append operations.
///   `List` defines a red-black tree where the "key" of a node is the current index of it in the list.
internal protocol RedBlackValue {
    typealias Key: Equatable

    func key(@noescape left: Void->Self?) -> Key
    func compare(key: Key, @noescape left: Void->Self?, insert: Bool) -> RedBlackComparisonResult<Key>

    /// Recalculate self's state with specified new children. Return true if this self's parent also needs to be fixed up.
    mutating func fixup(@noescape left: Void->Self?, @noescape right: Void->Self?) -> Bool
}

internal struct RedBlackTree<Value: RedBlackValue> {
    internal typealias Key = Value.Key
    private typealias Payload = RedBlackPayload<Value>

    private var tree: BinaryTree<Payload>

    // Init

    internal init() {
        self.tree = BinaryTree<Payload>()
    }

    internal var count: Int { return tree.count }

    internal var root: Index? { return tree.root }

    internal subscript(index: Index) -> Value {
        get {
            return value(index)
        }
        set(newValue) {
            // The new value must have the same key as the old.
            let node = tree[index]
            let oldValue = node.payload.value
            let left = { self.tree[node.left]?.payload.value }
            assert(oldValue.key(left) == newValue.key(left))
            self.tree[index].payload.value = newValue
        }
    }
    internal mutating func replace(index: Index, with value: Value) {
    }
    


    internal func find(key: Key) -> Index? {
        var key = key
        var index = tree.root
        while let i = index {
            switch self.compare(i, key: key, insert: false) {
            case .Found:
                return i
            case .Descend(let d, with: let k):
                key = k
                index = tree[i, d]
            }
        }
        return nil
    }

    internal var first: Index? {
        guard let r = root else { return nil }
        return minimumUnder(r)
    }

    internal var last: Index? {
        guard let r = root else { return nil }
        return maximumUnder(r)
    }

    internal func successor(index: Index) -> Index? {
        return step(index, towards: .Right)
    }

    internal func predecessor(index: Index) -> Index? {
        return step(index, towards: .Left)
    }

    internal func insertionSlotFor(key: Key) -> (Index?, Slot) {
        guard let root = tree.root else { return (nil, .Root) }

        func slot(child: Index?, _ parent: Index?, _ direction: Direction?) -> (Index?, Slot) {
            guard let d = direction else { return (child, .Root) }
            return (child, .Toward(d, under: parent!))
        }

        var key = key
        var parent: Index? = nil
        var direction: Direction? = nil
        var child = tree.root

        while let c = child {
            switch self.compare(c, key: key, insert: true) {
            case .Found:
                return slot(c, parent, direction)
            case .Descend(let d, with: let k):
                key = k
                parent = c
                direction = d
                child = tree[c, d]
            }
        }
        return slot(nil, parent, direction)
    }

    internal mutating func insert(value: Value, into slot: Slot) -> Index {
        precondition(tree.indexInSlot(slot) == nil)
        return tree.insert(Payload(value: value), into: slot)
    }

    internal mutating func remove(index: Index) {
        // Find the node that we will actually remove. The node has to have at most one child.
        var y: Index
        if let _ = tree.left(index), let r = tree.right(index) {
            y = minimumUnder(r) // Remove node following original index
            setValue(index, value: value(y))
        }
        else {
            y = index
        }

        let slot = tree.remove(y)
        fixupAfterRemove(slot)
    }

    // Lookup utilites

    private func color(index: Index?) -> Color {
        guard let index = index else { return .Black }
        return tree[index].payload.color
    }
    private func isRed(index: Index?) -> Bool {
        return color(index) == .Red
    }
    private func isBlack(index: Index?) -> Bool {
        return color(index) == .Black
    }

    private func value(index: Index) -> Value {
        return tree[index].payload.value
    }
    private func value(index: Index?) -> Value? {
        guard let index = index else { return nil }
        return self.value(index)
    }

    private func compare(index: Index, key: Key, insert: Bool) -> RedBlackComparisonResult<Key> {
        let node = tree[index]
        let result = node.payload.value.compare(key, left: { self.tree[node.left]?.payload.value }, insert: insert)
        return result
    }

    private mutating func fixup(index: Index) -> Bool {
        var node = tree[index]
        let result = node.payload.value.fixup({ self.tree[node.left]?.payload.value }, right: { self.tree[node.right]?.payload.value })
        tree[index].payload.value = node.payload.value
        return result
    }

    private mutating func fixupChain(index: Index) {
        var index: Index? = index
        while let i = index where self.fixup(i) {
            index = tree[i, .Parent]
        }
    }

    private mutating func setRed(index: Index) {
        tree[index].payload.color = .Red
    }
    private mutating func setBlack(index: Index) {
        tree[index].payload.color = .Black
    }
    private mutating func setValue(index: Index, value: Value) {
        tree[index].payload.value = value
    }

    // Private helpers

    private func step(index: Index, towards direction: Direction) -> Index? {
        if let n = tree[index, direction] {
            return tree.furthestLeafUnder(n, towards: direction.opposite)
        }
        var child = index
        var parent = tree.parent(child)
        while let p = parent where child == tree[p, direction] {
            child = p
            parent = tree.parent(child)
        }
        return parent
    }

    private func minimumUnder(index: Index) -> Index {
        return tree.furthestLeafUnder(index, towards: .Left)
    }

    private func maximumUnder(index: Index) -> Index {
        return tree.furthestLeafUnder(index, towards: .Right)
    }

    private mutating func fixupAfterInsert(new: Index) {

    }

    private mutating func fixupAfterRemove(slot: Slot) {

    }

}

