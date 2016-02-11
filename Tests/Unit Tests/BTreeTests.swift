//
//  BTreeTests.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2016-01-13.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import Foundation
import XCTest
@testable import TreeCollections

extension BTreeNode {
    var depth: Int {
        var depth = 0
        var node = self
        while !node.isLeaf {
            node = node.children[0]
            depth += 1
        }
        return depth
    }

    func assertValid(file: FileString = __FILE__, line: UInt = __LINE__) {
        func testNode(level level: Int, node: BTreeNode<Key, Payload>, minKey: Key?, maxKey: Key?) -> (maxlevel: Int, count: Int, defects: [String]) {
            var defects: [String] = []

            // Check item order
            var prev = minKey
            for key in node.keys {
                if let p = prev where p > key {
                    defects.append("Invalid item order: \(p) > \(key)")
                }
                prev = key
            }
            if let maxKey = maxKey, prev = prev where prev > maxKey {
                defects.append("Invalid item order: \(prev) > \(maxKey)")
            }

            // Check leaf node
            if node.isLeaf {
                if node.keys.count > node.order - 1 {
                    defects.append("Oversize leaf node: \(node.keys.count) > \(node.order - 1)")
                }
                if level > 0 && node.keys.count < (node.order - 1) / 2 {
                    defects.append("Undersize leaf node: \(node.keys.count) < \((node.order - 1) / 2)")
                }
                if node.payloads.count != node.keys.count {
                    defects.append("Mismatching item counts in leaf node (keys.count: \(node.keys.count), payloads.count: \(node.payloads.count)")
                }
                if !node.children.isEmpty {
                    defects.append("Leaf node should have no children, this one has \(node.children.count)")
                }
                return (level, node.keys.count, defects)
            }

            // Check child count
            if node.children.count > node.order {
                defects.append("Oversize internal node: \(node.children.count) > \(node.order)")
            }
            if level > 0 && node.children.count < (node.order + 1) / 2 {
                defects.append("Undersize internal node: \(node.children.count) < \((node.order + 1) / 2)")
            }
            if level == 0 && node.children.count < 2 {
                defects.append("Undersize root node: \(node.children.count) < 2")
            }
            // Check item count
            if node.keys.count != node.children.count - 1 {
                defects.append("Mismatching item counts in internal node (keys.count: \(node.keys.count), children.count: \(node.children.count)")
            }
            if node.payloads.count != node.keys.count {
                defects.append("Mismatching item counts in internal node (keys.count: \(node.keys.count), payloads.count: \(node.payloads.count)")
            }

            // Recursion
            var maxLevels = Array<Int>()
            var count = node.keys.count
            for slot in 0 ..< node.children.count {
                let (m, c, d) = testNode(
                    level: level + 1,
                    node: node.children[slot],
                    minKey: (slot > 0 ? node.keys[slot - 1] : minKey),
                    maxKey: (slot < node.keys.count - 1 ? node.keys[slot + 1] : maxKey))
                maxLevels.append(m)
                count += c
                defects.appendContentsOf(d)
            }
            if node.count != count {
                defects.append("Mismatching internal node count: \(node.count) vs \(count)")
            }
            if Set(maxLevels).count != 1 {
                defects.append("Leaves aren't on the same level; maxLevels: \(maxLevels)")
            }
            return (maxLevels[0], count, defects)
        }

        let (_, _, defects) = testNode(level: 0, node: self, minKey: nil, maxKey: nil)
        for d in defects {
            XCTFail(d, file: file, line: line)
        }
    }

    func insert(payload: Payload, at key: Key) {
        var splinter: BTreeSplinter<Key, Payload>? = nil
        self.editAtKey(key) { node, slot, match in
            precondition(!match)
            if node.isLeaf {
                node.keys.insert(key, atIndex: slot)
                node.payloads.insert(payload, atIndex: slot)
                node.count += 1
                if node.isTooLarge {
                    splinter = node.split()
                }
            }
            else {
                node.count += 1
                if let s = splinter {
                    node.keys.insert(s.separator.0, atIndex: slot)
                    node.payloads.insert(s.separator.1, atIndex: slot)
                    node.children.insert(s.node, atIndex: slot + 1)
                    splinter = (node.isTooLarge ? node.split() : nil)
                }
            }
        }
        if let s = splinter {
            let left = clone()
            let right = s.node
            keys = [s.separator.0]
            payloads = [s.separator.1]
            children = [left, right]
            count = left.count + right.count + 1
        }
    }

