//
//  BTreeCursor.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2016-02-12.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

private enum WalkDirection {
    case Forward
    case Backward
}

/// A stateful editing interface for efficiently inserting/removing/updating a range of elements in a b-tree.
///
/// Creating a cursor over a tree takes exclusive ownership of it; the tree is in a transient invalid state
/// while the cursor is active. (In particular, element counts are not finalized until the cursor is deactivated.)
///
/// The cursor always focuses on a particular spot on the tree: either a particular element, or the empty spot after 
/// the last element. There are methods to move the cursor to the next or previous element, to modify the currently 
/// focused element, to insert a new element before the current position, and to remove the currently focused element
/// from the tree.
///
/// Note that the cursor does not verify that keys you insert/modify uphold tree invariants -- it is your responsibility
/// to guarantee keys remain in ascending order while you're working with the cursor.
///
/// Creating a cursor takes O(log(*n*)) steps; once the cursor has been created, the complexity of most manipulations
/// is amortized O(1). For example, appending *k* new elements without a cursor takes O(*k* * log(*n*)) steps;
/// using a cursor to do the same only takes O(log(*n*) + *k*).
internal final class BTreeCursor<Key: Comparable, Payload> {
    typealias Distance = Int
    typealias Node = BTreeNode<Key, Payload>

    /// The root node in the tree that is being edited. Note that this isn't a valid b-tree while the cursor is active:
    /// each node on the current path has an invalid `count` field. (Other b-tree invariants are kept, though.)
    private var root: Node

    /// The current path in the tree that is being edited.
    ///
    /// Only the last node on the path has correct `count`; the element count of the currently focused descendant
    /// subtree is subtracted from each ancestor's count.
    /// I.e., `path[i].count = realCount(path[i]) - realCount(path[i+1])`.
    ///
    private var path: [Node]

    /// The slots on the path to the currently focused part of the tree.
    private var slots: [Int]

    /// The current count of elements in the tree. This is always kept up to date, while `root.count` is usually invalid.
    internal private(set) var count: Int

    /// The position of the currenly focused element in the tree.
    internal private(set) var position: Int

    //MARK: Simple properties

    internal var isValid: Bool { return !path.isEmpty }
    internal var isAtStart: Bool { return position == 0 }
    internal var isAtEnd: Bool { return position == count }

    //MARK: Initializers

    internal init() {
        let root = Node()
        self.root = root
        self.count = 0
        self.position = 0
        self.path = [root]
        self.slots = [0]
    }

    internal convenience init(startOf root: Node) {
        self.init(root: root, position: 0)
    }

    internal convenience init(endOf root: Node) {
        self.init(root: root, position: root.count)
    }

    internal init(root: Node, position: Int) {
        precondition(position >= 0 && position <= root.count)
        let root = root.clone()
        self.root = root
        self.count = root.count
        self.position = 0
        self.path = [root]
        self.slots = []
        descendToPosition(position)
    }

    /// Initialize a new cursor positioned at the specified `key`. If the key isn't in the tree, then the cursor
    /// is positioned after the last element whose key is below `key`.
    internal init(root: Node, key: Key) {
        let root = root.clone()
        self.root = root
        self.count = root.count
        self.position = 0
        self.path = [root]
        self.slots = []

        if root.isEmpty {
            self.slots.append(0)
            return
        }

        var node = root
        while !node.isLeaf {
            let slot = node.slotOf(key)
            slots.append(slot.index)
            position += (0..<slot.index).reduce(0) { $0 + node.children[$1].count + 1 }
            if slot.match {
                position += node.children[slot.index].count
                return
            }
            let child = node.makeChildUnique(slot.index)
            node.count -= child.count
            path.append(child)
            node = child
        }
        let slot = node.slotOf(key)
        if slot.index < node.keys.count {
            position += slot.index
            slots.append(slot.index)
        }
        else {
            position += slot.index - 1
            slots.append(slot.index - 1)
            moveForward()
        }
    }

    //MARK: Finishing

    /// Finalize editing the tree and return it, deactivating this cursor.
    /// You'll need to create a new cursor to continue editing the tree.
    @warn_unused_result
    internal func finish() -> Node {
        var childCount = 0
        while !path.isEmpty {
            let node = path.removeLast()
            node.count += childCount
            childCount = node.count
        }
        assert(root.count == count)
        defer { invalidate() }
        return root
    }

