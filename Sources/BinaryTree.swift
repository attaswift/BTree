//
//  BinaryTree.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-14.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

typealias Index = UInt32

internal enum Direction {
    case Left
    case Right

    var link: Link {
        switch self {
        case .Left: return .LeftChild
        case .Right: return .RightChild
        }
    }

    var opposite: Direction {
        switch self {
        case .Left: return .Right
        case .Right: return .Left
        }
    }
}

internal enum Slot: Equatable {
    case Root
    case Toward(Direction, under: Index)
}
internal func ==(a: Slot, b: Slot) -> Bool {
    switch a {
    case .Root:
        if case .Root = b {
            return true
        }
        else {
            return false
        }
    case .Toward(let ad, under: let ap):
        if case .Toward(let bd, under: let bp) = b {
            return ad == bd && ap == bp
        }
        else {
            return false
        }
    }
}

internal enum Link {
    case Parent
    case LeftChild
    case RightChild
}

internal struct BinaryNode<Payload> {
    internal private(set) var parent: Index?
    internal private(set) var left: Index?
    internal private(set) var right: Index?
    internal var payload: Payload

    private init(parent: Index?, payload: Payload) {
        self.parent = parent
        self.payload = payload
    }
}

extension BinaryNode {
    subscript(link: Link) -> Index? {
        get {
            switch link {
            case .Parent: return parent
            case .LeftChild: return left
            case .RightChild: return right
            }
        }
        set(index) {
            switch link {
            case .Parent: parent = index
            case .LeftChild: left = index
            case .RightChild: right = index
            }
        }
    }

    subscript(direction: Direction) -> Index? {
        get { return self[direction.link] }
        set { self[direction.link] = newValue }
    }

    func isChild(child: Index) -> Bool {
        return child == self[.LeftChild] || child == self[.RightChild]
    }

    mutating func replaceChild(old: Index, with new: Index?) {
        assert(left == old || right == old)
        if left == old {
            left = new
        }
        else {
            right = new
        }
    }
}

/// Implements a binary tree with value semantics that stores all its nodes in an array.
/// The tree provides the following operations:
///
/// - Looking up the index of the root node.
/// - Getting and setting the payload of a node that has a given index.
/// - Given an index, navigate to its parent index, left child index or right child index.
/// - Insert a new leaf node under a parent.
/// - Remove a node that has at most one child.
/// - Left and right tree rotations.
///
/// All of these operations have O(1) time complexity. 
/// (Insertion has amortized O(1) -- the array needs to be resized sometimes.)
internal struct BinaryTree<Payload> {
    internal typealias Node = BinaryNode<Payload>

    private var nodes: ContiguousArray<Node> = []

    /// The number of nodes in this tree.
    internal var count: Int {
        return nodes.count
    }

    /// Returns an index to the root node of the tree, or nil if the tree is empty.
    internal var root: Index? {
        // The root is always at index 0.
        return nodes.count > 0 ? 0 : nil
    }

    /// Gets or replaces the node at `index`.
    internal subscript(index: Index) -> Node {
        get { return nodes[Int(index)] }
        set { nodes[Int(index)] = newValue }
    }

    internal subscript(index: Index?) -> Node? {
        guard let index = index else { return nil }
        return self[index] as Node
    }

    /// Accesses the specified link of the node at `index`.
    internal private(set) subscript(index: Index, link: Link) -> Index? {
        get { return self[index][link] }
        set(new) { self[index][link] = new }
    }

    /// Accesses the specified child of the node at `index`.
    internal private(set) subscript(index: Index, direction: Direction) -> Index? {
        get { return self[index, direction.link] }
        set(new) { self[index, direction.link] = new }
    }

    /// Returns the slot of the node at `index`.
    internal func slotOf(index: Index) -> Slot {
        if let parent = self[index, .Parent] {
            if self[parent, .LeftChild] == index {
                return .Toward(.Left, under: parent)
            }
            else {
                return .Toward(.Right, under: parent)
            }
        }
        else {
            return .Root
        }
    }

