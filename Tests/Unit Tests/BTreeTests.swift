//
//  BTreeTests.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2016-01-13.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import TreeCollections

extension BTree {
    func assertValid(file file: FileString = __FILE__, line: UInt = __LINE__) {
        root.assertValid(file: file, line: line)
    }
}

class BTreeTests: XCTestCase {
    typealias Tree = BTree<Int, String>
    let order = 7

    func testEmptyTree() {
        let tree = Tree(order: order)
        tree.assertValid()
        XCTAssertTrue(tree.isEmpty)
        XCTAssertEqual(tree.count, 0)
        XCTAssertEqual(tree.depth, 0)
        XCTAssertEqual(tree.order, order)
        XCTAssertElementsEqual(tree, [])
        XCTAssertEqual(tree.startIndex, tree.endIndex)
        XCTAssertNil(tree.payloadOf(1))
    }

    func testUniquing() {
        let tree = minimalTree(depth: 1, order: 7)
        var copy = tree
        copy.makeUnique()
        copy.assertValid()
        XCTAssertTrue(tree.root !== copy.root)
        XCTAssertElementsEqual(copy, tree)
    }

    func testGenerate() {
        let tree = minimalTree(depth: 2, order: 5)
        let c = tree.count
        XCTAssertElementsEqual(GeneratorSequence(tree.generate()), (0 ..< c).map { ($0, String($0)) })
    }

    func testForEach() {
        let tree = maximalTree(depth: 2, order: order)
        var values: Array<Int> = []
        tree.forEach { values.append($0.0) }
        XCTAssertElementsEqual(values, 0..<tree.count)
    }

    func testInterruptibleForEach() {
        let tree = maximalTree(depth: 1, order: 5)
        for i in 0...tree.count {
            var j = 0
            tree.forEach { pair -> Bool in
                XCTAssertEqual(pair.0, j)
                XCTAssertLessThanOrEqual(j, i)
                if j == i { return false }
                j += 1
                return true
            }
            XCTAssertEqual(j, i)
        }
    }

    func testIterationUsingIndexingForward() {
        let tree = maximalTree(depth: 3, order: 3)
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
        let tree = maximalTree(depth: 3, order: 3)
        var index = tree.endIndex
        var i = tree.count
        while index != tree.startIndex {
            index = index.predecessor()
            i -= 1
            XCTAssertEqual(tree[index].0, i)
        }
        XCTAssertEqual(i, 0)
    }

    func testElementAtPosition() {
        let tree = maximalTree(depth: 3, order: 3)
        for p in 0 ..< tree.count {
            let element = tree.elementAtPosition(p)
            XCTAssertEqual(element.0, p)
            XCTAssertEqual(element.1, String(p))
        }
    }

    func testPayloadOfKey() {
        let count = 42
        let tree = Tree(sortedElements: (0 ..< count).map { (2 * $0, String(2 * $0)) }, order: 3)
        for selector: BTreeKeySelector in [.Any, .First, .Last] {
            for k in (0 ..< count).lazy.map({ 2 * $0 }) {
                XCTAssertEqual(tree.payloadOf(k, choosing: selector), String(k), String(selector))
                XCTAssertNil(tree.payloadOf(k + 1, choosing: selector))
            }
            XCTAssertNil(tree.payloadOf(-1, choosing: selector))
        }
    }

    func testIndexOfKey() {
        let count = 42
        let tree = Tree(sortedElements: (0 ..< count).map { (2 * $0, String(2 * $0)) }, order: 3)
        for selector: BTreeKeySelector in [.Any, .First, .Last] {
            for k in (0 ..< count).lazy.map({ 2 * $0 }) {
                XCTAssertNil(tree.indexOf(k + 1, choosing: selector))
                guard let index = tree.indexOf(k, choosing: selector) else {
                    XCTFail("index is nil for key=\(k), selector=\(selector)")
                    continue
                }
                XCTAssertEqual(tree[index].0, k)
            }
            XCTAssertNil(tree.indexOf(-1, choosing: selector))
        }
    }

    func testPositionOfKey() {
        let count = 42
        let tree = Tree(sortedElements: (0 ..< count).map { (2 * $0, String(2 * $0)) }, order: 3)
        for selector: BTreeKeySelector in [.Any, .First, .Last] {
            for k in (0 ..< count).lazy.map({ 2 * $0 }) {
                XCTAssertNil(tree.positionOf(k + 1, choosing: selector))
                guard let position = tree.positionOf(k, choosing: selector) else {
                    XCTFail("position is nil for key=\(k), selector=\(selector)")
                    continue
                }
                XCTAssertEqual(tree.elementAtPosition(position).0, k)
            }
            XCTAssertNil(tree.positionOf(-1, choosing: selector))
        }
    }

