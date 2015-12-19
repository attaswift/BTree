//
//  RedBlackTree2.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-17.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

public struct RedBlackHandle<Config: RedBlackConfig, Payload>: Equatable {
    private let _index: UInt32

    private init(_ index: Int) {
        self._index = UInt32(index)
    }

    private var index: Int { return Int(_index) }
}
public func ==<C: RedBlackConfig, P>(a: RedBlackHandle<C, P>, b: RedBlackHandle<C, P>) -> Bool {
    return a._index == b._index
}

internal enum Color {
    case Red
    case Black
}

/// A direction represents a choice between a left and right child in a binary tree.
public enum RedBlackDirection {
    /// The left child.
    case Left
    /// The right child.
    case Right

    /// The opposite direction.
    var opposite: RedBlackDirection {
        switch self {
        case .Left: return .Right
        case .Right: return .Left
        }
    }
}

/// A slot in the binary tree represents a place into which you can put a node.
/// The tree's root is one slot, and so is either child of another node.
internal enum RedBlackSlot<Config: RedBlackConfig, Payload>: Equatable {
    internal typealias Handle = RedBlackHandle<Config, Payload>

    /// A slot representing the place of the topmost node in the tree.
    case Root
    /// A slot representing the child towards a certain direction under a certain parent node in the tree.
    case Toward(RedBlackDirection, under: Handle)
}
internal func ==<Config: RedBlackConfig, Payload>(a: RedBlackSlot<Config, Payload>, b: RedBlackSlot<Config, Payload>) -> Bool {
    return a == b
}



internal struct RedBlackNode<Config: RedBlackConfig, Payload> {
    typealias Handle = RedBlackHandle<Config, Payload>
    typealias Reduction = Config.Reduction
    typealias Head = Reduction.Item

    private(set) var parent: Handle?
    private(set) var left: Handle?
    private(set) var right: Handle?

    private(set) var head: Head
    private(set) var reduction: Reduction

    private(set) var payload: Payload

    private(set) var color: Color

    private init(parent: Handle?, head: Head, payload: Payload) {
        self.parent = parent
        self.left = nil
        self.right = nil
        self.head = head
        self.reduction = Reduction(head)
        self.payload = payload
        self.color = .Red
    }

    internal subscript(direction: RedBlackDirection) -> Handle? {
        get {
            switch direction {
            case .Left: return left
            case .Right: return right
            }
        }
        mutating set(handle) {
            switch direction {
            case .Left: left = handle
            case .Right: right = handle
            }
        }
    }
}

public struct RedBlackTree<Config: RedBlackConfig, Payload> {
    //MARK: Type aliases

    public typealias Handle = RedBlackHandle<Config, Payload>
    public typealias Reduction = Config.Reduction
    public typealias Head = Reduction.Item
    public typealias Key = Config.Key

    public typealias Element = (Key, Payload)

    internal typealias Node = RedBlackNode<Config, Payload>
    internal typealias Slot = RedBlackSlot<Config, Payload>

    //MARK: Stored properties

    internal private(set) var nodes: ContiguousArray<Node>

    /// The handle of the root node of the tree, or nil if the tree is empty.
    public private(set) var root: Handle?

    /// The handle of the leftmost node of the tree, or nil if the tree is empty.
    public private(set) var leftmost: Handle?

    /// The handle of the rightmost node of the tree, or nil if the tree is empty.
    public private(set) var rightmost: Handle?

    /// Initializes an empty tree.
    public init() {
        nodes = []
        root = nil
        leftmost = nil
        rightmost = nil
    }
}

//MARK: Initializers

public extension RedBlackTree {

    public init<C: CollectionType where C.Generator.Element == (Key, Payload)>(_ elements: C) {
        self.init()
        self.reserveCapacity(Int(elements.count.toIntMax()))
        for (key, payload) in elements {
            self.insert(key, payload: payload)
        }
    }

