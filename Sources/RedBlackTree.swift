//
//  RedBlackTree2.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-17.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

public struct RedBlackIndex<Config: RedBlackConfig, Payload>: Equatable {
    private let _index: UInt32

    private init(_ index: Int) {
        self._index = UInt32(index)
    }

    private var index: Int { return Int(_index) }
}
public func ==<C: RedBlackConfig, P>(a: RedBlackIndex<C, P>, b: RedBlackIndex<C, P>) -> Bool {
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
    internal typealias Index = RedBlackIndex<Config, Payload>

    /// A slot representing the place of the topmost node in the tree.
    case Root
    /// A slot representing the child towards a certain direction under a certain parent node in the tree.
    case Toward(RedBlackDirection, under: Index)
}
internal func ==<Config: RedBlackConfig, Payload>(a: RedBlackSlot<Config, Payload>, b: RedBlackSlot<Config, Payload>) -> Bool {
    return a == b
}



internal struct RedBlackNode<Config: RedBlackConfig, Payload> {
    typealias Index = RedBlackIndex<Config, Payload>
    typealias Reduction = Config.Reduction
    typealias Head = Reduction.Item

    private(set) var parent: Index?
    private(set) var left: Index?
    private(set) var right: Index?

    private(set) var head: Head
    private(set) var reduction: Reduction

    private(set) var payload: Payload

    private(set) var color: Color

    private init(parent: Index?, head: Head, payload: Payload) {
        self.parent = parent
        self.left = nil
        self.right = nil
        self.head = head
        self.reduction = Reduction(head)
        self.payload = payload
        self.color = .Red
    }

    internal subscript(direction: RedBlackDirection) -> Index? {
        get {
            switch direction {
            case .Left: return left
            case .Right: return right
            }
        }
        mutating set(index) {
            switch direction {
            case .Left: left = index
            case .Right: right = index
            }
        }
    }
}

public struct RedBlackTree<Config: RedBlackConfig, Payload> {
    //MARK: Type aliases

    public typealias Index = RedBlackIndex<Config, Payload>
    public typealias Reduction = Config.Reduction
    public typealias Head = Reduction.Item
    public typealias Key = Config.Key

    public typealias Element = (Key, Payload)

    internal typealias Node = RedBlackNode<Config, Payload>
    internal typealias Slot = RedBlackSlot<Config, Payload>

    //MARK: Stored properties

    internal private(set) var nodes: ContiguousArray<Node>

    /// The index of the root node of the tree, or nil if the tree is empty.
    public private(set) var root: Index?

    /// The index of the leftmost node of the tree, or nil if the tree is empty.
    public private(set) var leftmost: Index?

    /// The index of the rightmost node of the tree, or nil if the tree is empty.
    public private(set) var rightmost: Index?

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

//MARK: Looking up an index.

public extension RedBlackTree {

    /// Returns or updates the node at `index`.
    /// - Complexity: O(1)
    internal private(set) subscript(index: Index) -> Node {
        get {
            return nodes[index.index]
        }
        set(node) {
            nodes[index.index] = node
        }
    }

    /// Returns the node at `index`, or nil if `index` is nil.
    /// - Complexity: O(1)
    internal subscript(index: Index?) -> Node? {
        guard let index = index else { return nil }
        return self[index] as Node
    }

    /// Returns the payload of the node at `index`.
    /// - Complexity: O(1)
    public func payloadOf(index: Index) -> Payload {
        return self[index].payload
    }

    /// Updates the payload of the node at `index`.
    /// - Returns: The previous payload of the node.
    /// - Complexity: O(1)
    public mutating func setPayload(payload: Payload, of index: Index) -> Payload {
        var node = self[index]
        let old = node.payload
        node.payload = payload
        self[index] = node
        return old
    }

    /// Returns the head of the node at `index`.
    /// - Complexity: O(1)
    public func headOf(index: Index) -> Head {
        return self[index].head
    }

