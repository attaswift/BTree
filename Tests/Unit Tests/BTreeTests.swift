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

class BTreeTests: XCTestCase {
    typealias Node = BTreeNode<Int, String>
    let order = 7

    func testEmptyTree() {
        let tree = Node(order: order)
        tree.assertValid()
        XCTAssertTrue(tree.isEmpty)
        XCTAssertEqual(tree.count, 0)
        XCTAssertElementsEqual(tree, [])

        XCTAssertEqual(tree.startIndex, tree.endIndex)

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

        XCTAssertNotEqual(tree.startIndex, tree.endIndex)
        XCTAssertEqual(tree[tree.startIndex].0, 1)
        XCTAssertEqual(tree[tree.startIndex].1, "One")
    }

    func testRemovingTheSingleKey() {
        let tree = Node(order: order)
        tree.insert("One", at: 1)
        XCTAssertEqual(tree.remove(1), "One")
        tree.assertValid()

        XCTAssertTrue(tree.isEmpty)
        XCTAssertEqual(tree.count, 0)
        XCTAssertElementsEqual(tree, [])

        XCTAssertEqual(tree.startIndex, tree.endIndex)
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

    func testIterationUsingIndexingForward() {
        let tree = maximalTreeOfDepth(3, order: 3)
        var index = tree.startIndex
        var i = 0
        while index != tree.endIndex {
            XCTAssertEqual(tree[index].0, i)
            index = index.successor()
            i += 1
        }
        XCTAssertEqual(i, tree.count)
    }

    func testIterationUsingIndexingBackward() {
        let tree = maximalTreeOfDepth(3, order: 3)
        var index = tree.endIndex
        var i = tree.count
        while index != tree.startIndex {
            index = index.predecessor()
            i -= 1
            XCTAssertEqual(tree[index].0, i)
        }
        XCTAssertEqual(i, 0)
    }

    func testForEach() {
        let tree = maximalTreeOfDepth(2, order: order)
        var values: Array<Int> = []
        tree.forEach { values.append($0.0) }
        XCTAssertElementsEqual(values, 0..<tree.count)
    }

    func testInterruptibleForEach() {
        let tree = maximalTreeOfDepth(1, order: 5)
        for i in 0...tree.count {
            var j = 0
            tree.forEach { pair -> Bool in
                XCTAssertEqual(pair.0, j)
                XCTAssertLessThanOrEqual(j, i)
                if j == i { return false }
                j += 1
                return true
            }
        }
    }

    func testSlotOfParentChild() {
        let root = maximalTreeOfDepth(1, order: 5)
        XCTAssertEqual(root.slotOf(root.children[0]), 0)
        XCTAssertEqual(root.slotOf(root.children[1]), 1)
        XCTAssertNil(root.children[1].slotOf(root))
    }

    func testJoin() {
        func createTree(keys: Range<Int> = 0..<0) -> Node {
            let t = Node(order: 5)
            for key in keys {
                t.insert(String(key), at: key)
            }
            return t
        }
        func checkTree(t: Node, _ keys: Range<Int>, file: FileString = __FILE__, line: UInt = __LINE__) {
            t.assertValid(file: file, line: line)
            XCTAssertElementsEqual(t, keys.map { ($0, String($0)) }, file: file, line: line)
        }

        checkTree(Node.join(left: createTree(), separator: (0, "0"), right: createTree()), 0...0)
        checkTree(Node.join(left: createTree(), separator: (0, "0"), right: createTree(1...1)), 0...1)
        checkTree(Node.join(left: createTree(0...0), separator: (1, "1"), right: createTree()), 0...1)
        checkTree(Node.join(left: createTree(0...0), separator: (1, "1"), right: createTree(2...2)), 0...2)

        checkTree(Node.join(left: createTree(0...98), separator: (99, "99"), right: createTree(100...100)), 0...100)
        checkTree(Node.join(left: createTree(0...0), separator: (1, "1"), right: createTree(2...100)), 0...100)
        checkTree(Node.join(left: createTree(0...99), separator: (100, "100"), right: createTree(101...200)), 0...200)

        do {
            let l = maximalTreeOfDepth(2, order: 3)
            let r = maximalTreeOfDepth(2, order: 3, offset: l.count + 1)
            let s = (l.count, String(l.count))
            let c = l.count + r.count + 1
            checkTree(Node.join(left: l, separator: s, right: r), 0..<c)
        }

        do {
            let l = maximalTreeOfDepth(1, order: 3)
            let r = maximalTreeOfDepth(2, order: 3, offset: l.count + 1)
            let s = (l.count, String(l.count))
            let c = l.count + r.count + 1
            checkTree(Node.join(left: l, separator: s, right: r), 0..<c)
        }

        do {
            let l = maximalTreeOfDepth(2, order: 3)
            let r = maximalTreeOfDepth(1, order: 3, offset: l.count + 1)
            let s = (l.count, String(l.count))
            let c = l.count + r.count + 1
            checkTree(Node.join(left: l, separator: s, right: r), 0..<c)
        }
    }

    func testSequenceConversion() {
        func check(range: Range<Int>, file: FileString = __FILE__, line: UInt = __LINE__) {
            let order = 5
            let sequence = range.map { ($0, String($0)) }
            let tree = Node(sortedElements: sequence, order: order)
            tree.assertValid(file: file, line: line)
            XCTAssertElementsEqual(tree, sequence, file: file, line: line)
        }
        check(0..<0)
        check(0..<1)
        check(0..<4)
        check(0..<5)
        check(0..<10)
        check(0..<100)
        check(0..<200)
    }

    func testUnsortedSequenceConversion() {
        let tree = Node(elements: [(3, "3"), (1, "1"), (4, "4"), (2, "2"), (0, "0")])
        tree.assertValid()
        XCTAssertElementsEqual(tree, [(0, "0"), (1, "1"), (2, "2"), (3, "3"), (4, "4")])
    }

    func testSequenceConversionToMaximalTrees() {
        func checkDepth(depth: Int, file: FileString = __FILE__, line: UInt = __LINE__) {
            let order = 5
            let keysPerNode = order - 1
            var count = keysPerNode
            for _ in 0 ..< depth {
                count = count * (keysPerNode + 1) + keysPerNode
            }
            let sequence = (0 ..< count).map { ($0, String($0)) }
            let tree = Node(sortedElements: sequence, order: order, fillFactor: 1.0)
            tree.assertValid(file: file, line: line)
            tree.forEachNode { node in
                XCTAssertEqual(node.keys.count, keysPerNode, file: file, line: line)
            }
        }

        checkDepth(0)
        checkDepth(1)
        checkDepth(2)
        checkDepth(3)
    }
}