    public mutating func reserveCapacity(minimumCapacity: Int) {
        nodes.reserveCapacity(minimumCapacity)
    }
}

//MARK: Count of nodes

public extension RedBlackTree {
    /// The number of nodes in the tree.
    public var count: Int { return nodes.count }
    public var isEmpty: Bool { return nodes.isEmpty }
}

//MARK: Looking up a handle.

public extension RedBlackTree {

    /// Returns or updates the node at `handle`.
    /// - Complexity: O(1)
    internal private(set) subscript(handle: Handle) -> Node {
        get {
            return nodes[handle.index]
        }
        set(node) {
            nodes[handle.index] = node
        }
    }

    /// Returns the node at `handle`, or nil if `handle` is nil.
    /// - Complexity: O(1)
    internal subscript(handle: Handle?) -> Node? {
        guard let handle = handle else { return nil }
        return self[handle] as Node
    }

    /// Returns the payload of the node at `handle`.
    /// - Complexity: O(1)
    public func payloadAt(handle: Handle) -> Payload {
        return self[handle].payload
    }

    /// Updates the payload of the node at `handle`.
    /// - Returns: The previous payload of the node.
    /// - Complexity: O(1)
    public mutating func setPayloadAt(handle: Handle, to payload: Payload) -> Payload {
        var node = self[handle]
        let old = node.payload
        node.payload = payload
        self[handle] = node
        return old
    }

    /// Returns the key of the node at `handle`.
    /// - Complexity: O(log(count)) if the reduction is non-empty; O(1) otherwise.
    /// - Note: If you need to get the key for a range of nodes, and you have a non-empty reduction, using a generator
    ///   is faster than querying the keys of each node one by one.
    /// - SeeAlso: `generate`, `generateFrom`
    public func keyAt(handle: Handle) -> Key {
        let node = self[handle]
        let prefix = reductionOfAllNodesBefore(handle)
        return Config.key(node.head, reducedPrefix: prefix)
    }

    /// Returns a typle containing the key and payload of the node at `handle`.
    /// - Complexity: O(log(count)) if the reduction is non-empty; O(1) otherwise.
    /// - Note: If you need to get the key for a range of nodes, and you have a non-empty reduction, using a generator
    ///   is faster than querying the keys of each node one by one.
    /// - SeeAlso: `generate`, `generateFrom`
    public func elementAt(handle: Handle) -> Element {
        return (keyAt(handle), self[handle].payload)
    }

    /// Returns the head of the node at `handle`.
    /// - Complexity: O(1)
    public func headAt(handle: Handle) -> Head {
        return self[handle].head
    }

    /// Updates the head of the node at `handle`. 
    ///
    /// It is only supported to change the head when a the new value does
    /// not affect the order of the nodes already in the tree. New keys of nodes before or equal to `handle` must match
    /// their previous ones, but keys of nodes above `handle` may be changed -- as long as the ordering stays constant.
    ///
    /// - Note: Being able to update the head is useful when the reduction is a summation, 
    ///   like in a tree implementing a concatenation of arrays, where each array's handle range in the resulting 
    ///   collection is a count of elements in all arrays before it. Here, the head of node is the count of its
    ///   payload array. When the count changes, handles after the modified array change too, but their ordering remains
    ///   the same. Calling `setHead` is ~3 times faster than just removing and re-adding the node.
    ///
    /// - Requires: The key of the old node must match the new node. `compare(key(old, prefix), new, prefix) == .Match`
    ///
    /// - Warning: Changing the head to a value that changes the ordering of items will break ordering in the tree. 
    ///   In unoptimized builds, the implementation throws a fatal error if the above expression evaluates to false, 
    ///   but this is elided from optimized builds. You should know what you're doing.
    ///
    /// - Returns: The previous head of the node.
    ///
    /// - Complexity: O(log(count))
    ///
    public mutating func setHeadAt(handle: Handle, to head: Head) -> Head {
        var node = self[handle]
        assert({
            let prefix = reductionOfAllNodesBefore(handle) // This is O(log(n)) -- which is why this is not in a precondition.
            let key = Config.key(node.head, reducedPrefix: prefix)
            return Config.compare(key, to: head, reducedPrefix: prefix) == .Matching
            }())
        let old = node.head
        node.head = head
        self[handle] = node
        updateReductionsAtAndAbove(handle)
        return old
    }
}

