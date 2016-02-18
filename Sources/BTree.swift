//
//  BTree.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2016-01-13.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import Foundation

// `bTreeNodeSize` is the maximum size (in bytes) of the keys in a single, fully loaded b-tree node.
// This is related to the order of the b-tree, i.e., the maximum number of children of an internal node.
//
// Common sense indicates (and benchmarking verifies) that the fastest b-tree order depends on `strideof(key)`:
// doubling the size of the key roughly halves the optimal order. So there is a certain optimal overall node size that
// is independent of the key; this value is supposed to be that size.
//
// Obviously, the optimal node size depends on the hardware we're running on.
// Benchmarks performed on various systems (Apple A5X, A8X, A9; Intel Core i5 Sandy Bridge, Core i7 Ivy Bridge) 
// indicate that 8KiB is a good overall choice.
// (This may be related to the size of the L1 cache, which is frequently 16kiB or 32kiB.)
//
// It is not a good idea to use powers of two as the b-tree order, as that would lead to Array reallocations just before
// a node is split. A node size that's just below 2^n seems like a good choice.
internal let bTreeNodeSize = 8191

//MARK: BTreeNode definition

/// A node in an in-memory b-tree data structure, efficiently mapping `Comparable` keys to arbitrary payloads.
/// Iterating over the elements in a b-tree returns them in ascending order of their keys.
internal final class BTreeNode<Key: Comparable, Payload>: NonObjectiveCBase {
    /// FIXME: Allocate keys/payloads/children in a single buffer

    /// A sorted array of keys.
    internal var keys: Array<Key>
    /// The payload that belongs to each key in the `keys` array, respectively.
    internal var payloads: Array<Payload>
    /// An empty array (when this is a leaf), or `keys.count + 1` child nodes (when this is an internal node).
    internal var children: Array<BTreeNode>

    /// The number of elements in this b-tree.
    internal var count: Int

    /// The order of this b-tree. An internal node will have at most this many children.
    internal var _order: Int32
    /// The depth of this b-tree.
    internal var _depth: Int32

    internal var depth: Int { return numericCast(_depth) }
    internal var order: Int { return numericCast(_order) }

    internal init(order: Int, keys: Array<Key>, payloads: Array<Payload>, children: Array<BTreeNode>) {
        assert(children.count == 0 || keys.count == children.count - 1)
        assert(payloads.count == keys.count)
        self._order = numericCast(order)
        self.keys = keys
        self.payloads = payloads
        self.children = children
        self.count = self.keys.count + children.reduce(0) { $0 + $1.count }
        self._depth = (children.count == 0 ? 0 : children[0]._depth + 1)
        super.init()
        assert(children.indexOf { $0._depth + 1 != self._depth } == nil)
    }
}

//MARK: Convenience initializers

extension BTreeNode {
    static var defaultOrder: Int {
        return max(bTreeNodeSize / strideof(Key), 32)
    }

    convenience init(order: Int = BTreeNode<Key, Payload>.defaultOrder) { // TODO: This should be internal
        self.init(order: order, keys: [], payloads: [], children: [])
    }

    internal convenience init(left: BTreeNode, separator: (Key, Payload), right: BTreeNode) {
        assert(left.order == right.order)
        self.init(
            order: left.order,
            keys: [separator.0],
            payloads: [separator.1],
            children: [left, right])
    }
}

//MARK: Uniqueness

extension BTreeNode {
    func makeChildUnique(index: Int) -> BTreeNode {
        guard !isUniquelyReferenced(&children[index]) else { return children[index] }
        let clone = children[index].clone()
        children[index] = clone
        return clone
    }

    func clone() -> BTreeNode {
        return BTreeNode(order: order, keys: keys, payloads: payloads, children: children)
    }
}

//MARK: Internal limits and properties

extension BTreeNode {
    internal var maxChildren: Int { return order }
    internal var minChildren: Int { return (maxChildren + 1) / 2 }
    internal var maxKeys: Int { return maxChildren - 1 }
    internal var minKeys: Int { return minChildren - 1 }

    internal var isLeaf: Bool { return children.isEmpty }
    internal var isTooSmall: Bool { return keys.count < minKeys }
    internal var isTooLarge: Bool { return keys.count > maxKeys }
    internal var isBalanced: Bool { return keys.count >= minKeys && keys.count <= maxKeys }
}

//MARK: SequenceType

extension BTreeNode: SequenceType {
    typealias Generator = BTreeGenerator<Key, Payload>
    typealias Element = Generator.Element

    var isEmpty: Bool { return count == 0 }

    func generate() -> Generator {
        return BTreeGenerator(self)
    }

