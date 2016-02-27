//
//  BTreeNode.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-01-13.
//  Copyright © 2015–2016 Károly Lőrentey.
//

// `bTreeNodeSize` is the maximum size (in bytes) of the keys in a single, fully loaded b-tree node.
// This is related to the order of the b-tree, i.e., the maximum number of children of an internal node.
//
// Common sense indicates (and benchmarking verifies) that the fastest b-tree order depends on `strideof(key)`:
// doubling the size of the key roughly halves the optimal order. So there is a certain optimal overall node size that
// is independent of the key; this value is supposed to be that size.
//
// Obviously, the optimal node size depends on the hardware we're running on.
// Benchmarks performed on various systems (Apple A5X, A8X, A9; Intel Core i5 Sandy Bridge, Core i7 Ivy Bridge) 
// indicate that 16KiB is a good overall choice.
// (This may be related to the size of the L1 cache, which is frequently 16kiB or 32kiB.)
//
// It is not a good idea to use powers of two as the b-tree order, as that would lead to Array reallocations just before
// a node is split. A node size that's just below 2^n seems like a good choice.
internal let bTreeNodeSize = 16383

//MARK: BTreeNode definition

/// A node in an in-memory b-tree data structure, efficiently mapping `Comparable` keys to arbitrary payloads.
/// Iterating over the elements in a b-tree returns them in ascending order of their keys.
internal final class BTreeNode<Key: Comparable, Payload>: NonObjectiveCBase {
    typealias Element = Generator.Element
    typealias Node = BTreeNode<Key, Payload>

    /// FIXME: Allocate keys/payloads/children in a single buffer

    /// The elements stored in this node, sorted by key.
    internal var elements: Array<Element>
    /// An empty array (when this is a leaf), or `elements.count + 1` child nodes (when this is an internal node).
    internal var children: Array<BTreeNode>

    /// The number of elements in this b-tree.
    internal var count: Int

    /// The order of this b-tree. An internal node will have at most this many children.
    internal var _order: Int32
    /// The depth of this b-tree.
    internal var _depth: Int32

    internal var depth: Int { return numericCast(_depth) }
    internal var order: Int { return numericCast(_order) }

    internal init(order: Int, elements: Array<Element>, children: Array<BTreeNode>, count: Int) {
        assert(children.count == 0 || elements.count == children.count - 1)
        self._order = numericCast(order)
        self.elements = elements
        self.children = children
        self.count = count
        self._depth = (children.count == 0 ? 0 : children[0]._depth + 1)
        super.init()
        assert(children.indexOf { $0._depth + 1 != self._depth } == nil)
    }
}

//MARK: Convenience initializers

extension BTreeNode {
    static var defaultOrder: Int {
        return max(bTreeNodeSize / strideof(Element), 8)
    }

    convenience init(order: Int = Node.defaultOrder) {
        self.init(order: order, elements: [], children: [], count: 0)
    }

    internal convenience init(left: Node, separator: (Key, Payload), right: Node) {
        assert(left.order == right.order)
        assert(left.depth == right.depth)
        self.init(
            order: left.order,
            elements: [separator],
            children: [left, right],
            count: left.count + 1 + right.count)
    }

    internal convenience init(node: BTreeNode, slotRange: Range<Int>) {
        if node.isLeaf {
            let elements = Array(node.elements[slotRange])
            self.init(order: node.order, elements: elements, children: [], count: elements.count)
        }
        else if slotRange.count == 0 {
            let n = node.children[slotRange.startIndex]
            self.init(order: n.order, elements: n.elements, children: n.children, count: n.count)
        }
        else {
            let elements = Array(node.elements[slotRange])
            let children = Array(node.children[slotRange.startIndex ... slotRange.endIndex])
            let count = children.reduce(elements.count) { $0 + $1.count }
            self.init(order: node.order, elements: elements, children: children, count: count)
        }
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
        return BTreeNode(order: order, elements: elements, children: children, count: count)
    }
}

//MARK: Basic limits and properties

extension BTreeNode {
    internal var maxChildren: Int { return order }
    internal var minChildren: Int { return (maxChildren + 1) / 2 }
    internal var maxKeys: Int { return maxChildren - 1 }
    internal var minKeys: Int { return minChildren - 1 }

    internal var isLeaf: Bool { return children.isEmpty }
    internal var isTooSmall: Bool { return elements.count < minKeys }
    internal var isTooLarge: Bool { return elements.count > maxKeys }
    internal var isBalanced: Bool { return elements.count >= minKeys && elements.count <= maxKeys }
}

//MARK: SequenceType

extension BTreeNode: SequenceType {
    typealias Generator = BTreeGenerator<Key, Payload>

    var isEmpty: Bool { return count == 0 }

    func generate() -> Generator {
        return BTreeGenerator(BTreeStrongPath(root: self, position: 0))
    }

    /// Call `body` on each element in self in the same order as a for-in loop.
    func forEach(@noescape body: (Element) throws -> ()) rethrows {
        if isLeaf {
            for element in elements {
                try body(element)
            }
        }
        else {
            for i in 0 ..< elements.count {
                try children[i].forEach(body)
                try body(elements[i])
            }
            try children[elements.count].forEach(body)
        }
    }