//MARK: Inorder walk

extension RedBlackTree {

    public func successor(handle: Handle) -> Handle? {
        return step(handle, toward: .Right)
    }

    public func predecessor(handle: Handle) -> Handle? {
        return step(handle, toward: .Left)
    }

    public func step(handle: Handle, toward direction: RedBlackDirection) -> Handle? {
        let node = self[handle]
        if let next = node[direction] {
            return handleOfFurthestNodeUnder(next, toward: direction.opposite)
        }

        var child = handle
        var parent = node.parent
        while let p = parent {
            let n = self[p]
            if n[direction] != child { return p }
            child = p
            parent = n.parent
        }
        return nil
    }

    public func handleOfLeftmostNodeUnder(handle: Handle) -> Handle {
        return handleOfFurthestNodeUnder(handle, toward: .Left)
    }

    public func handleOfRightmostNodeUnder(handle: Handle) -> Handle {
        return handleOfFurthestNodeUnder(handle, toward: .Right)
    }
    
    public func handleOfFurthestNodeUnder(handle: Handle, toward direction: RedBlackDirection) -> Handle {
        var handle = handle
        while let next = self[handle][direction] {
            handle = next
        }
        return handle
    }
}


//MARK: Generating all items in the tree

public struct RedBlackGenerator<Config: RedBlackConfig, Payload>: GeneratorType {
    typealias Tree = RedBlackTree<Config, Payload>
    private let tree: Tree
    private var handle: Tree.Handle?
    private var reduction: Tree.Reduction

    public mutating func next() -> Tree.Element? {
        guard let handle = handle else { return nil }
        let node = tree[handle]
        let key = Config.key(node.head, reducedPrefix: reduction)
        reduction = reduction + node.head
        self.handle = tree.successor(handle)
        return (key, node.payload)
    }
}

extension RedBlackTree: SequenceType {
    public typealias Generator = RedBlackGenerator<Config, Payload>

    /// Return a generator that provides an ordered list of all (key, payload) pairs that are currently in the tree.
    /// - Complexity: O(1) to get the generator; O(count) to retrieve all elements.
    public func generate() -> Generator {
        return RedBlackGenerator(tree: self, handle: leftmost, reduction: Reduction())
    }

    /// Return a generator that provides an ordered list of (key, payload) pairs that are at or after `handle`.
    /// - Complexity: O(1) to get the generator; O(count) to retrieve all elements.
    public func generateFrom(handle: Handle) -> Generator {
        return RedBlackGenerator(tree: self, handle: handle, reduction: Reduction())
    }
}

//MARK: Searching in the tree

extension RedBlackTree {
    internal func find(key: Key, @noescape step: (Handle, KeyMatchResult)->KeyMatchResult) {
        if sizeof(Reduction.self) == 0 {
            var handle = self.root
            while let h = handle {
                let node = self[h]
                let match = Config.compare(key, to: node.head, reducedPrefix: Reduction())
                switch step(h, match) {
                case .Before: handle = node.left
                case .Matching: return
                case .After: handle = node.right
                }
            }
        }
        else {
            var handle = self.root
            var reduction = Reduction()
            while let h = handle {
                let node = self[h]
                let r = reduction + self[node.left]?.reduction
                let match = Config.compare(key, to: node.head, reducedPrefix: r)
                switch step(h, match) {
                case .Before:
                    handle = node.left
                case .Matching:
                    return
                case .After:
                    reduction = r + node.head
                    handle = node.right
                }
            }
        }
    }

