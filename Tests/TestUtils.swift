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


func *(i: Int, s: String) -> String {
    var result = ""
    (0..<i).forEach { _ in result += s }
    return result
}

extension RedBlackTree {
    typealias Info = RedBlackInfo<Config, Payload>

    func dump() -> String {
        func dump(handle: Handle?, prefix: Summary) -> String {
            guard let handle = handle else { return "" }
            let node = self[handle]

            var s = prefix
            let left = dump(node.left, prefix: s)

            s += self[node.left]?.summary
            let root = String(Config.key(node.head, prefix: s))

            s += node.head
            let right = dump(node.right, prefix: s)
            return "(" + [left, root, right].filter { !$0.isEmpty }.joinWithSeparator(" ") + ")"
        }
        return dump(root, prefix: Summary())
    }

    func dumpNode(handle: Handle) -> String {
        let node = self[handle]
        return "\(handle): \(node.summary) ⟼ \(node.payload)"
    }
    func dumpNode(i: Int) -> String {
        let node = nodes[i]
        return "#\(i): \(node.summary) ⟼ \(node.payload)"
    }

    func lookup(directions: RedBlackDirection...) -> Handle? {
        return self.lookup(directions)
    }

    func lookup<S: SequenceType where S.Generator.Element == RedBlackDirection>(directions: S) -> Handle? {
        var handle = self.root
        for direction in directions {
            guard let h = handle else { return nil }
            handle = self[h][direction]
        }
        return handle
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