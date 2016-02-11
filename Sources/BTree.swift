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

    /// The order of this b-tree. An internal node will have at most this many children.
    internal var order: Int

    internal var count: Int

    internal init(order: Int, keys: Array<Key>, payloads: Array<Payload>, children: Array<BTreeNode>) {
        assert(children.count == 0 || keys.count == children.count - 1)
        assert(payloads.count == keys.count)
        self.order = order
        self.keys = keys
        self.payloads = payloads
        self.children = children
        self.count = self.keys.count + children.reduce(0) { $0 + $1.count }
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
}

//MARK: Uniqueness

extension BTreeNode {
    func makeChildUnique(index: Int) {
        guard !isUniquelyReferenced(&children[index]) else { return }
        children[index] = children[index].clone()
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

    internal var depth: Int {
        var depth = 0
        var node = self
        while !node.isLeaf {
            node = node.children[0]
            depth += 1
        }
        return depth
    }
}

//MARK: SequenceType

extension BTreeNode: SequenceType {
    typealias Generator = BTreeGenerator<Key, Payload>
    typealias Element = Generator.Element

    var isEmpty: Bool { return count == 0 }

    func generate() -> Generator {
        return BTreeGenerator(self)
    }

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

    func setPayloadAt(index: Index, payload: Payload) -> Payload {
        precondition(index.root.value === self)
        let node = index.path.last!.value!
        let payload = node.payloads[index.slot]
        node.payloads[index.slot] = payload
        return payload
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
    internal func editAtPosition(position: Int, @noescape operation: (node: BTreeNode, slot: Int) -> Void) {
        precondition(position >= 0 && position < self.count)
        if isLeaf {
            operation(node: self, slot: position)
            return
        }
        var count = 0
        for slot in 0 ..< children.count {
            let child = children[slot]
            let c = count + child.count
            if position < c {
                self.makeChildUnique(slot)
                child.editAtPosition(position - count, operation: operation)
                operation(node: self, slot: slot)
                return
            }
            if position == c {
                operation(node: self, slot: slot)
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
        assert(isTooLarge)
        let count = keys.count
        let median = count / 2

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
        return BTreeSplinter(separator: separator, node: node)
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

//MARK: Appending sequences

extension BTreeNode {
    convenience init<S: SequenceType where S.Generator.Element == Element>(_ elements: S) {
        self.init()
        self.appendContentsOf(elements.sort { $0.0 < $1.0 })
    }
    convenience init<S: SequenceType where S.Generator.Element == Element>(sortedElements: S) {
        self.init()
        self.appendContentsOf(sortedElements)
    }

    func appendContentsOf<S: SequenceType where S.Generator.Element == Element>(elements: S) {
        typealias Node = BTreeNode<Key, Payload>

        // Prepare self by collecting the nodes on the rightmost path, uniquing each of them.
        var path = [self]
        while !path[0].isLeaf {
            let parent = path[0]
            let c = parent.children.count
            parent.makeChildUnique(c - 1)
            path.insert(parent.children[c - 1], atIndex: 0)
        }
        var counts = [path[0].count] // Counts of nodes on path without their rightmost subtree
        for i in 1 ..< path.count {
            counts.append(path[i].count - path[i - 1].count)
        }

        // Now go through the supplied elements one by one and append each of them to `path`.
        // This is just a nonrecursive variant of `insert`, using `path` to eliminate the recursive descend.
        var lastKey: Key? = path[0].keys.last
        for (key, payload) in elements {
            precondition(lastKey <= key)
            lastKey = key
            path[0].keys.append(key)
            path[0].payloads.append(payload)
            path[0].count += 1
            counts[0] += 1
            var i = 0
            while path[i].isTooLarge {
                if i == path.count - 1 {
                    // Insert new level, keeping self as the root node.
                    assert(path[i] === self)
                    let left = self.clone()
                    self.keys.removeAll()
                    self.payloads.removeAll()
                    self.children.removeAll()
                    let splinter = left.split()
                    let right = splinter.node
                    path.insert(right, atIndex: i)
                    counts[i] -= left.count + 1

                    self.keys.append(splinter.separator.0)
                    self.payloads.append(splinter.separator.1)
                    self.children = [left, right]
                    counts.append(left.count + 1)
                    self.count = left.count + 1 + right.count
                }
                else {
                    let c = counts[i]
                    let left = path[i]
                    let splinter = left.split()
                    let right = splinter.node
                    path[i] = right
                    counts[i] = c - left.count - 1

                    path[i + 1].keys.append(splinter.separator.0)
                    path[i + 1].payloads.append(splinter.separator.1)
                    path[i + 1].children.append(right)
                    counts[i + 1] += 1 + left.count
                    path[i + 1].count = counts[i + 1] + right.count
                }
                i += 1
            }
        }
        // Finally, update counts in rightmost path to root.
        for i in 1 ..< path.count {
            path[i].count = counts[i] + path[i - 1].count
        }
    }
}