    //MARK: Navigation

    /// Invalidate this cursor.
    private func invalidate() {
        self.root = Node()
        self.count = 0
        self.position = 0
        self.path = []
        self.slots = []
    }

    private func ascend(direction: WalkDirection) {
        while path.count > 1 {
            let node = path.removeLast()
            slots.removeLast()
            let parent = path[path.count - 1]
            let slot = slots[slots.count - 1]
            parent.count += node.count
            precondition(parent.children[slot] === node)
            if direction == .Forward && slot < parent.keys.count {
                return
            }
            else if direction == .Backward && slot > 0 {
                slots[slots.count - 1] = slot - 1
                return
            }
        }
        invalidate()
    }

    private func descend(direction: WalkDirection) {
        precondition(self.path.count > 0)
        let parent = self.path.last!
        assert(!parent.isLeaf)
        let slot = (direction == .Forward ? slots.last! + 1 : slots.last!)
        slots[slots.count - 1] = slot
        var node = parent.makeChildUnique(slot)
        parent.count -= node.count
        path.append(node)
        while !node.isLeaf {
            let slot = (direction == .Forward ? 0 : node.children.count - 1)
            slots.append(slot)
            let child = node.makeChildUnique(slot)
            node.count -= child.count
            path.append(child)
            node = child
        }
        slots.append(direction == .Forward ? 0 : node.keys.count - 1)
    }

    /// Position the cursor on the next element in the b-tree.
    ///
    /// - Requires: `!isAtEnd`
    internal func moveForward() {
        precondition(position < count)
        position += 1
        let node = path.last!
        if node.isLeaf {
            if slots.last! < node.keys.count - 1 || position == count {
                slots[slots.count - 1] += 1
            }
            else {
                ascend(.Forward)
            }
        }
        else {
            descend(.Forward)
        }
    }

    /// Position this cursor to the previous element in the b-tree.
    ///
    /// - Requires: `!isAtStart`
    internal func moveBackward() {
        precondition(!isAtStart)
        position -= 1
        let node = path.last!
        if node.isLeaf {
            if slots.last! > 0 {
                slots[slots.count - 1] -= 1
            }
            else {
                ascend(.Backward)
            }
        }
        else {
            descend(.Backward)
        }
    }

    internal func moveToStart() {
        moveToPosition(0)
    }

    internal func moveToEnd() {
        moveToPosition(self.count)
    }

    internal func moveToPosition(position: Int) {
        precondition(isValid && position >= 0 && position <= count)
        // Pop to ancestor whose subtree contains the desired position.
        while path.count > 1 {
            let range = rangeOfPositionForLastNode()
            if range.contains(position) {
                break
            }
            path.removeLast()
            path[path.count - 1].count += range.count
            slots.removeLast()
            self.position = range.endIndex
        }
        let node = path.last!
        self.position -= node.positionOfSlot(slots.removeLast())
        self.descendToPosition(position)
    }

    private func rangeOfPositionForLastNode() -> Range<Int> {
        let node = path.last!
        let nodeStart = self.position - node.positionOfSlot(slots.last!)
        let nodeEnd = nodeStart + node.count
        return nodeStart ..< nodeEnd
    }

    private func descendToPosition(position: Int) {
        var node = path.last!
        assert(self.position <= position && position <= self.position + node.count)
        assert(self.slots.count == self.path.count - 1)
        var pos = position - self.position
        self.position = position
        while !node.isLeaf {
            var count = 0
            for slot in 0 ..< node.children.count {
                let c = node.children[slot].count
                if pos == count + c && slot < node.keys.count {
                    slots.append(slot)
                    return
                }
                if pos <= count + c {
                    // Descend
                    slots.append(slot)
                    let child = node.makeChildUnique(slot)
                    node.count -= child.count
                    path.append(child)
                    node = child
                    pos -= count
                    break
                }
                count += c + 1
            }
        }
        assert(pos <= node.keys.count)
        slots.append(pos)
    }

    //MARK: Editing

    /// Get or set the key of the currently focused element.
    /// Note that changing the key is potentially dangerous; it is the caller's responsibility to ensure that 
    /// keys remain in ascending order.
    internal var key: Key {
        get {
            precondition(!self.isAtEnd)
            return path.last!.keys[slots.last!]
        }
        set {
            precondition(!self.isAtEnd)
            path.last!.keys[slots.last!] = newValue
        }
    }

