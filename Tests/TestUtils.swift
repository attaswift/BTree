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

    var defects: [(Handle, String, String, UInt)] = []

    mutating func addDefect(handle: Handle, _ description: String, file: String = __FILE__, line: UInt = __LINE__) {
        defects.append((handle, description, file, line))
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


    func printDump() {
        func dump(handle: Handle?, prefix: Summary) -> (Int, [(KeyMatchResult, String, [String])]) {
            guard let handle = handle else { return (0, []) }
            let node = self[handle]
            let (leftTabs, leftLines) = dump(node.left, prefix: prefix)
            let p = prefix + self[node.left]?.summary
            let (rightTabs, rightLines) = dump(node.right, prefix: p + node.head)

            let tabs = max(leftTabs, rightTabs)

            let dot = (node.color == .Black ? "●" : "○")
            let root = ["\(handle):","    \(Config.key(node.head, prefix: p))", "⟼ \(node.payload)", "\t☺:\(node.head)", "\t∑:\(node.summary)"]

            if leftLines.isEmpty && rightLines.isEmpty {
                return (tabs, [(.Matching, "\(dot)\t", root)])
            }

            var lines: [(KeyMatchResult, String, [String])] = []

            let rightIndent = (tabs - rightTabs) * "\t"
            if rightLines.isEmpty {
                lines.append((.After, "┏━\t" + "\t" + rightIndent, ["nil"]))
            }
            else {
                for (m, graphic, text) in rightLines {
                    switch m {
                    case .After:
                        lines.append((.After, "\t" + graphic + rightIndent, text))
                    case .Matching:
                        lines.append((.After, "┏━\t" + graphic + rightIndent, text))
                    case .Before:
                        lines.append((.After, "┃\t" + graphic + rightIndent, text))
                    }
                }
            }

            lines.append((.Matching, "\(dot)\t\t" + tabs * "\t", root))

            let leftIndent = (tabs - leftTabs) * "\t"
            if leftLines.isEmpty {
                lines.append((.Before, "┗━\t" + "\t" + leftIndent, ["nil"]))
            }
            else {
                for (m, graphic, text) in leftLines {
                    switch m {
                    case .After:
                        lines.append((.Before, "┃\t" + graphic + leftIndent, text))
                    case .Matching:
                        lines.append((.Before, "┗━\t" + graphic + leftIndent, text))
                    case .Before:
                        lines.append((.Before, "\t" + graphic + leftIndent, text))
                    }
                }
            }
            return (tabs + 1, lines)
        }


        let lines = dump(root, prefix: Summary()).1

        let columnCount = lines.reduce(0) { a, l in max(a, l.2.count) }
        var columnWidths = [Int](count: columnCount, repeatedValue: 0)
        lines.lazy.flatMap { $0.2.enumerate() }.forEach { i, c in
            columnWidths[i] = max(columnWidths[i], c.characters.count)
        }

        for (_, graphic, columns) in lines {
            var line = graphic
            columns.enumerate().forEach { i, c in
                line += c
                line += String(count: columnWidths[i] - c.characters.count + 1, repeatedValue: " " as Character)
            }
            print(line)
        }
    }

    private func collectInfo(blacklist: Set<Handle>, handle: Handle?, parent: Handle?, prefix: Summary) -> Info {
        guard let handle = handle else { return Info() }
        var info = Info()
        let node = self[handle]

        if blacklist.contains(handle) {
            info.addDefect(handle, "node is linked more than once")
            return info
        }
        var blacklist = blacklist
        blacklist.insert(handle)

        let li = collectInfo(blacklist, handle: node.left, parent: handle, prefix: prefix)
        let ri = collectInfo(blacklist, handle: node.right, parent: handle, prefix: prefix + li.summary + node.head)
        info.summary = li.summary + node.head + ri.summary

        info.nodeCount = li.nodeCount + 1 + ri.nodeCount
        info.minDepth = min(li.minDepth, ri.minDepth) + 1
        info.maxDepth = max(li.maxDepth, ri.maxDepth) + 1
        info.minRank = min(li.minRank, ri.minRank) + (node.color == .Black ? 1 : 0)
        info.maxRank = max(li.maxRank, ri.maxRank) + (node.color == .Black ? 1 : 0)

        info.defects = li.defects + ri.defects
        info.color = node.color

        if node.parent != parent {
            info.addDefect(handle, "parent is \(node.parent), expected \(parent)")
        }
        if node.color == .Red {
            if li.color != .Black {
                info.addDefect(handle, "color is red but left child(\(node.left) is also red")
            }
            if ri.color != .Black {
                info.addDefect(handle, "color is red but right child(\(node.left) is also red")
            }
        }
        if li.minRank != ri.minRank {
            info.addDefect(handle, "mismatching child subtree ranks: \(li.minRank) vs \(ri.minRank)")
        }
        if info.summary != node.summary {
            info.addDefect(handle, "summary is \(node.summary), expected \(info.summary)")
        }
        let key = Config.key(node.head, prefix: prefix + li.summary)
        info.maxKey = ri.maxKey
        info.minKey = li.minKey
        if let lk = li.maxKey where Config.compare(lk, to: node.head, prefix: prefix + li.summary) == .After {
            info.addDefect(handle, "node's key is ordered before its maximum left descendant: \(key) < \(lk)")
        }
        if let rk = ri.minKey where Config.compare(rk, to: node.head, prefix: prefix + li.summary) == .Before {
            info.addDefect(handle, "node's key is ordered after its minimum right descendant: \(key) > \(rk)")
        }
        return info
    }

    var debugInfo: Info {
        var info = collectInfo([], handle: root, parent: nil, prefix: Summary())
        if info.color == .Red {
            info.addDefect(root!, "root is red")
        }
        if info.nodeCount != count {
            info.addDefect(root!, "count of reachable nodes is \(info.nodeCount), expected \(count)")
        }
        return info
    }
    func assertTreeIsValid() {
        let info = debugInfo
        for (handle, explanation, file, line) in info.defects {
            XCTFail("\(handle): \(explanation)", file: file, line: line)
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