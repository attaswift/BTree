//
//  BTree.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2016-01-13.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import Foundation

internal let bTreeOrder = 10

private let maxChildren = bTreeOrder
private let minChildren = (bTreeOrder + 1) / 2
private let maxKeys = bTreeOrder - 1
private let minKeys = (bTreeOrder - 1) / 2

public struct BTree<Key: Comparable, Payload>: SequenceType {
    public typealias Generator = BTreeGenerator<Key, Payload>

    /// A sorted array of keys.
    internal var keys: Array<Key>
    /// The payload that belongs to each key in the `keys` array, respectively.
    internal var payloads: Array<Payload>
    /// An empty array (when this is a leaf), or `keys.count + 1` child nodes (when this is an internal node).
    internal var children: Array<BTree>

    public private(set) var count: Int

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

    public var isEmpty: Bool { return count == 0 }

    public func generate() -> Generator {
        return BTreeGenerator(self)
    }

    internal var isLeaf: Bool { return children.isEmpty }

    internal var level: Int {
        var level = 0
        var node = self
        while !node.isLeaf {
            level += 1
            node = node.children[0]
        }
        return level
    }

    internal func slotOf(key: Key) -> Int {
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
        return start
    }

    public func payloadOf(key: Key) -> Payload? {
        var node = self
        while true {
            let slot = node.slotOf(key)
            if slot != node.keys.count && node.keys[slot] == key {
                return node.payloads[slot]
            }
            if node.children.isEmpty {
                return nil
            }
            node = node.children[slot]
        }
    }

    private mutating func split() -> (separator: (Key, Payload), splinter: BTree<Key, Payload>) {
        assert(keys.count > maxKeys)
        let count = keys.count
        let median = count / 2

        let separator = (keys[median], payloads[median])
        let splinter = BTree(
            keys: Array(keys[median + 1 ..< count]),
            payloads: Array(payloads[median + 1 ..< count]),
            children: isLeaf ? [] : Array(children[median + 1...count + 1]))
        keys.removeRange(Range(start: median, end: count))
        payloads.removeRange(Range(start: median, end: count))
        children.removeRange(Range(start: median + 1, end: count + 1))
        return (separator, splinter)
    }

    private mutating func insertAndSplit(key: Key, _ payload: Payload) -> (separator: (Key, Payload), splinter: BTree<Key, Payload>)? {
        count += 1
        let slot = slotOf(key)
        if isLeaf {
            keys.insert(key, atIndex: slot)
            payloads.insert(payload, atIndex: slot)
        }
        else {
            guard let (separator, splinter) = children[slot].insertAndSplit(key, payload) else { return nil }
            keys.insert(separator.0, atIndex: slot)
            payloads.insert(separator.1, atIndex: slot)
            children.insert(splinter, atIndex: slot)
        }
        return keys.count <= maxKeys ? nil : split()
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
    }

    internal func maxKey() -> Key {
        var node = self
        while !node.isLeaf {
            node = node.children.last!
        }
        return node.keys.last!
    }

    private var isTooSmall: Bool { return keys.count < minKeys }
    private var isTooLarge: Bool { return keys.count > maxKeys }
    private var isBalanced: Bool { return keys.count >= minKeys && keys.count <= maxKeys }

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
        children[slot].keys.insert(keys[slot], atIndex: 0)
        children[slot].payloads.insert(payloads[slot], atIndex: 0)
        if !children[slot].isLeaf {
            let lastGrandChildBeforeSlot = children[slot - 1].children.removeLast()
            children[slot].children.insert(lastGrandChildBeforeSlot, atIndex: 0)

            children[slot - 1].count -= lastGrandChildBeforeSlot.count
            children[slot].count += lastGrandChildBeforeSlot.count
        }
        keys[slot] = children[slot - 1].keys.removeLast()
        payloads[slot] = children[slot - 1].payloads.removeLast()

        children[slot - 1].count -= 1
        children[slot].count += 1
    }

    private mutating func collapse(slot: Int) {
        assert(slot < children.count - 1)
        let next = children.removeAtIndex(slot + 1)
        children[slot].keys.append(keys.removeAtIndex(slot + 1))
        children[slot].payloads.append(payloads.removeAtIndex(slot + 1))
        children[slot].count += 1

        children[slot].keys.appendContentsOf(next.keys)
        children[slot].payloads.appendContentsOf(next.payloads)
        if !next.isLeaf {
            children[slot].children.appendContentsOf(next.children)
            children[slot].count += next.count
        }
        assert(children[slot].isBalanced)
    }

    private mutating func fixDeficiency(slot: Int) {
        assert(!isLeaf && children[slot].isTooSmall)
        if slot > 0 && children[slot - 1].keys.count > minKeys {
            rotateRight(slot)
        }
        else if slot < children.count && children[slot + 1].keys.count > minKeys {
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
            if slot != keys.count && keys[slot] == key {
                // In leaf nodes, we can just directly remove the key.
                keys.removeAtIndex(slot)
                count -= 1
                return payloads.removeAtIndex(slot)
            }
            return nil
        }

        let payload: Payload
        if slot != keys.count && keys[slot] == key {
            // For internal nodes, we move the previous item in place of the removed one,
            // and remove its original slot instead. (The previous item is always in a leaf node.)
            payload = payloads[slot]
            let previousKey = children[slot].maxKey()
            let previousPayload = removeAndCollapse(previousKey)
            keys[slot] = previousKey
            payloads[slot] = previousPayload!
            count -= 1
        }
        else {
            guard let p = children[slot].removeAndCollapse(key) else { return nil }
            count -= 1
            payload = p
        }
        if children[slot].isTooSmall { fixDeficiency(slot) }
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
            var n = node
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