    /// A version of `forEach` that allows `body` to interrupt iteration by returning `false`.
    /// 
    /// - Returns: `true` iff `body` returned true for all elements in the tree.
    func forEach(@noescape body: (Element) throws -> Bool) rethrows -> Bool {
        if isLeaf {
            for element in elements {
                guard try body(element) else { return false }
            }
        }
        else {
            for i in 0 ..< elements.count {
                guard try children[i].forEach(body) else { return false }
                guard try body(elements[i]) else { return false }
            }
            guard try children[elements.count].forEach(body) else { return false }
        }
        return true
    }

}

//MARK: Slots

extension BTreeNode {
    internal func setElementInSlot(slot: Int, to element: Element) -> Element {
        let old = elements[slot]
        elements[slot] = element
        return old
    }

    internal func insert(element: Element, inSlot slot: Int) {
        elements.insert(element, atIndex: slot)
        count += 1
    }

    internal func append(element: Element) {
        elements.append(element)
        count += 1
    }

    internal func removeSlot(slot: Int) -> Element {
        count -= 1
        return elements.removeAtIndex(slot)
    }

    /// Does one step toward looking up an element with `key`, returning the slot index of a direct match (if any), 
    /// and the slot index to use to continue descending.
    ///
    /// - Complexity: O(log(order))
    @inline(__always)
    internal func slotOf(key: Key, choosing selector: BTreeKeySelector = .First) -> (match: Int?, descend: Int) {
        switch selector {
        case .First, .Any:
            var start = 0
            var end = elements.count
            while start < end {
                let mid = start + (end - start) / 2
                if elements[mid].0 < key {
                    start = mid + 1
                }
                else {
                    end = mid
                }
            }
            return (start < elements.count && elements[start].0 == key ? start : nil, start)
        case .Last:
            var start = -1
            var end = elements.count - 1
            while start < end {
                let mid = start + (end - start + 1) / 2
                if elements[mid].0 > key {
                    end = mid - 1
                }
                else {
                    start = mid
                }
            }
            return (start >= 0 && elements[start].0 == key ? start : nil, start + 1)
        case .After:
            var start = 0
            var end = elements.count
            while start < end {
                let mid = start + (end - start) / 2
                if elements[mid].0 <= key {
                    start = mid + 1
                }
                else {
                    end = mid
                }
            }
            return (start < elements.count ? start : nil, start)
        }
    }

    /// Return the slot towards of the element at `position` in the subtree rooted at this node.
    internal func slotOfPosition(position: Int) -> (index: Int, match: Bool, position: Int) {
        assert(position >= 0 && position <= count)
        if position == count {
            return (index: elements.count, match: true, position: count)
        }
        if isLeaf {
            return (position, true, position)
        }
        else if position <= count / 2 {
            var p = 0
            for i in 0 ..< children.count - 1 {
                let c = children[i].count
                if position == p + c {
                    return (index: i, match: true, position: p + c)
                }
                if position < p + c {
                    return (index: i, match: false, position: p + c)
                }
                p += c + 1
            }
            let c = children.last!.count
            precondition(count == p + c, "Invalid B-Tree")
            return (index: children.count - 1, match: false, position: count)
        }
        else {
            var p = count
            for i in (1 ..< children.count).reverse() {
                let c = children[i].count
                if position == p - (c + 1) {
                    return (index: i - 1, match: true, position: position)
                }
                if position > p - (c + 1) {
                    return (index: i, match: false, position: p)
                }
                p -= c + 1
            }
            let c = children.first!.count
            precondition(p - c == 0, "Invalid B-Tree")
            return (index: 0, match: false, position: c)
        }
    }

    /// Return the position of the element at `slot` in the subtree rooted at this node.
    internal func positionOfSlot(slot: Int) -> Int {
        let c = elements.count
        assert(slot >= 0 && slot <= c)
        guard !isLeaf else {
            return slot
        }
        if slot == c {
            return count
        }
        if slot <= c / 2 {
            return children[0...slot].reduce(slot) { $0 + $1.count }
        }
        return count - children[slot + 1 ... c].reduce(c - slot) { $0 + $1.count }
    }

    /// Returns true iff the subtree at this node is guaranteed to contain the specified element 
    /// with `key` (if it exists).
    /// Returns false if the key falls into the first or last child subtree, so containment depends
    /// on the contents of the ancestors of this node.
    internal func contains(key: Key, choosing selector: BTreeKeySelector) -> Bool {
        let firstKey = elements.first!.0
        let lastKey = elements.last!.0
        if key < firstKey {
            return false
        }
        if key == firstKey && selector == .First {
            return false
        }
        if key > lastKey {
            return false
        }
        if key == lastKey && (selector == .Last || selector == .After) {
            return false
        }
        return true
    }
}

//MARK: Lookups

extension BTreeNode {
    /// Returns the first element at or under this node, or `nil` if this node is empty.
    ///
    /// - Complexity: O(log(`count`))
    var first: Element? {
        var node = self
        while let child = node.children.first {
            node = child
        }
        return node.elements.first
    }

