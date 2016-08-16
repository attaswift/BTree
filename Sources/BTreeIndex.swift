//
//  BTreeIndex.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-11.
//  Copyright © 2015–2016 Károly Lőrentey.
//

/// An index into a collection that uses a B-tree for storage.
///
/// This index satisfies `Collection`'s requirement for O(1) access, but
/// it is only suitable for read-only processing -- most tree mutations will 
/// invalidate all existing indexes.
/// 
/// - SeeAlso: `BTreeCursor` for an efficient way to modify a batch of values in a B-tree.
public struct BTreeIndex<Key: Comparable, Value> {
    typealias Node = BTreeNode<Key, Value>
    typealias State = BTreeWeakPath<Key, Value>

    internal private(set) var state: State

    internal init(_ state: State) {
        self.state = state
    }
    
    /// Advance to the next index.
    ///
    /// - Requires: self is valid and not the end index.
    /// - Complexity: Amortized O(1).
    public mutating func increment() {
        state.moveForward()
    }
    
    /// Advance to the previous index.
    ///
    /// - Requires: self is valid and not the start index.
    /// - Complexity: Amortized O(1).
    public mutating func decrement() {
        state.moveBackward()
    }

    /// Advance this index by `distance` elements.
    ///
    /// - Complexity: O(log(*n*)) where *n* is the number of elements in the tree.
    public mutating func advance(by distance: Int) {
        state.move(toOffset: state.offset + distance)
    }

    @discardableResult
    public mutating func advance(by distance: Int, limitedBy limit: BTreeIndex) -> Bool {
        state.expectRoot(limit.state.root)
        if (distance >= 0 && state.offset + distance > limit.state.offset)
            || (distance < 0 && state.offset + distance < limit.state.offset) {
            self = limit
            return false
        }
        state.move(toOffset: state.offset + distance)
        return true
    }

    /// Return the next index after `self` in its collection.
    ///
    /// - Requires: self is valid and not the end index.
    /// - Complexity: Amortized O(1).
    public func successor() -> BTreeIndex {
        var result = self
        result.increment()
        return result
    }

    /// Return the index preceding `self` in its collection.
    ///
    /// - Requires: self is valid and not the start index.
    /// - Complexity: Amortized O(1).
    public func predecessor() -> BTreeIndex {
        var result = self
        result.decrement()
        return result
    }

    /// Return the result of advancing `self` by `n` positions.
    /// 
    /// - Complexity: O(log(`n`))
    public func advanced(by n: Int) -> BTreeIndex {
        var result = self
        result.advance(by: n)
        return result
    }

    /// Return the result of advancing self by `n` positions, or until it equals `limit`.
    ///
    /// - Complexity: O(log(`n`))
    public func advanced(by n: Int, limit: BTreeIndex) -> BTreeIndex? {
        state.expectRoot(limit.state.root)
        let d = self.distance(to: limit)
        if d > 0 ? d < n : d > n {
            return nil
        }
        return self.advanced(by: n)
    }

    /// Return the number of steps between `self` an `end`.
    ///
    /// - Complexity: O(1)
    public func distance(to end: BTreeIndex) -> Int {
        state.expectRoot(end.state.root)
        return end.state.offset - state.offset
    }
}

extension BTreeIndex: Comparable {
    /// Return true iff `a` is equal to `b`.
    public static func ==(a: BTreeIndex, b: BTreeIndex) -> Bool {
        guard let ar = a.state._root.value else { a.state.invalid() }
        guard let br = b.state._root.value else { b.state.invalid() }
        precondition(ar === br, "Indices to different trees cannot be compared")
        return a.state.offset == b.state.offset
    }

    /// Return true iff `a` is less than `b`.
    public static func <(a: BTreeIndex, b: BTreeIndex) -> Bool {
        guard let ar = a.state._root.value else { a.state.invalid() }
        guard let br = b.state._root.value else { b.state.invalid() }
        precondition(ar === br, "Indices to different trees cannot be compared")
        return a.state.offset < b.state.offset
    }
}

/// A mutable path in a B-tree, holding weak references to nodes on the path.
/// This path variant does not support modifying the tree itself; it is suitable for use in indices.
///
/// After a path of this kind has been created, the original tree might mutated in a way that invalidates
/// the path, setting some of its weak references to nil, or breaking the consistency of its trail of slot indices.
/// The path checks for this during navigation, and traps if it finds itself invalidated.
///
internal struct BTreeWeakPath<Key: Comparable, Value>: BTreePath {
    typealias Node = BTreeNode<Key, Value>

    var _root: Weak<Node>
    var offset: Int

    var _path: [Weak<Node>]
    var _slots: [Int]
    var _node: Weak<Node>
    var slot: Int?

    init(root: Node) {
        self._root = Weak(root)
        self.offset = root.count
        self._path = []
        self._slots = []
        self._node = Weak(root)
        self.slot = nil
    }

    var root: Node {
        guard let root = _root.value else { invalid() }
        return root
    }
    var count: Int { return root.count }
    var length: Int { return _path.count + 1}

    var node: Node {
        guard let node = _node.value else { invalid() }
        return node
    }
    
    internal func expectRoot(_ root: Node) {
        expectValid(_root.value === root)
    }

    internal func expectValid(_ expression: @autoclosure (Void) -> Bool, file: StaticString = #file, line: UInt = #line) {
        precondition(expression(), "Invalid BTreeIndex", file: file, line: line)
    }

    internal func invalid(_ file: StaticString = #file, line: UInt = #line) -> Never  {
        preconditionFailure("Invalid BTreeIndex", file: file, line: line)
    }

    mutating func popFromSlots() {
        assert(self.slot != nil)
        let node = self.node
        offset += node.count - node.offset(ofSlot: slot!)
        slot = nil
    }

    mutating func popFromPath() {
        assert(_path.count > 0 && slot == nil)
        let child = node
        _node = _path.removeLast()
        expectValid(node.children[_slots.last!] === child)
        slot = _slots.removeLast()
    }

    mutating func pushToPath() {
        assert(self.slot != nil)
        let child = node.children[slot!]
        _path.append(_node)
        _node = Weak(child)
        _slots.append(slot!)
        slot = nil
    }

    mutating func pushToSlots(_ slot: Int, offsetOfSlot: Int) {
        assert(self.slot == nil)
        offset -= node.count - offsetOfSlot
        self.slot = slot
    }

    func forEach(ascending: Bool, body: (Node, Int) -> Void) {
        if ascending {
            var child: Node? = node
            body(child!, slot!)
            for i in (0 ..< _path.count).reversed() {
                guard let node = _path[i].value else { invalid() }
                let slot = _slots[i]
                expectValid(node.children[slot] === child)
                child = node
                body(node, slot)
            }
        }
        else {
            for i in 0 ..< _path.count {
                guard let node = _path[i].value else { invalid() }
                let slot = _slots[i]
                expectValid(node.children[slot] === (i < _path.count - 1 ? _path[i + 1].value : _node.value))
                body(node, slot)
            }
            body(node, slot!)
        }
    }

    func forEachSlot(ascending: Bool, body: (Int) -> Void) {
        if ascending {
            body(slot!)
            _slots.reversed().forEach(body)
        }
        else {
            _slots.forEach(body)
            body(slot!)
        }
    }
}