    func remove(key: Key, root: Bool = true) -> Payload? {
        var found: Bool = false
        var result: Payload? = nil
        editAtKey(key) { node, slot, match in
            if node.isLeaf {
                assert(!found)
                if !match { return }
                found = true
                node.keys.removeAtIndex(slot)
                result = node.payloads.removeAtIndex(slot)
                node.count -= 1
                return
            }
            if match {
                assert(!found)
                // For internal nodes, we move the previous item in place of the removed one,
                // and remove its original slot instead. (The previous item is always in a leaf node.)
                result = node.payloads[slot]
                node.makeChildUnique(slot)
                let previousKey = node.children[slot].maxKey()!
                let previousPayload = node.children[slot].remove(previousKey, root: false)!
                node.keys[slot] = previousKey
                node.payloads[slot] = previousPayload
                found = true
            }
            if found {
                node.count -= 1
                if node.children[slot].isTooSmall {
                    node.fixDeficiency(slot)
                }
            }
        }
        if root && keys.isEmpty && children.count == 1 {
            let node = children[0]
            keys = node.keys
            payloads = node.payloads
            children = node.children
        }
        return result
    }
}


func maximalTreeOfDepth(depth: Int, order: Int) -> BTreeNode<Int, String> {
    func maximalTreeOfDepth(depth: Int, inout key: Int) -> BTreeNode<Int, String> {
        let tree = BTreeNode<Int, String>(order: order)
        if depth == 0 {
            for _ in 0 ..< tree.order - 1 {
                tree.insert(String(key), at: key)
                key += 1
            }
        }
        else {
            for i in 0 ..< tree.order {
                let child = maximalTreeOfDepth(depth - 1, key: &key)
                tree.children.append(child)
                tree.count += child.count
                if i < tree.order - 1 {
                    tree.keys.append(key)
                    tree.payloads.append(String(key))
                    tree.count += 1
                    key += 1
                }
            }
        }
        return tree
    }

    var key = 0
    return maximalTreeOfDepth(depth, key: &key)
}

class BTreeTests: XCTestCase {
    typealias Node = BTreeNode<Int, String>
    let order = 7

    func testEmptyTree() {
        let tree = Node(order: order)
        tree.assertValid()
        XCTAssertTrue(tree.isEmpty)
        XCTAssertEqual(tree.count, 0)
        XCTAssertElementsEqual(tree, [])

        XCTAssertNil(tree.payloadOf(1))
    }

    func testInsertingASingleKey() {
        let tree = Node(order: order)
        tree.insert("One", at: 1)
        tree.assertValid()
        XCTAssertFalse(tree.isEmpty)
        XCTAssertEqual(tree.count, 1)
        XCTAssertElementsEqual(tree, [(1, "One")])

        XCTAssertEqual(tree.payloadOf(1), "One")
        XCTAssertNil(tree.payloadOf(2))
    }

    func testRemovingTheSingleKey() {
        let tree = Node(order: order)
        tree.insert("One", at: 1)
        XCTAssertEqual(tree.remove(1), "One")
        tree.assertValid()

        XCTAssertTrue(tree.isEmpty)
        XCTAssertEqual(tree.count, 0)
        XCTAssertElementsEqual(tree, [])

    }

    func testInsertingAndRemovingTwoKeys() {
        let tree = Node(order: order)
        tree.insert("One", at: 1)
        tree.insert("Two", at: 2)
        tree.assertValid()

        XCTAssertFalse(tree.isEmpty)
        XCTAssertEqual(tree.count, 2)
        XCTAssertElementsEqual(tree, [(1, "One"), (2, "Two")])

        XCTAssertEqual(tree.payloadOf(1), "One")
        XCTAssertEqual(tree.payloadOf(2), "Two")
        XCTAssertNil(tree.payloadOf(3))

        XCTAssertEqual(tree.remove(1), "One")
        tree.assertValid()

        XCTAssertFalse(tree.isEmpty)
        XCTAssertEqual(tree.count, 1)
        XCTAssertElementsEqual(tree, [(2, "Two")])

        XCTAssertEqual(tree.remove(2), "Two")
        tree.assertValid()

        XCTAssertTrue(tree.isEmpty)
        XCTAssertEqual(tree.count, 0)
        XCTAssertElementsEqual(tree, [])
    }

    func testSplittingRoot() {
        let tree = Node(order: order)
        var reference = Array<(Int, String)>()
        for i in 0..<tree.order {
            tree.insert("\(i)", at: i)
            tree.assertValid()
            reference.append((i, "\(i)"))
        }

        XCTAssertFalse(tree.isEmpty)
        XCTAssertEqual(tree.count, tree.order)
        XCTAssertElementsEqual(tree, reference)

        XCTAssertEqual(tree.keys.count, 1)
        XCTAssertEqual(tree.children.count, 2)
        XCTAssertEqual(tree.depth, 1)
    }

    func testRemovingNonexitentKeys() {
        let tree = Node(order: order)
        for i in 0..<tree.order {
            tree.insert("\(2 * i)", at: 2 * i)
            tree.assertValid()
        }
        for i in 0..<tree.order {
            XCTAssertNil(tree.remove(2 * i + 1))
        }
    }

