//
//  BTree.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2016-01-13.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import Foundation

internal let bTreeOrder = 7

private let maxChildren = bTreeOrder
private let minChildren = (bTreeOrder + 1) / 2
private let maxKeys = bTreeOrder - 1
private let minKeys = (bTreeOrder - 1) / 2
public struct BTree<Key: Comparable, Payload>: SequenceType {
    public typealias Generator = BTreeGenerator<Key, Payload>
    public typealias Element = Generator.Element

    /// A sorted array of keys.
    internal var keys: Array<Key>
    /// The payload that belongs to each key in the `keys` array, respectively.
    internal var payloads: Array<Payload>
    /// An empty array (when this is a leaf), or `keys.count + 1` child nodes (when this is an internal node).
    internal var children: Array<BTree>

    public internal(set) var count: Int

    internal init(keys: Array<Key>, payloads: Array<Payload>, children: Array<BTree>) {
        self.keys = keys
        self.payloads = payloads
        self.children = children
        self.count = self.keys.count + children.reduce(0) { $0 + $1.count }
    }

    public init() {
        self.keys = []
        self.payloads = []
        self.children = []
        self.count = 0
    }

    private static func bulkLoad<S: SequenceType where S.Generator.Element == Element>(elements: S) -> BTree<Key, Payload> {
        typealias Tree = BTree<Key, Payload>
        var path: [Tree] = [Tree()]
        var lastKey: Key? = nil
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
                    path.append(Tree())
                }
                path[i + 1].keys.append(sep.0)
                path[i + 1].payloads.append(sep.1)
                path[i + 1].children.append(left)
                path[i + 1].count += 1 + left.count
                i += 1
            }
        }
        for i in 1 ..< path.count {
            let previous = path[i - 1]
            path[i].children.append(previous)
            path[i].count += previous.count
        }
        return path.last!
    }
    
    public init<S: SequenceType where S.Generator.Element == Element>(_ elements: S) {
        self = .bulkLoad(elements.sort { $0.0 < $1.0 })
    }
    public init<S: SequenceType where S.Generator.Element == Element>(sortedElements: S) {
        self = .bulkLoad(sortedElements)
    }

    public var isEmpty: Bool { return count == 0 }

    public func generate() -> Generator {
        return BTreeGenerator(self)
    }

    internal var isLeaf: Bool { return children.isEmpty }
    internal var isTooSmall: Bool { return keys.count < minKeys }
    internal var isTooLarge: Bool { return keys.count > maxKeys }
    internal var isBalanced: Bool { return keys.count >= minKeys && keys.count <= maxKeys }

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

    private mutating func split() -> (separator: (Key, Payload), splinter: BTree<Key, Payload>) {
        assert(isTooLarge)
        let count = keys.count
        let median = count / 2

        let separator = (keys[median], payloads[median])
        let splinter = BTree(
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

    internal func maxKey() -> Key {
        var node = self
        while !node.isLeaf {
            node = node.children.last!
        }
        return node.keys.last!
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

    public mutating func remove(key: Key) -> Payload? {
        guard let payload = removeAndCollapse(key) else { return nil }
        if keys.count == 0 && children.count == 1 {
            self = children[0]
        }
        return payload
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