    func testPositionOfIndex() {
        let count = 42
        let tree = Tree(sortedElements: (0 ..< count).map { (2 * $0, String(2 * $0)) }, order: 3)
        var index = tree.startIndex
        var position = 0
        while position < count {
            XCTAssertEqual(tree[index].0, 2 * position)
            XCTAssertEqual(tree.positionOfIndex(index), position)
            index = index.successor()
            position += 1
        }
        XCTAssertEqual(index, tree.endIndex)
    }

    func testIndexOfPosition() {
        let count = 42
        let tree = Tree(sortedElements: (0 ..< count).map { (2 * $0, String(2 * $0)) }, order: 3)
        var position = 0
        while position < count {
            let index = tree.indexOfPosition(position)
            XCTAssertEqual(tree[index].0, 2 * position)
            position += 1
        }
    }

    func testInsertAtPosition() {
        let count = 42
        var tree = Tree(sortedElements: (0 ..< count).map { (2 * $0 + 1, String(2 * $0 + 1)) }, order: 3)
        var position = 0
        while position < count {
            let key = 2 * position
            tree.insert((key, String(key)), at: 2 * position)
            tree.assertValid()
            position += 1
        }
        XCTAssertElementsEqual(tree.map { $0.0 }, 0 ..< 2 * count)
    }

    func testSetPayloadAtPosition() {
        let count = 42
        var tree = Tree(sortedElements: (0 ..< count).map { ($0, "") }, order: 3)
        var position = 0
        while position < count {
            let old = tree.setPayloadAt(position, to: String(position))
            XCTAssertEqual(old, "")
            tree.assertValid()
            position += 1
        }
        XCTAssertElementsEqual(tree, (0 ..< count).map { ($0, String($0)) })
    }

    func testInsertElementFirst() {
        let count = 42
        var tree = Tree(order: 3)
        for i in 0 ..< count {
            tree.insert((0, String(i)), at: .First)
            tree.assertValid()
        }
        XCTAssertElementsEqual(tree, (0 ..< count).reverse().map { (0, String($0)) })
    }

    func testInsertElementLast() {
        let count = 42
        var tree = Tree(order: 3)
        for i in 0 ..< count {
            tree.insert((0, String(i)), at: .Last)
            tree.assertValid()
        }
        XCTAssertElementsEqual(tree, (0 ..< count).map { (0, String($0)) })
    }

    func testInsertElementAny() { // Same as .Last
        let count = 42
        var tree = Tree(order: 3)
        for i in 0 ..< count {
            tree.insert((0, String(i)))
            tree.assertValid()
        }
        XCTAssertElementsEqual(tree, (0 ..< count).map { (0, String($0)) })
    }

    func testInsertOrReplaceAny() {
        let count = 42
        var tree = Tree(sortedElements: (0 ..< count).map { (2 * $0, "*\(2 * $0)") }, order: 3)
        for key in 0 ..< 2 * count {
            let old = tree.insertOrReplace((key, String(key)), at: .Any)
            tree.assertValid()
            if key & 1 == 0 {
                XCTAssertEqual(old, "*\(key)")
            }
            else {
                XCTAssertNil(old)
            }
        }
        XCTAssertElementsEqual(tree, (0 ..< 2 * count).map { ($0, String($0)) })
    }

    func testInsertOrReplaceFirst() {
        var tree = Tree(order: 3)
        for k in 0 ..< 42 {
            tree.insert((k, String(k) + "/1"))
            tree.insert((k, String(k) + "/2"))
            tree.insert((k, String(k) + "/3"))
        }
        tree.assertValid()
        for k in 0 ..< 42 {
            tree.insertOrReplace((k, String(k) + "/1*"), at: .First)
            tree.assertValid()
        }
        XCTAssertElementsEqual(tree.map { $0.1 }, (0 ..< 42).flatMap { key -> [String] in
            let ks = String(key)
            return [ks + "/1*", ks + "/2", ks + "/3"]
        })
    }

