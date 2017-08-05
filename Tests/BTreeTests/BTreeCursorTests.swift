//
//  BTreeCursorTests.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-19.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import Foundation
import XCTest
@testable import BTree

class BTreeCursorTests: XCTestCase {
    typealias Tree = BTree<Int, String>

    func testCursorWithEmptyTree() {
        func checkEmpty(_ cursor: BTreeCursor<Int, String>) {
            XCTAssertTrue(cursor.isValid)
            XCTAssertTrue(cursor.isAtStart)
            XCTAssertTrue(cursor.isAtEnd)
            XCTAssertEqual(cursor.count, 0)
            let node = cursor.finish()
            assertEqualElements(node, [])
        }

        var tree = Tree()
        tree.withCursorAtStart(checkEmpty)
        tree.withCursorAtEnd(checkEmpty)
        tree.withCursor(atOffset: 0, body: checkEmpty)
        tree.withCursor(onKey: 42, choosing: .first, body: checkEmpty)
        tree.withCursor(onKey: 42, choosing: .last, body: checkEmpty)
        tree.withCursor(onKey: 42, choosing: .after, body: checkEmpty)
        tree.withCursor(onKey: 42, choosing: .any, body: checkEmpty)
    }

    func testCursorAtStart() {
        var tree = maximalTree(depth: 2, order: 5)
        tree.withCursorAtStart { cursor in
            XCTAssertTrue(cursor.isAtStart)
            XCTAssertFalse(cursor.isAtEnd)
            XCTAssertEqual(cursor.offset, 0)
            XCTAssertEqual(cursor.key, 0)
            XCTAssertEqual(cursor.value, "0")
        }
    }

    func testCursorAtEnd() {
        var tree = maximalTree(depth: 2, order: 5)
        let count = tree.count
        tree.withCursorAtEnd { cursor in
            XCTAssertFalse(cursor.isAtStart)
            XCTAssertTrue(cursor.isAtEnd)
            XCTAssertEqual(cursor.offset, count)
        }
    }

    func testCursorAtOffset() {
        var tree = maximalTree(depth: 3, order: 4)
        let c = tree.count
        for p in 0 ..< c {
            tree.withCursor(atOffset: p) { cursor in
                XCTAssertEqual(cursor.offset, p)
                XCTAssertEqual(cursor.key, p)
                XCTAssertEqual(cursor.value, String(p))
            }
        }
        tree.withCursor(atOffset: c) { cursor in
            XCTAssertTrue(cursor.isAtEnd)
        }
    }

    func testCursorAtKeyFirst() {
        let count = 42
        var tree = Tree(order: 3)
        for k in (0 ..< count).map({ 2 * $0 }) {
            tree.insert((k, String(k) + "/1"))
            tree.insert((k, String(k) + "/2"))
            tree.insert((k, String(k) + "/3"))
        }
        tree.assertValid()

        for i in 0 ..< count {
            tree.withCursor(onKey: 2 * i + 1, choosing: .first) { cursor in
                XCTAssertEqual(cursor.offset, 3 * (i + 1))
            }
            tree.withCursor(onKey: 2 * i, choosing: .first) { cursor in
                XCTAssertEqual(cursor.offset, 3 * i)
                XCTAssertEqual(cursor.key, 2 * i)
                XCTAssertEqual(cursor.value, String(2 * i) + "/1")
            }
        }
    }

    func testCursorAtKeyLast() {
        let count = 42
        var tree = Tree(order: 3)
        for k in (0 ..< count).map({ 2 * $0 }) {
            tree.insert((k, String(k) + "/1"))
            tree.insert((k, String(k) + "/2"))
            tree.insert((k, String(k) + "/3"))
        }
        tree.assertValid()

        for i in 0 ..< count {
            tree.withCursor(onKey: 2 * i + 1, choosing: .last) { cursor in
                XCTAssertEqual(cursor.offset, 3 * (i + 1))
            }
            tree.withCursor(onKey: 2 * i, choosing: .last) { cursor in
                XCTAssertEqual(cursor.offset, 3 * i + 2)
                XCTAssertEqual(cursor.key, 2 * i)
                XCTAssertEqual(cursor.value, String(2 * i) + "/3")
            }
        }
    }

