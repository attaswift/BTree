//
//  BinaryTreeTests.swift
//  TreeCollectionsTests
//
//  Created by Károly Lőrentey on 2015-12-14.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import TreeCollections

class BinaryTreeTests: XCTestCase {
    
    func testEmptyTree() {
        let tree = BinaryTree<Int>()
        XCTAssertEqual(tree.count, 0)
        XCTAssertNil(tree.root)
        XCTAssertEqual(tree.dump(), "")
    }

    func testInsertingARootNode() {
        var tree = BinaryTree<Int>()
        let index: Index = tree.insert(42, into: .Root)
        XCTAssertEqual(tree.count, 1)
        XCTAssertEqual(tree.root, index)

        XCTAssert(tree.checkInvariants())
        XCTAssertEqual(tree.dump(), "(42)")
    }

    func testInsertingALeftChildNode() {
        var tree = BinaryTree<Int>()
        let root: Index = tree.insert(42, into: .Root)
        let index = tree.insert(23, into: .Toward(.Left, under: root))
        XCTAssertEqual(tree[root].payload, 42)
        XCTAssertEqual(tree[index].payload, 23)

        XCTAssert(tree.checkInvariants())
        XCTAssertEqual(tree.dump(), "((23) 42)")
    }

    func testInsertingARightChildNode() {
        var tree = BinaryTree<Int>()
        let root: Index = tree.insert(42, into: .Root)
        let index = tree.insert(23, into: .Toward(.Right, under: root))
        XCTAssertEqual(tree[root].payload, 42)
        XCTAssertEqual(tree[index].payload, 23)

        XCTAssert(tree.checkInvariants())
        XCTAssertEqual(tree.dump(), "(42 (23))")
    }

    func testBuildingASearchTree() {
        var tree = BinaryTree<Int>()
        let i4 = tree.insert(4, into: .Root)

        let i2 = tree.insert(2, into: .Toward(.Left, under: i4))
        let i1 = tree.insert(1, into: .Toward(.Left, under: i2))
        let i3 = tree.insert(3, into: .Toward(.Right, under: i2))

        let i6 = tree.insert(6, into: .Toward(.Right, under: i4))
        let i5 = tree.insert(5, into: .Toward(.Left, under: i6))
        let i7 = tree.insert(7, into: .Toward(.Right, under: i6))

        XCTAssertEqual(tree.count, 7)

        XCTAssertEqual(tree[i1].payload, 1)
        XCTAssertEqual(tree[i2].payload, 2)
        XCTAssertEqual(tree[i3].payload, 3)
        XCTAssertEqual(tree[i4].payload, 4)
        XCTAssertEqual(tree[i5].payload, 5)
        XCTAssertEqual(tree[i6].payload, 6)
        XCTAssertEqual(tree[i7].payload, 7)

        XCTAssert(tree.checkInvariants())
        XCTAssertEqual(tree.dump(), "(((1) 2 (3)) 4 ((5) 6 (7)))")
    }

    func testRemovingRoot() {
        var tree = BinaryTree<Int>()
        let root = tree.insert(10, into: .Root)
        let slot = tree.remove(root)

        XCTAssertEqual(slot, Slot.Root)
        XCTAssertEqual(tree.count, 0)
        XCTAssertEqual(tree.root, nil)
    }

    func testRemovingNodes() {
        var tree = BinaryTree<Int>()

        // Insert elements 1...7 into a search tree.
        let i4 = tree.insert(4, into: .Root)
        let i2 = tree.insert(2, into: .Toward(.Left, under: i4))
        tree.insert(1, into: .Toward(.Left, under: i2))
        tree.insert(3, into: .Toward(.Right, under: i2))
        let i6 = tree.insert(6, into: .Toward(.Right, under: i4))
        let i5 = tree.insert(5, into: .Toward(.Left, under: i6))
        tree.insert(7, into: .Toward(.Right, under: i6))

        XCTAssert(tree.checkInvariants())
        XCTAssertEqual(tree.dump(), "(((1) 2 (3)) 4 ((5) 6 (7)))")

        // Remove 5 (root.right.left)
        var slot = tree.remove(i5)
        XCTAssertEqual(slot, Slot.Toward(.Left, under: tree.lookup(.Right)!))
        XCTAssert(tree.checkInvariants())
        XCTAssertEqual(tree.dump(), "(((1) 2 (3)) 4 (6 (7)))")

        // Remove 6 (root.right)
        slot = tree.remove(tree.lookup(.Right)!)
        XCTAssertEqual(tree.dump(), "(((1) 2 (3)) 4 (7))")
        XCTAssertEqual(slot, Slot.Toward(.Right, under: tree.root!))
        XCTAssert(tree.checkInvariants())

        // Remove 3 (root.left.right)
        slot = tree.remove(tree.lookup(.Left, .Right)!)
        XCTAssertEqual(tree.dump(), "(((1) 2) 4 (7))")
        XCTAssertEqual(slot, Slot.Toward(.Right, under: tree.lookup(.Left)!))
        XCTAssert(tree.checkInvariants())

        // Remove 1 (root.left.left)
        slot = tree.remove(tree.lookup(.Left, .Left)!)
        XCTAssertEqual(tree.dump(), "((2) 4 (7))")
        XCTAssertEqual(slot, Slot.Toward(.Left, under: tree.lookup(.Left)!))
        XCTAssert(tree.checkInvariants())

        // Remove 7 (root.right)
        slot = tree.remove(tree.lookup(.Right)!)
        XCTAssertEqual(tree.dump(), "((2) 4)")
        XCTAssertEqual(slot, Slot.Toward(.Right, under: tree.root!))
        XCTAssert(tree.checkInvariants())

        // Remove 4 (root)
        slot = tree.remove(tree.root!)
        XCTAssertEqual(tree.dump(), "(2)")
        XCTAssertEqual(slot, Slot.Root)
        XCTAssert(tree.checkInvariants())

        // Remove 2 (root)
        slot = tree.remove(tree.root!)
        XCTAssertEqual(tree.dump(), "")
        XCTAssertEqual(slot, Slot.Root)
        XCTAssert(tree.checkInvariants())
    }

