//
//  BTreeBuilderTests.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-29.
//  Copyright © 2016–2017 Károly Lőrentey.
//

import XCTest
@testable import BTree

class BTreeBuilderTests: XCTestCase {
    typealias Builder = BTreeBuilder<Int, String>
    typealias Node = BTreeNode<Int, String>
    typealias Tree = BTree<Int, String>
    typealias Element = (Int, String)

    func elements<S: Sequence>(_ range: S) -> [Element] where S.Element == Int {
        return range.map { ($0, String($0)) }
    }

    func testBTreeInitDropDuplicatesEmpty() {
        let tree = Tree(sortedElements: [], dropDuplicates: true, order: 5)
        tree.assertValid()
        assert(tree.order == 5)
        assertEqualElements(tree, [])
    }

    func testBTreeInitDropDuplicates() {
        let tree = Tree(sortedElements: [(0, "0"), (0, "1"), (0, "2"), (1, "3"), (1, "4")], dropDuplicates: true, order: 5)
        tree.assertValid()
        assert(tree.order == 5)
        assertEqualElements(tree, [(0, "2"), (1, "4")])
    }

    func testEmpty() {
        var builder = Builder(order: 5, keysPerNode: 3)
        let tree = builder.finish()
        tree.assertValid()
        assert(tree.order == 5)
        assertEqualElements(tree, [])
    }

    func testSingleElement() {
        var builder = Builder(order: 5, keysPerNode: 3)
        builder.append((0, "0"))
        let tree = builder.finish()
        tree.assertValid()
        assertEqualElements(tree, [(0, "0")])
    }

    func testFullNodeWithDepth0() {
        var builder = Builder(order: 5, keysPerNode: 3)
        builder.append((0, "0"))
        builder.append((1, "1"))
        builder.append((2, "2"))
        let node = builder.finish()
        node.assertValid()
        node.forEachNode { XCTAssertEqual($0.elements.count, 3) }
        assertEqualElements(node, [(0, "0"), (1, "1"), (2, "2")])
        XCTAssertEqual(node.depth, 0)
    }

    func testFullNodeWithDepth1() {
        var builder = Builder(order: 5, keysPerNode: 3)
        for i in 0 ..< 15 {
            builder.append((i, String(i)))
        }
        let node = builder.finish()
        node.assertValid()
        node.forEachNode { XCTAssertEqual($0.elements.count, 3) }
        assertEqualElements(node, (0 ..< 15).map { ($0, String($0)) })
        XCTAssertEqual(node.depth, 1)
    }

    func testFullNodeWithDepth2() {
        var builder = Builder(order: 5, keysPerNode: 3)
        for i in 0 ..< 63 {
            builder.append((i, String(i)))
        }
        let node = builder.finish()
        node.assertValid()
        node.forEachNode { XCTAssertEqual($0.elements.count, 3) }
        assertEqualElements(node, (0 ..< 63).map { ($0, String($0)) })
        XCTAssertEqual(node.depth, 2)
    }

    func testPartialNodeWithDepth2() {
        var builder = Builder(order: 5, keysPerNode: 3)
        for i in 0 ..< 60 {
            builder.append((i, String(i)))
        }
        let node = builder.finish()
        node.assertValid()
        assertEqualElements(node, (0 ..< 60).map { ($0, String($0)) })
        XCTAssertEqual(node.depth, 2)
    }

    func testAppendingEmptyNodes() {
        var builder = Builder(order: 5, keysPerNode: 3)
        for i in 0 ..< 63 {
            builder.append(Node(order: 5))
            builder.append((i, String(i)))
        }
        builder.append(Node(order: 5))
        let node = builder.finish()
        node.assertValid()
        node.forEachNode { XCTAssertEqual($0.elements.count, 3) }
        assertEqualElements(node, (0 ..< 63).map { ($0, String($0)) })
        XCTAssertEqual(node.depth, 2)
    }

    func testAppendingSingleElementNodes() {
        var builder = Builder(order: 5, keysPerNode: 3)
        for i in 0 ..< 63 {
            let node = Node(order: 5, elements: [(i, String(i))], children: [], count: 1)
            builder.append(node)
        }
        let node = builder.finish()
        node.assertValid()
        node.forEachNode { XCTAssertEqual($0.elements.count, 3) }
        assertEqualElements(node, (0 ..< 63).map { ($0, String($0)) })
        XCTAssertEqual(node.depth, 2)
    }

    func testAppendingTwoElementNodes() {
        var builder = Builder(order: 5, keysPerNode: 3)
        for i in 0 ..< 31 {
            let node = Node(order: 5, elements: elements(2 * i ..< 2 * i + 2), children: [], count: 2)
            builder.append(node)
        }
        builder.append((62, "62"))
        let node = builder.finish()
        node.assertValid()
        node.forEachNode { XCTAssertEqual($0.elements.count, 3) }
        assertEqualElements(node, (0 ..< 63).map { ($0, String($0)) })
        XCTAssertEqual(node.depth, 2)
    }