    /// Finds and returns the handle of a node that matches `key`, or nil if no such node exists.
    /// - Complexity: O(log(count))
    public func find(key: Key) -> Handle? {
        // Topmost is the best, since it terminates on the first match.
        return handleOfTopmostNodeMatching(key)
    }

    /// Finds and returns the handle of the topmost node that matches `key`, or nil if no such node exists.
    /// - Complexity: O(log(count))
    public func handleOfTopmostNodeMatching(key: Key) -> Handle? {
        var result: Handle? = nil
        find(key) { handle, match in
            if match == .Matching {
                result = handle
            }
            return match
        }
        return result
    }

    /// Finds and returns the handle of the leftmost node that matches `key`, or nil if no such node exists.
    /// - Complexity: O(log(count))
    public func handleOfLeftmostNodeMatching(key: Key) -> Handle? {
        var result: Handle? = nil
        find(key) { handle, match in
            switch match {
            case .Before:
                return .Before
            case .Matching:
                result = handle
                return .Before
            case .After:
                return .After
            }
        }
        return result
    }

    /// Finds and returns the handle of the leftmost node that matches `key` or is after it, or nil if no such node exists.
    /// - Complexity: O(log(count))
    public func handleOfLeftmostNodeMatchingOrAfter(key: Key) -> Handle? {
        var result: Handle? = nil
        find(key) { handle, match in
            switch match {
            case .Before:
                result = handle
                return .Before
            case .Matching:
                result = handle
                return .Before
            case .After:
                return .After
            }
        }
        return result
    }

    /// Finds and returns the handle of the leftmost node that sorts after `key`, or nil if no such node exists.
    /// - Complexity: O(log(count))
    public func handleOfLeftmostNodeAfter(key: Key) -> Handle? {
        var result: Handle? = nil
        find(key) { handle, match in
            switch match {
            case .Before:
                result = handle
                return .Before
            case .Matching:
                return .After
            case .After:
                return .After
            }
        }
        return result
    }

    /// Finds and returns the handle of the rightmost node that matches `key`, or nil if no such node exists.
    /// - Complexity: O(log(count))
    public func handleOfRightmostNodeMatching(key: Key) -> Handle? {
        var result: Handle? = nil
        find(key) { handle, match in
            switch match {
            case .Before:
                return .Before
            case .Matching:
                result = handle
                return .After
            case .After:
                return .After
            }
        }
        return result
    }

    /// Finds and returns the handle of the rightmost node that sorts before `key`, or nil if no such node exists.
    /// - Complexity: O(log(count))
    public func handleOfRightmostNodeBefore(key: Key) -> Handle? {
        var result: Handle? = nil
        find(key) { handle, match in
            switch match {
            case .Before:
                return .Before
            case .Matching:
                return .Before
            case .After:
                result = handle
                return .After
            }
        }
        return result
    }

    /// Finds and returns the handle of the rightmost node that sorts before or matches `key`, or nil if no such node exists.
    /// - Complexity: O(log(count))
    public func handleOfRightmostNodeBeforeOrMatching(key: Key) -> Handle? {
        var result: Handle? = nil
        find(key) { handle, match in
            switch match {
            case .Before:
                return .Before
            case .Matching:
                result = handle
                return .After
            case .After:
                result = handle
                return .After
            }
        }
        return result
    }
}

//MARK: Managing the reduction data

extension RedBlackTree {
    /// Updates the reduction cached at `handle`, assuming that the children have up-to-date data.
    /// - Complexity: O(1) - 3 lookups
    private mutating func updateReductionAt(handle: Handle) {
        guard sizeof(Reduction.self) > 0 else { return }
        var node = self[handle]
        node.reduction = self[node.left]?.reduction + node.head + self[node.right]?.reduction
        self[handle] = node
    }

