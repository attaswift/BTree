//
//  BTree.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2016-01-13.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import Foundation

// This is the size (in bytes) of all the keys that we want to store inside a single, fully loaded b-tree node.
// This is related to the order of the b-tree, i.e., the maximum number of children of an internal node.
//
// Common sense indicates (and benchmarking verifies) that the fastest b-tree order depends on `strideof(key)`:
// doubling the size of the key roughly halves the optimal order. So there is a certain optimal overall node size that
// is independent of the key; this value is supposed to be that size.
//
// Obviously, the optimal node size depends on the hardware we're running on.
internal var bTreeNodeSize = 12288 // == 0.75 * 16kiB

//MARK: BTree definition

public struct BTree<Key: Comparable, Payload> {

    /// A sorted array of keys.
    internal var keys: Array<Key>
    /// The payload that belongs to each key in the `keys` array, respectively.
    internal var payloads: Array<Payload>
    /// An empty array (when this is a leaf), or `keys.count + 1` child nodes (when this is an internal node).
    internal var children: Array<BTree>

    /// The order of this b-tree. An internal node will have at most this many children.
    internal var order: Int

    public internal(set) var count: Int

    internal init(order: Int, keys: Array<Key>, payloads: Array<Payload>, children: Array<BTree>) {
        assert(children.count <= order)
        assert(keys.count < order && (children.count == 0 || keys.count == children.count - 1))
        assert(payloads.count == keys.count)
        self.order = order
        self.keys = keys
        self.payloads = payloads
        self.children = children
        self.count = self.keys.count + children.reduce(0) { $0 + $1.count }
    }
}

//MARK: Convenience initializers

extension BTree {
    internal static var defaultOrder: Int {
        return max(bTreeNodeSize / strideof(Key), 32)
    }

    public init() {
        self.init(order: BTree<Key, Payload>.defaultOrder)
    }

    internal init(order: Int) {
        self.init(order: order, keys: [], payloads: [], children: [])
    }
}

//MARK: SequenceType

extension BTree: SequenceType {
    public typealias Generator = BTreeGenerator<Key, Payload>
    public typealias Element = Generator.Element

    public var isEmpty: Bool { return count == 0 }

    public func generate() -> Generator {
        return BTreeGenerator(self)
    }
}

public struct BTreeGenerator<Key: Comparable, Payload>: GeneratorType {
    public typealias Tree = BTree<Key, Payload>
    public typealias Element = (Key, Payload)

    var nodePath: [Tree]
    var indexPath: [Int]