    internal func left(index: Index) -> Index? {
        return self[index, .LeftChild]
    }
    internal func right(index: Index) -> Index? {
        return self[index, .RightChild]
    }
    internal func parent(index: Index) -> Index? {
        return self[index, .Parent]
    }

    /// Returns the index of the node in `slot`, or nil if the slot is currently empty.
    internal func indexInSlot(slot: Slot) -> Index? {
        switch slot {
        case .Root:
            return root
        case .Toward(let direction, under: let parent):
            return self[parent, direction]
        }
    }

    internal func furthestLeafUnder(index: Index, towards direction: Direction) -> Index {
        var index = index
        while let next = self[index, direction] {
            index = next
        }
        return index
    }


    /// Inserts a new node with `payload` into `slot`. The slot must currently be empty.
    internal mutating func insert(payload: Payload, into slot: Slot) -> Index {
        assert(indexInSlot(slot) == nil)
        switch slot {
        case .Root:
            nodes.append(Node(parent: nil, payload: payload))
            return 0
        case .Toward(let direction, under: let parent):
            let index = Index(nodes.count)
            self[parent, direction] = index
            nodes.append(Node(parent: parent, payload: payload))
            return index
        }
    }

    /// Remove the node with the given index, invalidating all existing indexes. The deleted node
    /// must have at most one child.
    ///
    /// The index contained in the returned slot can be used to continue operating on the tree.
    ///
    /// - Parameter index: The index of a node with at most one child.
    /// - Returns: The slot from which the node has been removed.
    ///
    internal mutating func remove(index: Index) -> Slot {
        let node = self[index]
        assert(node.left == nil || node.right == nil)

        let slot = slotOf(index)
        if let c = node.left ?? node.right {
            var cn = self[c]
            cn.parent = node.parent
            self[index] = cn
            return _remove(c, updating: slot)
        }
        else {
            if case .Toward(let direction, under: let parent) = slot {
                self[parent, direction] = nil
            }
            return _remove(index, updating: slot)
        }
    }

    private mutating func _remove(index: Index, updating slot: Slot) -> Slot {
        let lastIndex = Index(nodes.count - 1)
        if index < lastIndex {
            // Remove the node with the largest index instead, and then reinsert it at `i`
            let last = nodes.removeLast()
            nodes[Int(last.parent!)].replaceChild(lastIndex, with: index)
            if let l = last.left { self[l, .Parent] = index }
            if let r = last.right { self[r, .Parent] = index }
            self[index] = last
            switch slot {
            case .Toward(let direction, under: let i) where i == lastIndex:
                return .Toward(direction, under: index)
            default:
                return slot
            }
        }
        else {
            nodes.removeLast()
            return slot
        }
    }

    internal mutating func reserveCapacity(minimumCapacity: Int) {
        self.nodes.reserveCapacity(minimumCapacity)
    }

    internal mutating func removeAll(keepCapacity keepCapacity: Bool = false) {
        self.nodes.removeAll(keepCapacity: keepCapacity)
    }

    /// Rotates the subtree rooted at `index` in the specified direction. Used when the tree implements
    /// a binary search tree.
    ///
    /// The child towards the opposite of `direction` under `index` becomes the new root, 
    /// and the previous root becomes its child towards `dir`. The rest of the children 
    /// are linked up to preserve BST ordering.
    ///
    /// After the rotation, `index` will still refer to the new root of the subtree.
    internal mutating func rotate(index: Index, _ dir: Direction) {
        assert(self[index, dir.opposite] != nil)
        let opp = dir.opposite
        let x = index
        let y = self[index, dir.opposite]!

        // To leave roots at index 0, this rotation swaps data between parent and child
        var a = self[x]
        var b = self[y]

        b.parent = a.parent
        a.parent = x
        a[opp] = b[dir]
        b[dir] = y
        if let ad = a[dir] { self[ad, .Parent] = y }
        if let bo = b[opp] { self[bo, .Parent] = x }

        self[x] = b
        self[y] = a
    }
}

