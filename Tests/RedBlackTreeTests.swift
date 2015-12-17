//
//  RedBlackTreeTests.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-15.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import TreeCollections

private class FixupList {
    var fixups: Set<Int> = []

    init() {}

    func add(i: Int) { fixups.insert(i) }
    func clear() { fixups.removeAll() }
    var list: [Int] { return fixups.sort() }
}

private struct Value: RedBlackValue, CustomStringConvertible {
    typealias Key = Int

    let fixups: FixupList
    var i: Int

    init(_ i: Int, _ fixups: FixupList) {
        self.fixups = fixups
        self.i = i
    }

    func compare(key: Key, @noescape left: Void->Value?, insert: Bool) -> RedBlackComparisonResult<Key> {
        if i > key {
            return .Descend(.Left, with: key)
        }
        else if i < key {
            return .Descend(.Right, with: key)
        }
        else {
            return .Found
        }
    }

    /// Recalculate self's state with specified new children. Return true if this self's parent also needs to be fixed up.
    mutating func fixup(@noescape left: Void->Value?, @noescape right: Void->Value?) -> Bool {
        fixups.add(i)
        return false
    }

    var description: String { return "\(i)" }

}

private func assertTreeIsValid(tree: RedBlackTree<Value>) -> Bool {
    let info = tree.debugInfo
    if !info.isValidRedBlackTree {
        XCTFail("Tree is not a valid red-black tree: \(info)")
        return false
    }
    return true
}

class RedBlackTreeTests: XCTestCase {
    func testSampleInsertionsAndRemovals() {
        let fixups = FixupList()
        var tree = RedBlackTree<Value>()
        tree.insert(Value(1, fixups), into: tree.insertionSlotFor(1).1)

        XCTAssertEqual(tree.dump(), "(1)")
        XCTAssertEqual(fixups.list, [])
        XCTAssertTrue(tree.debugInfo.isValidRedBlackTree, "\(tree.debugInfo)")
        fixups.clear()

        tree.insert(Value(4, fixups), into: tree.insertionSlotFor(4).1)

        XCTAssertEqual(tree.dump(), "(1 (4R))")
        XCTAssertEqual(fixups.list, [1])
        XCTAssertTrue(tree.debugInfo.isValidRedBlackTree, "\(tree.debugInfo)")
        fixups.clear()

        tree.insert(Value(5, fixups), into: tree.insertionSlotFor(5).1)

        XCTAssertEqual(tree.dump(), "((1R) 4 (5R))")
        XCTAssertEqual(fixups.list, [1, 4])
        XCTAssertTrue(tree.debugInfo.isValidRedBlackTree, "\(tree.debugInfo)")
        fixups.clear()

        tree.insert(Value(2, fixups), into: tree.insertionSlotFor(2).1)

        XCTAssertEqual(tree.dump(), "((1 (2R)) 4 (5))")
        XCTAssertEqual(fixups.list, [1])
        XCTAssertTrue(tree.debugInfo.isValidRedBlackTree, "\(tree.debugInfo)")
        fixups.clear()

        tree.insert(Value(3, fixups), into: tree.insertionSlotFor(3).1)

        XCTAssertEqual(tree.dump(), "(((1R) 2 (3R)) 4 (5))")
        XCTAssertEqual(fixups.list, [1, 2])
        XCTAssertTrue(tree.debugInfo.isValidRedBlackTree, "\(tree.debugInfo)")
        fixups.clear()

        XCTAssertEqual(tree[tree.find(1)]?.i, 1)
        XCTAssertEqual(tree[tree.find(2)]?.i, 2)
        XCTAssertEqual(tree[tree.find(3)]?.i, 3)
        XCTAssertEqual(tree[tree.find(4)]?.i, 4)
        XCTAssertEqual(tree[tree.find(5)]?.i, 5)

        tree.remove(tree.find(4)!)

        XCTAssertEqual(tree.dump(), "((1) 2 ((3R) 5))")
        XCTAssertEqual(fixups.list, [2, 5])
        XCTAssertTrue(tree.debugInfo.isValidRedBlackTree, "\(tree.debugInfo)")
        fixups.clear()

        tree.remove(tree.find(2)!)

        XCTAssertEqual(tree.dump(), "((1) 3 (5))")
        XCTAssertEqual(fixups.list, [3, 5])
        XCTAssertTrue(tree.debugInfo.isValidRedBlackTree, "\(tree.debugInfo)")
        fixups.clear()

        tree.remove(tree.find(1)!)

        XCTAssertEqual(tree.dump(), "(3 (5R))")
        XCTAssertEqual(fixups.list, [3])
        XCTAssertTrue(tree.debugInfo.isValidRedBlackTree, "\(tree.debugInfo)")
        fixups.clear()

        tree.remove(tree.find(3)!)

        XCTAssertEqual(tree.dump(), "(5)")
        XCTAssertEqual(fixups.list, [])
        XCTAssertTrue(tree.debugInfo.isValidRedBlackTree, "\(tree.debugInfo)")
        fixups.clear()

        tree.remove(tree.find(5)!)

        XCTAssertEqual(tree.dump(), "")
        XCTAssertEqual(fixups.list, [])
        XCTAssertTrue(tree.debugInfo.isValidRedBlackTree, "\(tree.debugInfo)")
        fixups.clear()

    }

