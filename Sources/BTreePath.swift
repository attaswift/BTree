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

    init(_ root: Node)

    /// The root node of the underlying b-tree.
    var root: BTreeNode<Key, Payload> { get }

    /// The trail slot indexes that lead from the root to the currently focused element.
    var slots: [Int] { get set }

    /// The current position of this path. Setting this property changes the path to point at the given position.
    var position: Int { get set }

    /// The number of elements in the tree.
    var count: Int { get }

    /// The number of nodes on the path from the root to the node that holds the focused element, including both ends.
    var length: Int { get }

    /// The final node on the path; i.e., the node that holds the currently focused element.
    var lastNode: BTreeNode<Key, Payload> { get }

    /// Get or set the selected slot in the last node on the path.
    var lastSlot: Int { get set }

    /// Pop and return the last slot in `slots`, creating an incomplete path.
    /// The path's `position` is updated to the position of the element following the subtree at the last node.
    mutating func popFromSlots() -> Int

    /// Pop and return the last node in an incomplete path, focusing the element following its subtree.
    /// This restores the path to a completed state.
    mutating func popFromPath() -> Node

    /// Push the child node before the currently focused element on the path, creating an incomplete path.
    mutating func pushToPath() -> Node

    /// Push the specified slot onto `slots`, completing the path.
    /// The path's `position` is updated to the position of the currently focused element.
    mutating func pushToSlots(slot: Int, positionOfSlot: Int)

    /// Call `body` for each node and associated slot on the way from the currently selected element up to the root node.
    func forEachAscending(@noescape body: (Node, Int) -> Void)

    /// Finish working with the path and return the root node.
    mutating func finish() -> BTree<Key, Payload>
}

extension BTreePath {
    typealias Element = (Key, Payload)
    typealias Tree = BTree<Key, Payload>
    typealias Node = BTreeNode<Key, Payload>

    init(startOf root: Node) { self.init(root: root, position: 0) }
    init(endOf root: Node) { self.init(root: root, position: root.count) }
    
    init(root: Node, position: Int) {
        self.init(root)
        descend(toPosition: position)
    }

    init(root: Node, key: Key, choosing selector: BTreeKeySelector) {
        self.init(root)
        descend(to: key, choosing: selector)
    }

    init(root: Node, slots: [Int]) {
        self.init(root)
        descend(to: slots)
    }

    /// Return true iff the path contains at least one node.
    var isValid: Bool { return length > 0 }
    /// Return true iff the current position is at the start of the tree.
    var isAtStart: Bool { return position == 0 }
    /// Return true iff the current position is at the end of the tree.
    var isAtEnd: Bool { return position == count }

    /// Push the specified slot onto `slots`, completing the path.
    mutating func pushToSlots(slot: Int) {
        pushToSlots(slot, positionOfSlot: lastNode.positionOfSlot(slot))
    }

    mutating func finish() -> Tree {
        return Tree(root)
    }