    func newTree() -> BinaryTree<Int> {
        // Insert elements 1...7 into tree.
        var tree = BinaryTree<Int>()
        let i4 = tree.insert(4, into: .Root)
        let i2 = tree.insert(2, into: .Toward(.Left, under: i4))
        tree.insert(1, into: .Toward(.Left, under: i2))
        tree.insert(3, into: .Toward(.Right, under: i2))
        let i6 = tree.insert(6, into: .Toward(.Right, under: i4))
        tree.insert(5, into: .Toward(.Left, under: i6))
        tree.insert(7, into: .Toward(.Right, under: i6))
        return tree
    }

    func testPayloadSetterHasValueSemantics() {
        var tree = newTree()
        let copy = tree
        let i4 = tree.lookup(.Left, .Left)!
        tree[i4].payload = 10
        XCTAssertEqual(tree[i4].payload, 10)
        XCTAssertEqual(copy[i4].payload, 1)
        XCTAssertEqual(tree.dump(), "(((10) 2 (3)) 4 ((5) 6 (7)))")
        XCTAssertEqual(copy.dump(), "(((1) 2 (3)) 4 ((5) 6 (7)))")
    }

    func testRemovalHasValueSemantics() {
        var tree = newTree()
        let copy = tree
        let i4 = tree.lookup(.Left, .Left)!
        tree.remove(i4)
        XCTAssertEqual(copy[i4].payload, 1)
        XCTAssertEqual(tree.dump(), "((2 (3)) 4 ((5) 6 (7)))")
        XCTAssertEqual(copy.dump(), "(((1) 2 (3)) 4 ((5) 6 (7)))")
    }

    func testInsertionHasValueSemantics() {
        var tree = newTree()
        let copy = tree
        let i3 = tree.lookup(.Left, .Right)!
        tree.insert(100, into: .Toward(.Left, under: i3))
        XCTAssertEqual(tree.dump(), "(((1) 2 ((100) 3)) 4 ((5) 6 (7)))")
        XCTAssertEqual(copy.dump(), "(((1) 2 (3)) 4 ((5) 6 (7)))")
    }

    func testRotations() {
        var tree = BinaryTree<Int>()
        let i2 = tree.insert(2, into: .Root)
        tree.insert(1, into: .Toward(.Left, under: i2))
        let i4 = tree.insert(4, into: .Toward(.Right, under: i2))
        tree.insert(3, into: .Toward(.Left, under: i4))
        let i6 = tree.insert(6, into: .Toward(.Right, under: i4))
        tree.insert(5, into: .Toward(.Left, under: i6))
        tree.insert(7, into: .Toward(.Right, under: i6))

        XCTAssertEqual(tree.dump(), "((1) 2 ((3) 4 ((5) 6 (7))))")

        tree.rotate(i4, .Left)

        XCTAssertEqual(tree.dump(), "((1) 2 (((3) 4 (5)) 6 (7)))")
        XCTAssert(tree.checkInvariants())
        XCTAssertEqual(tree[i4].payload, 6) // 4 and 6 get swapped so that root's index stays the same

        tree.rotate(i4, .Right)
        XCTAssertEqual(tree.dump(), "((1) 2 ((3) 4 ((5) 6 (7))))")
        XCTAssert(tree.checkInvariants())
        XCTAssertEqual(tree[i4].payload, 4) // 4 and 6 get swapped again
    }
}
