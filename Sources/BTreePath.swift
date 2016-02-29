//
//  BTreePath.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-25.
//  Copyright © 2016 Károly Lőrentey.
//

/// A protocol that represents a mutable path from the root of a b-tree to one of its elements.
/// The extension methods defined on `BTreePath` provide a uniform way to navigate around in a b-tree,
/// independent of the details of the path representation.
///
/// There are three concrete implementations of this protocol:
///
/// - `BTreeStrongPath` holds strong references and doesn't support modifying the tree. It is used by `BTreeGenerator`.
/// - `BTreeWeakPath` holds weak references and doesn't support modifying the tree. It is used by `BTreeIndex`.
/// - `BTreeCursorPath` holds strong references and supports modifying the tree. It is used by `BTreeCursor`.
///
/// This protocol saves us from having to maintain three slightly different variants of the same navigation methods.
internal protocol BTreePath {
    typealias Key: Comparable
    typealias Payload

    /// Create a new incomplete path focusing at the root of a tree.
    init(_ root: Node)

    /// The root node of the underlying b-tree.
    var root: BTreeNode<Key, Payload> { get }

    /// The current position of this path. Setting this property changes the path to point at the given position.
    var position: Int { get set }

    /// The number of elements in the tree.
    var count: Int { get }

    /// The number of nodes on the path from the root to the node that holds the focused element, including both ends.
    var length: Int { get }

    /// The final node on the path; i.e., the node that holds the currently focused element.
    var node: BTreeNode<Key, Payload> { get }

    /// The final slot on the path, or `nil` if the path is currently incomplete.
    var slot: Int? { get set }

    /// Pop the last slot in `slots`, creating an incomplete path.
    /// The path's `position` is updated to the position of the element following the subtree at the last node.
    mutating func popFromSlots()

    /// Pop the last node in an incomplete path, focusing the element following its subtree.
    /// This restores the path to a completed state.
    mutating func popFromPath()

    /// Push the child node before the currently focused element on the path, creating an incomplete path.
    mutating func pushToPath()

    /// Push the specified slot onto `slots`, completing the path.
    /// The path's `position` is updated to the position of the currently focused element.
    mutating func pushToSlots(slot: Int, positionOfSlot: Int)

    /// Call `body` for each node and associated slot on the way from the currently selected element up to the root node.
    func forEach(ascending ascending: Bool, @noescape body: (Node, Int) -> Void)
    func forEachSlot(ascending ascending: Bool, @noescape body: Int -> Void)

    /// Finish working with the path and return the root node.
    mutating func finish() -> BTreeNode<Key, Payload>
}

extension BTreePath {
    internal typealias Element = (Key, Payload)
    internal typealias Tree = BTree<Key, Payload>
    internal typealias Node = BTreeNode<Key, Payload>

    init(startOf root: Node) {
        self.init(root: root, position: 0)
    }

    init(endOf root: Node) {
        // The end position can be anywhere on the rightmost path of the tree,
        // so let's try the spot after the last element of the root.
        // This can spare us O(log(n)) steps if this path is only used for reference.
        self.init(root)
        pushToSlots(root.elements.count, positionOfSlot: root.count)
    }
    
    init(root: Node, position: Int) {
        self.init(root)
        descend(toPosition: position)
    }

    init(root: Node, key: Key, choosing selector: BTreeKeySelector) {
        self.init(root)
        descend(to: key, choosing: selector)
    }

    init<Path: BTreePath where Path.Key == Key, Path.Payload == Payload>(root: Node, slotsFrom path: Path) {
        self.init(root)
        path.forEachSlot(ascending: false) { slot in
            if self.slot != nil {
                pushToPath()
            }
            self.pushToSlots(slot)
        }
    }

    /// Return true iff the path contains at least one node.
    var isValid: Bool { return length > 0 }
    /// Return true iff the current position is at the start of the tree.
    var isAtStart: Bool { return position == 0 }
    /// Return true iff the current position is at the end of the tree.
    var isAtEnd: Bool { return position == count }

    /// Push the specified slot onto `slots`, completing the path.
    mutating func pushToSlots(slot: Int) {
        pushToSlots(slot, positionOfSlot: node.positionOfSlot(slot))
    }

    mutating func finish() -> Node {
        return root
    }

    /// Return the element at the current position.
    var element: Element { return node.elements[slot!] }
    /// Return the key of the element at the current position.
    var key: Key { return element.0 }
    /// Return the payload of the element at the current position.
    var payload: Payload { return element.1 }

    /// Move to the next element in the b-tree.
    ///
    /// - Requires: `!isAtEnd`
    /// - Complexity: Amortized O(1)
    mutating func moveForward() {
        precondition(position < count)
        position += 1
        if node.isLeaf {
            if slot! < node.elements.count - 1 || position == count {
                slot! += 1
            }
            else {
                // Ascend
                repeat {
                    slot = nil
                    popFromPath()
                } while slot == node.elements.count
            }
        }
        else {
            // Descend
            slot! += 1
            pushToPath()
            while !node.isLeaf {
                slot = 0
                pushToPath()
            }
            slot = 0
        }
    }

    /// Move to the previous element in the b-tree.
    ///
    /// - Requires: `!isAtStart`
    /// - Complexity: Amortized O(1)
    mutating func moveBackward() {
        precondition(!isAtStart)
        position -= 1
        if node.isLeaf {
            if slot! > 0 {
                slot! -= 1
            }
            else {
                // Ascend
                repeat {
                    slot = nil
                    popFromPath()
                } while slot! == 0
                slot! -= 1
            }
        }
        else {
            // Descend
            assert(!node.isLeaf)
            pushToPath()
            while !node.isLeaf {
                slot = node.children.count - 1
                pushToPath()
            }
            slot = node.elements.count - 1
        }
    }

