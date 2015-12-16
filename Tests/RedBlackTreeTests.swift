//
//  RedBlackTreeTests.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-15.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import TreeCollections

private struct Value: RedBlackValue, CustomStringConvertible {
    typealias Key = Int

    var i: Int

    init(_ i: Int) { self.i = i }

    func key(@noescape left: Void->Value?) -> Key {
        return i
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
        return false
    }

    var description: String { return "\(i)" }

}

private func verifyTree(tree: RedBlackTree<Value>) -> Bool {
    let info = tree.debugInfo
    if !info.isValidRedBlackTree {
        XCTFail("Tree is not a valid red-black tree: \(info)")
        return false
    }
    return true
}

class RedBlackTreeTests: XCTestCase {
    func testSampleInsertion() {
        var tree = RedBlackTree<Value>()
        tree.insert(Value(1), into: tree.insertionSlotFor(1).1)
        tree.insert(Value(3), into: tree.insertionSlotFor(3).1)
        tree.insert(Value(4), into: tree.insertionSlotFor(4).1)

        XCTAssertEqual(tree.dump(), "((1R) 3 (4R))")
        XCTAssertTrue(tree.debugInfo.isValidRedBlackTree, "\(tree.debugInfo)")
        
        tree.insert(Value(2), into: tree.insertionSlotFor(2).1)

        XCTAssertEqual(tree.dump(), "((1 (2R)) 3 (4))")
        XCTAssertTrue(tree.debugInfo.isValidRedBlackTree, "\(tree.debugInfo)")
    }

    func testInsertingSequentially() {
        var tree = RedBlackTree<Value>()

        for i in 1...100 {
            let index = tree.insert(Value(i), into: tree.insertionSlotFor(i).1)
            verifyTree(tree)
            XCTAssertEqual(tree[index].i, i)
        }

        print(tree.debugInfo)
    }

    func testInsertionInRandomOrder() {
        var tree = RedBlackTree<Value>()

        let permutation = [5, 9, 10, 6, 14, 17, 7, 18, 27, 16, 23, 26, 30, 3, 2, 22, 25, 24, 13, 12, 21, 15, 1, 28, 4, 19, 8, 29, 20, 11]
        for i in permutation {
            let index = tree.insert(Value(i), into: tree.insertionSlotFor(i).1)
            if !verifyTree(tree) {
                print("While inserting \(i)")
            }
            XCTAssertEqual(tree[index].i, i)
        }

        print(tree.debugInfo)
    }

}
