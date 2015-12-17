//
//  BinaryTree.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-14.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// Represents a reference to a node in a binary tree.
/// The generic type parameter only serves to differentiate between indexes belonging to different types of trees;
/// in actuality, an index is only valid on a single tree, and even there it is easily invalidated by a mutating method.
struct BinaryIndex<Payload>: Equatable {
    /// This is simply the index inside of the tree's backing array. 
    /// Represented as an UInt32 to save space (which is probably silly).
    private let _value: UInt32

    private init(_ value: Int) { self._value = UInt32(value) }

    private var value: Int { return Int(_value) }
}
func ==<Payload>(a: BinaryIndex<Payload>, b: BinaryIndex<Payload>) -> Bool {
    return a._value == b._value
}

/// A direction represents a choice between a left and right child in a binary tree.
internal enum Direction {
    case Left
    case Right

    /// The opposite direction.
    var opposite: Direction {
        switch self {
        case .Left: return .Right
        case .Right: return .Left
        }
    }
}

/// A slot in the binary tree represents a place into which you can put a node.
/// The tree's root is one slot, and so is either child of another node.
internal enum BinarySlot<Payload>: Equatable {
    internal typealias Index = BinaryIndex<Payload>

    /// A slot representing the place of the topmost node in the tree.
    case Root
    /// A slot representing the child towards a certain direction under a certain parent node in the tree.
    case Toward(Direction, under: Index)
}
internal func ==<Payload>(a: BinarySlot<Payload>, b: BinarySlot<Payload>) -> Bool {
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

/// Node in a binary tree, with a payload and links to its children and parent.
internal struct BinaryNode<Payload> {
    // It's a shame we need to store the parent link -- the only reason we require it is that we need to be able to
    // swap a node with a random one (for removal).

    internal typealias Index = BinaryIndex<Payload>

    /// The link to the parent of this node.
    internal private(set) var parent: Index?
    /// The link to the left child of this node.
    internal private(set) var left: Index?
    /// The link to the right child of this node.
    internal private(set) var right: Index?
    /// The payload of this node.
    internal var payload: Payload

    private init(parent: Index?, payload: Payload) {
        self.parent = parent
        self.payload = payload
    }
}

extension BinaryNode {
    subscript(direction: Direction) -> Index? {
        get {
            switch direction {
            case .Left: return left
            case .Right: return right
            }
        }
        set(index) {
            switch direction {
            case .Left: left = index
            case .Right: right = index
            }
        }
    }
    func isChild(child: Index) -> Bool {
        return child == left || child == right
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

/// Implements a generic binary tree with copy-on-write value semantics. 
/// Each node contains a freely configurable `Payload` component. 
/// The nodes in a binary tree are stored in an array that is kept compact.
///
/// `BinaryTree` supports the following basic operations:
///
/// - Looking up the index of the root node.
/// - Getting and setting the payload of a node that has a given index.
/// - Given an index, navigate to the index of its parent node, left child or right child.
/// - Insert a new leaf node under a parent with a given payload.
/// - Remove a node that has at most one child, using its index.
/// - Left and right tree rotations, as used in balancing algorithms.
///
/// All of these operations have O(1) time complexity. 
/// (Insertion has amortized O(1) -- the array needs to be resized sometimes.)
internal struct BinaryTree<Payload> {
    internal typealias Node = BinaryNode<Payload>
    internal typealias Index = BinaryIndex<Payload>
    internal typealias Slot = BinarySlot<Payload>

    // TODO: As far as I know, the array never shrinks. Try replacing this with a SegmentedArray.
    private var nodes: ContiguousArray<Node> = []
    internal private(set) var firstIndex: Index?
    internal private(set) var lastIndex: Index?

    /// The number of nodes in this tree.
    internal var count: Int {
        return nodes.count
    }

    /// Returns an index to the root node of the tree, or nil if the tree is empty.
    internal var root: Index? {
        // The root is always at index 0.
        return nodes.count > 0 ? Index(0) : nil
    }

    /// Gets or replaces the node at `index`.
    internal subscript(index: Index) -> Node {
        get { return nodes[index.value] }
        set { nodes[index.value] = newValue }
    }

    internal subscript(index: Index?) -> Node? {
        guard let index = index else { return nil }
        return nodes[index.value]
    }

    /// Accesses the specified child of the node at `index`.
    internal private(set) subscript(index: Index, direction: Direction) -> Index? {
        get { return self[index][direction] }
        set(new) { self[index][direction] = new }
    }

    /// Returns the slot of the node at `index`.
    internal func slotOf(index: Index) -> Slot {
        if let parent = self[index].parent {
            if self[parent].left == index {
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

    internal func inorderStep(index: Index, towards direction: Direction) -> Index? {
        if let n = self[index, direction] {
            return self.furthestLeafUnder(n, towards: direction.opposite)
        }
        var child = index
        var parent = self[child].parent
        while let p = parent where child == self[p, direction] {
            child = p
            parent = self[child].parent
        }
        return parent
    }



    /// Inserts a new node with `payload` into `slot`. The slot must currently be empty.
    internal mutating func insert(payload: Payload, into slot: Slot) -> Index {
        assert(indexInSlot(slot) == nil)
        switch slot {
        case .Root:
            nodes.append(Node(parent: nil, payload: payload))
            let index = Index(0)
            firstIndex = index
            lastIndex = index
            return index
        case .Toward(let direction, under: let parent):
            let index = Index(nodes.count)
            self[parent, direction] = index
            nodes.append(Node(parent: parent, payload: payload))
            if firstIndex == parent && direction == .Left { firstIndex = index }
            if lastIndex == parent && direction == .Right { lastIndex = index }
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
        let slot = slotOf(index)

        if index == firstIndex { firstIndex = inorderStep(index, towards: .Right) }
        if index == lastIndex { lastIndex = inorderStep(index, towards: .Left) }

        let left = node.left
        let right = node.right
        assert(left == nil || right == nil)
        if left == nil && right == nil {
            if case .Toward(let direction, under: let parent) = slot {
                self[parent, direction] = nil
            }
            return _remove(index, updating: slot)
        }
        else {
            let rem: Index = left ?? right!
            var n = self[rem]
            n.parent = node.parent
            self[index] = n

            if rem == firstIndex { firstIndex = index }
            if rem == lastIndex { lastIndex = index }

            return _remove(rem, updating: slot)
        }
    }

    // Discard the (already unlinked) node at `index`, updating its slot if its parent needed to be moved.
    private mutating func _remove(index: Index, updating slot: Slot) -> Slot {

        let highestIndex = Index(nodes.count - 1)
        if index.value < highestIndex.value {
            // Remove the node with the largest index instead, and then reinsert it at `i`
            let last = nodes.removeLast()
            self[last.parent!].replaceChild(highestIndex, with: index)
            if let l = last.left { self[l].parent = index }
            if let r = last.right { self[r].parent = index }
            if firstIndex == highestIndex { firstIndex = index }
            if lastIndex == highestIndex { lastIndex = index }
            self[index] = last
            if case .Toward(let direction, under: let i) = slot where i == highestIndex {
                return .Toward(direction, under: index)
            }
            else {
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
        self.firstIndex = nil
        self.lastIndex = nil
    }

    /// Rotates the subtree rooted at `index` in the specified direction. Used when the tree implements
    /// a binary search tree.
    ///
    /// The child towards the opposite of `direction` under `index` becomes the new root, 
    /// and the previous root becomes its child towards `dir`. The rest of the children 
    /// are linked up to preserve BST ordering.
    ///
    /// After the rotation, the new root of the subtree will be at `index`. (The original root becomes its child toward `direction`.)
    /// - Returns: The new index of the node that was previously at `index`.
    internal mutating func rotate(index: Index, _ dir: Direction) -> Index {
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
        if let ad = a[dir] { self[ad].parent = y }
        if let bo = b[opp] { self[bo].parent = x }

        self[x] = b
        self[y] = a

        switch dir {
        case .Left:
            if lastIndex == y { lastIndex = x }
            if firstIndex == x { firstIndex = y }
        case .Right:
            if firstIndex == y { firstIndex = x }
            if lastIndex == x { lastIndex = y }
        }

        return y
    }
}

