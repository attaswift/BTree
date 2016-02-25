//
//  BTreeIndex.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-11.
//  Copyright © 2015–2016 Károly Lőrentey.
//

/// An index into a collection that uses a b-tree for storage.
///
/// This index satisfies `CollectionType`'s requirement for O(1) access, but
/// it is only suitable for read-only processing -- most tree mutations will 
/// invalidate all existing indexes.
/// 
/// - SeeAlso: `BTreeCursor` for an efficient way to modify a batch of values in a b-tree.
public struct BTreeIndex<Key: Comparable, Payload>: BidirectionalIndexType {
    public typealias Distance = Int
    typealias Node = BTreeNode<Key, Payload>
    typealias State = BTreeWeakPath<Key, Payload>

    internal private(set) var state: State

    internal init(_ state: State) {
        self.state = state
    }
    
    /// Advance to the next index.
    ///
    /// - Requires: self is valid and not the end index.
    /// - Complexity: Amortized O(1).
    public mutating func successorInPlace() {
        state.moveForward()
    }
    
    /// Advance to the previous index.
    ///
    /// - Requires: self is valid and not the start index.
    /// - Complexity: Amortized O(1).
    public mutating func predecessorInPlace() {
        state.moveBackward()
    }

    /// Return the next index after `self` in its collection.
    ///
    /// - Requires: self is valid and not the end index.
    /// - Complexity: Amortized O(1).
    @warn_unused_result
    public func successor() -> BTreeIndex {
        var result = self
        result.successorInPlace()
        return result
    }

    /// Return the index preceding `self` in its collection.
    ///
    /// - Requires: self is valid and not the start index.
    /// - Complexity: Amortized O(1).
    @warn_unused_result
    public func predecessor() -> BTreeIndex {
        var result = self
        result.predecessorInPlace()
        return result
    }
}

/// Return true iff `a` is equal to `b`.
@warn_unused_result
public func == <Key: Comparable, Payload>(a: BTreeIndex<Key, Payload>, b: BTreeIndex<Key, Payload>) -> Bool {
    guard let ar = a.state._root.value else { a.state.invalid() }
    guard let br = b.state._root.value else { b.state.invalid() }
    precondition(ar === br, "Indices to different trees cannot be compared")
    return a.state.position == b.state.position
}

/// A mutable path in a b-tree, holding weak references to nodes on the path.
/// This path variant does not support modifying the tree itself; it is suitable for use in indices.
///
/// After a path of this kind has been created, the original tree might mutated in a way that invalidates
/// the path, setting some of its weak references to nil, or breaking the consistency of its trail of slot indices.
/// The path checks for this during navigation, and traps if it finds itself invalidated.
///
internal struct BTreeWeakPath<Key: Comparable, Payload>: BTreePath {
    typealias Node = BTreeNode<Key, Payload>

    var _root: Weak<Node>
    var path: [Weak<Node>]
    var slots: [Int]
    var position: Int

    var root: Node {
        guard let root = _root.value else { invalid() }
        return root
    }
    var length: Int { return path.count }
    var count: Int { return root.count }

    init(_ root: Node) {
        self._root = Weak(root)
        self.path = [Weak(root)]
        self.slots = []
        self.position = root.count
    }

    internal func expectRoot(root: Node) {
        expectValid(_root.value === root)
    }

    internal func expectValid(@autoclosure expression: Void->Bool, file: StaticString = __FILE__, line: UInt = __LINE__) {
        precondition(expression(), "Invalid BTreeCursor", file: file, line: line)
    }

    @noreturn internal func invalid(file: StaticString = __FILE__, line: UInt = __LINE__) {
        preconditionFailure("Invalid BTreeCursor", file: file, line: line)
    }

    var lastSlot: Int {
        get { return slots.last! }
        set { slots[slots.count - 1] = newValue }
    }

    var lastNode: Node {
        guard let node = path.last!.value else { invalid() }
        return node
    }

    mutating func popFromSlots() -> Int {
        assert(path.count == slots.count)
        let slot = slots.removeLast()
        let node = lastNode
        position += node.count - node.positionOfSlot(slot)
        return slot
    }

    mutating func popFromPath() -> Node {
        assert(path.count > 0 && path.count == slots.count + 1)
        guard let child = path.removeLast().value else { invalid() }
        expectValid(path.count == 0 || lastNode.children[slots.last!] === child)
        return child
    }

    mutating func pushToPath() -> Node {
        assert(path.count == slots.count)
        let parent = lastNode
        let slot = slots.last!
        let child = parent.children[slot]
        path.append(Weak(child))
        return child
    }

    mutating func pushToSlots(slot: Int, positionOfSlot: Int) {
        assert(path.count == slots.count + 1)
        let node = lastNode
        position -= node.count - positionOfSlot
        slots.append(slot)
    }

    func forEachAscending(@noescape body: (Node, Int) -> Void) {
        var child: Node? = nil
        for i in (0 ..< path.count).reverse() {
            guard let node = path[i].value else { invalid() }
            let slot = slots[i]
            expectValid(child == nil || node.children[slot] === child)
            child = node
            body(node, slot)
        }
    }
}