    func testInsertOrReplaceLast() {
        var tree = Tree(order: 3)
        for k in 0 ..< 42 {
            tree.insert((k, String(k) + "/1"))
            tree.insert((k, String(k) + "/2"))
            tree.insert((k, String(k) + "/3"))
        }
        tree.assertValid()
        for k in 0 ..< 42 {
            tree.insertOrReplace((k, String(k) + "/3*"), at: .Last)
            tree.assertValid()
        }
        XCTAssertElementsEqual(tree.map { $0.1 }, (0 ..< 42).flatMap { key -> [String] in
            let ks = String(key)
            return [ks + "/1", ks + "/2", ks + "/3*"]
            })
    }

    func testRemoveAtPosition() {
        var tree = maximalTree(depth: 3, order: 3)
        let c = tree.count
        var reference = Array((0..<c).map { ($0, String($0)) })
        while tree.count > 0 {
            let p = tree.count / 2
            let element = tree.removeAt(p)
            let ref = reference.removeAtIndex(p)
            tree.assertValid()
            XCTAssertElementsEqual(tree, reference)
            XCTAssertEqual(element.0, ref.0)
            XCTAssertEqual(element.1, ref.1)
        }
    }

    func testRemoveKeyFirst() {
        let count = 42
        var tree = Tree(order: 3)
        for k in (0 ..< count).map({ 2 * $0 }) {
            tree.insert((k, String(k) + "/1"))
            tree.insert((k, String(k) + "/2"))
            tree.insert((k, String(k) + "/3"))
        }
        tree.assertValid()

        for k in 0 ..< count {
            XCTAssertNil(tree.remove(2 * k + 1, at: .First))
            guard let old = tree.remove(2 * k, at: .First) else { XCTFail(String(2 * k)); continue }
            XCTAssertEqual(old, String(2 * k) + "/1")
            tree.assertValid()
        }

        XCTAssertElementsEqual(tree.map { $0.1 }, (0 ..< count).flatMap { key -> [String] in
            let ks = String(2 * key)
            return [ks + "/2", ks + "/3"]
            }
        )
    }

    func testRemoveKeyLast() {
        let count = 42
        var tree = Tree(order: 3)
        for k in (0 ..< count).map({ 2 * $0 }) {
            tree.insert((k, String(k) + "/1"))
            tree.insert((k, String(k) + "/2"))
            tree.insert((k, String(k) + "/3"))
        }
        tree.assertValid()

        for k in 0 ..< count {
            XCTAssertNil(tree.remove(2 * k + 1, at: .Last))
            guard let old = tree.remove(2 * k, at: .Last) else { XCTFail(String(2 * k)); continue }
            XCTAssertEqual(old, String(2 * k) + "/3")
            tree.assertValid()
        }

        XCTAssertElementsEqual(tree.map { $0.1 }, (0 ..< count).flatMap { key -> [String] in
            let ks = String(2 * key)
            return [ks + "/1", ks + "/2"]
            }
        )
    }


    func testRemoveKeyAny() { // Same as .First
        let count = 42
        var tree = Tree(order: 3)
        for k in (0 ..< count).map({ 2 * $0 }) {
            tree.insert((k, String(k) + "/1"))
            tree.insert((k, String(k) + "/2"))
            tree.insert((k, String(k) + "/3"))
        }
        tree.assertValid()

        for k in 0 ..< count {
            XCTAssertNil(tree.remove(2 * k + 1))
            guard let old = tree.remove(2 * k) else { XCTFail(String(2 * k)); continue }
            XCTAssertEqual(old, String(2 * k) + "/1")
            tree.assertValid()
        }

        XCTAssertElementsEqual(tree.map { $0.1 }, (0 ..< count).flatMap { key -> [String] in
            let ks = String(2 * key)
            return [ks + "/2", ks + "/3"]
            }
        )
    }

    ////

    func testInsertingASingleKey() {
        var tree = Tree(order: order)
        tree.insert((1, "One"))
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
        var tree = Tree(order: order)
        tree.insert((1, "One"))
        XCTAssertEqual(tree.remove(1), "One")
        tree.assertValid()

        XCTAssertTrue(tree.isEmpty)
        XCTAssertEqual(tree.count, 0)
        XCTAssertElementsEqual(tree, [])

        XCTAssertEqual(tree.startIndex, tree.endIndex)
    }

    func testInsertingAndRemovingTwoKeys() {
        var tree = Tree(order: order)
        tree.insert((1, "One"))
        tree.insert((2, "Two"))
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
        var tree = Tree(order: order)
        var reference = Array<(Int, String)>()
        for i in 0..<tree.order {
            tree.insert((i, "\(i)"))
            tree.assertValid()
            reference.append((i, "\(i)"))
        }

        XCTAssertFalse(tree.isEmpty)
        XCTAssertEqual(tree.count, tree.order)
        XCTAssertElementsEqual(tree, reference)
        XCTAssertEqual(tree.depth, 1)

        XCTAssertEqual(tree.root.keys.count, 1)
        XCTAssertEqual(tree.root.children.count, 2)
    }