    /// Returns the last element at or under this node, or `nil` if this node is empty.
    ///
    /// - Complexity: O(log(`count`))
    var last: Element? {
        var node = self
        while let child = node.children.last {
            node = child
        }
        return node.elements.last
    }
}

//MARK: Editing

extension BTreeNode {
    internal func edit(@noescape descend descend: Node -> Int?, @noescape ascend: (Node, Int) -> Void) {
        guard let slot = descend(self) else { return }
        do {
            let child = makeChildUnique(slot)
            child.edit(descend: descend, ascend: ascend)
        }
        ascend(self, slot)
    }
}

//MARK: Splitting

internal struct BTreeSplinter<Key: Comparable, Payload> {
    let separator: (Key, Payload)
    let node: BTreeNode<Key, Payload>
}

extension BTreeNode {
    /// Split this node into two, removing the high half of the nodes and putting them in a splinter.
    ///
    /// - Returns: A splinter containing the higher half of the original node.
    @warn_unused_result
    internal func split() -> BTreeSplinter<Key, Payload> {
        assert(isTooLarge)
        return split(at: elements.count / 2)
    }

    /// Split this node into two at the key at index `median`, removing all elements at or above `median` 
    /// and putting them in a splinter.
    ///
    /// - Returns: A splinter containing the higher half of the original node.
    @warn_unused_result
    internal func split(at median: Int) -> BTreeSplinter<Key, Payload> {
        let count = elements.count
        let separator = elements[median]
        let node = BTreeNode(node: self, slotRange: median + 1 ..< count)
        elements.removeRange(median ..< count)
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
        elements.insert(splinter.separator, atIndex: slot)
        children.insert(splinter.node, atIndex: slot + 1)
    }
}

//MARK: Removal

extension BTreeNode {
    /// Reorganize the tree rooted at `self` so that the undersize child in `slot` is corrected.
    /// As a side effect of the process, `self` may itself become undersized, but all of its descendants
    /// become balanced.
    internal func fixDeficiency(slot: Int) {
        assert(!isLeaf && children[slot].isTooSmall)
        if slot > 0 && children[slot - 1].elements.count > minKeys {
            rotateRight(slot)
        }
        else if slot < children.count - 1 && children[slot + 1].elements.count > minKeys {
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

    internal func rotateRight(slot: Int) {
        assert(slot > 0)
        makeChildUnique(slot)
        makeChildUnique(slot - 1)
        children[slot].elements.insert(elements[slot - 1], atIndex: 0)
        if !children[slot].isLeaf {
            let lastGrandChildBeforeSlot = children[slot - 1].children.removeLast()
            children[slot].children.insert(lastGrandChildBeforeSlot, atIndex: 0)

            children[slot - 1].count -= lastGrandChildBeforeSlot.count
            children[slot].count += lastGrandChildBeforeSlot.count
        }
        elements[slot - 1] = children[slot - 1].elements.removeLast()
        children[slot - 1].count -= 1
        children[slot].count += 1
    }
    
    internal func rotateLeft(slot: Int) {
        assert(slot < children.count - 1)
        makeChildUnique(slot)
        makeChildUnique(slot + 1)
        children[slot].elements.append(elements[slot])
        if !children[slot].isLeaf {
            let firstGrandChildAfterSlot = children[slot + 1].children.removeAtIndex(0)
            children[slot].children.append(firstGrandChildAfterSlot)

            children[slot + 1].count -= firstGrandChildAfterSlot.count
            children[slot].count += firstGrandChildAfterSlot.count
        }
        elements[slot] = children[slot + 1].elements.removeAtIndex(0)
        children[slot].count += 1
        children[slot + 1].count -= 1
    }

    internal func collapse(slot: Int) {
        assert(slot < children.count - 1)
        makeChildUnique(slot)
        let next = children.removeAtIndex(slot + 1)
        children[slot].elements.append(elements.removeAtIndex(slot))
        children[slot].count += 1
        children[slot].elements.appendContentsOf(next.elements)
        children[slot].count += next.count
        if !next.isLeaf {
            children[slot].children.appendContentsOf(next.children)
        }
        assert(children[slot].isBalanced)
    }
}

//MARK: Join

extension BTreeNode {
    /// Create and return a new b-tree consisting of elements of `left`,`separator` and the elements of `right`, 
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
        assert(node.depth == scion.depth)
        if append {
            node.elements.append(separator)
            node.elements.appendContentsOf(right.elements)
            node.children.appendContentsOf(right.children)
        }
        else {
            node.elements = left.elements + [separator] + node.elements
            node.children = left.children + node.children
        }

        // Split nodes if necessary to restore balance.
        if node.isTooLarge {
            path.removeLast()
            var splinter = Optional(node.split())
            while let s = splinter where !path.isEmpty {
                let node = path.removeLast()
                node.insert(s, inSlot: append ? node.elements.count : 0)
                splinter = node.isTooLarge ? node.split() : nil
            }
            if let s = splinter {
                return BTreeNode(left: stock, separator: s.separator, right: s.node)
            }
        }
        return stock
    }
}