    /// Move to the start of the b-tree.
    ///
    /// - Complexity: O(log(`position`))
    mutating func moveToStart() {
        move(toPosition: 0)
    }

    /// Move to the end of the b-tree.
    ///
    /// - Complexity: O(log(`count` - `position`))
    mutating func moveToEnd() {
        popFromSlots()
        while self.count > self.position {
            popFromPath()
            popFromSlots()
        }
        self.descend(toPosition: self.count)
    }

    /// Move to the specified position in the b-tree.
    ///
    /// - Complexity: O(log(*distance*)), where *distance* is the absolute difference between the desired and current
    ///   positions.
    mutating func move(toPosition position: Int) {
        precondition(position >= 0 && position <= count)
        if position == count {
            moveToEnd()
            return
        }
        // Pop to ancestor whose subtree contains the desired position.
        popFromSlots()
        while position < self.position - node.count || position >= self.position {
            popFromPath()
            popFromSlots()
        }
        self.descend(toPosition: position)
    }

    /// Move to the element with the specified key.
    /// If there are no such elements, move to the first element after `key` (or at the end of tree).
    /// If there are multiple such elements, `selector` determines which one to find.
    ///
    /// - Complexity: O(log(`count`))
    mutating func move(to key: Key, choosing selector: BTreeKeySelector = .Any) {
        popFromSlots()
        while length > 1 && !node.contains(key, choosing: selector) {
            popFromPath()
            popFromSlots()
        }
        self.descend(to: key, choosing: selector)
    }

    /// Starting from an incomplete path, descend to the element at the specified position.
    mutating func descend(toPosition position: Int) {
        assert(position >= self.position - node.count && position <= self.position)
        assert(self.slot == nil)
        var slot = node.slotOfPosition(position - (self.position - node.count))
        pushToSlots(slot.index, positionOfSlot: slot.position)
        while !slot.match {
            pushToPath()
            slot = node.slotOfPosition(position - (self.position - node.count))
            pushToSlots(slot.index, positionOfSlot: slot.position)
        }
        assert(self.position == position)
        assert(self.slot != nil)
    }

    /// Starting from an incomplete path, descend to the element with the specified key.
    mutating func descend(to key: Key, choosing selector: BTreeKeySelector) {
        assert(self.slot == nil)
        if count == 0 {
            pushToSlots(0)
            return
        }

        var match: (depth: Int, slot: Int)? = nil
        while true {
            let slot = node.slotOf(key, choosing: selector)
            if let m = slot.match {
                if node.isLeaf || selector == .Any {
                    pushToSlots(m)
                    return
                }
                match = (depth: length, slot: m)
            }
            if node.isLeaf {
                if let m = match {
                    for _ in 0 ..< length - m.depth {
                        popFromPath()
                        popFromSlots()
                    }
                    pushToSlots(m.slot)
                }
                else if slot.descend < node.elements.count {
                    pushToSlots(slot.descend)
                }
                else {
                    pushToSlots(slot.descend - 1)
                    moveForward()
                }
                break
            }
            pushToSlots(slot.descend)
            pushToPath()
        }
    }

    /// Return a tuple containing a tree with all elements before the current position,
    /// the currently focused element, and a tree with all elements after the currrent position.
    ///
    /// - Complexity: O(log(`count`))
    @warn_unused_result
    func split() -> (prefix: Tree, separator: Element, suffix: Tree) {
        precondition(!isAtEnd)
        var left: Node? = nil
        var separator: Element? = nil
        var right: Node? = nil
        forEach(ascending: true) { node, slot in
            if separator == nil {
                left = Node(node: node, slotRange: 0 ..< slot)
                separator = node.elements[slot]
                let c = node.elements.count
                right = Node(node: node, slotRange: slot + 1 ..< c)
            }
            else {
                if slot >= 1 {
                    let l = Node(node: node, slotRange: 0 ..< slot - 1)
                    let s = node.elements[slot - 1]
                    left = Node.join(left: l, separator: s, right: left!)
                }
                let c = node.elements.count
                if slot <= c - 1 {
                    let r = Node(node: node, slotRange: slot + 1 ..< c)
                    let s = node.elements[slot]
                    right = Node.join(left: right!, separator: s, right: r)
                }
            }
        }
        return (Tree(left!), separator!, Tree(right!))
    }

    /// Return a tree containing all elements before (and not including) the current position.
    ///
    /// - Complexity: O(log(`count`))
    @warn_unused_result
    func prefix() -> Tree {
        precondition(!isAtEnd)
        var prefix: Node? = nil
        forEach(ascending: true) { node, slot in
            if prefix == nil {
                prefix = Node(node: node, slotRange: 0 ..< slot)
            }
            else if slot >= 1 {
                let l = Node(node: node, slotRange: 0 ..< slot - 1)
                let s = node.elements[slot - 1]
                prefix = Node.join(left: l, separator: s, right: prefix!)
            }
        }
        return Tree(prefix!)
    }

    /// Return a tree containing all elements after (and not including) the current position.
    ///
    /// - Complexity: O(log(`count`))
    @warn_unused_result
    func suffix() -> Tree {
        precondition(!isAtEnd)
        var suffix: Node? = nil
        forEach(ascending: true) { node, slot in
            if suffix == nil {
                let c = node.elements.count
                suffix = Node(node: node, slotRange: slot + 1 ..< c)
                return
            }
            let c = node.elements.count
            if slot <= c - 1 {
                let r = Node(node: node, slotRange: slot + 1 ..< c)
                let s = node.elements[slot]
                suffix = Node.join(left: suffix!, separator: s, right: r)
            }
        }
        return Tree(suffix!)
    }
}