    /// Updates the head of the node at `index`. 
    ///
    /// It is only supported to change the head when a the new value does
    /// not affect the order of the nodes already in the tree. New keys of nodes before or equal to `index` must match
    /// their previous ones, but keys of nodes above `index` may be changed -- as long as the ordering stays constant.
    ///
    /// - Note: Being able to update the head is useful when the reduction is a summation, 
    ///   like in a tree implementing a concatenation of arrays, where each array's index range in the resulting 
    ///   collection is a count of elements in all arrays before it. Here, the head of node is the count of its
    ///   payload array. When the count changes, indexes after the modified array change too, but their ordering remains
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
    public mutating func setHead(head: Head, of index: Index) -> Head {
        var node = self[index]
        assert({
            let prefix = reductionOfAllNodesBefore(index) // This is O(log(n)) -- which is why this is not in a precondition.
            let key = Config.key(node.head, reducedPrefix: prefix)
            return Config.compare(key, to: head, reducedPrefix: prefix) == .Matching
            }())
        let old = node.head
        node.head = head
        self[index] = node
        updateReductionsAtAndAbove(index)
        return old
    }
}

//MARK: Inorder walk

extension RedBlackTree {

    public func successor(index: Index) -> Index? {
        return step(index, to: .Right)
    }

    public func predecessor(index: Index) -> Index? {
        return step(index, to: .Left)
    }

    public func step(index: Index, to direction: RedBlackDirection) -> Index? {
        let node = self[index]
        if let next = node[direction] {
            return indexOfFurthestNodeUnder(next, toward: direction.opposite)
        }

        var child = index
        var parent = node.parent
        while let p = parent {
            let n = self[p]
            if n[direction] != child { return p }
            child = p
            parent = n.parent
        }
        return nil
    }

    public func indexOfLeftmostNodeUnder(index: Index) -> Index {
        return indexOfFurthestNodeUnder(index, toward: .Left)
    }

    public func indexOfRightmostNodeUnder(index: Index) -> Index {
        return indexOfFurthestNodeUnder(index, toward: .Right)
    }
    
    public func indexOfFurthestNodeUnder(index: Index, toward direction: RedBlackDirection) -> Index {
        var index = index
        while let next = self[index][direction] {
            index = next
        }
        return index
    }
}


//MARK: Generating all items in the tree

public struct RedBlackGenerator<Config: RedBlackConfig, Payload>: GeneratorType {
    typealias Tree = RedBlackTree<Config, Payload>
    private let tree: Tree
    private var index: Tree.Index?
    private var reduction: Tree.Reduction

    public mutating func next() -> Tree.Element? {
        guard let index = index else { return nil }
        let node = tree[index]
        let key = Config.key(node.head, reducedPrefix: reduction)
        reduction = reduction + node.head
        self.index = tree.successor(index)
        return (key, node.payload)
    }
}

extension RedBlackTree: SequenceType {
    public typealias Generator = RedBlackGenerator<Config, Payload>

    public func generate() -> Generator {
        return RedBlackGenerator(tree: self, index: leftmost, reduction: Reduction())
    }
}

//MARK: Searching in the tree

extension RedBlackTree {
    internal func find(key: Key, @noescape step: (Index, KeyMatchResult)->KeyMatchResult) {
        if sizeof(Reduction.self) == 0 {
            var index = self.root
            while let i = index {
                let node = self[i]
                let match = Config.compare(key, to: node.head, reducedPrefix: Reduction())
                switch step(i, match) {
                case .Before: index = node.left
                case .Matching: return
                case .After: index = node.right
                }
            }
        }
        else {
            var index = self.root
            var reduction = Reduction()
            while let i = index {
                let node = self[i]
                let r = reduction + self[node.left]?.reduction
                let match = Config.compare(key, to: node.head, reducedPrefix: r)
                switch step(i, match) {
                case .Before:
                    index = node.left
                case .Matching:
                    return
                case .After:
                    reduction = r + node.head
                    index = node.right
                }
            }
        }
    }

    /// Finds and returns the index of a node that matches `key`, or nil if no such node exists.
    /// - Complexity: O(log(count))
    public func find(key: Key) -> Index? {
        // Topmost is the best, since it terminates on the first match.
        return indexOfTopmostNodeMatching(key)
    }

