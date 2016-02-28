//
//  BTreeBuilder.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-28.
//  Copyright © 2016 Károly Lőrentey.
//

private enum BuilderState {
    /// The builder needs a separator element.
    case Separator
    /// The builder is filling up a seedling node.
    case Element
}

/// A construct for efficiently building a fully loaded b-tree from a series of elements.
///
/// The bulk loading algorithm works growing a line of perfectly loaded saplings, in order of decreasing depth,
/// with a separator element between each of them.
///
/// Added elements are collected into a separator and a new leaf node (called the "seedling").
/// When the seedling becomes full it is appended to or recursively merged into the list of saplings.
///
/// When `finish` is called, the final list of saplings plus the last partial seedling is joined
/// into a single tree, which becomes the root.
internal struct BTreeBuilder<Key: Comparable, Payload> {
    typealias Node = BTreeNode<Key, Payload>
    typealias Element = Node.Element

    private let order: Int
    private let keysPerNode: Int
    private var saplings: [Node]
    private var separators: [Element]
    private var seedling: Node
    private var state: BuilderState

    init(order: Int, keysPerNode: Int) {
        precondition(order > 1)
        precondition(keysPerNode >= (order - 1) / 2 && keysPerNode <= order - 1)

        self.order = order
        self.keysPerNode = keysPerNode
        self.saplings = []
        self.separators = []
        self.seedling = Node(order: order)
        self.state = .Element
    }

    mutating func append(element: Element) {
        switch state {
        case .Separator:
            separators.append(element)
            state = .Element
        case .Element:
            seedling.append(element)
            if seedling.count == keysPerNode {
                finishSeedling()
                state = .Separator
            }
        }
    }

    private mutating func finishSeedling() {
        // Append seedling into saplings, combining the last few seedlings when possible.
        while !saplings.isEmpty && seedling.elements.count == keysPerNode {
            let sapling = saplings.last!
            assert(sapling.depth >= seedling.depth)
            if sapling.depth == seedling.depth + 1 && sapling.elements.count < keysPerNode {
                // Graft current seedling under the last sapling, as a new child branch.
                saplings.removeLast()
                let separator = separators.removeLast()
                sapling.elements.append(separator)
                sapling.children.append(seedling)
                sapling.count += seedling.count + 1
                seedling = sapling
            }
            else if sapling.depth == seedling.depth && sapling.elements.count == keysPerNode {
                // We have two full nodes; add them as two branches of a new, deeper seedling.
                saplings.removeLast()
                let separator = separators.removeLast()
                seedling = Node(left: sapling, separator: separator, right: seedling)
            }
            else {
                break
            }
        }
        saplings.append(seedling)
        seedling = Node(order: order)
    }

    mutating func finish() -> Node {
        // Merge all saplings and the seedling into a single tree.
        var root: Node
        if separators.count == saplings.count - 1 {
            assert(seedling.count == 0)
            root = saplings.removeLast()
        }
        else {
            root = seedling
        }
        assert(separators.count == saplings.count)
        while !saplings.isEmpty {
            root = Node.join(left: saplings.removeLast(), separator: separators.removeLast(), right: root)
        }
        return root
    }
}