    func testCursorAtKeyAfter() {
        let count = 42
        var tree = Tree(order: 3)
        for k in (0 ... count).map({ 2 * $0 }) {
            tree.insert((k, String(k) + "/1"))
            tree.insert((k, String(k) + "/2"))
            tree.insert((k, String(k) + "/3"))
        }
        tree.assertValid()

        for i in 0 ..< count {
            tree.withCursor(onKey: 2 * i + 1, choosing: .after) { cursor in
                XCTAssertEqual(cursor.offset, 3 * (i + 1))
            }
            tree.withCursor(onKey: 2 * i, choosing: .after) { cursor in
                XCTAssertEqual(cursor.offset, 3 * (i + 1))
                XCTAssertEqual(cursor.key, 2 * (i + 1))
                XCTAssertEqual(cursor.value, String(2 * (i + 1)) + "/1")
            }
        }
    }

    func testCursorAtKeyAny() {
        let count = 42
        var tree = Tree(order: 3)
        for k in (0 ..< count).map({ 2 * $0 }) {
            tree.insert((k, String(k) + "/1"))
            tree.insert((k, String(k) + "/2"))
            tree.insert((k, String(k) + "/3"))
        }
        tree.assertValid()

        for i in 0 ..< count {
            tree.withCursor(onKey: 2 * i + 1) { cursor in
                XCTAssertEqual(cursor.offset, 3 * (i + 1))
            }
            tree.withCursor(onKey: 2 * i) { cursor in
                XCTAssertGreaterThanOrEqual(cursor.offset, 3 * i)
                XCTAssertLessThan(cursor.offset, 3 * (i + 1))
                XCTAssertEqual(cursor.key, 2 * i)
                XCTAssertTrue(cursor.value.hasPrefix(String(2 * i) + "/"), cursor.value)
            }
        }
    }

    func testCursorAtIndex() {
        var tree = maximalTree(depth: 3, order: 3)
        let count = tree.count
        for i in 0 ... count {
            let index = tree.index(tree.startIndex, offsetBy: i)
            tree.withCursor(at: index) { cursor in
                XCTAssertEqual(cursor.offset, i)
                if i != count {
                    XCTAssertEqual(cursor.key, i)
                }
            }
        }
    }

    func testMoveForward() {
        var tree = maximalTree(depth: 2, order: 5)
        let count = tree.count
        tree.withCursorAtStart { cursor in
            var i = 0
            while !cursor.isAtEnd {
                XCTAssertEqual(cursor.offset, i)
                XCTAssertEqual(cursor.key, i)
                XCTAssertEqual(cursor.value, String(i))
                XCTAssertEqual(cursor.element.0, i)
                XCTAssertEqual(cursor.element.1, String(i))
                cursor.moveForward()
                i += 1
            }
            XCTAssertEqual(i, count)
        }
    }

    func testMoveBackward() {
        var tree = maximalTree(depth: 2, order: 5)
        tree.withCursorAtEnd { cursor in
            var i = cursor.count
            while !cursor.isAtStart {
                XCTAssertEqual(cursor.offset, i)
                cursor.moveBackward()
                i -= 1
                XCTAssertEqual(cursor.key, i)
                XCTAssertEqual(cursor.value, String(i))
            }
            XCTAssertEqual(i, 0)
        }
    }

    func testMoveToEnd() {
        var tree = maximalTree(depth: 2, order: 5)
        let c = tree.count
        for i in 0 ... c {
            tree.withCursor(atOffset: i) { cursor in
                cursor.moveToEnd()
                XCTAssertTrue(cursor.isAtEnd)
                XCTAssertEqual(cursor.offset, c)
            }
        }
    }
    
