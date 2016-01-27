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
}

public struct BTreeGenerator<Key: Comparable, Payload>: GeneratorType {
    public typealias Element = (Key, Payload)
    typealias Node = BTreeNode<Key, Payload>

    var nodePath: [Node]
    var indexPath: [Int]

    init(_ root: Node) {
        if root.count == 0 {
            self.nodePath = []
            self.indexPath = []
        }
        else {
            var node = root
            var path: Array<Node> = [root]
            while !node.isLeaf {
                node = node.children.first!
                path.append(node)
            }
            self.nodePath = path
            self.indexPath = Array(count: path.count, repeatedValue: 0)
        }
    }

    public mutating func next() -> Element? {
        let level = nodePath.count
        guard level > 0 else { return nil }
        let node = nodePath[level - 1]
        let index = indexPath[level - 1]
        let result = (node.keys[index], node.payloads[index])
        if !node.isLeaf {
            // Descend
            indexPath[level - 1] = index + 1
            var n = node.children[index + 1]
            nodePath.append(n)
            indexPath.append(0)
            while !n.isLeaf {
                n = n.children.first!
                nodePath.append(n)
                indexPath.append(0)
            }
        }
        else if index < node.keys.count - 1 {
            indexPath[level - 1] = index + 1
        }
        else {
            // Ascend
            nodePath.removeLast()
            indexPath.removeLast()
            while !nodePath.isEmpty && indexPath.last == nodePath.last!.keys.count {
                nodePath.removeLast()
                indexPath.removeLast()
            }
        }
        return result
    }
}

//MARK: CollectionType
extension BTreeNode: CollectionType {
    typealias Index = BTreeIndex<Key, Payload>

    var startIndex: Index {
        return Index(startIndexOf: self)
    }

    var endIndex: Index {
        return Index()
    }

    subscript(index: Index) -> (Key, Payload) {
        get {
            precondition(index.path.first!.value! === self)
            let node = index.path.last!.value!
            return (node.keys[index.index], node.payloads[index.index])
        }
    }
}

private struct Weak<T: AnyObject> {
    weak var value: T?

    init(_ value: T) {
        self.value = value
    }
}

private enum WalkDirection {
    case Forward
    case Backward
}

public struct BTreeIndex<Key: Comparable, Payload>: BidirectionalIndexType {
    public typealias Distance = Int
    typealias Node = BTreeNode<Key, Payload>

    private var path: [Weak<Node>]
    private var index: Int

    internal init() {
        self.path = []
        self.index = 0
    }

    internal init(startIndexOf root: Node) {
        var node = root
        var path = [Weak(root)]
        while !node.isLeaf {
            node = node.children[0]
            path.append(Weak(node))
        }
        self.path = path
        self.index = 0
    }
    
    internal init(path: [Node], index: Int) {
        self.path = path.map { Weak($0) }
        self.index = index
    }
    private init(path: [Weak<Node>], index: Int) {
        self.path = path
        self.index = index
    }

    private mutating func invalidate() {
        self.path = []
        self.index = 0
    }

    private func indexOf(node: Node, under parent: Node) -> Int? {
        return parent.children.indexOf { $0 === node }
    }

    private mutating func ascend(direction: WalkDirection) {
        while let node = path.removeLast().value, parent = self.path.last?.value {
            guard let i = indexOf(node, under: parent) else {
                break
            }
            if direction == .Forward && i < parent.keys.count {
                index = i
                return
            }
            else if direction == .Backward && i > 0 {
                index = i - 1
                return
            }
        }
        invalidate()
    }

    private mutating func descend(direction: WalkDirection) {
        guard let n = self.path.last?.value else { invalidate(); return }
        assert(!n.isLeaf)
        var node = n.children[direction == .Forward ? index + 1 : index]
        path.append(Weak(node))
        while !node.isLeaf {
            node = node.children[direction == .Forward ? 0 : node.children.count - 1]
            path.append(Weak(node))
        }
        index = direction == .Forward ? 0 : node.keys.count - 1
    }

    private mutating func successorInPlace() {
        guard let node = self.path.last?.value else { return }
        if node.isLeaf {
            if index < node.keys.count - 1 {
                index += 1
            }
            else {
                ascend(.Forward)
            }
        }
        else {
            descend(.Forward)
        }
    }
    private mutating func predecessorInPlace() {
        guard let node = self.path.last?.value else { return }
        if node.isLeaf {
            if index > 0 {
                index -= 1
            }
            else {
                ascend(.Backward)
            }
        }
        else {
            descend(.Backward)
        }
    }

    public func successor() -> BTreeIndex<Key, Payload> {
        var result = self
        result.successorInPlace()
        return result
    }

    public func predecessor() -> BTreeIndex<Key, Payload> {
        var result = self
        result.predecessorInPlace()
        return result
    }
}

public func == <Key: Comparable, Payload>(a: BTreeIndex<Key, Payload>, b: BTreeIndex<Key, Payload>) -> Bool {
    // TODO: Invalid indexes may compare unequal under this definition.
    guard a.index == b.index else { return false }
    guard a.path.count == b.path.count else { return false }
    for i in 0 ..< a.path.count {
        if a.path[i].value !== b.path[i].value{
            return false
        }
    }
    return true
}

//MARK: Lookup