    /// Updates the reduction cached at `handle` and its ancestors, assuming that all other nodes have up-to-date data.
    /// - Complexity: O(log(count)) for nonempty reductions, O(1) when the reduction is empty.
    private mutating func updateReductionsAtAndAbove(handle: Handle?) {
        guard sizeof(Reduction.self) > 0 else { return }
        var handle: Handle? = handle
        while let h = handle {
            self.updateReductionAt(h)
            handle = self[h].parent
        }
    }

    /// Returns the reduction calculated over the sequence all nodes preceding `handle` in the tree.
    /// - Complexity: O(log(count) for nonempty reductions, O(1) when the reduction is empty.
    private func reductionOfAllNodesBefore(handle: Handle) -> Reduction {
        func reductionOfLeftSubtree(handle: Handle) -> Reduction {
            guard sizeof(Reduction.self) > 0 else { return Reduction() }
            guard let left = self[handle].left else { return Reduction() }
            return self[left].reduction
        }

        guard sizeof(Reduction.self) > 0 else { return Reduction() }
        var handle = handle
        var reduction = reductionOfLeftSubtree(handle)
        while case .Toward(let direction, under: let parent) = slotOf(handle) {
            if direction == .Right {
                reduction = reductionOfLeftSubtree(parent) + self[parent].reduction + reduction
            }
            handle = parent
        }
        return reduction
    }
}

//MARK: Rotation

extension RedBlackTree {
    /// Rotates the subtree rooted at `handle` in the specified direction. Used when the tree implements
    /// a binary search tree.
    ///
    /// The child towards the opposite of `direction` under `handle` becomes the new root,
    /// and the previous root becomes its child towards `dir`. The rest of the children
    /// are linked up to preserve ordering in a binary search tree.
    ///
    /// - Returns: The handle of the new root of the subtree.
    internal mutating func rotate(handle: Handle, _ dir: RedBlackDirection) -> Handle {
        let x = handle
        let opp = dir.opposite
        guard let y = self[handle][opp] else { fatalError("Invalid rotation") }

        var xn = self[x]
        var yn = self[y]

        //      x                y
        //     / \              / \
        //    a   y    <-->    x   c
        //       / \          / \
        //      b   c        a   b

        let b = yn[dir]

        yn.parent = xn.parent
        xn.parent = y
        yn[dir] = x

        xn[opp] = b
        if let b = b { self[b].parent = x }

        self[x] = xn
        self[y] = yn

        if root == x { root = y }
        // leftmost, rightmost are invariant under rotations

        self.updateReductionAt(x)
        self.updateReductionAt(y)

        return y
    }
}

//MARK: Inserting an individual element
extension RedBlackTree {
    internal func slotOf(handle: Handle) -> Slot {
        guard let parent = self[handle].parent else { return .Root }
        let pn = self[parent]
        let direction: RedBlackDirection = (handle == pn.left ? .Left : .Right)
        return .Toward(direction, under: parent)
    }

    private func compare(key: Key, with handle: Handle) -> KeyMatchResult {
        let reduction = reductionOfAllNodesBefore(handle)
        return Config.compare(key, to: self[handle].head, reducedPrefix: reduction)
    }


    public mutating func insert(key: Key, payload: Payload) -> Handle {
        func insertionSlotOf(key: Key) -> Slot {
            var slot: Slot = .Root
            self.find(key) { handle, match in
                switch match {
                case .Before:
                    slot = .Toward(.Left, under: handle)
                    return .Before
                case .Matching:
                    slot = .Toward(.Right, under: handle)
                    return .After
                case .After:
                    slot = .Toward(.Right, under: handle)
                    return .After
                }
            }
            return slot
        }

        let slot = insertionSlotOf(key)
        return insert(key, payload: payload, into: slot)
    }