    internal init(_ root: Tree) {
        if root.count == 0 {
            self.nodePath = []
            self.indexPath = []
        }
        else {
            var node = root
            var path: Array<Tree> = [root]
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

//MARK: Internal limits and properties

extension BTree {
    internal var maxChildren: Int { return order }
    internal var minChildren: Int { return (maxChildren + 1) / 2 }
    internal var maxKeys: Int { return maxChildren - 1 }
    internal var minKeys: Int { return minChildren - 1 }

    internal var isLeaf: Bool { return children.isEmpty }
    internal var isTooSmall: Bool { return keys.count < minKeys }
    internal var isTooLarge: Bool { return keys.count > maxKeys }
    internal var isBalanced: Bool { return keys.count >= minKeys && keys.count <= maxKeys }
}

//MARK: Lookup

extension BTree {
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

    public func payloadOf(key: Key) -> Payload? {
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
}

//MARK: Insertion

extension BTree {
    public mutating func insert(key: Key, _ payload: Payload) {
        guard let (separator, right) = self.insertAndSplit(key, payload) else { return }
        let left = self
        keys.removeAll()
        payloads.removeAll()
        children.removeAll()
        keys.append(separator.0)
        payloads.append(separator.1)
        children.append(left)
        children.append(right)
        count = left.count + right.count + 1
    }

    private mutating func insertAndSplit(key: Key, _ payload: Payload) -> (separator: (Key, Payload), splinter: BTree<Key, Payload>)? {
        count += 1
        let slot = slotOf(key).index
        if isLeaf {
            keys.insert(key, atIndex: slot)
            payloads.insert(payload, atIndex: slot)
        }
        else {
            guard let (separator, splinter) = children[slot].insertAndSplit(key, payload) else { return nil }
            keys.insert(separator.0, atIndex: slot)
            payloads.insert(separator.1, atIndex: slot)
            children.insert(splinter, atIndex: slot + 1)
        }
        return isTooLarge ? split() : nil
    }

    private mutating func split() -> (separator: (Key, Payload), splinter: BTree<Key, Payload>) {
        assert(isTooLarge)
        let count = keys.count
        let median = count / 2

        let separator = (keys[median], payloads[median])
        let splinter = BTree(
            order: self.order,
            keys: Array(keys[median + 1 ..< count]),
            payloads: Array(payloads[median + 1 ..< count]),
            children: isLeaf ? [] : Array(children[median + 1 ..< count + 1]))
        keys.removeRange(Range(start: median, end: count))
        payloads.removeRange(Range(start: median, end: count))
        if isLeaf {
            self.count = median
        }
        else {
            children.removeRange(Range(start: median + 1, end: count + 1))
            self.count = median + children.reduce(0, combine: { $0 + $1.count })
        }
        return (separator, splinter)
    }
}

//MARK: Removal

extension BTree {
    public mutating func remove(key: Key) -> Payload? {
        guard let payload = removeAndCollapse(key) else { return nil }
        if keys.count == 0 && children.count == 1 {
            self = children[0]
        }
        return payload
    }

    private mutating func removeAndCollapse(key: Key) -> Payload? {
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
            let previousKey = children[slot.index].maxKey()
            let previousPayload = children[slot.index].removeAndCollapse(previousKey)
            keys[slot.index] = previousKey
            payloads[slot.index] = previousPayload!
            count -= 1
        }
        else {
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

    private mutating func fixDeficiency(slot: Int) {
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

    private mutating func rotateRight(slot: Int) {
        assert(slot > 0)
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
    
    private mutating func rotateLeft(slot: Int) {
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

    private mutating func collapse(slot: Int) {
        assert(slot < children.count - 1)
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

extension BTree {
    public init<S: SequenceType where S.Generator.Element == Element>(_ elements: S) {
        self.init()
        self.appendContentsOf(elements.sort { $0.0 < $1.0 })
    }
    public init<S: SequenceType where S.Generator.Element == Element>(sortedElements: S) {
        self.init()
        self.appendContentsOf(sortedElements)
    }

    public mutating func appendContentsOf<S: SequenceType where S.Generator.Element == Element>(elements: S) {
        typealias Tree = BTree<Key, Payload>
        let order = self.order

        // Prepare self by extracting the nodes on the rightmost path.
        // This not only gets us a nice path to the insertion point,
        // but also makes node references unique, preventing COW copies.
        var path: [Tree] = [self]
        self = Tree(order: order) // Make sure path contains the only ref to self's data (in this function)
        while !path[0].isLeaf {
            let rightmostChild = path[0].children.removeLast()
            path.insert(rightmostChild, atIndex: 0)
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
            var i = 0
            while path[i].isTooLarge {
                var left = path[i]
                if i > 0 {
                    // Splitting is complicated by the fact that nodes on `path` are in extracted form.
                    // Putting back the rightmost child of path[i] allows us to call `split()` on it.
                    // Note that we don't put back the rightmost grandchild, so path[i] is still an invalid b-tree;
                    // however, it looks good enough for `split` to work.
                    let prev = path[i - 1]
                    left.children.append(prev)
                    left.count += prev.count
                }
                let (sep, right) = left.split()
                path[i] = right
                if i > 0 {
                    let prev = path[i].children.removeLast()
                    path[i].count -= prev.count
                }
                if i == path.count - 1 {
                    path.append(Tree(order: order))
                }
                path[i + 1].keys.append(sep.0)
                path[i + 1].payloads.append(sep.1)
                path[i + 1].children.append(left)
                path[i + 1].count += 1 + left.count
                i += 1
            }
        }
        // Finally, go through `path` and put each child back into its parent.
        for i in 1 ..< path.count {
            let previous = path[i - 1]
            path[i].children.append(previous)
            path[i].count += previous.count
        }
        self = path.last!
    }
}