extension BTreeNode {
    private func slotOf(key: Key) -> (index: Int, match: Bool) {
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
                return Index(path: path, index: slot.index)
            }
            node = node.children[slot.index]
            path.append(Weak(node))
        }
        let slot = node.slotOf(key)
        guard slot.match else { return nil }
        return Index(path: path, index: slot.index)
    }
}

//MARK: Positional lookup

extension BTreeNode {
    func positionOf(key: Key) -> Int? {
        var node = self
        var index = 0
        while !node.isLeaf {
            let slot = node.slotOf(key)
            index += node.children[0 ..< slot.index].reduce(0, combine: { $0 + $1.count })
            if slot.match {
                return index
            }
            node = node.children[slot.index]
        }
        let slot = node.slotOf(key)
        guard slot.match else { return nil }
        return index + slot.index
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

//MARK: Insertion

extension BTreeNode {
    func set(key: Key, to payload: Payload) -> Payload? {
        return self.insert(payload, at: key, replacingExisting: true)
    }
    func insert(payload: Payload, at key: Key) {
        self.insert(payload, at: key, replacingExisting: false)
    }

    private func insert(payload: Payload, at key: Key, replacingExisting replace: Bool) -> Payload? {
        let (old, splinter) = self.insertAndSplit(key, payload, replace: replace)
        guard let (separator, right) = splinter else { return old }
        let left = clone()
        keys.removeAll()
        payloads.removeAll()
        children.removeAll()
        keys.append(separator.0)
        payloads.append(separator.1)
        children.append(left)
        children.append(right)
        count = left.count + right.count + 1
        return old
    }

    private func insertAndSplit(key: Key, _ payload: Payload, replace: Bool) -> (old: Payload?, (separator: (Key, Payload), splinter: BTreeNode<Key, Payload>)?) {
        let slot = slotOf(key)
        if slot.match && replace {
            let old = payloads[slot.index]
            keys[slot.index] = key
            payloads[slot.index] = payload
            return (old, nil)
        }
        if isLeaf {
            keys.insert(key, atIndex: slot.index)
            payloads.insert(payload, atIndex: slot.index)
            count += 1
            return (nil, (isTooLarge ? split() : nil))
        }

        makeChildUnique(slot.index)
        let (old, splinter) = children[slot.index].insertAndSplit(key, payload, replace: replace)
        if old == nil {
            count += 1
        }
        guard let (separator, right) = splinter else { return (old, nil) }
        keys.insert(separator.0, atIndex: slot.index)
        payloads.insert(separator.1, atIndex: slot.index)
        children.insert(right, atIndex: slot.index + 1)
        return (old, (isTooLarge ? split() : nil))
    }

    private func split() -> (separator: (Key, Payload), splinter: BTreeNode<Key, Payload>) {
        assert(isTooLarge)
        let count = keys.count
        let median = count / 2

        let separator = (keys[median], payloads[median])
        let splinter = BTreeNode(
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
        return (separator, splinter)
    }
}

//MARK: Removal

extension BTreeNode {
    func remove(key: Key) -> Payload? {
        guard let payload = removeAndCollapse(key) else { return nil }
        if keys.count == 0 && children.count == 1 {
            let n = children[0]
            self.keys = n.keys
            self.payloads = n.payloads
            self.children = n.children
            return payload
        }
        return payload
    }

    func removeAt(index: Index) -> (Key, Payload) {
        let (key, payload) = self[index]
        remove(key)
        return (key, payload)
    }

    func removeAndCollapse(key: Key) -> Payload? {
        let slot = self.slotOf(key)
        if isLeaf {
            guard slot.match else { return nil }
            // In leaf nodes, we can just directly remove the key.
            keys.removeAtIndex(slot.index)
            count -= 1
            return payloads.removeAtIndex(slot.index)
        }

        let payload: Payload
        if slot.match {
            // For internal nodes, we move the previous item in place of the removed one,
            // and remove its original slot instead. (The previous item is always in a leaf node.)
            payload = payloads[slot.index]
            makeChildUnique(slot.index)
            let previousKey = children[slot.index].maxKey()
            let previousPayload = children[slot.index].removeAndCollapse(previousKey)
            keys[slot.index] = previousKey
            payloads[slot.index] = previousPayload!
            count -= 1
        }
        else {
            makeChildUnique(slot.index)
            guard let p = children[slot.index].removeAndCollapse(key) else { return nil }
            count -= 1
            payload = p
        }
        if children[slot.index].isTooSmall {
            fixDeficiency(slot.index)
        }
        return payload
    }

    internal func maxKey() -> Key {
        var node = self
        while !node.isLeaf {
            node = node.children.last!
        }
        return node.keys.last!
    }

    private func fixDeficiency(slot: Int) {
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
                    let (sep, right) = left.split()
                    path.insert(right, atIndex: i)
                    counts[i] -= left.count + 1

                    self.keys.append(sep.0)
                    self.payloads.append(sep.1)
                    self.children = [left, right]
                    counts.append(left.count + 1)
                    self.count = left.count + 1 + right.count
                }
                else {
                    let c = counts[i]
                    let left = path[i]
                    let (sep, right) = left.split()
                    path[i] = right
                    counts[i] = c - left.count - 1

                    path[i + 1].keys.append(sep.0)
                    path[i + 1].payloads.append(sep.1)
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

