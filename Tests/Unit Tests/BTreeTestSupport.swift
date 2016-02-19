//
//  BTreeTestSupport.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2016-02-19.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import Foundation
import XCTest
@testable import TreeCollections

extension BTreeNode {
    func assertValid(file file: FileString = __FILE__, line: UInt = __LINE__) {
        func testNode(level level: Int, node: BTreeNode<Key, Payload>, minKey: Key?, maxKey: Key?) -> (count: Int, defects: [String]) {
            var defects: [String] = []

            // Check item order
            var prev = minKey
            for key in node.keys {
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
                if node.keys.count > node.order - 1 {
                    defects.append("Oversize leaf node: \(node.keys.count) > \(node.order - 1)")
                }
                if level > 0 && node.keys.count < (node.order - 1) / 2 {
                    defects.append("Undersize leaf node: \(node.keys.count) < \((node.order - 1) / 2)")
                }
                if node.payloads.count != node.keys.count {
                    defects.append("Mismatching item counts in leaf node (keys.count: \(node.keys.count), payloads.count: \(node.payloads.count)")
                }
                if !node.children.isEmpty {
                    defects.append("Leaf node should have no children, this one has \(node.children.count)")
                }
                if node.depth != 0 {
                    defects.append("Lead node should have depth 0")
                }
                return (node.keys.count, defects)
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
            if node.keys.count != node.children.count - 1 {
                defects.append("Mismatching item counts in internal node (keys.count: \(node.keys.count), children.count: \(node.children.count)")
            }
            if node.payloads.count != node.keys.count {
                defects.append("Mismatching item counts in internal node (keys.count: \(node.keys.count), payloads.count: \(node.payloads.count)")
            }

            // Recursion
            var count = node.keys.count
            for slot in 0 ..< node.children.count {
                let child = node.children[slot]
                let (c, d) = testNode(
                    level: level + 1,
                    node: child,
                    minKey: (slot > 0 ? node.keys[slot - 1] : minKey),
                    maxKey: (slot < node.keys.count - 1 ? node.keys[slot + 1] : maxKey))
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

    func insert(payload: Payload, at key: Key) {
        var splinter: BTreeSplinter<Key, Payload>? = nil
        self.editAtKey(key) { node, slot, match in
            precondition(!match)
            if node.isLeaf {
                node.keys.insert(key, atIndex: slot)
                node.payloads.insert(payload, atIndex: slot)
                node.count += 1
                if node.isTooLarge {
                    splinter = node.split()
                }
            }
            else {
                node.count += 1
                if let s = splinter {
                    node.insert(s, inSlot: slot)
                    splinter = (node.isTooLarge ? node.split() : nil)
                }
            }
        }
        if let s = splinter {
            let left = clone()
            let right = s.node
            keys = [s.separator.0]
            payloads = [s.separator.1]
            children = [left, right]
            count = left.count + right.count + 1
            _depth = _depth + 1
        }
    }

    func remove(key: Key, root: Bool = true) -> Payload? {
        var found: Bool = false
        var result: Payload? = nil
        editAtKey(key) { node, slot, match in
            if node.isLeaf {
                assert(!found)
                if !match { return }
                found = true
                node.keys.removeAtIndex(slot)
                result = node.payloads.removeAtIndex(slot)
                node.count -= 1
                return
            }
            if match {
                assert(!found)
                // For internal nodes, we move the previous item in place of the removed one,
                // and remove its original slot instead. (The previous item is always in a leaf node.)
                result = node.payloads[slot]
                node.makeChildUnique(slot)
                let previousKey = node.children[slot].maxKey()!
                let previousPayload = node.children[slot].remove(previousKey, root: false)!
                node.keys[slot] = previousKey
                node.payloads[slot] = previousPayload
                found = true
            }
            if found {
                node.count -= 1
                if node.children[slot].isTooSmall {
                    node.fixDeficiency(slot)
                }
            }
        }
        if root && keys.isEmpty && children.count == 1 {
            let node = children[0]
            keys = node.keys
            payloads = node.payloads
            children = node.children
            _depth -= 1
        }
        return result
    }

    func forEachNode(@noescape operation: Node -> Void) {
        operation(self)
        for child in children {
            child.forEachNode(operation)
        }
    }
}


func maximalTreeOfDepth(depth: Int, order: Int, offset: Int = 0) -> BTreeNode<Int, String> {
    func maximalTreeOfDepth(depth: Int, inout key: Int) -> BTreeNode<Int, String> {
        let tree = BTreeNode<Int, String>(order: order)
        tree._depth = numericCast(depth)
        if depth == 0 {
            for _ in 0 ..< tree.order - 1 {
                tree.insert(String(key), at: key)
                key += 1
            }
        }
        else {
            for i in 0 ..< tree.order {
                let child = maximalTreeOfDepth(depth - 1, key: &key)
                tree.children.append(child)
                tree.count += child.count
                if i < tree.order - 1 {
                    tree.keys.append(key)
                    tree.payloads.append(String(key))
                    tree.count += 1
                    key += 1
                }
            }
        }
        return tree
    }

    var key = offset
    return maximalTreeOfDepth(depth, key: &key)
}
