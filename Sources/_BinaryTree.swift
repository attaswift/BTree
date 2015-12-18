//
//  BinaryTree.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-14.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// A generic binary tree with copy-on-write value semantics.
/// Each node contains a freely configurable `Payload` component. 
/// The nodes in a binary tree are stored in an array that is kept compact.
///
/// `BinaryTree` supports the following basic operations:
///
/// - Looking up the index of the root, the leftmost, or rightmost node in the tree.
///    ```
///    let rootIndex = tree.root
///    let first = tree.leftmost
///    let last = tree.rightmost
///    ```
/// - Getting and setting the payload of a node that has a given index.
///    ```
///    let payload = tree[index].payload
///    tree[index].payload = new
///    ```
/// - Given an index, navigating to the index of its parent node, left child or right child.
///    ```
///    let left = tree[index].left
///    let right = tree[index].right
///    let parent = tree[index].parent
///    let anUncle = tree[tree[parent]?.parent]?.left
///    ```
/// - Inserting a new leaf node under a parent with a given payload.
///    ```
///    if let first = tree.leftmost {
///        tree.insert(value, under: .Toward(.Left, tree.leftmost))
///    } else {
///        tree.insert(value, under: .Root)
///    }
///    ```
/// - Removing a node that has at most one child, using its index.
///    ```
///    tree.remove(index)
///    ```
/// - Removing all nodes in a tree at once.
///    ```
///    tree.removeAll()
///    ```
/// - Left and right tree rotations, as used in tree balancing algorithms.
///    ```
///    tree.rotate(index, .Left)
///    ```
///
/// All of these operations except `removeAll` have O(1) time complexity.
/// (Insertion has amortized O(1) -- the array needs to be resized sometimes.)
/// `removeAll` is O(n) if payloads have to be individually deinitialized (e.g. because they reference counted stored properties), and O(1) otherwise.
///
/// Note that like `Array`, `BinaryTree` does not ever shrink its allocated storage.
///
internal struct BinaryTree<Payload> {
    internal typealias Node = BinaryTreeNode<Payload>
    internal typealias Index = BinaryTreeIndex<Payload>
    internal typealias Slot = BinaryTreeSlot<Payload>

    // TODO: As far as I know, the array never shrinks. Try replacing this with a SegmentedArray.
    private var nodes: ContiguousArray<Node> = []
    internal private(set) var leftmost: Index?
    internal private(set) var rightmost: Index?

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

    /// Returns the node at `index`, or nil if `index` is nil.
    internal subscript(index: Index?) -> Node? {
        guard let index = index else { return nil }
        return nodes[index.value]
    }

    /// Accesses the specified child of the node at `index`.
    internal private(set) subscript(index: Index, direction: BinaryTreeDirection) -> Index? {
        get { return self[index][direction] }
        set(new) { self[index][direction] = new }
    }

    /// Reserve enough storage capacity to store at least `minimumCapacity` nodes.
    internal mutating func reserveCapacity(minimumCapacity: Int) {
        self.nodes.reserveCapacity(minimumCapacity)
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

    /// Returns the node that is furthest down towards `direction` from the node at `index`.
    internal func furthestLeafUnder(index: Index, towards direction: BinaryTreeDirection) -> Index {
        var index = index
        while let next = self[index, direction] {
            index = next
        }
        return index
    }

    /// Performs a step in an inorder walk of the tree starting from `index`, toward `direction`.
    internal func inorderStep(index: Index, towards direction: BinaryTreeDirection) -> Index? {
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
            leftmost = index
            rightmost = index
            return index
        case .Toward(let direction, under: let parent):
            let index = Index(nodes.count)
            self[parent, direction] = index
            nodes.append(Node(parent: parent, payload: payload))
            if leftmost == parent && direction == .Left { leftmost = index }
            if rightmost == parent && direction == .Right { rightmost = index }
            return index
        }
    }