    public mutating func insert(key: Key, payload: Payload, after predecessor: Handle) -> Handle {
        assert(predecessor == self.handleOfRightmostNodeBefore(key) || compare(key, with: predecessor) == .Matching)
        let node = self[predecessor]
        if let right = node.right {
            let next = handleOfLeftmostNodeUnder(right)
            return insert(key, payload: payload, into: .Toward(.Left, under: next))
        }
        else {
            return insert(key, payload: payload, into: .Toward(.Right, under: predecessor))
        }
    }

    public mutating func insert(key: Key, payload: Payload, before successor: Handle) -> Handle {
        assert(successor == self.handleOfLeftmostNodeAfter(key) || compare(key, with: successor) == .Matching)
        let node = self[successor]
        if let left = node.left {
            let previous = handleOfRightmostNodeUnder(left)
            return insert(key, payload: payload, into: .Toward(.Right, under: previous))
        }
        else {
            return insert(key, payload: payload, into: .Toward(.Left, under: successor))
        }
    }

    private mutating func insert(key: Key, payload: Payload, into slot: Slot) -> Handle {
        let handle = Handle(nodes.count)
        switch slot {
        case .Root:
            assert(nodes.isEmpty)
            self.root = handle
            self.leftmost = handle
            self.rightmost = handle
            nodes.append(Node(parent: nil, head: Config.head(key), payload: payload))
        case .Toward(let direction, under: let parent):
            assert(self[parent][direction] == nil)
            self[parent][direction] = handle
            nodes.append(Node(parent: parent, head: Config.head(key), payload: payload))
            if leftmost == parent && direction == .Left { leftmost = handle }
            if rightmost == parent && direction == .Right { rightmost = handle }
            updateReductionsAtAndAbove(parent)
        }

        if sizeof(Reduction.self) > 0 {
            // Update reductions
            var parent = self[handle].parent
            while let p = parent {
                var pn = self[p]
                pn.reduction = self[pn.left]?.reduction + pn.head + self[pn.right]?.reduction
                self[p] = pn
                parent = self[p].parent
            }
        }

        rebalanceAfterInsertion(handle)
        return handle
    }
}

//MARK: Append and merge

extension RedBlackTree {

    public mutating func append(tree: RedBlackTree<Config, Payload>) {
        func ordered(a: (RedBlackTree<Config, Payload>, Handle, Reduction), before b: (RedBlackTree<Config, Payload>, Handle, Reduction)) -> Bool {
            let ak = Config.key(a.0[a.1].head, reducedPrefix: a.2)
            return Config.compare(ak, to: b.0[b.1].head, reducedPrefix: b.2) != .After
        }

        guard let b1 = rightmost else { self = tree; return }
        guard let c2 = tree.leftmost else { return }

        let rb = reductionOfAllNodesBefore(b1)
        let rc = rb + self[b1].head
        precondition(ordered((self, b1, rb), before: (tree, c2, rc)))

        var reduction = rc
        var previous1 = b1
        var next2: Handle? = c2
        while let h2 = next2 {
            let node2 = tree[h2]
            previous1 = self.insert(Config.key(node2.head, reducedPrefix: reduction), payload: node2.payload, after: previous1)
            reduction = reduction + node2.head
            next2 = tree.successor(h2)
        }
    }

    public mutating func merge(tree: RedBlackTree<Config, Payload>) {
        if tree.count > self.count {
            let copy = self
            self = tree
            self.merge(copy)
            return
        }
        var handle = tree.leftmost
        var reduction = Reduction()
        while let h = handle {
            let node = tree[h]
            let key = Config.key(node.head, reducedPrefix: reduction)
            reduction = reduction + node.head
            self.insert(key, payload: node.payload)
            handle = tree.successor(h)
        }
    }
}

//MARK: Removal of nodes

