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

    func testEmptyTree() {
        let tree = BTree<Int, String>()
        XCTAssertTrue(tree.isEmpty)
        XCTAssertEqual(tree.count, 0)
        XCTAssertEqual(tree, [])
    }

    func testInsertingASingleKey() {
        var tree = BTree<Int, String>()
        tree.insert(1, "One")
        XCTAssertFalse(tree.isEmpty)
        XCTAssertEqual(tree.count, 1)
        XCTAssertEqual(tree, [(1, "One")])
    }

    func testRemovingTheSingleKey() {
        var tree = BTree<Int, String>()
        tree.insert(1, "One")
        XCTAssertEqual(tree.remove(1), "One")

        XCTAssertTrue(tree.isEmpty)
        XCTAssertEqual(tree.count, 0)
        XCTAssertEqual(tree, [])
    }

    func testInsertingTwoKeys() {
        var tree = BTree<Int, String>()
        tree.insert(1, "One")
        tree.insert(2, "Two")

        XCTAssertFalse(tree.isEmpty)
        XCTAssertEqual(tree.count, 2)
        XCTAssertEqual(tree, [(1, "One"), (2, "Two")])
    }
}