    /// Get or set the payload of the currently focused element.
    internal var payload: Payload {
        get {
            precondition(!self.isAtEnd)
            return path.last!.payloads[slots.last!]
        }
        set {
            precondition(!self.isAtEnd)
            path.last!.payloads[slots.last!] = newValue
        }
    }

    /// Update the payload stored at the cursor's current position and return the previous value.
    /// This method does not change the cursor's position.
    internal func setPayload(payload: Payload) -> Payload {
        precondition(!self.isAtEnd)
        let node = path.last!
        let slot = slots.last!
        let old = node.payloads[slot]
        node.payloads[slot] = payload
        return old
    }

    /// Insert a new element after the cursor's current position, and position the cursor on the new element.
    internal func insertAfter(key: Key, _ payload: Payload) {
        precondition(!self.isAtEnd)
        count += 1
        if path.last!.isLeaf {
            let node = path.last!
            let slot = slots.last!
            node.keys.insert(key, atIndex: slot + 1)
            node.payloads.insert(payload, atIndex: slot + 1)
            slots[slots.count - 1] = slot + 1
            node.count += 1
            self.position += 1
        }
        else {
            moveForward()
            let node = path.last!
            assert(node.isLeaf && slots.last == 0)
            node.keys.insert(key, atIndex: 0)
            node.payloads.insert(payload, atIndex: 0)
            node.count += 1
        }
        fixupAfterInsert()
    }

    /// Insert a new element before the cursor's current position, and leave the cursor positioned on the original element.
    internal func insertBefore(key: Key, _ payload: Payload) {
        precondition(self.isValid)
        count += 1
        if path.last!.isLeaf {
            let node = path.last!
            let slot = slots.last!
            node.keys.insert(key, atIndex: slot)
            node.payloads.insert(payload, atIndex: slot)
            node.count += 1
        }
        else {
            moveBackward()
            let node = path.last!
            assert(node.isLeaf && slots.last == node.keys.count - 1)
            node.keys.append(key)
            node.payloads.append(payload)
            slots[slots.count - 1] = node.keys.count - 1
            node.count += 1
            self.position += 1
        }
        fixupAfterInsert()
        moveForward()
    }

    private func fixupAfterInsert() {
        guard path.last!.isTooLarge else { return }

        // Split nodes on the way to the root until we restore the b-tree's size constraints.
        var i = path.count - 1
        while path[i].isTooLarge {
            // Split path[i], which must have correct count.
            let left = path[i]
            let slot = slots[i]
            let splinter = left.split()
            let right = splinter.node
            if slot > left.keys.count {
                // Focused element is in the new branch; adjust state accordingly.
                slots[i] = slot - left.keys.count - 1
                path[i] = right
            }
            else if slot == left.keys.count {
                // Focused element is the new separator; adjust state accordingly.
                assert(i == path.count - 1)
                path.removeLast()
                slots.removeLast()
            }

            if i > 0 {
                // Insert splinter into parent node and fix its count field.
                let parent = path[i - 1]
                let pslot = slots[i - 1]
                parent.insert(splinter, inSlot: pslot)
                parent.count += left.count + right.count + 1
                if slot > left.keys.count {
                    // Focused element is in the new branch; update state accordingly.
                    slots[i - 1] = pslot + 1
                }
                i -= 1
            }
            else {
                // Create new root node.
                self.root = Node(
                    order: self.root.order,
                    keys: [splinter.separator.0],
                    payloads: [splinter.separator.1],
                    children: [left, right])
                path.insert(self.root, atIndex: 0)
                slots.insert(slot > left.keys.count ? 1 : 0, atIndex: 0)
            }
        }

        // Size constraints are now OK, but counts on path have become valid, so we need to restore 
        // cursor state by subtracting focused children.
        while i < path.count - 1 {
            path[i].count -= path[i + 1].count
            i += 1
        }
    }

    /// Remove the element at the cursor's current position, and position the cursor at the removed element's successor.
    internal func remove() -> (Key, Payload) {
        precondition(!isAtEnd)
        fatalError("Implement this")
        return (key, payload)
    }
}