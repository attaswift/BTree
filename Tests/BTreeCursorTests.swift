//
//  BTreeCursorTests.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-19.
//  Copyright © 2015–2016 Károly Lőrentey.
//

import Foundation
import XCTest
@testable import BTree

class BTreeCursorTests: XCTestCase {
    typealias Tree = BTree<Int, String>

    func testCursorWithEmptyTree() {
        func checkEmpty(cursor: BTreeCursor<Int, String>) {
            XCTAssertTrue(cursor.isValid)
            XCTAssertTrue(cursor.isAtStart)
            XCTAssertTrue(cursor.isAtEnd)
            XCTAssertEqual(cursor.count, 0)
            let tree = cursor.finish()
            XCTAssertElementsEqual(tree, [])
        }

        var tree = Tree()
        tree.withCursorAtStart(checkEmpty)
        tree.withCursorAtEnd(checkEmpty)
        tree.withCursorAtPosition(0, body: checkEmpty)
        tree.withCursorAt(42, choosing: .First, body: checkEmpty)
        tree.withCursorAt(42, choosing: .Last, body: checkEmpty)
        tree.withCursorAt(42, choosing: .Any, body: checkEmpty)
    }

    func testCursorAtStart() {
        var tree = maximalTree(depth: 2, order: 5)
        tree.withCursorAtStart { cursor in
            XCTAssertTrue(cursor.isAtStart)
            XCTAssertFalse(cursor.isAtEnd)
            XCTAssertEqual(cursor.position, 0)
            XCTAssertEqual(cursor.key, 0)
            XCTAssertEqual(cursor.payload, "0")
        }
    }

    func testCursorAtEnd() {
        var tree = maximalTree(depth: 2, order: 5)
        let count = tree.count
        tree.withCursorAtEnd { cursor in
            XCTAssertFalse(cursor.isAtStart)
            XCTAssertTrue(cursor.isAtEnd)
            XCTAssertEqual(cursor.position, count)
        }
    }