    func testMoveToOffset() {
        var tree = maximalTree(depth: 2, order: 5)
        tree.withCursorAtStart { cursor in
            var i = 0
            var j = cursor.count - 1
            var toggle = false
            while i < j {
                if toggle {
                    cursor.offset = i
                    XCTAssertEqual(cursor.offset, i)
                    XCTAssertEqual(cursor.key, i)
                    i += 1
                    toggle = false
                }
                else {
                    cursor.move(toOffset: j)
                    XCTAssertEqual(cursor.offset, j)
                    XCTAssertEqual(cursor.key, j)
                    j -= 1
                    toggle = true
                }
            }
            cursor.move(toOffset: cursor.count)
            XCTAssertTrue(cursor.isAtEnd)
            cursor.moveBackward()
            XCTAssertEqual(cursor.key, cursor.count - 1)
        }
    }

    func testMoveToKey() {
        let count = 42
        var tree = BTree((0..<count).map { (2 * $0, String(2 * $0)) }, order: 3)
        tree.withCursorAtStart() { cursor in
            var start = 0
            var end = count - 1
            while start < end {
                cursor.move(to: 2 * end)
                XCTAssertEqual(cursor.offset, end)
                XCTAssertEqual(cursor.key, 2 * end)

                cursor.move(to: 2 * start + 1)
                XCTAssertEqual(cursor.offset, start + 1)
                XCTAssertEqual(cursor.key, 2 * start + 2)

                start += 1
                end -= 1
            }

            start = 0
            end = count - 1
            while start < end {
                cursor.move(to: 2 * end - 1)
                XCTAssertEqual(cursor.offset, end)
                XCTAssertEqual(cursor.key, 2 * end)

                cursor.move(to: 2 * start)
                XCTAssertEqual(cursor.offset, start)
                XCTAssertEqual(cursor.key, 2 * start)

                start += 1
                end -= 1
            }
        }
    }

    func testReplacingElement() {
        var tree = maximalTree(depth: 2, order: 5)
        tree.withCursorAtStart { cursor in
            while !cursor.isAtEnd {
                let k = cursor.key
                cursor.element = (2 * k, String(2 * k))
                cursor.moveForward()
            }
            let node = cursor.finish()
            node.assertValid()
            var i = 0
            for (key, value) in node {
                XCTAssertEqual(key, 2 * i)
                XCTAssertEqual(value, String(2 * i))
                i += 1
            }
        }
    }

    func testReplacingKeyAndValue() {
        var tree = maximalTree(depth: 2, order: 5)
        tree.withCursorAtStart { cursor in
            while !cursor.isAtEnd {
                cursor.key = 2 * cursor.key
                cursor.value = String(cursor.key)
                cursor.moveForward()
            }
            let node = cursor.finish()
            node.assertValid()
            var i = 0
            for (key, value) in node {
                XCTAssertEqual(key, 2 * i)
                XCTAssertEqual(value, String(2 * i))
                i += 1
            }
        }
    }

    func testSetValue() {
        var tree = maximalTree(depth: 2, order: 5)
        tree.withCursorAtStart { cursor in
            var i = 0
            while !cursor.isAtEnd {
                XCTAssertEqual(cursor.setValue("Hello"), String(i))
                cursor.moveForward()
                i += 1
            }
        }
        tree.assertValid()
        for (_, value) in tree {
            XCTAssertEqual(value, "Hello")
        }
    }

    func testBuildingATreeUsingInsertBefore() {
        var tree = Tree(order: 3)
        tree.withCursorAtEnd { cursor in
            XCTAssertTrue(cursor.isAtEnd)
            for i in 0..<30 {
                cursor.insert((i, String(i)))
                XCTAssertTrue(cursor.isAtEnd)
            }
        }
        tree.assertValid()
        assertEqualElements(tree, (0..<30).map { ($0, String($0)) })
    }

