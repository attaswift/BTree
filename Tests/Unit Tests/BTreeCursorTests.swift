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
    typealias Node = BTreeNode<Int, String>

    func testCursorInitWithEmptyTree() {
        func checkEmpty(cursor: BTreeCursor<Int, String>) {
            XCTAssertTrue(cursor.isValid)
            XCTAssertTrue(cursor.isAtStart)
            XCTAssertTrue(cursor.isAtEnd)
            XCTAssertEqual(cursor.count, 0)
            let tree = cursor.finish()
            XCTAssertElementsEqual(tree, [])
        }

        checkEmpty(BTreeCursor())
        checkEmpty(BTreeCursor(startOf: Node(order: 3)))
        checkEmpty(BTreeCursor(endOf: Node(order: 3)))
        checkEmpty(BTreeCursor(root: Node(order: 3), position: 0))
        checkEmpty(BTreeCursor(root: Node(order: 3), key: 42))

    }

    func testCursorInitAtStart() {
        let tree = maximalTreeOfDepth(2, order: 5)
        let cursor = BTreeCursor(startOf: tree)
        XCTAssertTrue(cursor.isAtStart)
        XCTAssertFalse(cursor.isAtEnd)
        XCTAssertEqual(cursor.position, 0)
        XCTAssertEqual(cursor.key, 0)
        XCTAssertEqual(cursor.payload, "0")
    }

    func testCursorInitAtEnd() {
        let tree = maximalTreeOfDepth(2, order: 5)
        let cursor = BTreeCursor(endOf: tree)
        XCTAssertFalse(cursor.isAtStart)
        XCTAssertTrue(cursor.isAtEnd)
        XCTAssertEqual(cursor.position, tree.count)
    }

    func testCursorInitAtPosition() {
        let tree = maximalTreeOfDepth(2, order: 5)
        let count = tree.count
        for i in 0..<count {
            let cursor = BTreeCursor(root: tree, position: i)
            XCTAssertEqual(cursor.key, i)
            XCTAssertEqual(cursor.payload, String(i))
        }
        XCTAssertTrue(BTreeCursor(root: tree, position: count).isAtEnd)
    }

    func testCursorInitAtKey() {
        let tree = Node(order: 3)
        (0...30).map { 2 * $0 }.forEach { tree.insert(String($0), at: $0) }

        for i in 0...60 {
            let cursor = BTreeCursor(root: tree, key: i)
            let expectedKey = (i + 1) & ~1
            XCTAssertEqual(cursor.key, expectedKey)
            XCTAssertEqual(cursor.payload, String(expectedKey))
        }
        XCTAssertTrue(BTreeCursor(root: tree, key: 61).isAtEnd)
    }

    func testCursorMoveForward() {
        let cursor = BTreeCursor(startOf: maximalTreeOfDepth(2, order: 5))
        var i = 0
        while !cursor.isAtEnd {
            XCTAssertEqual(cursor.key, i)
            XCTAssertEqual(cursor.payload, String(i))
            cursor.moveForward()
            i += 1
        }
        let tree = cursor.finish()
        XCTAssertEqual(i, tree.count)
    }

    func testCursorMoveBackward() {
        let cursor = BTreeCursor(endOf: maximalTreeOfDepth(2, order: 5))
        var i = cursor.count
        while !cursor.isAtStart {
            cursor.moveBackward()
            i -= 1
            XCTAssertEqual(cursor.key, i)
            XCTAssertEqual(cursor.payload, String(i))
        }
        XCTAssertEqual(i, 0)
    }

    func testCursorMoveToPosition() {
        let cursor = BTreeCursor(startOf: maximalTreeOfDepth(2, order: 5))
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

    func testCursorUpdatingData() {
        let cursor = BTreeCursor(startOf: maximalTreeOfDepth(2, order: 5))
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

    func testCursorSetPayload() {
        let cursor = BTreeCursor(startOf: maximalTreeOfDepth(2, order: 5))
        var i = 0
        while !cursor.isAtEnd {
            XCTAssertEqual(cursor.setPayload("Hello"), String(i))
            cursor.moveForward()
            i += 1
        }
        let tree = cursor.finish()
        tree.assertValid()
        for (_, payload) in tree {
            XCTAssertEqual(payload, "Hello")
        }
    }

    func testCursorBuildingATreeUsingInsertBefore() {
        let cursor = BTreeCursor(startOf: Node(order: 5))
        XCTAssertTrue(cursor.isAtEnd)
        for i in 0..<30 {
            cursor.insertBefore(i, String(i))
            XCTAssertTrue(cursor.isAtEnd)
        }
        let tree = cursor.finish()
        tree.assertValid()
        XCTAssertElementsEqual(tree, (0..<30).map { ($0, String($0)) })
    }

    func testCursorBuildingATreeInTwoPassesUsingInsertBefore() {
        let cursor = BTreeCursor(startOf: Node(order: 5))
        XCTAssertTrue(cursor.isAtEnd)
        let c = 30
        for i in 0..<c {
            cursor.insertBefore(2 * i + 1, String(2 * i + 1))
            XCTAssertTrue(cursor.isAtEnd)
        }

        cursor.moveToStart()
        XCTAssertEqual(cursor.position, 0)
        for i in 0..<c {
            XCTAssertEqual(cursor.key, 2 * i + 1)
            XCTAssertEqual(cursor.position, 2 * i)
            XCTAssertEqual(cursor.count, c + i)
            cursor.insertBefore(2 * i, String(2 * i))
            XCTAssertEqual(cursor.key, 2 * i + 1)
            XCTAssertEqual(cursor.position, 2 * i + 1)
            XCTAssertEqual(cursor.count, c + i + 1)
            cursor.moveForward()
        }

        let tree = cursor.finish()
        tree.assertValid()
        XCTAssertElementsEqual(tree, (0 ..< 2 * c).map { ($0, String($0)) })
    }

    func testCursorBuildingATreeUsingInsertAfter() {
        let cursor = BTreeCursor<Int, String>(startOf: Node(order: 5))
        cursor.insertBefore(0, "0")
        cursor.moveToStart()
        let c = 30
        for i in 1 ..< c {
            cursor.insertAfter(i, String(i))
            XCTAssertEqual(cursor.position, i)
            XCTAssertEqual(cursor.key, i)
        }
        let tree = cursor.finish()
        tree.assertValid()
        XCTAssertElementsEqual(tree, (0..<30).map { ($0, String($0)) })
    }

    func testCursorBuildingATreeInTwoPassesUsingInsertAfter() {
        let cursor = BTreeCursor(startOf: Node(order: 5))
        XCTAssertTrue(cursor.isAtEnd)
        let c = 30
        for i in 0..<c {
            cursor.insertBefore(2 * i, String(2 * i))
        }

        cursor.moveToStart()
        XCTAssertEqual(cursor.position, 0)
        for i in 0..<c {
            XCTAssertEqual(cursor.key, 2 * i)
            XCTAssertEqual(cursor.position, 2 * i)
            XCTAssertEqual(cursor.count, c + i)
            cursor.insertAfter(2 * i + 1, String(2 * i + 1))
            XCTAssertEqual(cursor.key, 2 * i + 1)
            XCTAssertEqual(cursor.position, 2 * i + 1)
            XCTAssertEqual(cursor.count, c + i + 1)
            cursor.moveForward()
        }

        let tree = cursor.finish()
        tree.assertValid()
        XCTAssertElementsEqual(tree, (0 ..< 2 * c).map { ($0, String($0)) })
    }

    func testCursorBuildingATreeBackward() {
        let cursor = BTreeCursor(startOf: Node(order: 5))
        XCTAssertTrue(cursor.isAtEnd)
        let c = 30
        for i in (c - 1).stride(through: 0, by: -1) {
            cursor.insertBefore(i, String(i))
            XCTAssertEqual(cursor.count, c - i)
            XCTAssertEqual(cursor.position, 1)
            cursor.moveBackward()
            XCTAssertEqual(cursor.position, 0)
            XCTAssertEqual(cursor.key, i)
        }
    }

    func testRemoveAllElementsInOrder() {
        let cursor = BTreeCursor(startOf: maximalTreeOfDepth(2, order: 5))
        var i = 0
        while cursor.count > 0 {
            let (key, payload) = cursor.remove()
            XCTAssertEqual(key, i)
            XCTAssertEqual(payload, String(i))
            XCTAssertEqual(cursor.position, 0)
            i += 1
        }
    }

    func testRemoveEachElement() {
        let tree = maximalTreeOfDepth(2, order: 5)
        for i in 0..<tree.count {
            let cursor = BTreeCursor(root: tree, position: i)
            let removed = cursor.remove()
            XCTAssertEqual(removed.0, i)
            XCTAssertEqual(removed.1, String(i))
            let newTree = cursor.finish()
            newTree.assertValid()
            XCTAssertElementsEqual(newTree, (0..<tree.count).filter{$0 != i}.map{ ($0, String($0)) })
        }
    }

    func testCursorRemoveRangeFromMaximalTree() {
        let tree = maximalTreeOfDepth(3, order: 3)
        let count = tree.count
        for i in 0 ..< count {
            for n in 0 ... count - i {
                let cursor = BTreeCursor(root: tree, position: i)
                cursor.remove(n)
                let t = cursor.finish()
                t.assertValid()
                let keys = Array(0..<i) + Array(i + n ..< count)
                XCTAssertElementsEqual(t, keys.map { ($0, String($0)) })
            }
        }
        tree.assertValid()
        XCTAssertElementsEqual(tree, (0..<count).map { ($0, String($0)) })
    }

    func testCursorInsertSequence() {
        let cursor = BTreeCursor(startOf: Node(order: 3))
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

        let tree = cursor.finish()
        tree.assertValid()
        XCTAssertElementsEqual(tree, (0 ..< 30).map { ($0, String($0)) })
    }
}