    /// Remove the node with the given index, _invalidating all existing indexes_. The deleted node
    /// must have at most one child.
    ///
    /// A side effect of this operation is that a random node in the tree usually changes it index.
    /// Therefore, all previously stored indexes need to be discarded after a removal.
    /// (Internally maintained indexes (`root`, `leftmost` and `rightmost`) are automatically updated.)
    /// The index contained in the returned slot can be used to continue operating on the tree.
    ///
    /// - Parameter index: The index of a node with at most one child.
    /// - Returns: The slot from which the node has been removed.
    ///
    internal mutating func remove(index: Index) -> Slot {
        let node = self[index]
        let slot = slotOf(index)

        if index == leftmost { leftmost = inorderStep(index, towards: .Right) }
        if index == rightmost { rightmost = inorderStep(index, towards: .Left) }

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

            if rem == leftmost { leftmost = index }
            if rem == rightmost { rightmost = index }

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
            if leftmost == highestIndex { leftmost = index }
            if rightmost == highestIndex { rightmost = index }
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

    /// Remove all nodes of the tree.
    /// - Parameter keepCapacity: If true, the tree will keep its allocated storage. If false, the storage is released.
    internal mutating func removeAll(keepCapacity keepCapacity: Bool = false) {
        self.nodes.removeAll(keepCapacity: keepCapacity)
        self.leftmost = nil
        self.rightmost = nil
    }

    /// Rotates the subtree rooted at `index` in the specified direction. Used when the tree implements
    /// a binary search tree.
    ///
    /// The child towards the opposite of `direction` under `index` becomes the new root, 
    /// and the previous root becomes its child towards `dir`. The rest of the children 
    /// are linked up to preserve ordering in a binary search tree.
    ///
    /// - Warning: After the rotation, the new root of the subtree will be at `index`.
    /// (The original root becomes its child toward `direction`, whose index is returned.)
    /// - Returns: The new index of the node that was previously at `index`.
    internal mutating func rotate(index: Index, _ dir: BinaryTreeDirection) -> Index {
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
            if rightmost == y { rightmost = x }
            if leftmost == x { leftmost = y }
        case .Right:
            if leftmost == y { leftmost = x }
            if rightmost == x { rightmost = y }
        }

        return y
    }
}

/// Represents a reference to a node in a binary tree.
/// The generic type parameter only serves to differentiate between indexes belonging to different types of trees;
/// in actuality, an index is only valid on a single tree, and even there it is easily invalidated by a mutating method.
struct BinaryTreeIndex<Payload>: Equatable {
    /// This is simply the index inside of the tree's backing array.
    /// Represented as an UInt32 to save space (which is probably silly).
    private let _value: UInt32

    private init(_ value: Int) { self._value = UInt32(value) }

    private var value: Int { return Int(_value) }
}
func ==<Payload>(a: BinaryTreeIndex<Payload>, b: BinaryTreeIndex<Payload>) -> Bool {
    return a._value == b._value
}

/// A direction represents a choice between a left and right child in a binary tree.
internal enum BinaryTreeDirection {
    /// The left child.
    case Left
    /// The right child.
    case Right

    /// The opposite direction.
    var opposite: BinaryTreeDirection {
        switch self {
        case .Left: return .Right
        case .Right: return .Left
        }
    }
}

/// A slot in the binary tree represents a place into which you can put a node.
/// The tree's root is one slot, and so is either child of another node.
internal enum BinaryTreeSlot<Payload>: Equatable {
    internal typealias Index = BinaryTreeIndex<Payload>

    /// A slot representing the place of the topmost node in the tree.
    case Root
    /// A slot representing the child towards a certain direction under a certain parent node in the tree.
    case Toward(BinaryTreeDirection, under: Index)
}
internal func ==<Payload>(a: BinaryTreeSlot<Payload>, b: BinaryTreeSlot<Payload>) -> Bool {
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
internal struct BinaryTreeNode<Payload> {
    // It's a shame we need to store the parent link -- the only reason we require it is that we need to be able to
    // swap a node with a random one (for removal).

    internal typealias Index = BinaryTreeIndex<Payload>

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

extension BinaryTreeNode {
    /// Get or set the child index toward `direction`.
    subscript(direction: BinaryTreeDirection) -> Index? {
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

    /// Replace the child with index `old` with `new`.
    /// - Precondition: `old` == `left` || `old` == `right`
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