    func testBuildingATreeInTwoPassesUsingInsertBefore() {
        var tree = Tree(order: 5)
        let c = 30
        tree.withCursorAtStart() { cursor in
            XCTAssertTrue(cursor.isAtEnd)
            for i in 0..<c {
                cursor.insert((2 * i + 1, String(2 * i + 1)))
                XCTAssertTrue(cursor.isAtEnd)
            }

            cursor.moveToStart()
            XCTAssertEqual(cursor.offset, 0)
            for i in 0..<c {
                XCTAssertEqual(cursor.key, 2 * i + 1)
                XCTAssertEqual(cursor.offset, 2 * i)
                XCTAssertEqual(cursor.count, c + i)
                cursor.insert((2 * i, String(2 * i)))
                XCTAssertEqual(cursor.key, 2 * i + 1)
                XCTAssertEqual(cursor.offset, 2 * i + 1)
                XCTAssertEqual(cursor.count, c + i + 1)
                cursor.moveForward()
            }
        }
        tree.assertValid()
        assertEqualElements(tree, (0 ..< 2 * c).map { ($0, String($0)) })
    }

    func testBuildingATreeUsingInsertAfter() {
        var tree = Tree(order: 5)
        let c = 30
        tree.withCursorAtStart() { cursor in
            cursor.insert((0, "0"))
            cursor.moveToStart()
            for i in 1 ..< c {
                cursor.insertAfter((i, String(i)))
                XCTAssertEqual(cursor.offset, i)
                XCTAssertEqual(cursor.key, i)
            }
        }
        tree.assertValid()
        assertEqualElements(tree, (0..<30).map { ($0, String($0)) })
    }

    func testBuildingATreeInTwoPassesUsingInsertAfter() {
        var tree = Tree(order: 5)
        let c = 30
        tree.withCursorAtStart() { cursor in
            XCTAssertTrue(cursor.isAtEnd)
            for i in 0..<c {
                cursor.insert((2 * i, String(2 * i)))
            }

            cursor.moveToStart()
            XCTAssertEqual(cursor.offset, 0)
            for i in 0..<c {
                XCTAssertEqual(cursor.key, 2 * i)
                XCTAssertEqual(cursor.offset, 2 * i)
                XCTAssertEqual(cursor.count, c + i)
                cursor.insertAfter((2 * i + 1, String(2 * i + 1)))
                XCTAssertEqual(cursor.key, 2 * i + 1)
                XCTAssertEqual(cursor.offset, 2 * i + 1)
                XCTAssertEqual(cursor.count, c + i + 1)
                cursor.moveForward()
            }
        }
        tree.assertValid()
        assertEqualElements(tree, (0 ..< 2 * c).map { ($0, String($0)) })
    }

    func testBuildingATreeBackward() {
        var tree = Tree(order: 5)
        let c = 30
        tree.withCursorAtStart() { cursor in
            XCTAssertTrue(cursor.isAtEnd)
            for i in stride(from: c - 1, through: 0, by: -1) {
                cursor.insert((i, String(i)))
                XCTAssertEqual(cursor.count, c - i)
                XCTAssertEqual(cursor.offset, 1)
                cursor.moveBackward()
                XCTAssertEqual(cursor.offset, 0)
                XCTAssertEqual(cursor.key, i)
            }
        }
        tree.assertValid()
        assertEqualElements(tree, (0 ..< c).map { ($0, String($0)) })
    }

    func testInsertAtEveryOffset() {
        let c = 100
        let reference = (0 ..< c).map { ($0, String($0)) }
        let tree = Tree(sortedElements: reference, order: 5)
        for i in 0 ... c {
            var test = tree
            test.withCursor(atOffset: i) { cursor in
                cursor.insert((i, "*\(i)"))
            }
            var expected = reference
            expected.insert((i, "*\(i)"), at: i)
            test.assertValid()
            assertEqualElements(test, expected)
            assertEqualElements(tree, reference)
        }
    }