    /// Return the element at the current position.
    var element: Element { return lastNode.elements[lastSlot] }
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
        let node = lastNode
        if node.isLeaf {
            if lastSlot < node.elements.count - 1 || position == count {
                lastSlot += 1
            }
            else {
                // Ascend
                repeat {
                    slots.removeLast()
                    popFromPath()
                } while slots.last! == lastNode.elements.count
            }
        }
        else {
            // Descend
            lastSlot += 1
            var node = pushToPath()
            while !node.isLeaf {
                slots.append(0)
                node = pushToPath()
            }
            slots.append(0)
        }
    }

    /// Move to the previous element in the b-tree.
    ///
    /// - Requires: `!isAtStart`
    /// - Complexity: Amortized O(1)
    mutating func moveBackward() {
        precondition(!isAtStart)
        position -= 1
        let node = lastNode
        if node.isLeaf {
            if slots.last! > 0 {
                slots[slots.count - 1] -= 1
            }
            else {
                repeat {
                    slots.removeLast()
                    popFromPath()
                } while slots.last! == 0
                slots[slots.count - 1] -= 1
            }
        }
        else {
            precondition(length > 0)
            assert(!lastNode.isLeaf)
            var node = pushToPath()
            while !node.isLeaf {
                let slot = node.children.count - 1
                slots.append(slot)
                node = pushToPath()
            }
            slots.append(node.elements.count - 1)
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
        precondition(isValid && position >= 0 && position <= count)
        if position == count {
            moveToEnd()
            return
        }
        // Pop to ancestor whose subtree contains the desired position.
        popFromSlots()
        while position < self.position - lastNode.count || position >= self.position {
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
        while length > 1 && !lastNode.contains(key, choosing: selector) {
            popFromPath()
            popFromSlots()
        }
        self.descend(to: key, choosing: selector)
    }

    /// Starting from an incomplete path, descend to the element at the specified position.
    mutating func descend(toPosition position: Int) {
        assert(position >= self.position - lastNode.count && position <= self.position)
        assert(length == self.slots.count + 1)
        var node = lastNode
        var slot = node.slotOfPosition(position - (self.position - node.count))
        pushToSlots(slot.index, positionOfSlot: slot.position)
        while !slot.match {
            node = pushToPath()
            slot = node.slotOfPosition(position - (self.position - node.count))
            pushToSlots(slot.index, positionOfSlot: slot.position)
        }
        assert(self.position == position)
        assert(length == slots.count)
    }

    /// Starting from an incomplete path, descend to the element with the specified key.
    mutating func descend(to key: Key, choosing selector: BTreeKeySelector) {
        assert(length == slots.count + 1)
        if count == 0 {
            pushToSlots(0)
            return
        }

        var node = lastNode
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
            node = pushToPath()
        }
    }

    /// Starting from an incomplete path, descend to the element at the end of the specified trail of slots.
    mutating func descend(to slots: [Int]) {
        assert(length == self.slots.count + 1)
        for i in 0 ..< slots.count {
            let slot = slots[i]
            pushToSlots(slot)
            if i != slots.count - 1 {
                pushToPath()
            }
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
        forEachAscending { node, slot in
            if separator == nil {
                left = (slot == 0 && !node.isLeaf ? node.children[0].clone() : Node(node: node, slotRange: 0 ..< slot))
                separator = node.elements[slot]
                let c = node.elements.count
                right = (slot == c - 1 && !node.isLeaf ? node.children[c].clone() : Node(node: node, slotRange: slot + 1 ..< c))
            }
            else {
                if slot >= 1 {
                    let l = slot == 1 ? node.children[0].clone() : Node(node: node, slotRange: 0 ..< slot - 1)
                    let s = node.elements[slot - 1]
                    left = Node.join(left: l, separator: s, right: left!)
                }
                let c = node.elements.count
                if slot <= c - 1 {
                    let r = slot == c - 1 ? node.children[c].clone() : Node(node: node, slotRange: slot + 1 ..< c)
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
        forEachAscending { node, slot in
            if prefix == nil {
                prefix = (slot == 0 && !node.isLeaf ? node.children[0].clone() : Node(node: node, slotRange: 0 ..< slot))
            }
            else if slot >= 1 {
                let l = slot == 1 ? node.children[0].clone() : Node(node: node, slotRange: 0 ..< slot - 1)
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
        forEachAscending { node, slot in
            if suffix == nil {
                let c = node.elements.count
                suffix = (slot == c - 1 && !node.isLeaf ? node.children[c].clone() : Node(node: node, slotRange: slot + 1 ..< c))
                return
            }
            let c = node.elements.count
            if slot <= c - 1 {
                let r = slot == c - 1 ? node.children[c].clone() : Node(node: node, slotRange: slot + 1 ..< c)
                let s = node.elements[slot]
                suffix = Node.join(left: suffix!, separator: s, right: r)
            }
        }
        return Tree(suffix!)
    }
}