extension RedBlackTree {
    /// Remove the node at `handle`, invalidating all existing handles.
    /// - Note: You can use the returned handle to continue operating on the tree without having to find your place again.
    /// - Returns: The handle of the node that used to follow the removed node in the original tree, or nil if 
    ///   `handle` was at the rightmost position.
    /// - Complexity: O(log(count))
    public mutating func removeAndReturnSuccessor(handle: Handle) -> Handle? {
        return _remove(handle, successor: successor(handle))
    }

    /// Remove the node at `handle`, invalidating all existing handles.
    /// - Note: You need to discard your existing handles into the tree after you call this method.
    /// - SeeAlso: `removeAndReturnSuccessor`
    /// - Complexity: O(log(count))
    public mutating func remove(handle: Handle) {
        _remove(handle, successor: nil)
    }

    /// Remove a node, keeping track of its successor.
    /// - Returns: The handle of `successor` after the removal.
    private mutating func _remove(handle: Handle, successor: Handle?) -> Handle? {
        assert(handle != successor)
        // Fixme: Removing from a red-black tree is one ugly algorithm.
        let node = self[handle]
        if let _ = node.left, r = node.right {
            // We can't directly remove a node with two children, but its successor is suitable.
            // Let's remove it instead, placing its payload into handle.
            let next = successor ?? handleOfLeftmostNodeUnder(r)
            let n = self[next]
            self[handle].head = n.head
            self[handle].payload = n.payload
            // Note that the above doesn't change root, leftmost, rightmost.
            // The reduction will be updated on the way up.
            return _remove(next, keeping: handle)
        }
        else {
            return _remove(handle, keeping: successor)
        }
    }

    /// Remove a node with at most one child, while keeping track of another handle.
    /// - Returns: The handle of `marker` after the removal.
    private mutating func _remove(handle: Handle, keeping marker: Handle?) -> Handle? {
        let node = self[handle]
        let slot = slotOf(handle)
        assert(node.left == nil || node.right == nil)

        let child = node.left ?? node.right
        if let child = child {
            var n = self[child]
            n.parent = node.parent
            self[child] = n
        }
        if case .Toward(let d, under: let p) = slot {
            self[p][d] = child
        }

        if root == handle { root = child }
        if leftmost == handle { leftmost = child ?? node.parent }
        if rightmost == handle { rightmost = child ?? node.parent }

        updateReductionsAtAndAbove(node.parent)

        if node.color == .Black {
            rebalanceAfterRemoval(slot)
        }

        return deleteUnlinkedHandle(handle, keeping: marker)
    }

    private mutating func deleteUnlinkedHandle(removed: Handle, keeping marker: Handle?) -> Handle? {
        let last = Handle(nodes.count - 1)
        if removed == last {
            nodes.removeLast()
            return marker
        }
        else {
            // Move the last node into handle, and remove its original place instead.
            let node = nodes.removeLast()
            self[removed] = node
            if case .Toward(let d, under: let p) = slotOf(last) { self[p][d] = removed }
            if let l = node.left { self[l].parent = removed }
            if let r = node.right { self[r].parent = removed }

            if root == last { root = removed }
            if leftmost == last { leftmost = removed }
            if rightmost == last { rightmost = removed }

            return marker == last ? removed : marker
        }
    }

