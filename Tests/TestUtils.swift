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

struct RedBlackInfo<Config: RedBlackConfig, Payload> {
    typealias Tree = RedBlackTree<Config, Payload>
    typealias Handle = Tree.Handle
    typealias Summary = Tree.Summary
    typealias Key = Tree.Key

    var nodeCount: Int = 0

    var minDepth: Int = 0
    var maxDepth: Int = 0

    var minRank: Int = 0
    var maxRank: Int = 0

    var color: Color = .Black
    var summary: Summary = Summary()
    var minKey: Key? = nil
    var maxKey: Key? = nil

    var defects: [(Handle, String)] = []
}

extension RedBlackTree {
    typealias Info = RedBlackInfo<Config, Payload>

    func dump() -> String {
        func dump(handle: Handle?, prefix: Summary) -> String {
            guard let handle = handle else { return "" }
            let node = self[handle]
            let p = prefix + self[node.left]?.summary
            let left = dump(node.left, prefix: prefix)
            let root = String(Config.key(node.head, prefix: p))
            let right = dump(node.right, prefix: p + node.head)
            return "(" + [left, root, right].joinWithSeparator(", ") + ")"
        }
        return dump(root, prefix: Summary())
    }

    var debugInfo: Info {
        func collectInfo(handle: Handle?, parent: Handle?, prefix: Summary) -> Info {
            if let handle = handle {
                var info = Info()
                let node = self[handle]

                var sum = prefix
                let li = collectInfo(node.left, parent: handle, prefix: sum)
                sum = prefix + li.summary + node.head
                let ri = collectInfo(node.right, parent: handle, prefix: sum)
                info.summary = sum + ri.summary

                info.nodeCount = li.nodeCount + 1 + ri.nodeCount
                info.minDepth = min(li.minDepth, ri.minDepth) + 1
                info.maxDepth = max(li.maxDepth, ri.maxDepth) + 1
                info.minRank = min(li.minRank, ri.minRank) + (node.color == .Black ? 1 : 0)
                info.maxRank = max(li.maxRank, ri.maxRank) + (node.color == .Black ? 1 : 0)

                info.defects = li.defects + ri.defects
                info.color = node.color

                if node.parent != parent {
                    info.defects.append((handle, "parent is \(node.parent), expected \(parent)"))
                }
                if node.color == .Red {
                    if li.color != .Black {
                        info.defects.append((handle, "color is red but left child(\(node.left) is also red"))
                    }
                    if ri.color != .Black {
                        info.defects.append((handle, "color is red but right child(\(node.left) is also red"))
                    }
                }
                if li.minRank != ri.minRank {
                    info.defects.append((handle, "mismatching child subtree ranks: \(li.minRank) vs \(ri.minRank)"))
                }
                if info.summary != node.summary {
                    info.defects.append((handle, "summary is \(node.summary), expected \(info.summary)"))
                }
                let key = Config.key(node.head, prefix: prefix + li.summary)
                info.maxKey = ri.maxKey
                info.minKey = li.minKey
                if let lk = li.maxKey where Config.compare(lk, to: node.head, prefix: prefix + li.summary) == .After {
                    info.defects.append((handle, "node's key is ordered before its maximum left descendant: \(key) < \(lk)"))
                }
                if let rk = ri.minKey where Config.compare(rk, to: node.head, prefix: prefix + li.summary) == .Before {
                    info.defects.append((handle, "node's key is ordered after its minimum right descendant: \(key) > \(rk)"))
                }
                return info
            }
            else {
                return RedBlackInfo()
            }
        }
        var info = collectInfo(root, parent: nil, prefix: Summary())
        if info.color == .Red {
            info.defects.append((root!, "root is red"))
        }
        if info.nodeCount != count {
            info.defects.append((root!, "count of reachable nodes is \(info.nodeCount), expected \(count)"))
        }
        return info
    }
    func assertTreeIsValid() {
        let info = debugInfo
        for (handle, explanation) in info.defects {
            XCTFail("\(handle): \(explanation)")
        }
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