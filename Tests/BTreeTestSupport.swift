//
//  BTreeTestSupport.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-19.
//  Copyright © 2015–2016 Károly Lőrentey.
//

import Foundation
import XCTest
@testable import BTree

extension BTreeNode {
    func assertValid(file file: FileString = __FILE__, line: UInt = __LINE__) {
        func testNode(level level: Int, node: BTreeNode<Key, Payload>, minKey: Key?, maxKey: Key?) -> (count: Int, defects: [String]) {
            var defects: [String] = []

            // Check item order
            var prev = minKey
            for key in node.elements.map({ $0.0 }) {
                if let p = prev where p > key {
                    defects.append("Invalid item order: \(p) > \(key)")
                }
                prev = key
            }
            if let maxKey = maxKey, prev = prev where prev > maxKey {
                defects.append("Invalid item order: \(prev) > \(maxKey)")
            }

            // Check leaf node
            if node.isLeaf {
                if node.elements.count > node.order - 1 {
                    defects.append("Oversize leaf node: \(node.elements.count) > \(node.order - 1)")
                }
                if level > 0 && node.elements.count < (node.order - 1) / 2 {
                    defects.append("Undersize leaf node: \(node.elements.count) < \((node.order - 1) / 2)")
                }
                if !node.children.isEmpty {
                    defects.append("Leaf node should have no children, this one has \(node.children.count)")
                }
                if node.depth != 0 {
                    defects.append("Lead node should have depth 0")
                }
                return (node.elements.count, defects)
            }

            // Check child count
            if node.children.count > node.order {
                defects.append("Oversize internal node: \(node.children.count) > \(node.order)")
            }
            if level > 0 && node.children.count < (node.order + 1) / 2 {
                defects.append("Undersize internal node: \(node.children.count) < \((node.order + 1) / 2)")
            }
            if level == 0 && node.children.count < 2 {
                defects.append("Undersize root node: \(node.children.count) < 2")
            }
            // Check item count
            if node.elements.count != node.children.count - 1 {
                defects.append("Mismatching item counts in internal node (elements.count: \(node.elements.count), children.count: \(node.children.count)")
            }

            // Recursion
            var count = node.elements.count
            for slot in 0 ..< node.children.count {
                let child = node.children[slot]
                let (c, d) = testNode(
                    level: level + 1,
                    node: child,
                    minKey: (slot > 0 ? node.elements.map { $0.0 }[slot - 1] : minKey),
                    maxKey: (slot < node.elements.count - 1 ? node.elements.map { $0.0 }[slot + 1] : maxKey))
                if node.depth != child.depth + 1 {
                    defects.append("Invalid depth: \(node.depth) in parent vs \(child.depth) in child")
                }
                count += c
                defects.appendContentsOf(d)
            }
            if node.count != count {
                defects.append("Mismatching internal node count: \(node.count) vs \(count)")
            }
            return (count, defects)
        }

        let (_, defects) = testNode(level: 0, node: self, minKey: nil, maxKey: nil)
        for d in defects {
            XCTFail(d, file: file, line: line)
        }
    }

    func forEachNode(@noescape operation: Node -> Void) {
        operation(self)
        for child in children {
            child.forEachNode(operation)
        }
    }

    var dump: String {
        var r = "("
        if isLeaf {
            let keys = elements.lazy.map { String($0.0) }
            r += keys.joinWithSeparator(" ")
        }
        else {
            for i in 0 ..< elements.count {
                r += children[i].dump
                r += " "
                r += String(elements[i].0)
                r += " "
            }
            r += children[elements.count].dump
        }
        r += ")"
        return r
    }
}

func uniformNode(depth depth: Int, order: Int, keysPerNode: Int, offset: Int = 0) -> BTreeNode<Int, String> {
    precondition(keysPerNode < order && keysPerNode >= (order - 1) / 2)
    var count = keysPerNode
    for _ in 0 ..< depth {
        count *= keysPerNode + 1
        count += keysPerNode
    }
    let sequence = (offset ..< offset + count).map { ($0, String($0)) }
    let tree = BTree<Int, String>(sortedElements: sequence, order: order, fillFactor: Double(keysPerNode) / Double(order - 1))
    return tree.root
}

