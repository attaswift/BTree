//
//  BTreeGenerator.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-11.
//  Copyright © 2015–2016 Károly Lőrentey.
//

/// A generator for all elements stored in a b-tree, in ascending key order.
public struct BTreeGenerator<Key: Comparable, Payload>: GeneratorType {
    public typealias Element = (Key, Payload)
    typealias Node = BTreeNode<Key, Payload>
    typealias State = BTreeStrongPath<Key, Payload>

    var state: State

    internal init(_ state: State) {
        self.state = state
    }

    /// Advance to the next element and return it, or return `nil` if no next element exists.
    ///
    /// - Complexity: Amortized O(1)
    public mutating func next() -> Element? {
        if state.isAtEnd { return nil }
        let result = state.element
        state.moveForward()
        return result
    }
}

/// A mutable path in a b-tree, holding strong references to nodes on the path.
/// This path variant does not support modifying the tree itself; it is suitable for use in generators.
internal struct BTreeStrongPath<Key: Comparable, Payload>: BTreePath {
    typealias Node = BTreeNode<Key, Payload>

    var root: Node
    var path: [Node]
    var slots: [Int]
    var position: Int

    init(_ root: Node) {
        self.root = root
        self.path = [root]
        self.slots = []
        self.position = root.count
    }

    var length: Int { return path.count }
    var count: Int { return root.count }

    var lastNode: Node { return path.last! }

    var lastSlot: Int {
        get { return slots.last! }
        set { slots[slots.count - 1] = newValue }
    }

    mutating func popFromSlots() -> Int {
        assert(path.count == slots.count)
        let slot = slots.removeLast()
        let node = path.last!
        position += node.count - node.positionOfSlot(slot)
        return slot
    }

    mutating func popFromPath() -> Node {
        assert(path.count > 0 && path.count == slots.count + 1)
        return path.removeLast()
    }

    mutating func pushToPath() -> Node {
        assert(path.count == slots.count)
        let parent = path.last!
        let slot = slots.last!
        let child = parent.children[slot]
        path.append(child)
        return child
    }

    mutating func pushToSlots(slot: Int, positionOfSlot: Int) {
        assert(path.count == slots.count + 1)
        let node = path.last!
        position -= node.count - positionOfSlot
        slots.append(slot)
    }

    func forEachAscending(@noescape body: (Node, Int) -> Void) {
        for i in (0 ..< path.count).reverse() {
            body(path[i], slots[i])
        }
    }
}
