//
//  RedBlackTree.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-14.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

internal enum Color {
    case Red
    case Black
}

internal struct RedBlackPayload<Value: RedBlackValue> {
    var value: Value
    var color: Color = .Red

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

    // Implementation mostly follows Cormen et al.[1], with many adjustments.
    //
    // [1]: Cormen, Leiserson, Rivest, Stein: Introduction to Algorithms, 2nd ed. (MIT Press, 2001)

    internal typealias Key = Value.Key
    internal typealias Payload = RedBlackPayload<Value>

    internal private(set) var tree: BinaryTree<Payload>

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
        assert(tree.indexInSlot(slot) == nil)
        let index = tree.insert(Payload(value: value), into: slot)
        rebalanceAfterInsert(index, slot: slot)
        return index
    }

    internal mutating func remove(index: Index) -> Value {
        let old = value(index)

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
        rebalanceAfterRemove(slot)
        return old
    }

    internal mutating func reserveCapacity(minimumCapacity: Int) {
        self.tree.reserveCapacity(minimumCapacity)
    }

    internal mutating func removeAll(keepCapacity keepCapacity: Bool = false) {
        tree.removeAll(keepCapacity: keepCapacity)
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

    private mutating func fixup(index: Index?) -> Bool {
        guard let index = index else { return false }
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

    private mutating func rebalanceAfterInsert(new: Index, slot: Slot) -> Index {
        var new = new
        var x = new
        while case .Toward(let xdir, under: let p) = tree.slotOf(x) {
            guard isRed(p) else {
                fixupChain(p)
                break
            }
            fixup(p)
            guard case .Toward(let pdir, under: let gp) = tree.slotOf(p) else  { fatalError("Invalid tree with red root") }
            let popp = pdir.opposite

            if let y = tree[gp, popp] where isRed(y) {
                setBlack(p)
                setBlack(y)
                setRed(gp)
                x = gp
            }
            else {
                if xdir == popp {
                    tree.rotate(p, pdir)
                    if x == new {
                        new = p // new node moved up to root of subtree
                    }
                    fixup(x)
                }
                tree.rotate(gp, popp)
                if p == new {
                    new = gp // new node moved up to root of subtree
                }
                setBlack(gp)
                setRed(p)
                fixup(p)
                fixup(gp)
            }
        }
        tree[tree.root!].payload.color = .Black
        return new
    }

    private mutating func rebalanceAfterRemove(slot: Slot) {

    }

}

internal struct RedBlackInfo: CustomStringConvertible {
    let depths: Range<Int>
    let ranks: Range<Int>
    let invalidRedNodes: [Index]

    var isValidRedBlackTree: Bool {
        return ranks.count == 1 && invalidRedNodes.isEmpty
    }

    var description: String {
        return "[depth: \(depths.startIndex)...\(depths.endIndex - 1), rank: \(ranks.startIndex)...\(ranks.endIndex - 1), bad reds: \(invalidRedNodes)]"
    }
}
extension RedBlackTree {

    internal var debugInfo: RedBlackInfo {
        func walk(index: Index?, shouldBeBlack: Bool) -> RedBlackInfo {
            if let index = index {
                let color = self.color(index)
                let i1 = walk(tree.left(index), shouldBeBlack: color == .Red)
                let i2 = walk(tree.right(index), shouldBeBlack: color == .Red)
                let b = color == .Black ? 1 : 0

                let colorError: [Index] = (color == .Red && shouldBeBlack ? [index] : [])

                return RedBlackInfo(
                    depths: Range(
                        start: min(i1.depths.startIndex, i2.depths.startIndex) + 1,
                        end: max(i1.depths.endIndex, i2.depths.endIndex) + 1),
                    ranks: Range(
                        start: min(i1.ranks.startIndex, i2.ranks.startIndex) + b,
                        end: max(i1.ranks.endIndex, i2.ranks.endIndex) + b),
                    invalidRedNodes: i1.invalidRedNodes + i2.invalidRedNodes + colorError)
            }
            else {
                return RedBlackInfo(
                    depths: Range(start: 0, end: 1),
                    ranks: Range(start: 0, end: 1),
                    invalidRedNodes: [])
            }
        }
        return walk(tree.root, shouldBeBlack: true)
    }
}
