//
//  TestUtils.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-15.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import TreeCollections

func noop<Value>(value: Value) {
}

// This basic overload is missing from XCTest, so it upgrades everything to Optional which makes reports harder to read.
public func XCTAssertEqual<T : Equatable>(@autoclosure expression1: () -> T, @autoclosure _ expression2: () -> T, _ message: String = "", file: String = __FILE__, line: UInt = __LINE__) {
    let a = expression1()
    let b = expression2()
    if a != b {
        let m = message.isEmpty ? "XCTAssertEqual failed: (\"\(a)\") is not equal to (\"\(b)\")" : message
        XCTFail(m, file: file, line: line)
    }
}

extension BinaryTree {
    func checkInvariants() -> Bool {
        var count = 0
        func check(index: Index?, under parent: Index?) -> Bool {
            guard let index = index else { return true }
            count += 1
            let node = self[index]
            guard parent == node.parent else { return false }
            guard check(node.left, under: index) else { return false }
            guard check(node.right, under: index) else { return false }
            return true
        }

        guard check(self.root, under: nil) else { return false }

        if count > 0 {
            guard let first = leftmost where self.inorderStep(first, towards: .Left) == nil else { return false }
            guard let last = rightmost where self.inorderStep(last, towards: .Right) == nil else { return false }
        }

        return count == self.count
    }

    func dump() -> String {
        func dump(index: Index?) -> String {
            guard let index = index else { return "" }
            let left = dump(self[index].left)
            let right = dump(self[index].right)
            let space1 = left.isEmpty ? "" : " "
            let space2 = right.isEmpty ? "" : " "
            return "(\(left)\(space1)\(self[index].payload)\(space2)\(right))"
        }
        return dump(root)
    }

    func lookup(directions: Direction...) -> Index? {
        return self.lookup(directions)
    }

    func lookup<S: SequenceType where S.Generator.Element == Direction>(directions: S) -> Index? {
        var index = self.root
        for direction in directions {
            guard let i = index else { return nil }
            index = self[i, direction]
        }
        return index
    }
}

extension RedBlackTree {
    func dump() -> String {
        func dump(index: Index?) -> String {
            return self.tree.dump()
        }
        return dump(root)
    }
}

extension RedBlackPayload: CustomStringConvertible {
    var description: String {
        return "\(value)\(color == .Red ? "R" : "")"
    }
}

extension List {
    func checkCounts() -> Bool {
        var failedIndexes: [Tree.Index] = []
        func walk(index: Tree.Index?) -> Int {
            if let index = index {
                let measured = walk(tree.tree[index].left) + walk(tree.tree[index].right) + 1
                let stored = tree[index].state
                if measured != stored {
                    print("Subtree at index \(index) contains \(measured) nodes, but its root says it has \(stored)")
                    failedIndexes.append(index)
                }
                return measured
            }
            else {
                return 0
            }
        }

        if count > 0 {
            guard let first = tree.firstIndex where tree.predecessor(first) == nil else { return false }
            guard let last = tree.lastIndex where tree.successor(last) == nil else { return false }
        }
        return failedIndexes.isEmpty
    }
}

extension ListValue: CustomStringConvertible {
    var description: String {
        return "<\(self.element)/#\(self.state)>"
    }
}


func generatePermutations(count: Int) -> AnyGenerator<[Int]> {
    if count == 0 {
        return anyGenerator(EmptyCollection<[Int]>().generate())
    }
    if count == 1 {
        return anyGenerator(CollectionOfOne([0]).generate())
    }
    if count == 2 {
        return anyGenerator([[0, 1], [1, 0]].generate())
    }
    let generator = generatePermutations(count - 1)
    var perm: [Int] = []
    var next = -1
    return anyGenerator {
        if next < 0 {
            guard let p = generator.next() else { return nil }
            perm = p
            next = p.count
        }
        var r = perm
        r.insert(count - 1, atIndex: next)
        next -= 1
        return r
    }
}

class PermutationTests: XCTestCase {
    func testPermutations() {
        XCTAssertEqual(Array(generatePermutations(0)), [])
        XCTAssertEqual(Array(generatePermutations(1)), [[0]])
        XCTAssertEqual(Array(generatePermutations(2)), [[0, 1], [1, 0]])
        XCTAssertEqual(Array(generatePermutations(3)), [[0, 1, 2], [0, 2, 1], [2, 0, 1], [1, 0, 2], [1, 2, 0], [2, 1, 0]])
        var count = 0
        for p in generatePermutations(6) {
            XCTAssertEqual(p.sort(), [0, 1, 2, 3, 4, 5])
            count += 1
        }
        XCTAssertEqual(count, 6 * 5 * 4 * 3 * 2)
    }
}