    private mutating func rebalanceAfterRemoval(slot: Slot) {
        var slot = slot
        while case .Toward(let dir, under: let parent) = slot {
            let opp = dir.opposite
            let sibling = self[parent][opp]! // there's a missing black in slot, so it definitely has a sibling tree.
            let siblingNode = self[sibling]
            if siblingNode.color == .Red { // Case (1) in [CLRS]
                //       parent(B)[b+1]                   label(c)[rank]
                //      /         \                            c: R for red, B for black
                //   slot        sibling(R)                    rank: black count in subtree
                //   [b-1]        /      \
                //              [b]      [b]
                assert(isBlack(parent) && self[sibling].left != nil && self[sibling].right != nil)
                self.rotate(parent, dir)
                setBlack(sibling)
                setRed(parent)
                // Old sibling is now above the parent; new sibling is black.
                continue
            }
            let farNephew = siblingNode[opp]
            if let farNephew = farNephew where isRed(farNephew) { // Case (4) in [CLRS]
                //       parent[b+1]
                //       /         \
                //   slot       sibling(B)[b]
                //  [b-1]       /      \
                //           [b-1]   farNephew(R)[b-1]
                self.rotate(parent, dir)
                self[sibling].color = self[parent].color
                setBlack(farNephew)
                setBlack(parent)
                // We sacrificed nephew's red to restore the black count above slot. We're done!
                return
            }
            let closeNephew = siblingNode[dir]
            if let closeNephew = closeNephew where isRed(closeNephew) { // Case (3) in [CLRS]
                //        parent
                //       /      \
                //   slot       sibling(B)
                //  [b-1]      /          \
                //        closeNephew(R)  farNephew(B)
                //           [b-1]           [b-1]
                self.rotate(sibling, opp)
                self.rotate(parent, dir)
                self[closeNephew].color = self[parent].color
                setBlack(parent)
                // We've sacrificed the close nephew's red to restore the black count above slot. We're done!
                return
            }
            else { // Case (2) in [CLRS]
                //        parent
                //       /      \
                //   slot       sibling(B)
                //  [b-1]      /          \
                //        closeNephew(B)  farNephew(B)
                //           [b-1]           [b-1]

                // We are allowed to paint the sibling red, creating a missing black.
                setRed(sibling)

                if isRed(parent) { // We can finish this right now.
                    setBlack(parent)
                    return
                }
                // Repeat one level higher.
                slot = slotOf(parent)
            }
        }
    }
}

//MARK: Color management

extension RedBlackTree {
    /// Only non-nil nodes may be red.
    private func isRed(handle: Handle?) -> Bool {
        guard let handle = handle else { return false }
        return self[handle].color == .Red
    }
    /// Nil nodes are considered black.
    private func isBlack(handle: Handle?) -> Bool {
        guard let handle = handle else { return true }
        return self[handle].color == .Black
    }
    /// Only non-nil nodes may be set red.
    private mutating func setRed(handle: Handle) {
        self[handle].color = .Red
    }
    /// You can set a nil node black, but it's a noop.
    private mutating func setBlack(handle: Handle?) {
        guard let handle = handle else { return }
        self[handle].color = .Black
    }
}

//MARK: Rebalancing after an insertion
extension RedBlackTree {

    private mutating func rebalanceAfterInsertion(new: Handle) {
        var child = new
        while case .Toward(let dir, under: let parent) = slotOf(child) {
            assert(isRed(child))
            guard self[parent].color == .Red else { break }
            guard case .Toward(let pdir, under: let grandparent) = slotOf(parent) else  { fatalError("Invalid tree: root is red") }
            let popp = pdir.opposite

            if let aunt = self[grandparent][popp] where isRed(aunt) {
                //         grandparent(Black)
                //       /             \
                //     aunt(Red)     parent(Red)
                //                      |
                //                  child(Red)
                //
                setBlack(parent)
                setBlack(aunt)
                setRed(grandparent)
                child = grandparent
            }
            else if dir == popp {
                //         grandparent(Black)
                //       /             \
                //     aunt(Black)   parent(Red)
                //                    /         \
                //                  child(Red)   B
                //                    /   \
                //                   B     B
                self.rotate(parent, pdir)
                self.rotate(grandparent, popp)
                setBlack(child)
                setRed(grandparent)
                break
            }
            else {
                //         grandparent(Black)
                //       /             \
                //     aunt(Black)   parent(Red)
                //                    /      \
                //                   B    child(Red)
                //                           /    \
                //                          B      B
                self.rotate(grandparent, popp)
                setBlack(parent)
                setRed(grandparent)
                break
            }
        }
        setBlack(root)
    }
}