    func testAppendingThreeElementNodes() {
        var builder = Builder(order: 5, keysPerNode: 3)
        for i in 0 ..< 21 {
            let node = Node(order: 5, elements: elements(3 * i ..< 3 * i + 3), children: [], count: 3)
            builder.append(node)
        }
        let node = builder.finish()
        node.assertValid()
        node.forEachNode { XCTAssertEqual($0.elements.count, 3) }
        assertEqualElements(node, (0 ..< 63).map { ($0, String($0)) })
        XCTAssertEqual(node.depth, 2)
    }

    func testAppendingFourElementNodes() {
        var builder = Builder(order: 5, keysPerNode: 3)
        for i in 0 ..< 15 {
            let node = Node(order: 5, elements: elements(4 * i ..< 4 * i + 4), children: [], count: 4)
            builder.append(node)
        }
        builder.append((60, "60"))
        builder.append((61, "61"))
        builder.append((62, "62"))
        let node = builder.finish()
        node.assertValid()
        assertEqualElements(node, (0 ..< 63).map { ($0, String($0)) })
        XCTAssertEqual(node.depth, 2)
    }

    func testAppendingNodesWithDepth1() {
        var builder = Builder(order: 5, keysPerNode: 3)
        var i = 0
        for _ in 0 ..< 5 {
            let node = maximalNode(depth: 1, order: 5, offset: i)
            i += node.count
            builder.append(node)
        }
        let node = builder.finish()
        node.assertValid()
        assertEqualElements(node.map { $0.0 }, 0 ..< i)
    }

    func testAppendingOneElementThenANodeWithDepth1() {
        var builder = Builder(order: 5, keysPerNode: 3)
        var i = 0
        for _ in 0 ..< 4 {
            builder.append((i, String(i)))
            i += 1
            let node = minimalNode(depth: 1, order: 5, offset: i)
            i += node.count
            builder.append(node)
        }
        let node = builder.finish()
        node.assertValid()
        assertEqualElements(node.map { $0.0 }, 0 ..< i)
    }

    func testAppendingTwoElementsThenANodeWithDepth1() {
        var builder = Builder(order: 5, keysPerNode: 3)
        var i = 0
        for _ in 0 ..< 4 {
            builder.append((i, String(i)))
            builder.append((i + 1, String(i + 1)))
            i += 2
            let node = minimalNode(depth: 1, order: 5, offset: i)
            i += node.count
            builder.append(node)
        }
        let node = builder.finish()
        node.assertValid()
        assertEqualElements(node.map { $0.0 }, 0 ..< i)
    }

    func testAppendingTheSameNode() {
        // First, create a node with uniform keys.
        let nodeSize = 20
        var b = Builder(order: 5, keysPerNode: 4)
        for i in 0 ..< nodeSize {
            b.append((0, "\(i)"))
        }
        let node = b.finish()
        let values = (0 ..< nodeSize).map { "\($0)" }

        // Next, append this node 10 times to a new builder.
        var builder = Builder(order: 5, keysPerNode: 4)
        let appendCount = 10
        for _ in 0 ..< appendCount {
            builder.append(node)
            assertEqualElements(node.map { $0.1 }, values)
        }
        let large = builder.finish()
        assertEqualElements(large.map { $0.1 }, (0 ..< appendCount).flatMap { _ in values })

        // The result should have duplicate nodes.
        var nodes: Set<Ref<Node>> = []
        var nodeCount = 0
        large.forEachNode { node in
            nodes.insert(Ref(target: node))
            nodeCount += 1
        }
        XCTAssertLessThan(nodes.count, nodeCount)
    }

    func testAppendingSubtrees() {
        // First, create a node with uniform keys.
        let nodeSize = 50
        var b = Builder(order: 5, keysPerNode: 4)
        for i in 0 ..< nodeSize {
            b.append((0, "\(i)"))
        }
        let node = b.finish()

        var values: [Node] = []
        node.forEachNode { n in
            values.append(n.clone())
        }

        // Next, append all subtrees of this node to a new builder.
        var builder = Builder(order: 5, keysPerNode: 4)
        node.forEachNode { n in
            builder.append(n)
        }
        let large = builder.finish()

        // Result should have the same elements as the previously extracted subtree array.
        assertEqualElements(large.map { $0.1 }, values.flatMap { $0.map { $0.1 } })

        // The node should have the exact same subnodes as before.
        var i = 0
        node.forEachNode { n in
            let expected = values[i]
            XCTAssertEqual(n.count, expected.count)
            assertEqualElements(n.elements, expected.elements)
            XCTAssertTrue(n.children.elementsEqual(expected.children, by: ===))
            i += 1
        }
    }
}