    /// Finds and returns the index of the topmost node that matches `key`, or nil if no such node exists.
    /// - Complexity: O(log(count))
    public func indexOfTopmostNodeMatching(key: Key) -> Index? {
        var result: Index? = nil
        find(key) { index, match in
            if match == .Matching {
                result = index
            }
            return match
        }
        return result
    }

    /// Finds and returns the index of the leftmost node that matches `key`, or nil if no such node exists.
    /// - Complexity: O(log(count))
    public func indexOfLeftmostNodeMatching(key: Key) -> Index? {
        var result: Index? = nil
        find(key) { index, match in
            switch match {
            case .Before:
                return .Before
            case .Matching:
                result = index
                return .Before
            case .After:
                return .After
            }
        }
        return result
    }

    /// Finds and returns the index of the leftmost node that matches `key` or is after it, or nil if no such node exists.
    /// - Complexity: O(log(count))
    public func indexOfLeftmostNodeMatchingOrAfter(key: Key) -> Index? {
        var result: Index? = nil
        find(key) { index, match in
            switch match {
            case .Before:
                result = index
                return .Before
            case .Matching:
                result = index
                return .Before
            case .After:
                return .After
            }
        }
        return result
    }

    /// Finds and returns the index of the leftmost node that sorts after `key`, or nil if no such node exists.
    /// - Complexity: O(log(count))
    public func indexOfLeftmostNodeAfter(key: Key) -> Index? {
        var result: Index? = nil
        find(key) { index, match in
            switch match {
            case .Before:
                result = index
                return .Before
            case .Matching:
                return .After
            case .After:
                return .After
            }
        }
        return result
    }

    /// Finds and returns the index of the rightmost node that matches `key`, or nil if no such node exists.
    /// - Complexity: O(log(count))
    public func indexOfRightmostNodeMatching(key: Key) -> Index? {
        var result: Index? = nil
        find(key) { index, match in
            switch match {
            case .Before:
                return .Before
            case .Matching:
                result = index
                return .After
            case .After:
                return .After
            }
        }
        return result
    }

    /// Finds and returns the index of the rightmost node that sorts before `key`, or nil if no such node exists.
    /// - Complexity: O(log(count))
    public func indexOfRightmostNodeBefore(key: Key) -> Index? {
        var result: Index? = nil
        find(key) { index, match in
            switch match {
            case .Before:
                return .Before
            case .Matching:
                return .Before
            case .After:
                result = index
                return .After
            }
        }
        return result
    }

    /// Finds and returns the index of the rightmost node that sorts before or matches `key`, or nil if no such node exists.
    /// - Complexity: O(log(count))
    public func indexOfRightmostNodeBeforeOrMatching(key: Key) -> Index? {
        var result: Index? = nil
        find(key) { index, match in
            switch match {
            case .Before:
                return .Before
            case .Matching:
                result = index
                return .After
            case .After:
                result = index
                return .After
            }
        }
        return result
    }
}

//MARK: Managing the reduction data

extension RedBlackTree {
    /// Updates the reduction cached at `index`, assuming that the children have up-to-date data.
    /// - Complexity: O(1) - 3 lookups
    private mutating func updateReductionAt(index: Index) {
        guard sizeof(Reduction.self) > 0 else { return }
        var node = self[index]
        node.reduction = self[node.left]?.reduction + node.head + self[node.right]?.reduction
        self[index] = node
    }

    /// Updates the reduction cached at `index` and its ancestors, assuming that all other nodes have up-to-date data.
    /// - Complexity: O(log(count)) for nonempty reductions, O(1) when the reduction is empty.
    private mutating func updateReductionsAtAndAbove(index: Index) {
        guard sizeof(Reduction.self) > 0 else { return }
        var index: Index? = index
        while let i = index {
            self.updateReductionAt(i)
            index = self[i].parent
        }
    }

