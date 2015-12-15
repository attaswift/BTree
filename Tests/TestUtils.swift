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
        func check(node: Index?, under parent: Index?) -> Bool {
            guard let node = node else { return true }
            count += 1
            guard parent == self[node, .Parent] else { return false }
            guard check(self[node, .LeftChild], under: node) else { return false }
            guard check(self[node, .RightChild], under: node) else { return false }
            return true
        }

        check(self.root, under: nil)
        return count == self.count
    }

    func dump() -> String {
        func dump(index: Index?) -> String {
            guard let index = index else { return "" }
            let left = dump(self[index, .LeftChild])
            let right = dump(self[index, .RightChild])
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