    func testInsertSequence() {
        var tree = Tree(order: 3)
        tree.withCursorAtStart { cursor in
            cursor.insert((10 ..< 20).map { ($0, String($0)) })
            XCTAssertEqual(cursor.count, 10)
            XCTAssertEqual(cursor.offset, 10)

            cursor.insert([])
            XCTAssertEqual(cursor.count, 10)
            XCTAssertEqual(cursor.offset, 10)

            cursor.insert((20 ..< 30).map { ($0, String($0)) })
            XCTAssertEqual(cursor.count, 20)
            XCTAssertEqual(cursor.offset, 20)

            cursor.move(toOffset: 0)
            cursor.insert((0 ..< 5).map { ($0, String($0)) })
            XCTAssertEqual(cursor.count, 25)
            XCTAssertEqual(cursor.offset, 5)

            cursor.insert((5 ..< 9).map { ($0, String($0)) })
            XCTAssertEqual(cursor.count, 29)
            XCTAssertEqual(cursor.offset, 9)

            cursor.insert([(9, "9")])
            XCTAssertEqual(cursor.count, 30)
            XCTAssertEqual(cursor.offset, 10)
        }
        tree.assertValid()
        assertEqualElements(tree, (0 ..< 30).map { ($0, String($0)) })
    }

    func testRemoveAllElementsInOrder() {
        var tree = maximalTree(depth: 2, order: 5)
        tree.withCursorAtStart { cursor in
            var i = 0
            while cursor.count > 0 {
                let (key, value) = cursor.remove()
                XCTAssertEqual(key, i)
                XCTAssertEqual(value, String(i))
                XCTAssertEqual(cursor.offset, 0)
                i += 1
            }
        }
        tree.assertValid()
        assertEqualElements(tree, [])
    }

    func testRemoveEachElement() {
        let tree = maximalTree(depth: 2, order: 5)
        for i in 0..<tree.count {
            var copy = tree
            copy.withCursor(atOffset: i) { cursor in
                let removed = cursor.remove()
                XCTAssertEqual(removed.0, i)
                XCTAssertEqual(removed.1, String(i))
            }
            copy.assertValid()
            assertEqualElements(copy, (0..<tree.count).filter{$0 != i}.map{ ($0, String($0)) })
        }
    }

    func testRemoveRangeFromMaximalTree() {
        let tree = maximalTree(depth: 2, order: 3)
        let count = tree.count
        for i in 0 ..< count {
            for n in 0 ... count - i {
                var copy = tree
                copy.withCursor(atOffset: i) { cursor in
                    cursor.remove(n)
                }
                copy.assertValid()
                let keys = Array(0..<i) + Array(i + n ..< count)
                assertEqualElements(copy, keys.map { ($0, String($0)) })
            }
        }
        tree.assertValid()
        assertEqualElements(tree, (0..<count).map { ($0, String($0)) })
    }

    func testExtractRangeFromMaximalTree() {
        let tree = maximalTree(depth: 2, order: 3)
        let count = tree.count
        for i in 0 ..< count {
            for n in 0 ... count - i {
                var copy = tree
                copy.withCursor(atOffset: i) { cursor in
                    let extracted = cursor.extract(n)
                    extracted.assertValid()
                    assertEqualElements(extracted, (i ..< i + n).map { ($0, String($0)) })
                }
                copy.assertValid()
                let keys = Array(0..<i) + Array(i + n ..< count)
                assertEqualElements(copy, keys.map { ($0, String($0)) })
            }
        }
        tree.assertValid()
        assertEqualElements(tree, (0..<count).map { ($0, String($0)) })
    }

    func testRemoveAll() {
        var tree = maximalTree(depth: 2, order: 3)
        tree.withCursorAtStart { cursor in
            cursor.removeAll()
            XCTAssertEqual(cursor.count, 0)
            XCTAssertTrue(cursor.isAtEnd)
        }
        XCTAssertTrue(tree.isEmpty)
    }