func maximalNode(depth depth: Int, order: Int, offset: Int = 0) -> BTreeNode<Int, String> {
    return uniformNode(depth: depth, order: order, keysPerNode: order - 1, offset: offset)
}

func minimalNode(depth depth: Int, order: Int, offset: Int = 0) -> BTreeNode<Int, String> {
    return uniformNode(depth: depth, order: order, keysPerNode: (order - 1) / 2, offset: offset)
}

func uniformTree(depth depth: Int, order: Int, keysPerNode: Int, offset: Int = 0) -> BTree<Int, String> {
    return BTree(uniformNode(depth: depth, order: order, keysPerNode: keysPerNode, offset: offset))
}

func maximalTree(depth depth: Int, order: Int, offset: Int = 0) -> BTree<Int, String> {
    return BTree(maximalNode(depth: depth, order: order, offset: offset))
}

func minimalTree(depth depth: Int, order: Int, offset: Int = 0) -> BTree<Int, String> {
    return BTree(minimalNode(depth: depth, order: order, offset: offset))
}

class BTreeSupportTests: XCTestCase {
    func testMaximalNodeOfDepth0() {
        let node = maximalNode(depth: 0, order: 5)
        node.assertValid()

        XCTAssertEqual(node.elements.map { $0.0 }, [0, 1, 2, 3])
        XCTAssertEqual(node.elements.map { $0.1 }, ["0", "1", "2", "3"])
        XCTAssertEqual(node.children.count, 0)
        XCTAssertEqual(node.count, 4)
        XCTAssertEqual(node.order, 5)
        XCTAssertEqual(node.depth, 0)

        XCTAssertFalse(node.isEmpty)
        assertEqualElements(node, [(0, "0"), (1, "1"), (2, "2"), (3, "3")])
    }

    func testMaximalNodeOfDepth1() {
        let node = maximalNode(depth: 1, order: 3)
        node.assertValid()

        XCTAssertEqual(node.elements.map { $0.0 }, [2, 5])
        XCTAssertEqual(node.elements.map { $0.1 }, ["2", "5"])
        XCTAssertEqual(node.count, 8)
        XCTAssertEqual(node.order, 3)
        XCTAssertEqual(node.depth, 1)

        XCTAssertEqual(node.children.count, 3)
        var i = 0
        for child in node.children {
            XCTAssertEqual(child.elements.map { $0.0 }, [i, i + 1])
            XCTAssertEqual(child.elements.map { $0.1 }, (i ..< i + 2).map { String($0) })
            XCTAssertEqual(child.children.count, 0)
            XCTAssertEqual(child.count, 2)
            XCTAssertEqual(child.order, 3)
            XCTAssertEqual(child.depth, 0)
            i += 3
        }

        assertEqualElements(node, (0..<8).map { ($0, String($0)) })
    }

    func testMinimalNodeOfDepth0() {
        let node = minimalNode(depth: 0, order: 5)
        node.assertValid()

        XCTAssertEqual(node.elements.map { $0.0 }, [0, 1])
        XCTAssertEqual(node.elements.map { $0.1 }, ["0", "1"])
        XCTAssertEqual(node.children.count, 0)
        XCTAssertEqual(node.count, 2)
        XCTAssertEqual(node.order, 5)
        XCTAssertEqual(node.depth, 0)

        XCTAssertFalse(node.isEmpty)
        assertEqualElements(node, [(0, "0"), (1, "1")])
    }

    func testMinimalNodeOfDepth1() {
        let node = minimalNode(depth: 1, order: 3)
        node.assertValid()

        XCTAssertEqual(node.elements.map { $0.0 }, [1])
        XCTAssertEqual(node.elements.map { $0.1 }, ["1"])
        XCTAssertEqual(node.count, 3)
        XCTAssertEqual(node.order, 3)
        XCTAssertEqual(node.depth, 1)

        XCTAssertEqual(node.children.count, 2)
        var i = 0
        for child in node.children {
            XCTAssertEqual(child.elements.map { $0.0 }, [i])
            XCTAssertEqual(child.elements.map { $0.1 }, [String(i)])
            XCTAssertEqual(child.children.count, 0)
            XCTAssertEqual(child.count, 1)
            XCTAssertEqual(child.order, 3)
            XCTAssertEqual(child.depth, 0)
            i += 2
        }
        
        assertEqualElements(node, (0..<3).map { ($0, String($0)) })
    }
}
