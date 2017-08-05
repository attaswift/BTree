//
//  BTreePathTests.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-26.
//  Copyright © 2016–2017 Károly Lőrentey.
//

import XCTest
@testable import BTree


class PathTests<Path: BTreePath> where Path.Key == Int, Path.Value == String {
    typealias Tree = BTree<Int, String>
    typealias Node = BTreeNode<Int, String>

    func testInitStartOf() {
        let node = maximalNode(depth: 3, order: 3)
        let path = Path(startOf: node)
        XCTAssertTrue(path.isValid)
        XCTAssertTrue(path.isAtStart)
        XCTAssertFalse(path.isAtEnd)
        XCTAssertEqual(path.offset, 0)
        XCTAssertEqual(path.key, 0)
        XCTAssertEqual(path.value, "0")
    }

    func testInitEndOf() {
        let node = maximalNode(depth: 3, order: 3)
        let path = Path(endOf: node)
        XCTAssertTrue(path.isValid)
        XCTAssertFalse(path.isAtStart)
        XCTAssertTrue(path.isAtEnd)
        XCTAssertEqual(path.offset, node.count)
    }

    func withClone(_ tree: Tree, body: (Node) -> Node) {
        let node = tree.root.clone()
        withExtendedLifetime(node) {
            let result = body(node)
            assertEqualElements(result, tree)
        }
    }

    func testInitOffset() {
        let tree = maximalTree(depth: 3, order: 3)
        let c = tree.count
        for i in 0 ..< c {
            withClone(tree) { node in
                var path = Path(root: node, offset: i)
                XCTAssertTrue(path.isValid)
                XCTAssertEqual(path.offset, i)
                XCTAssertEqual(path.key, i)
                XCTAssertEqual(path.value, String(i))
                return path.finish()
            }
        }
        withClone(tree) { node in
            var path = Path(root: node, offset: c)
            XCTAssertEqual(path.offset, c)
            XCTAssertTrue(path.isAtEnd)
            return path.finish()
        }
    }

    func makeTree(count: Int) -> Tree {
        let range = 0 ... 2 * count + 1
        let contents = range.lazy.map { ($0 & ~1, String($0)) }
        return Tree(sortedElements: contents, order: 3)
    }
    
    func testInitKeyFirst() {
        let c = 26
        let tree = makeTree(count: c)
        for i in 0 ... c {
            withClone(tree) { node in
                var path = Path(root: node, key: 2 * i, choosing: .first)
                XCTAssertTrue(path.isValid)
                XCTAssertEqual(path.offset, 2 * i)
                XCTAssertEqual(path.key, 2 * i)
                XCTAssertEqual(path.value, String(2 * i))
                return path.finish()
            }
        }
        for i in 0 ..< c {
            withClone(tree) { node in
                var path = Path(root: node, key: 2 * i + 1, choosing: .first)
                XCTAssertTrue(path.isValid)
                XCTAssertEqual(path.offset, 2 * i + 2)
                XCTAssertEqual(path.key, 2 * i + 2)
                XCTAssertEqual(path.value, String(2 * i + 2))
                return path.finish()
            }
        }
    }

    func testInitKeyLast() {
        let c = 26
        let tree = makeTree(count: c)
        for i in 0 ... c {
            withClone(tree) { node in
                var path = Path(root: node, key: 2 * i, choosing: .last)
                XCTAssertTrue(path.isValid)
                XCTAssertEqual(path.offset, 2 * i + 1)
                XCTAssertEqual(path.key, 2 * i)
                XCTAssertEqual(path.value, String(2 * i + 1))
                return path.finish()
            }
        }
        for i in 0 ..< c {
            withClone(tree) { node in
                var path = Path(root: node, key: 2 * i + 1, choosing: .last)
                XCTAssertTrue(path.isValid)
                XCTAssertEqual(path.offset, 2 * i + 2)
                XCTAssertEqual(path.key, 2 * i + 2)
                XCTAssertEqual(path.value, String(2 * i + 2))
                return path.finish()
            }
        }
    }