    /// Call `body` on each element in self in the same order as a for-in loop.
    func forEach(@noescape body: (Element) throws -> ()) rethrows {
        if isLeaf {
            for i in 0 ..< keys.count {
                try body((keys[i], payloads[i]))
            }
        }
        else {
            for i in 0 ..< keys.count {
                try children[i].forEach(body)
                try body((keys[i], payloads[i]))
            }
            try children[keys.count].forEach(body)
        }
    }

    /// A version of `forEach` that allows `body` to interrupt iteration by returning `false`.
    /// 
    /// - Returns: `true` iff `body` returned true for all elements in the tree.
    func forEach(@noescape body: (Element) throws -> Bool) rethrows -> Bool {
        if isLeaf {
            for i in 0 ..< keys.count {
                guard try body((keys[i], payloads[i])) else { return false }
            }
        }
        else {
            for i in 0 ..< keys.count {
                guard try children[i].forEach(body) else { return false }
                guard try body((keys[i], payloads[i])) else { return false }
            }
            guard try children[keys.count].forEach(body) else { return false }
        }
        return true
    }

}

//MARK: CollectionType
extension BTreeNode: CollectionType {
    typealias Index = BTreeIndex<Key, Payload>

    var startIndex: Index {
        return Index(startIndexOf: self)
    }

    var endIndex: Index {
        return Index(endIndexOf: self)
    }

    subscript(index: Index) -> (Key, Payload) {
        get {
            precondition(index.root.value === self)
            let node = index.path.last!.value!
            return (node.keys[index.slot], node.payloads[index.slot])
        }
    }
}

//MARK: Lookup

extension BTreeNode {
    internal func slotOf(key: Key) -> (index: Int, match: Bool) {
        var start = 0
        var end = keys.count
        while start < end {
            let mid = start + (end - start) / 2
            if keys[mid] < key {
                start = mid + 1
            }
            else {
                end = mid
            }
        }
        return (start, start < keys.count && keys[start] == key)
    }

    internal func slotOf(child: BTreeNode) -> Int? {
        guard !isLeaf else { return nil }
        return self.children.indexOf { $0 === child }
    }

    func payloadOf(key: Key) -> Payload? {
        var node = self
        while !node.isLeaf {
            let slot = node.slotOf(key)
            if slot.match {
                return node.payloads[slot.index]
            }
            node = node.children[slot.index]
        }
        let slot = node.slotOf(key)
        guard slot.match else { return nil }
        return node.payloads[slot.index]
    }

    func indexOf(key: Key) -> Index? {
        var node = self
        var path = [Weak(self)]
        while !node.isLeaf {
            let slot = node.slotOf(key)
            if slot.match {
                return Index(path: path, slot: slot.index)
            }
            node = node.children[slot.index]
            path.append(Weak(node))
        }
        let slot = node.slotOf(key)
        guard slot.match else { return nil }
        return Index(path: path, slot: slot.index)
    }
}

//MARK: Positional lookup

extension BTreeNode {
    func positionOf(key: Key) -> Int? {
        var node = self
        var position = 0
        while !node.isLeaf {
            let slot = node.slotOf(key)
            position += node.children[0 ..< slot.index].reduce(0, combine: { $0 + $1.count })
            if slot.match {
                return position
            }
            node = node.children[slot.index]
        }
        let slot = node.slotOf(key)
        guard slot.match else { return nil }
        return position + slot.index
    }

    func positionOf(index: Index) -> Int {
        precondition(index.path.count > 0 && index.path[0].value === self)
        var position = index.slot
        var i = index.path.count - 1
        while i > 0 {
            guard let parent = index.path[i - 1].value else { fatalError("Invalid index") }
            guard let child = index.path[i].value else { fatalError("Invalid index") }
            guard let slot = parent.slotOf(child) else { fatalError("Invalid index") }
            position += slot
            for j in 0...slot {
                position += parent.children[j].count
            }
            i -= 1
        }
        return position
    }

    internal func slotOfPosition(position: Int) -> (index: Int, match: Bool, position: Int) {
        assert(position >= 0 && position <= count)
        if isLeaf {
            return (position, true, position)
        }
        else {
            var p = 0
            for i in 0 ..< children.count {
                let c = children[i].count
                if position == p + c {
                    return (index: i, match: true, position: p + c)
                }
                if position < p + c {
                    return (index: i, match: false, position: p + c)
                }
                p += c + 1
            }
            preconditionFailure("Invalid b-tree")
        }
    }

    internal func positionOfSlot(slot: Int) -> Int {
        assert(slot <= keys.count)
        if isLeaf {
            return slot
        }
        else {
            return children[0...slot].reduce(slot) { $0 + $1.count }
        }
    }

