//
//  BTreeGenerator.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2016-02-11.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

/// A generator for all elements stored in a b-tree, in ascending key order.
public struct BTreeGenerator<Key: Comparable, Payload>: GeneratorType {
    public typealias Element = (Key, Payload)
    typealias Node = BTreeNode<Key, Payload>

    var nodePath: [Node]
    var indexPath: [Int]

    init(_ root: Node) {
        if root.count == 0 {
            self.nodePath = []
            self.indexPath = []
        }
        else {
            var node = root
            var path: Array<Node> = []
            path.reserveCapacity(node.depth + 1)
            path.append(root)
            while !node.isLeaf {
                node = node.children.first!
                path.append(node)
            }
            self.nodePath = path
            self.indexPath = Array(count: path.count, repeatedValue: 0)
        }
    }

    /// Advance to the next element and return it, or return `nil` if no next element exists.
    public mutating func next() -> Element? {
        let level = nodePath.count
        guard level > 0 else { return nil }
        let node = nodePath[level - 1]
        let index = indexPath[level - 1]
        let result = (node.keys[index], node.payloads[index])
        if !node.isLeaf {
            // Descend
            indexPath[level - 1] = index + 1
            var n = node.children[index + 1]
            nodePath.append(n)
            indexPath.append(0)
            while !n.isLeaf {
                n = n.children.first!
                nodePath.append(n)
                indexPath.append(0)
            }
        }
        else if index < node.keys.count - 1 {
            indexPath[level - 1] = index + 1
        }
        else {
            // Ascend
            nodePath.removeLast()
            indexPath.removeLast()
            while !nodePath.isEmpty && indexPath.last == nodePath.last!.keys.count {
                nodePath.removeLast()
                indexPath.removeLast()
            }
        }
        return result
    }
}