    func testInitKeyAfter() {
        let c = 26
        let tree = makeTree(count: c)
        for i in 0 ..< c {
            withClone(tree) { node in
                var path = Path(root: node, key: 2 * i, choosing: .after)
                XCTAssertTrue(path.isValid)
                XCTAssertEqual(path.offset, 2 * i + 2)
                XCTAssertEqual(path.key, 2 * i + 2)
                XCTAssertEqual(path.value, String(2 * i + 2))
                return path.finish()
            }
        }

        for i in 0 ..< c {
            withClone(tree) { node in
                var path = Path(root: node, key: 2 * i + 1, choosing: .after)
                XCTAssertTrue(path.isValid)
                XCTAssertEqual(path.offset, 2 * i + 2)
                XCTAssertEqual(path.key, 2 * i + 2)
                XCTAssertEqual(path.value, String(2 * i + 2))
                return path.finish()
            }
        }
    }

    func testInitKeyAny() {
        let c = 26
        let tree = makeTree(count: c)
        for i in 0 ... c {
            withClone(tree) { node in
                var path = Path(root: node, key: 2 * i, choosing: .any)
                XCTAssertTrue(path.isValid)
                XCTAssertGreaterThanOrEqual(path.offset, 2 * i)
                XCTAssertLessThanOrEqual(path.offset, 2 * i + 1)
                XCTAssertEqual(path.key, 2 * i)
                XCTAssertTrue(path.value == String(2 * i + 1) || path.value == String(2 * i))
                return path.finish()
            }
        }
        for i in 0 ..< c {
            withClone(tree) { node in
                var path = Path(root: node, key: 2 * i + 1, choosing: .any)
                XCTAssertTrue(path.isValid)
                XCTAssertEqual(path.offset, 2 * i + 2)
                XCTAssertEqual(path.key, 2 * i + 2)
                XCTAssertEqual(path.value, String(2 * i + 2))
                return path.finish()
            }
        }
    }

    func testMoveForward() {
        let tree = maximalTree(depth: 3, order: 3)
        let c = tree.count
        withClone(tree) { node in
            var path = Path(startOf: node)
            var i = 0
            while !path.isAtEnd {
                XCTAssertTrue(path.isValid)
                XCTAssertEqual(path.offset, i)
                XCTAssertEqual(path.key, i)
                XCTAssertEqual(path.value, String(i))
                path.moveForward()
                i += 1
            }
            XCTAssertEqual(i, c)
            XCTAssertTrue(path.isAtEnd)
            XCTAssertEqual(path.offset, c)
            return path.finish()
        }
    }

    func testMoveBackward() {
        let tree = maximalTree(depth: 3, order: 3)
        let c = tree.count
        withClone(tree) { node in
            var path = Path(endOf: node)
            var i = c
            while !path.isAtStart {
                path.moveBackward()
                i -= 1
                XCTAssertTrue(path.isValid)
                XCTAssertEqual(path.offset, i)
                XCTAssertEqual(path.key, i)
                XCTAssertEqual(path.value, String(i))
            }
            XCTAssertEqual(i, 0)
            XCTAssertTrue(path.isAtStart)
            XCTAssertEqual(path.offset, 0)
            return path.finish()
        }
    }

    func testMoveToStart() {
        let tree = maximalTree(depth: 3, order: 3)
        withClone(tree) { node in
            var path = Path(endOf: node)
            path.moveToStart()
            XCTAssertTrue(path.isAtStart)
            XCTAssertEqual(path.offset, 0)
            XCTAssertEqual(path.key, 0)
            XCTAssertEqual(path.value, "0")
            return path.finish()
        }
    }

    func testMoveToEnd() {
        let tree = maximalTree(depth: 3, order: 3)
        let c = tree.count
        withClone(tree) { node in
            var path = Path(startOf: node)
            path.moveToEnd()
            XCTAssertTrue(path.isAtEnd)
            XCTAssertEqual(path.offset, c)
            return path.finish()
        }
    }