    internal func indexOfPosition(position: Int) -> Index {
        precondition(position >= 0 && position < count)
        var position = position
        var path = [Weak(self)]
        var node = self
        while !node.isLeaf {
            var count = 0
            for (i, child) in node.children.enumerate() {
                let c = count + child.count
                if position < c {
                    node = child
                    path.append(Weak(child))
                    position -= count
                    break
                }
                if position == c {
                    return Index(path: path, slot: i)
                }
                count = c + 1
            }
        }
        assert(position < node.keys.count)
        return Index(path: path, slot: position)
    }

    internal func elementAtPosition(position: Int) -> (Key, Payload) {
        precondition(position >= 0 && position < count)
        var position = position
        var node = self
        while !node.isLeaf {
            var count = 0
            for (i, child) in node.children.enumerate() {
                let c = count + child.count
                if position < c {
                    node = child
                    position -= count
                    break
                }
                if position == c {
                    return (node.keys[i], node.payloads[i])
                }
                count = c + 1
            }
        }
        return (node.keys[position], node.payloads[position])
    }
}

//MARK: Editing

extension BTreeNode {
    internal func editAtPosition(position: Int, @noescape operation: (node: BTreeNode, slot: Int, match: Bool) -> Void) {
        precondition(position >= 0 && position <= self.count)
        if isLeaf {
            operation(node: self, slot: position, match: true)
            return
        }
        var count = 0
        for slot in 0 ..< children.count {
            let child = children[slot]
            let c = count + child.count
            if position < c {
                self.makeChildUnique(slot)
                child.editAtPosition(position - count, operation: operation)
                operation(node: self, slot: slot, match: false)
                return
            }
            if position == c {
                operation(node: self, slot: slot, match: true)
                return
            }
            count = c + 1
        }
        fatalError("Invalid BTreeNode")
    }

    internal func editAtKey(key: Key, @noescape operation: (node: BTreeNode, slot: Int, match: Bool) -> Void) {
        let slot = slotOf(key)
        if slot.match || isLeaf {
            operation(node: self, slot: slot.index, match: slot.match)
            return
        }
        makeChildUnique(slot.index)
        let child = children[slot.index]
        child.editAtKey(key, operation: operation)
        operation(node: self, slot: slot.index, match: false)
    }
}

//MARK: Insertion

internal struct BTreeSplinter<Key: Comparable, Payload> {
    let separator: (Key, Payload)
    let node: BTreeNode<Key, Payload>
}

extension BTreeNode {
    /// Split this node into two, removing the high half of the nodes and putting them in a splinter.
    ///
    /// - Returns: A splinter containing the higher half of the original node.
    internal func split() -> BTreeSplinter<Key, Payload> {
        return split(keys.count / 2)
    }

    /// Split this node into two at the key at index `median`, removing all elements at or above `median` 
    /// and putting them in a splinter.
    ///
    /// - Returns: A splinter containing the higher half of the original node.
    internal func split(median: Int) -> BTreeSplinter<Key, Payload> {
        assert(isTooLarge)
        let count = keys.count
        let separator = (keys[median], payloads[median])
        let node = BTreeNode(
            order: self.order,
            keys: Array(keys[median + 1 ..< count]),
            payloads: Array(payloads[median + 1 ..< count]),
            children: isLeaf ? [] : Array(children[median + 1 ..< count + 1]))
        keys.removeRange(median ..< count)
        payloads.removeRange(median ..< count)
        if isLeaf {
            self.count = median
        }
        else {
            children.removeRange(median + 1 ..< count + 1)
            self.count = median + children.reduce(0, combine: { $0 + $1.count })
        }
        assert(node.depth == self.depth)
        return BTreeSplinter(separator: separator, node: node)
    }

    internal func insert(splinter: BTreeSplinter<Key, Payload>, inSlot slot: Int) {
        keys.insert(splinter.separator.0, atIndex: slot)
        payloads.insert(splinter.separator.1, atIndex: slot)
        children.insert(splinter.node, atIndex: slot + 1)
    }
}

//MARK: Removal

extension BTreeNode {
    internal func maxKey() -> Key? {
        var node = self
        while !node.isLeaf {
            node = node.children.last!
        }
        return node.keys.last
    }

    /// Reorganize the tree rooted at `self` so that the undersize child in `slot` is corrected.
    /// As a side effect of the process, `self` may itself become undersized, but all of its descendants
    /// become balanced.
    internal func fixDeficiency(slot: Int) {
        assert(!isLeaf && children[slot].isTooSmall)
        if slot > 0 && children[slot - 1].keys.count > minKeys {
            rotateRight(slot)
        }
        else if slot < children.count - 1 && children[slot + 1].keys.count > minKeys {
            rotateLeft(slot)
        }
        else if slot > 0 {
            // Collapse deficient slot into previous slot.
            collapse(slot - 1)
        }
        else {
            // Collapse next slot into deficient slot.
            collapse(slot)
        }
    }