    func testCursorAtPosition() {
        var tree = maximalTree(depth: 3, order: 4)
        let c = tree.count
        for p in 0 ..< c {
            tree.withCursorAtPosition(p) { cursor in
                XCTAssertEqual(cursor.position, p)
                XCTAssertEqual(cursor.key, p)
                XCTAssertEqual(cursor.payload, String(p))
            }
        }
        tree.withCursorAtPosition(c) { cursor in
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
            tree.withCursorAt(2 * i + 1, choosing: .First) { cursor in
                XCTAssertEqual(cursor.position, 3 * (i + 1))
            }
            tree.withCursorAt(2 * i, choosing: .First) { cursor in
                XCTAssertEqual(cursor.position, 3 * i)
                XCTAssertEqual(cursor.key, 2 * i)
                XCTAssertEqual(cursor.payload, String(2 * i) + "/1")
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
            tree.withCursorAt(2 * i + 1, choosing: .Last) { cursor in
                XCTAssertEqual(cursor.position, 3 * (i + 1))
            }
            tree.withCursorAt(2 * i, choosing: .Last) { cursor in
                XCTAssertEqual(cursor.position, 3 * i + 2)
                XCTAssertEqual(cursor.key, 2 * i)
                XCTAssertEqual(cursor.payload, String(2 * i) + "/3")
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
            tree.withCursorAt(2 * i + 1) { cursor in
                XCTAssertEqual(cursor.position, 3 * (i + 1))
            }
            tree.withCursorAt(2 * i) { cursor in
                XCTAssertGreaterThanOrEqual(cursor.position, 3 * i)
                XCTAssertLessThan(cursor.position, 3 * (i + 1))
                XCTAssertEqual(cursor.key, 2 * i)
                XCTAssertTrue(cursor.payload.hasPrefix(String(2 * i) + "/"), cursor.payload)
            }
        }
    }

    func testCursorAtIndex() {
        var tree = maximalTree(depth: 3, order: 3)
        let count = tree.count
        for i in 0 ... count {
            let index = tree.startIndex.advancedBy(i)
            tree.withCursorAt(index) { cursor in
                XCTAssertEqual(cursor.position, i)
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
                XCTAssertEqual(cursor.position, i)
                XCTAssertEqual(cursor.key, i)
                XCTAssertEqual(cursor.payload, String(i))
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
                XCTAssertEqual(cursor.position, i)
                cursor.moveBackward()
                i -= 1
                XCTAssertEqual(cursor.key, i)
                XCTAssertEqual(cursor.payload, String(i))
            }
            XCTAssertEqual(i, 0)
        }
    }

    func testMoveToEnd() {
        var tree = maximalTree(depth: 2, order: 5)
        let c = tree.count
        for i in 0 ... c {
            tree.withCursorAtPosition(i) { cursor in
                cursor.moveToEnd()
                XCTAssertTrue(cursor.isAtEnd)
                XCTAssertEqual(cursor.position, c)
            }
        }
    }
    
    func testMoveToPosition() {
        var tree = maximalTree(depth: 2, order: 5)
        tree.withCursorAtStart { cursor in
            var i = 0
            var j = cursor.count - 1
            var toggle = false
            while i < j {
                if toggle {
                    cursor.move(toPosition: i)
                    XCTAssertEqual(cursor.position, i)
                    XCTAssertEqual(cursor.key, i)
                    i += 1
                    toggle = false
                }
                else {
                    cursor.move(toPosition: j)
                    XCTAssertEqual(cursor.position, j)
                    XCTAssertEqual(cursor.key, j)
                    j -= 1
                    toggle = true
                }
            }
            cursor.move(toPosition: cursor.count)
            XCTAssertTrue(cursor.isAtEnd)
            cursor.moveBackward()
            XCTAssertEqual(cursor.key, cursor.count - 1)
        }
    }

    func testMoveToKey() {
        let count = 42
        var tree = BTree(elements: (0..<count).map { (2 * $0, String(2 * $0)) }, order: 3)
        tree.withCursorAtStart() { cursor in
            var start = 0
            var end = count - 1
            while start < end {
                cursor.move(to: 2 * end)
                XCTAssertEqual(cursor.position, end)
                XCTAssertEqual(cursor.key, 2 * end)

                cursor.move(to: 2 * start + 1)
                XCTAssertEqual(cursor.position, start + 1)
                XCTAssertEqual(cursor.key, 2 * start + 2)

                start += 1
                end -= 1
            }

            start = 0
            end = count - 1
            while start < end {
                cursor.move(to: 2 * end - 1)
                XCTAssertEqual(cursor.position, end)
                XCTAssertEqual(cursor.key, 2 * end)

                cursor.move(to: 2 * start)
                XCTAssertEqual(cursor.position, start)
                XCTAssertEqual(cursor.key, 2 * start)

                start += 1
                end -= 1
            }
        }
    }

    func testUpdatingData() {
        var tree = maximalTree(depth: 2, order: 5)
        tree.withCursorAtStart { cursor in
            while !cursor.isAtEnd {
                cursor.key = 2 * cursor.key
                cursor.payload = String(cursor.key)
                cursor.moveForward()
            }
            let tree = cursor.finish()
            tree.assertValid()
            var i = 0
            for (key, payload) in tree {
                XCTAssertEqual(key, 2 * i)
                XCTAssertEqual(payload, String(2 * i))
                i += 1
            }
        }
    }

    func testSetPayload() {
        var tree = maximalTree(depth: 2, order: 5)
        tree.withCursorAtStart { cursor in
            var i = 0
            while !cursor.isAtEnd {
                XCTAssertEqual(cursor.setPayload("Hello"), String(i))
                cursor.moveForward()
                i += 1
            }
        }
        tree.assertValid()
        for (_, payload) in tree {
            XCTAssertEqual(payload, "Hello")
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
        XCTAssertElementsEqual(tree, (0..<30).map { ($0, String($0)) })
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
            XCTAssertEqual(cursor.position, 0)
            for i in 0..<c {
                XCTAssertEqual(cursor.key, 2 * i + 1)
                XCTAssertEqual(cursor.position, 2 * i)
                XCTAssertEqual(cursor.count, c + i)
                cursor.insert((2 * i, String(2 * i)))
                XCTAssertEqual(cursor.key, 2 * i + 1)
                XCTAssertEqual(cursor.position, 2 * i + 1)
                XCTAssertEqual(cursor.count, c + i + 1)
                cursor.moveForward()
            }
        }
        tree.assertValid()
        XCTAssertElementsEqual(tree, (0 ..< 2 * c).map { ($0, String($0)) })
    }

    func testBuildingATreeUsingInsertAfter() {
        var tree = Tree(order: 5)
        let c = 30
        tree.withCursorAtStart() { cursor in
            cursor.insert((0, "0"))
            cursor.moveToStart()
            for i in 1 ..< c {
                cursor.insertAfter((i, String(i)))
                XCTAssertEqual(cursor.position, i)
                XCTAssertEqual(cursor.key, i)
            }
        }
        tree.assertValid()
        XCTAssertElementsEqual(tree, (0..<30).map { ($0, String($0)) })
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
            XCTAssertEqual(cursor.position, 0)
            for i in 0..<c {
                XCTAssertEqual(cursor.key, 2 * i)
                XCTAssertEqual(cursor.position, 2 * i)
                XCTAssertEqual(cursor.count, c + i)
                cursor.insertAfter((2 * i + 1, String(2 * i + 1)))
                XCTAssertEqual(cursor.key, 2 * i + 1)
                XCTAssertEqual(cursor.position, 2 * i + 1)
                XCTAssertEqual(cursor.count, c + i + 1)
                cursor.moveForward()
            }
        }
        tree.assertValid()
        XCTAssertElementsEqual(tree, (0 ..< 2 * c).map { ($0, String($0)) })
    }

    func testBuildingATreeBackward() {
        var tree = Tree(order: 5)
        let c = 30
        tree.withCursorAtStart() { cursor in
            XCTAssertTrue(cursor.isAtEnd)
            for i in (c - 1).stride(through: 0, by: -1) {
                cursor.insert((i, String(i)))
                XCTAssertEqual(cursor.count, c - i)
                XCTAssertEqual(cursor.position, 1)
                cursor.moveBackward()
                XCTAssertEqual(cursor.position, 0)
                XCTAssertEqual(cursor.key, i)
            }
        }
        tree.assertValid()
        XCTAssertElementsEqual(tree, (0 ..< c).map { ($0, String($0)) })
    }


    func testInsertSequence() {
        var tree = Tree(order: 3)
        tree.withCursorAtStart { cursor in
            cursor.insert((10 ..< 20).map { ($0, String($0)) })
            XCTAssertEqual(cursor.count, 10)
            XCTAssertEqual(cursor.position, 10)

            cursor.insert([])
            XCTAssertEqual(cursor.count, 10)
            XCTAssertEqual(cursor.position, 10)

            cursor.insert((20 ..< 30).map { ($0, String($0)) })
            XCTAssertEqual(cursor.count, 20)
            XCTAssertEqual(cursor.position, 20)

            cursor.move(toPosition: 0)
            cursor.insert((0 ..< 5).map { ($0, String($0)) })
            XCTAssertEqual(cursor.count, 25)
            XCTAssertEqual(cursor.position, 5)

            cursor.insert((5 ..< 9).map { ($0, String($0)) })
            XCTAssertEqual(cursor.count, 29)
            XCTAssertEqual(cursor.position, 9)

            cursor.insert([(9, "9")])
            XCTAssertEqual(cursor.count, 30)
            XCTAssertEqual(cursor.position, 10)
        }
        tree.assertValid()
        XCTAssertElementsEqual(tree, (0 ..< 30).map { ($0, String($0)) })
    }

    func testRemoveAllElementsInOrder() {
        var tree = maximalTree(depth: 2, order: 5)
        tree.withCursorAtStart { cursor in
            var i = 0
            while cursor.count > 0 {
                let (key, payload) = cursor.remove()
                XCTAssertEqual(key, i)
                XCTAssertEqual(payload, String(i))
                XCTAssertEqual(cursor.position, 0)
                i += 1
            }
        }
        tree.assertValid()
        XCTAssertElementsEqual(tree, [])
    }

    func testRemoveEachElement() {
        let tree = maximalTree(depth: 2, order: 5)
        for i in 0..<tree.count {
            var copy = tree
            copy.withCursorAtPosition(i) { cursor in
                let removed = cursor.remove()
                XCTAssertEqual(removed.0, i)
                XCTAssertEqual(removed.1, String(i))
            }
            copy.assertValid()
            XCTAssertElementsEqual(copy, (0..<tree.count).filter{$0 != i}.map{ ($0, String($0)) })
        }
    }

    func testRemoveRangeFromMaximalTree() {
        let tree = maximalTree(depth: 2, order: 3)
        let count = tree.count
        for i in 0 ..< count {
            for n in 0 ... count - i {
                var copy = tree
                copy.withCursorAtPosition(i) { cursor in
                    cursor.remove(n)
                }
                copy.assertValid()
                let keys = Array(0..<i) + Array(i + n ..< count)
                XCTAssertElementsEqual(copy, keys.map { ($0, String($0)) })
            }
        }
        tree.assertValid()
        XCTAssertElementsEqual(tree, (0..<count).map { ($0, String($0)) })
    }

    func testExtractRangeFromMaximalTree() {
        let tree = maximalTree(depth: 2, order: 3)
        let count = tree.count
        for i in 0 ..< count {
            for n in 0 ... count - i {
                var copy = tree
                copy.withCursorAtPosition(i) { cursor in
                    let extracted = cursor.extract(n)
                    extracted.assertValid()
                    XCTAssertElementsEqual(extracted, (i ..< i + n).map { ($0, String($0)) })
                }
                copy.assertValid()
                let keys = Array(0..<i) + Array(i + n ..< count)
                XCTAssertElementsEqual(copy, keys.map { ($0, String($0)) })
            }
        }
        tree.assertValid()
        XCTAssertElementsEqual(tree, (0..<count).map { ($0, String($0)) })
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
        t2.withCursorAtPosition(c - 1) { cursor in
            cursor.removeAllBefore(includingCurrent: true)
        }
        XCTAssertTrue(t2.isEmpty)

        var t3 = maximalTree(depth: 2, order: 3)
        t3.withCursorAtPosition(c - 1) { cursor in
            cursor.removeAllBefore(includingCurrent: false)
        }
        XCTAssertElementsEqual(t3, [(c - 1, String(c - 1))])

        var t4 = maximalTree(depth: 2, order: 3)
        t4.withCursorAtPosition(c - 10) { cursor in
            cursor.removeAllBefore(includingCurrent: true)
        }
        XCTAssertElementsEqual(t4, (c - 9 ..< c).map { ($0, String($0)) })

        var t5 = maximalTree(depth: 2, order: 3)
        t5.withCursorAtPosition(c - 10) { cursor in
            cursor.removeAllBefore(includingCurrent: false)
        }
        XCTAssertElementsEqual(t5, (c - 10 ..< c).map { ($0, String($0)) })

        var t6 = maximalTree(depth: 2, order: 3)
        t6.withCursorAtStart { cursor in
            cursor.removeAllBefore(includingCurrent: false)
        }
        XCTAssertElementsEqual(t6, (0 ..< c).map { ($0, String($0)) })

        var t7 = maximalTree(depth: 2, order: 3)
        t7.withCursorAtStart { cursor in
            cursor.removeAllBefore(includingCurrent: true)
        }
        XCTAssertElementsEqual(t7, (1 ..< c).map { ($0, String($0)) })
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
        XCTAssertElementsEqual(t2, [(0, "0")])

        var t3 = maximalTree(depth: 2, order: 3)
        t3.withCursorAtPosition(1) { cursor in
            cursor.removeAllAfter(includingCurrent: true)
        }
        XCTAssertElementsEqual(t3, [(0, "0")])

        var t4 = maximalTree(depth: 2, order: 3)
        t4.withCursorAtPosition(1) { cursor in
            cursor.removeAllAfter(includingCurrent: false)
        }
        XCTAssertElementsEqual(t4, [(0, "0"), (1, "1")])

        var t5 = maximalTree(depth: 2, order: 3)
        t5.withCursorAtPosition(10) { cursor in
            cursor.removeAllAfter(includingCurrent: true)
        }
        XCTAssertElementsEqual(t5, (0 ..< 10).map { ($0, String($0)) })

        var t6 = maximalTree(depth: 2, order: 3)
        t6.withCursorAtPosition(10) { cursor in
            cursor.removeAllAfter(includingCurrent: false)
        }
        XCTAssertElementsEqual(t6, (0 ... 10).map { ($0, String($0)) })

        var t7 = maximalTree(depth: 2, order: 3)
        let c = t7.count
        t7.withCursorAtPosition(c - 1) { cursor in
            cursor.removeAllAfter(includingCurrent: false)
        }
        XCTAssertElementsEqual(t7, (0 ..< c).map { ($0, String($0)) })
    }

}