    func testInsertingSequentially() {
        var tree = RedBlackTree<Value>()

        let fixups = FixupList()
        for i in 1...100 {
            let index = tree.insert(Value(i, fixups), into: tree.insertionSlotFor(i).1)
            assertTreeIsValid(tree)
            XCTAssertEqual(tree[index].i, i)
        }

        print(tree.debugInfo)
    }

    func testRemovingSequentially() {
        var tree = RedBlackTree<Value>()

        let fixups = FixupList()
        for i in 1...100 {
            tree.insert(Value(i, fixups), into: tree.insertionSlotFor(i).1)
        }
        for i in 1...100 {
            let index = tree.find(i)
            XCTAssertNotNil(index)
            tree.remove(index!)
            assertTreeIsValid(tree)
        }

        print(tree.debugInfo)
    }


    func testInsertionInRandomOrder() {
        var tree = RedBlackTree<Value>()

        let fixups = FixupList()
        let permutation = [5, 9, 10, 6, 14, 17, 7, 18, 27, 16, 23, 26, 30, 3, 2, 22, 25, 24, 13, 12, 21, 15, 1, 28, 4, 19, 8, 29, 20, 11]
        for i in permutation {
            let index = tree.insert(Value(i, fixups), into: tree.insertionSlotFor(i).1)
            print(tree.dump())
            assertTreeIsValid(tree)
            XCTAssertEqual(tree[index].i, i)
        }

        print(tree.debugInfo)
    }
    func testRemovalInRandomOrder() {
        var tree = RedBlackTree<Value>()

        let fixups = FixupList()
        for i in 1...30 {
            tree.insert(Value(i, fixups), into: tree.insertionSlotFor(i).1)
        }
        print(tree.debugInfo)
        let permutation = [5, 9, 10, 6, 14, 17, 7, 18, 27, 16, 23, 26, 30, 3, 2, 22, 25, 24, 13, 12, 21, 15, 1, 28, 4, 19, 8, 29, 20, 11]
        for i in permutation {
            let index = tree.find(i)
            XCTAssertNotNil(index)
            print(tree.dump())
            tree.remove(index!)
            assertTreeIsValid(tree)
        }
        print(tree.dump())
    }

    func testInsertionsAndRemovalsExhaustively() {

        let count = 4
        // Insert keys from 1 to count in all possible permutations, then remove them, again in every possible order.
        // Verify that red-black property holds at every steps.

        let fixups = FixupList()
        for order in generatePermutations(count) {
            var tree = RedBlackTree<Value>()
            for i in order {
                let (v, slot) = tree.insertionSlotFor(i)
                XCTAssertNil(v)
                tree.insert(Value(i, fixups), into: slot)
            }

            XCTAssertEqual(tree.count, count)
            assertTreeIsValid(tree)

            for removals in generatePermutations(count) {
                var t = tree
                for i in removals {
                    let index = t.find(i)
                    XCTAssertNotNil(index)
                    let v = t.remove(index!)
                    XCTAssertEqual(v.i, i)
                }
            }
        }
    }
}