    func testRemoveAllBefore() {
        var t1 = maximalTree(depth: 2, order: 3)
        let c = t1.count
        t1.withCursorAtEnd { cursor in
            cursor.removeAllBefore(includingCurrent: false)
        }
        XCTAssertTrue(t1.isEmpty)

        var t2 = maximalTree(depth: 2, order: 3)
        t2.withCursor(atOffset: c - 1) { cursor in
            cursor.removeAllBefore(includingCurrent: true)
        }
        XCTAssertTrue(t2.isEmpty)

        var t3 = maximalTree(depth: 2, order: 3)
        t3.withCursor(atOffset: c - 1) { cursor in
            cursor.removeAllBefore(includingCurrent: false)
        }
        assertEqualElements(t3, [(c - 1, String(c - 1))])

        var t4 = maximalTree(depth: 2, order: 3)
        t4.withCursor(atOffset: c - 10) { cursor in
            cursor.removeAllBefore(includingCurrent: true)
        }
        assertEqualElements(t4, (c - 9 ..< c).map { ($0, String($0)) })

        var t5 = maximalTree(depth: 2, order: 3)
        t5.withCursor(atOffset: c - 10) { cursor in
            cursor.removeAllBefore(includingCurrent: false)
        }
        assertEqualElements(t5, (c - 10 ..< c).map { ($0, String($0)) })

        var t6 = maximalTree(depth: 2, order: 3)
        t6.withCursorAtStart { cursor in
            cursor.removeAllBefore(includingCurrent: false)
        }
        assertEqualElements(t6, (0 ..< c).map { ($0, String($0)) })

        var t7 = maximalTree(depth: 2, order: 3)
        t7.withCursorAtStart { cursor in
            cursor.removeAllBefore(includingCurrent: true)
        }
        assertEqualElements(t7, (1 ..< c).map { ($0, String($0)) })
    }

    func testRemoveAllAfter() {
        var t1 = maximalTree(depth: 2, order: 3)
        t1.withCursorAtStart { cursor in
            cursor.removeAllAfter(includingCurrent: true)
        }
        XCTAssertTrue(t1.isEmpty)

        var t2 = maximalTree(depth: 2, order: 3)
        t2.withCursorAtStart { cursor in
            cursor.removeAllAfter(includingCurrent: false)
        }
        assertEqualElements(t2, [(0, "0")])

        var t3 = maximalTree(depth: 2, order: 3)
        t3.withCursor(atOffset: 1) { cursor in
            cursor.removeAllAfter(includingCurrent: true)
        }
        assertEqualElements(t3, [(0, "0")])

        var t4 = maximalTree(depth: 2, order: 3)
        t4.withCursor(atOffset: 1) { cursor in
            cursor.removeAllAfter(includingCurrent: false)
        }
        assertEqualElements(t4, [(0, "0"), (1, "1")])

        var t5 = maximalTree(depth: 2, order: 3)
        t5.withCursor(atOffset: 10) { cursor in
            cursor.removeAllAfter(includingCurrent: true)
        }
        assertEqualElements(t5, (0 ..< 10).map { ($0, String($0)) })

        var t6 = maximalTree(depth: 2, order: 3)
        t6.withCursor(atOffset: 10) { cursor in
            cursor.removeAllAfter(includingCurrent: false)
        }
        assertEqualElements(t6, (0 ... 10).map { ($0, String($0)) })

        var t7 = maximalTree(depth: 2, order: 3)
        let c = t7.count
        t7.withCursor(atOffset: c - 1) { cursor in
            cursor.removeAllAfter(includingCurrent: false)
        }
        assertEqualElements(t7, (0 ..< c).map { ($0, String($0)) })

        var t8 = maximalTree(depth: 2, order: 3)
        t8.withCursorAtEnd { cursor in
            cursor.removeAllAfter(includingCurrent: false)
        }
        assertEqualElements(t8, maximalTree(depth: 2, order: 3))

    }

}