    func testMoveToOffset() {
        let tree = maximalTree(depth: 3, order: 3)
        let c = tree.count
        withClone(tree) { node in
            var path = Path(endOf: node)
            var i = 0
            var j = c
            while i < j {
                path.move(toOffset: i)
                XCTAssertEqual(path.offset, i)
                XCTAssertEqual(path.key, i)
                i += 1

                j -= 1
                path.move(toOffset: j)
                XCTAssertEqual(path.offset, j)
                XCTAssertEqual(path.key, j)
            }
            path.move(toOffset: c)
            XCTAssertTrue(path.isAtEnd)
            XCTAssertEqual(path.offset, c)
            return path.finish()
        }
    }

    func testMoveToKeyFirst() {
        let c = 30
        let tree = makeTree(count: c)
        withClone(tree) { node in
            var path = Path(endOf: node)
            for i in 0...c {
                path.move(to: 2 * i, choosing: .first)
                XCTAssertEqual(path.offset, 2 * i)
                XCTAssertEqual(path.key, 2 * i)

                let j = c - i
                path.move(to: 2 * j + 1, choosing: .first)
                XCTAssertEqual(path.offset, 2 * j + 2)
                if i > 0 {
                    XCTAssertEqual(path.key, 2 * j + 2)
                }
                else {
                    XCTAssertTrue(path.isAtEnd)
                }
            }
            return path.finish()
        }
    }

    func testMoveToKeyLast() {
        let c = 26
        let tree = makeTree(count: c)
        withClone(tree) { node in
            var path = Path(endOf: node)
            for i in 0...c {
                path.move(to: 2 * i, choosing: .last)
                XCTAssertEqual(path.offset, 2 * i + 1)
                XCTAssertEqual(path.key, 2 * i)

                let j = c - i
                path.move(to: 2 * j + 1, choosing: .last)
                XCTAssertEqual(path.offset, 2 * j + 2)
                if i > 0 {
                    XCTAssertEqual(path.key, 2 * j + 2)
                }
                else {
                    XCTAssertTrue(path.isAtEnd)
                }
            }
            return path.finish()
        }
    }

    func testMoveToKeyAfter() {
        let c = 26
        let tree = makeTree(count: c)
        withClone(tree) { node in
            var path = Path(endOf: node)
            for i in 0...c {
                path.move(to: 2 * i, choosing: .after)
                XCTAssertEqual(path.offset, 2 * i + 2)
                if i < c {
                    XCTAssertEqual(path.key, 2 * i + 2)
                }
                else {
                    XCTAssertTrue(path.isAtEnd)
                }

                let j = c - i
                path.move(to: 2 * j + 1, choosing: .after)
                XCTAssertEqual(path.offset, 2 * j + 2)
                if i > 0 {
                    XCTAssertEqual(path.key, 2 * j + 2)
                }
                else {
                    XCTAssertTrue(path.isAtEnd)
                }
            }
            return path.finish()
        }
    }

    func testMoveToKeyAny() {
        let c = 26
        let tree = makeTree(count: c)
        withClone(tree) { node in
            var path = Path(endOf: node)
            for i in 0...c {
                path.move(to: 2 * i, choosing: .any)
                XCTAssertGreaterThanOrEqual(path.offset, 2 * i)
                XCTAssertLessThanOrEqual(path.offset, 2 * i + 1)
                XCTAssertEqual(path.key, 2 * i)

                let j = c - i
                path.move(to: 2 * j + 1, choosing: .any)
                XCTAssertEqual(path.offset, 2 * j + 2)
                if i > 0 {
                    XCTAssertEqual(path.key, 2 * j + 2)
                }
                else {
                    XCTAssertTrue(path.isAtEnd)
                }
            }
            return path.finish()
        }
    }

    func testSplit() {
        let tree = maximalTree(depth: 3, order: 3)
        let c = tree.count
        withClone(tree) { node in
            var path = Path(startOf: node)
            for i in 0 ..< c {
                XCTAssertEqual(path.offset, i)
                let (prefix, separator, suffix) = path.split()

                prefix.assertValid()
                assertEqualElements(prefix, (0..<i).map { ($0, String($0)) })

                XCTAssertEqual(separator.0, i)
                XCTAssertEqual(separator.1, String(i))

                suffix.assertValid()
                assertEqualElements(suffix, (i + 1 ..< c).map { ($0, String($0)) })

                path.moveForward()
            }
            return path.finish()
        }
    }