    private func rotateRight(slot: Int) {
        assert(slot > 0)
        makeChildUnique(slot)
        makeChildUnique(slot - 1)
        children[slot].keys.insert(keys[slot - 1], atIndex: 0)
        children[slot].payloads.insert(payloads[slot - 1], atIndex: 0)
        if !children[slot].isLeaf {
            let lastGrandChildBeforeSlot = children[slot - 1].children.removeLast()
            children[slot].children.insert(lastGrandChildBeforeSlot, atIndex: 0)

            children[slot - 1].count -= lastGrandChildBeforeSlot.count
            children[slot].count += lastGrandChildBeforeSlot.count
        }
        keys[slot - 1] = children[slot - 1].keys.removeLast()
        payloads[slot - 1] = children[slot - 1].payloads.removeLast()

        children[slot - 1].count -= 1
        children[slot].count += 1
    }
    
    private func rotateLeft(slot: Int) {
        assert(slot < children.count - 1)
        makeChildUnique(slot)
        makeChildUnique(slot + 1)
        children[slot].keys.append(keys[slot])
        children[slot].payloads.append(payloads[slot])
        if !children[slot].isLeaf {
            let firstGrandChildAfterSlot = children[slot + 1].children.removeAtIndex(0)
            children[slot].children.append(firstGrandChildAfterSlot)

            children[slot + 1].count -= firstGrandChildAfterSlot.count
            children[slot].count += firstGrandChildAfterSlot.count
        }
        keys[slot] = children[slot + 1].keys.removeAtIndex(0)
        payloads[slot] = children[slot + 1].payloads.removeAtIndex(0)

        children[slot].count += 1
        children[slot + 1].count -= 1
    }

    private func collapse(slot: Int) {
        assert(slot < children.count - 1)
        makeChildUnique(slot)
        let next = children.removeAtIndex(slot + 1)
        children[slot].keys.append(keys.removeAtIndex(slot))
        children[slot].payloads.append(payloads.removeAtIndex(slot))
        children[slot].count += 1

        children[slot].keys.appendContentsOf(next.keys)
        children[slot].payloads.appendContentsOf(next.payloads)
        children[slot].count += next.count
        if !next.isLeaf {
            children[slot].children.appendContentsOf(next.children)
        }
        assert(children[slot].isBalanced)
    }
}

//MARK: Join

extension BTreeNode {
    /// Create and return a new b-tree consisting of elements of `left`, the `separator` and the elements of `right`, 
    /// in this order.
    ///
    /// If you need to keep `left` and `right` intact, clone them before calling this function.
    ///
    /// - Requires: `l <= separator.0 && separator.0 <= r` for all keys `l` in `left` and all keys `r` in `right`.
    /// - Complexity: O(log(left.count + right.count))
    internal static func join(left left: BTreeNode, separator: (Key, Payload), right: BTreeNode) -> BTreeNode {
        precondition(left.order == right.order)
        let depthDelta = left.depth - right.depth
        let append = depthDelta >= 0
        
        let stock = append ? left : right
        let scion = append ? right : left
        // We'll graft the scion onto the stock.

        // First, find the insertion point, and preemptively update node counts on the way there.
        var path = [stock]
        var node = stock
        let c = scion.count
        node.count += c + 1
        for _ in 0 ..< abs(depthDelta) {
            node = node.makeChildUnique(append ? node.children.count - 1 : 0)
            path.append(node)
            node.count += c + 1
        }

        // Graft the scion into the stock by inserting the contents of its root into `node`.
        assert(node.isLeaf == scion.isLeaf)
        if append {
            node.keys.append(separator.0)
            node.keys.appendContentsOf(right.keys)
            node.payloads.append(separator.1)
            node.payloads.appendContentsOf(right.payloads)
            node.children.appendContentsOf(right.children)
        }
        else {
            node.keys = left.keys + [separator.0] + node.keys
            node.payloads = left.payloads + [separator.1] + node.payloads
            node.children = left.children + node.children
        }

        // Split nodes if necessary to restore balance.
        if node.isTooLarge {
            path.removeLast()
            var splinter = Optional(node.split())
            while let s = splinter where !path.isEmpty {
                let node = path.removeLast()
                node.insert(s, inSlot: append ? node.keys.count : 0)
                splinter = node.isTooLarge ? node.split() : nil
            }
            if let s = splinter {
                return BTreeNode(left: stock, separator: s.separator, right: s.node)
            }
        }
        return stock
    }
}