    /// Returns the reduction calculated over the sequence all nodes preceding `index` in the tree.
    /// - Complexity: O(log(count) for nonempty reductions, O(1) when the reduction is empty.
    private func reductionOfAllNodesBefore(index: Index) -> Reduction {
        func reductionOfLeftSubtree(index: Index) -> Reduction {
            guard sizeof(Reduction.self) < 0 else { return Reduction() }
            guard let left = self[index].left else { return Reduction() }
            return self[left].reduction
        }

        guard sizeof(Reduction.self) < 0 else { return Reduction() }
        var index = index
        var reduction = reductionOfLeftSubtree(index)
        while case .Toward(let direction, under: let parent) = slotOf(index) {
            if direction == .Right {
                reduction = reductionOfLeftSubtree(parent) + self[parent].reduction + reduction
            }
            index = parent
        }
        return reduction
    }
}

//MARK: Rotation

extension RedBlackTree {
    /// Rotates the subtree rooted at `index` in the specified direction. Used when the tree implements
    /// a binary search tree.
    ///
    /// The child towards the opposite of `direction` under `index` becomes the new root,
    /// and the previous root becomes its child towards `dir`. The rest of the children
    /// are linked up to preserve ordering in a binary search tree.
    ///
    /// - Returns: The index of the new root of the subtree.
    internal mutating func rotate(index: Index, _ dir: RedBlackDirection) -> Index {
        let x = index
        let opp = dir.opposite
        guard let y = self[index][opp] else { fatalError("Invalid rotation") }

        var xn = self[x]
        var yn = self[y]

        //     x                      y
        //  a      y    <-->     x        c
        //       b   c        a     b

        let b = yn[dir]

        yn.parent = xn.parent
        xn.parent = y
        yn[dir] = x

        xn[opp] = b
        if let b = b { self[b].parent = x }

        self[x] = xn
        self[y] = yn

        if root == x { root = y }

        self.updateReductionAt(x)
        self.updateReductionAt(y)

        return y
    }
}

//MARK: Inserting an individual element
extension RedBlackTree {
    internal func slotOf(index: Index) -> Slot {
        guard let parent = self[index].parent else { return .Root }
        let pn = self[parent]
        let direction: RedBlackDirection = (index == pn.left ? .Left : .Right)
        return .Toward(direction, under: parent)
    }

    private func compare(key: Key, with index: Index) -> KeyMatchResult {
        let reduction = reductionOfAllNodesBefore(index)
        return Config.compare(key, to: self[index].head, reducedPrefix: reduction)
    }


    public mutating func insert(key: Key, payload: Payload) -> Index {
        func insertionSlotOf(key: Key) -> Slot {
            var slot: Slot = .Root
            self.find(key) { index, match in
                switch match {
                case .Before:
                    slot = .Toward(.Left, under: index)
                    return .Before
                case .Matching:
                    slot = .Toward(.Right, under: index)
                    return .After
                case .After:
                    slot = .Toward(.Right, under: index)
                    return .After
                }
            }
            return slot
        }

        let slot = insertionSlotOf(key)
        return insert(key, payload: payload, into: slot)
    }

    public mutating func insert(key: Key, payload: Payload, after predecessor: Index) -> Index {
        assert(predecessor == self.indexOfRightmostNodeBefore(key) || compare(key, with: predecessor) == .Matching)
        let node = self[predecessor]
        if let right = node.right {
            let next = indexOfLeftmostNodeUnder(right)
            return insert(key, payload: payload, into: .Toward(.Left, under: next))
        }
        else {
            return insert(key, payload: payload, into: .Toward(.Right, under: predecessor))
        }
    }

    public mutating func insert(key: Key, payload: Payload, before successor: Index) -> Index {
        assert(successor == self.indexOfLeftmostNodeAfter(key) || compare(key, with: successor) == .Matching)
        let node = self[successor]
        if let left = node.left {
            let previous = indexOfRightmostNodeUnder(left)
            return insert(key, payload: payload, into: .Toward(.Right, under: previous))
        }
        else {
            return insert(key, payload: payload, into: .Toward(.Left, under: successor))
        }
    }