    func testRemovingNonexistentKeys() {
        var tree = Tree(order: order)
        for i in 0..<tree.order {
            tree.insert((2 * i, "\(2 * i)"))
            tree.assertValid()
        }
        for i in 0..<tree.order {
            XCTAssertNil(tree.remove(2 * i + 1))
        }
    }

    func testCollapsingRoot() {
        var tree = Tree(order: order)
        var reference = Array<(Int, String)>()
        for i in 0..<tree.order {
            tree.insert((i, String(i)))
            tree.assertValid()
            reference.append((i, "\(i)"))
        }
        tree.remove(0)
        tree.assertValid()
        reference.removeAtIndex(0)

        XCTAssertEqual(tree.depth, 0)
        XCTAssertEqual(tree.count, tree.order - 1)
        XCTAssertElementsEqual(tree, reference)
    }

    func testSplittingInternalNode() {
        var tree = Tree(order: order)
        var reference = Array<(Int, String)>()
        let c = (3 * tree.order + 1) / 2
        for i in 0 ..< c {
            tree.insert((i, String(i)))
            tree.assertValid()
            reference.append((i, "\(i)"))
        }

        XCTAssertEqual(tree.count, c)
        XCTAssertElementsEqual(tree, reference)

        XCTAssertEqual(tree.depth, 1)
    }

    func testCreatingMinimalTreeWithThreeLevels() {
        var tree = Tree(order: order)
        var reference = Array<(Int, String)>()
        let c = (tree.order * tree.order - 1) / 2 + tree.order
        for i in 0 ..< c {
            tree.insert((i, String(i)))
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
        var tree = Tree(order: order)
        let c = (tree.order * tree.order - 1) / 2 + tree.order
        for i in 0 ..< c {
            tree.insert((i, String(i)))
            tree.assertValid()
        }

        for i in 0 ..< c {
            XCTAssertEqual(tree.remove(i), "\(i)")
            tree.assertValid()
        }
        XCTAssertElementsEqual(tree, [])
    }

    func testRemovingRootFromMinimalTreeWithThreeLevels() {
        var tree = Tree(order: order)
        let c = (tree.order * tree.order - 1) / 2 + tree.order
        for i in 0 ..< c {
            tree.insert((i, String(i)))
            tree.assertValid()
        }
        XCTAssertEqual(tree.remove(c / 2), "\(c/2)")
        tree.assertValid()
        XCTAssertEqual(tree.depth, 1)
    }

    func testMaximalTreeOfDepth() {
        for depth in 0..<3 {
            let tree = maximalTree(depth: depth, order: order)
            tree.assertValid()
            XCTAssertEqual(tree.depth, depth)
            XCTAssertEqual(tree.count, (0...depth).reduce(1, combine: { p, _ in p * tree.order }) - 1)
        }
    }

    func testRemovingFromBeginningOfMaximalTreeWithThreeLevels() {
        // This test exercises left rotations.
        var tree = maximalTree(depth: 2, order: order)
        for key in 0..<tree.count {
            XCTAssertEqual(tree.remove(key), String(key))
            tree.assertValid()
        }
        XCTAssertTrue(tree.isEmpty)
    }
    func testRemovingFromEndOfMaximalTreeWithThreeLevels() {
        // This test exercises right rotations.
        var tree = maximalTree(depth: 2, order: order)
        for key in (0..<tree.count).reverse() {
            XCTAssertEqual(tree.remove(key), String(key))
            tree.assertValid()
        }
        XCTAssertTrue(tree.isEmpty)
    }

    func testSequenceConversion() {
        func check(range: Range<Int>, file: FileString = __FILE__, line: UInt = __LINE__) {
            let order = 5
            let sequence = range.map { ($0, String($0)) }
            let tree = Tree(sortedElements: sequence, order: order)
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
        let tree = Tree(elements: [(3, "3"), (1, "1"), (4, "4"), (2, "2"), (0, "0")])
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
            let tree = Tree(sortedElements: sequence, order: order, fillFactor: 1.0)
            tree.assertValid(file: file, line: line)
            tree.root.forEachNode { node in
                XCTAssertEqual(node.keys.count, keysPerNode, file: file, line: line)
            }
        }

        checkDepth(0)
        checkDepth(1)
        checkDepth(2)
        checkDepth(3)
    }
}