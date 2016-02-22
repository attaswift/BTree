//
//  BTreeCursorTests.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2016-02-19.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import Foundation
import XCTest
@testable import TreeCollections

class BTreeCursorTests: XCTestCase {
    typealias Tree = BTree<Int, String>

    func testCursorInitWithEmptyTree() {
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

    func testCursorInitAtStart() {
        var tree = maximalTree(depth: 2, order: 5)
        tree.withCursorAtStart { cursor in
            XCTAssertTrue(cursor.isAtStart)
            XCTAssertFalse(cursor.isAtEnd)
            XCTAssertEqual(cursor.position, 0)
            XCTAssertEqual(cursor.key, 0)
            XCTAssertEqual(cursor.payload, "0")
        }
    }

    func testCursorInitAtEnd() {
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

    func testCursorMoveForward() {
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

    func testCursorMoveBackward() {
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

    func testCursorMoveToPosition() {
        var tree = maximalTree(depth: 2, order: 5)
        tree.withCursorAtStart { cursor in
            var i = 0
            var j = cursor.count - 1
            var toggle = false
            while i < j {
                if toggle {
                    cursor.moveToPosition(i)
                    XCTAssertEqual(cursor.position, i)
                    XCTAssertEqual(cursor.key, i)
                    i += 1
                    toggle = false
                }
                else {
                    cursor.moveToPosition(j)
                    XCTAssertEqual(cursor.position, j)
                    XCTAssertEqual(cursor.key, j)
                    j -= 1
                    toggle = true
                }
            }
            cursor.moveToPosition(cursor.count)
            XCTAssertTrue(cursor.isAtEnd)
            cursor.moveBackward()
            XCTAssertEqual(cursor.key, cursor.count - 1)
        }
    }

    func testCursorUpdatingData() {
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

    func testCursorSetPayload() {
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

    func testCursorBuildingATreeUsingInsertBefore() {
        var tree = Tree(order: 3)
        tree.withCursorAtEnd { cursor in
            XCTAssertTrue(cursor.isAtEnd)
            for i in 0..<30 {
                cursor.insertBefore((i, String(i)))
                XCTAssertTrue(cursor.isAtEnd)
            }
        }
        tree.assertValid()
        XCTAssertElementsEqual(tree, (0..<30).map { ($0, String($0)) })
    }

    func testCursorBuildingATreeInTwoPassesUsingInsertBefore() {
        var tree = Tree(order: 5)
        let c = 30
        tree.withCursorAtStart() { cursor in
            XCTAssertTrue(cursor.isAtEnd)
            for i in 0..<c {
                cursor.insertBefore((2 * i + 1, String(2 * i + 1)))
                XCTAssertTrue(cursor.isAtEnd)
            }

            cursor.moveToStart()
            XCTAssertEqual(cursor.position, 0)
            for i in 0..<c {
                XCTAssertEqual(cursor.key, 2 * i + 1)
                XCTAssertEqual(cursor.position, 2 * i)
                XCTAssertEqual(cursor.count, c + i)
                cursor.insertBefore((2 * i, String(2 * i)))
                XCTAssertEqual(cursor.key, 2 * i + 1)
                XCTAssertEqual(cursor.position, 2 * i + 1)
                XCTAssertEqual(cursor.count, c + i + 1)
                cursor.moveForward()
            }
        }
        tree.assertValid()
        XCTAssertElementsEqual(tree, (0 ..< 2 * c).map { ($0, String($0)) })
    }

    func testCursorBuildingATreeUsingInsertAfter() {
        var tree = Tree(order: 5)
        let c = 30
        tree.withCursorAtStart() { cursor in
            cursor.insertBefore((0, "0"))
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

    func testCursorBuildingATreeInTwoPassesUsingInsertAfter() {
        var tree = Tree(order: 5)
        let c = 30
        tree.withCursorAtStart() { cursor in
            XCTAssertTrue(cursor.isAtEnd)
            for i in 0..<c {
                cursor.insertBefore((2 * i, String(2 * i)))
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

    func testCursorBuildingATreeBackward() {
        var tree = Tree(order: 5)
        let c = 30
        tree.withCursorAtStart() { cursor in
            XCTAssertTrue(cursor.isAtEnd)
            for i in (c - 1).stride(through: 0, by: -1) {
                cursor.insertBefore((i, String(i)))
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

    func testCursorRemoveRangeFromMaximalTree() {
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

    func testCursorExtractRangeFromMaximalTree() {
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

    func testCursorInsertSequence() {
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

            cursor.moveToPosition(0)
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
}