    private mutating func insert(key: Key, payload: Payload, into slot: Slot) -> Index {
        let index = Index(nodes.count)
        switch slot {
        case .Root:
            assert(nodes.isEmpty)
            self.root = index
            self.leftmost = index
            self.rightmost = index
            nodes.append(Node(parent: nil, head: Config.head(key), payload: payload))
        case .Toward(let direction, under: let parent):
            assert(self[parent][direction] == nil)
            self[parent][direction] = index
            nodes.append(Node(parent: parent, head: Config.head(key), payload: payload))
            if leftmost == parent && direction == .Left { leftmost = index }
            if rightmost == parent && direction == .Right { rightmost = index }
            updateReductionsAtAndAbove(parent)
        }

        if sizeof(Reduction.self) > 0 {
            // Update reductions
            var parent = self[index].parent
            while let p = parent {
                var pn = self[p]
                pn.reduction = self[pn.left]?.reduction + pn.head + self[pn.right]?.reduction
                self[p] = pn
                parent = self[p].parent
            }
        }

        rebalanceAfterInsertion(index)
        return index
    }
}

//MARK: Append and merge

extension RedBlackTree {

    public mutating func append(tree: RedBlackTree<Config, Payload>) {
        func ordered(a: (RedBlackTree<Config, Payload>, Index, Reduction), before b: (RedBlackTree<Config, Payload>, Index, Reduction)) -> Bool {
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
        var next2: Index? = c2
        while let i2 = next2 {
            let node2 = tree[i2]
            previous1 = self.insert(Config.key(node2.head, reducedPrefix: reduction), payload: node2.payload, after: previous1)
            reduction = reduction + node2.head
            next2 = tree.successor(i2)
        }
    }

    public mutating func merge(tree: RedBlackTree<Config, Payload>) {
        if tree.count > self.count {
            let copy = self
            self = tree
            self.merge(copy)
            return
        }
        var index = tree.leftmost
        var reduction = Reduction()
        while let i = index {
            let node = tree[i]
            let key = Config.key(node.head, reducedPrefix: reduction)
            reduction = reduction + node.head
            self.insert(key, payload: node.payload)
            index = tree.successor(i)
        }
    }
}

//MARK: Removal of nodes

extension RedBlackTree {
    /// Remove the node at `index`. 
    /// - Note: This operation invalidates all existing indexes. You can use the returned index to continue operating 
    ///   on the tree without having to find your place again.
    /// - Returns: The index of the node that used to follow the removed node in the original tree, or nil if 
    ///   `index` was at the rightmost position.
    /// - Complexity: O(log(count))
    public func remove(index: Index) -> Index? {
        // TODO
        return nil
    }

    private mutating func deleteUnlinkedIndex(removed: Index, updating index: Index) -> Index {
        let last = Index(nodes.count - 1)
        if removed == last {
            nodes.removeLast()
            return index
        }
        else {
            // Move the last node into index, and remove its original place instead.
            let node = nodes.removeLast()
            self[removed] = node
            if case .Toward(let d, under: let p) = slotOf(last) { self[p][d] = removed }
            if let l = node.left { self[l].parent = removed }
            if let r = node.right { self[r].parent = removed }
            if root == last { root = removed }
            if leftmost == last { leftmost = removed }
            if rightmost == last { rightmost = removed }
            return index == last ? removed : index
        }
    }
}

//MARK: Color management

extension RedBlackTree {
    /// Only non-nil nodes may be red.
    private func isRed(index: Index?) -> Bool {
        guard let index = index else { return false }
        return self[index].color == .Red
    }
    /// Nil nodes are considered black.
    private func isBlack(index: Index?) -> Bool {
        guard let index = index else { return true }
        return self[index].color == .Black
    }
    /// Only non-nil nodes may be set red.
    private mutating func setRed(index: Index) {
        self[index].color = .Red
    }
    /// You can set a nil node black, but it's a noop.
    private mutating func setBlack(index: Index?) {
        guard let index = index else { return }
        self[index].color = .Black
    }
}

//MARK: Rebalancing after an insertion
extension RedBlackTree {

    private mutating func rebalanceAfterInsertion(new: Index) {
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