    func testPrefix() {
        let tree = maximalTree(depth: 3, order: 3)
        let c = tree.count
        withClone(tree) { node in
            var path = Path(startOf: node)
            for i in 0 ..< c {
                XCTAssertEqual(path.offset, i)

                let prefix = path.prefix()
                prefix.assertValid()
                assertEqualElements(prefix, (0..<i).map { ($0, String($0)) })

                path.moveForward()
            }
            return path.finish()
        }
    }

    func testSuffix() {
        let tree = maximalTree(depth: 3, order: 3)
        let c = tree.count
        withClone(tree) { node in
            var path = Path(startOf: node)
            for i in 0 ..< c {
                XCTAssertEqual(path.offset, i)

                let suffix = path.suffix()
                suffix.assertValid()
                assertEqualElements(suffix, (i + 1 ..< c).map { ($0, String($0)) })

                path.moveForward()
            }
            return path.finish()
        }
    }

    func testForEach() {
        let tree = maximalTree(depth: 3, order: 3)
        withClone(tree) { node in
            var path = Path(startOf: node)
            var p: [(Node, Int)] = []
            path.forEach(ascending: false) { node, slot in
                if !p.isEmpty {
                    let (n, s) = p.last!
                    XCTAssertTrue(n.children[s] === node)
                }
                XCTAssertEqual(slot, 0)
                p.append((node, slot))
            }
            XCTAssertTrue(p.last!.0.isLeaf)

            path.forEach(ascending: true) { node, slot in
                let (n, s) = p.removeLast()
                XCTAssertTrue(node === n)
                XCTAssertEqual(slot, s)
            }

            return path.finish()
        }
    }

    func testForEachSlot() {
        let tree = maximalTree(depth: 3, order: 3)
        withClone(tree) { node in
            var path = Path(startOf: node)
            path.forEachSlot(ascending: false) { slot in
                XCTAssertEqual(slot, 0)
            }
            path.forEachSlot(ascending: true) { slot in
                XCTAssertEqual(slot, 0)
            }

            return path.finish()
        }
    }

    var testCases: [(String, () -> Void)] {
        return [
            ("testInitStartOf", testInitStartOf),
            ("testInitEndOf", testInitEndOf),
            ("testInitOffset", testInitOffset),
            ("testInitKeyFirst", testInitKeyFirst),
            ("testInitKeyLast", testInitKeyLast),
            ("testInitKeyAfter", testInitKeyAfter),
            ("testInitKeyAny", testInitKeyAny),
            ("testMoveForward", testMoveForward),
            ("testMoveBackward", testMoveBackward),
            ("testMoveToStart", testMoveToStart),
            ("testMoveToEnd", testMoveToEnd),
            ("testMoveToOffset", testMoveToOffset),
            ("testMoveToKeyFirst", testMoveToKeyFirst),
            ("testMoveToKeyLast", testMoveToKeyLast),
            ("testMoveToKeyAfter", testMoveToKeyAfter),
            ("testMoveToKeyAny", testMoveToKeyAny),
            ("testSplit", testSplit),
            ("testPrefix", testPrefix),
            ("testSuffix", testSuffix),
            ("testForEach", testForEach),
            ("testForEachSlot", testForEachSlot),
        ]
    }

}



class BTreePathTests: XCTestCase {
    /// Poor man's generic test runner
    func runTests<Path>(_ tests: PathTests<Path>) {
        for (name, testCase) in tests.testCases {
            print("  \(name)")
            testCase()
        }
    }

    func testStrongPaths() {
        let strongTests = PathTests<BTreeStrongPath<Int, String>>()
        runTests(strongTests)
    }

    func testWeakPaths() {
        let weakTests = PathTests<BTreeWeakPath<Int, String>>()
        runTests(weakTests)
    }

    func testCursorPaths() {
        let cursorTests = PathTests<BTreeCursorPath<Int, String>>()
        runTests(cursorTests)
    }
}
