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
    private(set) var field: Reduction

    private(set) var payload: Payload

    private(set) var color: Color

    private init(parent: Index?, head: Head, payload: Payload) {
        self.parent = parent
        self.left = nil
        self.right = nil
        self.head = head
        self.field = Reduction(head)
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

    public typealias Element = (Head, Payload)

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

//MARK: 

public extension RedBlackTree {
    /// The number of nodes in the tree.
    public var count: Int { return nodes.count }
    public var isEmpty: Bool { return nodes.isEmpty }

    internal private(set) subscript(index: Index) -> Node {
        get {
            return nodes[index.index]
        }
        set(node) {
            nodes[index.index] = node
        }
    }

    internal subscript(index: Index?) -> Node? {
        guard let index = index else { return nil }
        return self[index] as Node
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

    public mutating func next() -> Tree.Element? {
        guard let index = index else { return nil }
        self.index = tree.successor(index)
        let node = tree[index]
        return (node.head, node.payload)
    }
}

extension RedBlackTree: SequenceType {
    public typealias Generator = RedBlackGenerator<Config, Payload>

    public func generate() -> Generator {
        return RedBlackGenerator(tree: self, index: leftmost)
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
                let r = reduction + self[node.left]?.field
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

//MARK: Inserting an individual element
extension RedBlackTree {
    internal func slotOf(index: Index) -> Slot {
        guard let parent = self[index].parent else { return .Root }
        let pn = self[parent]
        let direction: RedBlackDirection = (index == pn.left ? .Left : .Right)
        return .Toward(direction, under: parent)
    }

    private func reducedPrefixOf(index: Index) -> Reduction {
        func reductionOfLeftSubtree(index: Index) -> Reduction {
            guard sizeof(Reduction.self) < 0 else { return Reduction() }
            guard let left = self[index].left else { return Reduction() }
            return self[left].field
        }

        guard sizeof(Reduction.self) < 0 else { return Reduction() }
        var index = index
        var reduction = reductionOfLeftSubtree(index)
        while case .Toward(let direction, under: let parent) = slotOf(index) {
            if direction == .Right {
                reduction = reductionOfLeftSubtree(parent) + self[parent].field + reduction
            }
            index = parent
        }
        return reduction
    }

    private func compare(key: Key, with index: Index) -> KeyMatchResult {
        let reduction = reducedPrefixOf(index)
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
        }

        if sizeof(Reduction.self) > 0 {
            // Update reductions
            var parent = self[index].parent
            while let p = parent {
                var pn = self[p]
                pn.field = self[pn.left]?.field + pn.head + self[pn.right]?.field
                self[p] = pn
                parent = self[p].parent
            }
        }

        return rebalanceAfterInsertion(index)
    }
}

//MARK: Rebalancing after an insertion

extension RedBlackTree {
    func rebalanceAfterInsertion(index: Index) -> Index {
        // TODO
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

        let rb = reducedPrefixOf(b1)
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