    func testCollapsingRoot() {
        let tree = Node(order: order)
        var reference = Array<(Int, String)>()
        for i in 0..<tree.order {
            tree.insert("\(i)", at: i)
            tree.assertValid()
            reference.append((i, "\(i)"))
        }
        tree.remove(0)
        tree.assertValid()
        reference.removeAtIndex(0)

        XCTAssertEqual(tree.count, tree.order - 1)
        XCTAssertElementsEqual(tree, reference)

        XCTAssertEqual(tree.keys.count, tree.count)
        XCTAssertEqual(tree.children.count, 0)
        XCTAssertEqual(tree.depth, 0)
    }

    func testSplittingInternalNode() {
        let tree = Node(order: order)
        var reference = Array<(Int, String)>()
        let c = (3 * tree.order + 1) / 2
        for i in 0 ..< c {
            tree.insert("\(i)", at: i)
            tree.assertValid()
            reference.append((i, "\(i)"))
        }

        XCTAssertEqual(tree.count, c)
        XCTAssertElementsEqual(tree, reference)

        XCTAssertEqual(tree.keys.count, 2)
        XCTAssertEqual(tree.children.count, 3)
        XCTAssertEqual(tree.depth, 1)
    }

    func testCreatingMinimalTreeWithThreeLevels() {
        let tree = Node(order: order)
        var reference = Array<(Int, String)>()
        let c = (tree.order * tree.order - 1) / 2 + tree.order
        for i in 0 ..< c {
            tree.insert("\(i)", at: i)
            tree.assertValid()
            reference.append((i, "\(i)"))
        }

        XCTAssertEqual(tree.count, c)
        XCTAssertElementsEqual(tree, reference)

        XCTAssertEqual(tree.depth, 2)

        XCTAssertEqual(tree.payloadOf(c / 2), "\(c / 2)")
        XCTAssertEqual(tree.payloadOf(c / 2 + 1), "\(c / 2 + 1)")
    }

    func testRemovingKeysFromMinimalTreeWithThreeLevels() {
        let tree = Node(order: order)
        let c = (tree.order * tree.order - 1) / 2 + tree.order
        for i in 0 ..< c {
            tree.insert("\(i)", at: i)
            tree.assertValid()
        }

        for i in 0 ..< c {
            XCTAssertEqual(tree.remove(i), "\(i)")
            tree.assertValid()
        }
        XCTAssertElementsEqual(tree, [])
    }

    func testRemovingRootFromMinimalTreeWithThreeLevels() {
        let tree = Node(order: order)
        let c = (tree.order * tree.order - 1) / 2 + tree.order
        for i in 0 ..< c {
            tree.insert("\(i)", at: i)
            tree.assertValid()
        }
        XCTAssertEqual(tree.remove(c / 2), "\(c/2)")
        tree.assertValid()
        XCTAssertEqual(tree.depth, 1)
    }

    func testMaximalTreeOfDepth() {
        for depth in 0..<3 {
            let tree = maximalTreeOfDepth(depth, order: order)
            tree.assertValid()
            XCTAssertEqual(tree.depth, depth)
            XCTAssertEqual(tree.count, (0...depth).reduce(1, combine: { p, _ in p * tree.order }) - 1)
        }
    }

    func testRemovingFromBeginningOfMaximalTreeWithThreeLevels() {
        // This test exercises left rotations.
        let tree = maximalTreeOfDepth(2, order: order)
        for key in 0..<tree.count {
            XCTAssertEqual(tree.remove(key), String(key))
            tree.assertValid()
        }
        XCTAssertTrue(tree.isEmpty)
    }
    func testRemovingFromEndOfMaximalTreeWithThreeLevels() {
        // This test exercises right rotations.
        let tree = maximalTreeOfDepth(2, order: order)
        for key in (0..<tree.count).reverse() {
            XCTAssertEqual(tree.remove(key), String(key))
            tree.assertValid()
        }
        XCTAssertTrue(tree.isEmpty)
    }

    func testBulkLoadingOneFullNode() {
        let elements = (0 ..< order - 1).map { ($0, String($0)) }
        let tree = Node(order: order)
        tree.appendContentsOf(elements)
        tree.assertValid()
        XCTAssertElementsEqual(tree, elements)
    }

    func testBulkLoadingOneFullNodePlusOne() {
        let elements = (0 ..< order).map { ($0, String($0)) }
        let tree = Node(order: order)
        tree.appendContentsOf(elements)
        tree.assertValid()
        XCTAssertElementsEqual(tree, elements)
    }

    func testSortedBulkLoadingFullLevels() {
        let maxKeys = order - 1
        let minKeys = maxKeys / 2

        var n = maxKeys
        var sum = n
        for i in 0..<3 {
            let elements = (0 ..< sum).map { ($0, String($0)) }
            let tree = Node(order: order)
            tree.appendContentsOf(elements)
            tree.assertValid()
            XCTAssertElementsEqual(tree, elements)
            XCTAssertEqual(tree.depth, i)

            let extra = (sum + 1, String(sum + 1))
            tree.insert(extra.1, at: extra.0)
            tree.assertValid()
            XCTAssertElementsEqual(tree, elements + [extra])
            XCTAssertEqual(tree.depth, i + 1)

            n = n * (minKeys + 1)
            sum += n
        }
    }
}