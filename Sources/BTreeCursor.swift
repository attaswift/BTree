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

    private init(_ root: Node) {
        self.root = root
        self.count = root.count
        self.position = root.count
        self.path = [root]
        self.slots = []
    }

    internal convenience init() {
        self.init(Node())
        pushToSlots(0)
    }

    internal convenience init(startOf root: Node) {
        self.init(root: root, position: 0)
    }

    internal convenience init(endOf root: Node) {
        self.init(root: root, position: root.count)
    }

    internal convenience init(root: Node, position: Int) {
        precondition(position >= 0 && position <= root.count)
        self.init(root.clone())
        descendToPosition(position)
    }

    /// Initialize a new cursor positioned at the specified `key`. If the key isn't in the tree, then the cursor
    /// is positioned after the last element whose key is below `key`.
    internal convenience init(root: Node, key: Key) {
        self.init(root.clone())
        descendToKey(key)
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

    private func popFromSlots() -> Int {
        assert(path.count == slots.count)
        let slot = slots.removeLast()
        let node = path.last!
        self.position += node.count - node.positionOfSlot(slot)
        return slot
    }
    private func popFromPath() -> Node {
        assert(path.count > 1 && path.count == slots.count + 1)
        let child = path.removeLast()
        let parent = path.last!
        parent.count += child.count
        return child
    }

    private func pushToPath() -> Node {
        assert(path.count == slots.count)
        let parent = path.last!
        let slot = slots.last!
        let child = parent.makeChildUnique(slot)
        parent.count -= child.count
        path.append(child)
        return child
    }
    private func pushToSlots(slot: Int, positionOfSlot: Int? = nil) {
        assert(path.count == slots.count + 1)
        let node = path.last!
        let p = positionOfSlot ?? node.positionOfSlot(slot)
        self.position -= node.count - p
        self.slots.append(slot)
    }

    /// Position the cursor on the next element in the b-tree.
    ///
    /// - Requires: `!isAtEnd`
    /// - Complexity: Amortized O(1)
    internal func moveForward() {
        precondition(position < count)
        position += 1
        let node = path.last!
        if node.isLeaf {
            if slots.last! < node.keys.count - 1 || position == count {
                slots[slots.count - 1] += 1
            }
            else {
                // Ascend
                repeat {
                    slots.removeLast()
                    popFromPath()
                } while slots.last! == path.last!.keys.count
            }
        }
        else {
            // Descend
            slots[slots.count - 1] += 1
            var node = pushToPath()
            while !node.isLeaf {
                slots.append(0)
                node = pushToPath()
            }
            slots.append(0)
        }
    }

    /// Position this cursor to the previous element in the b-tree.
    ///
    /// - Requires: `!isAtStart`
    /// - Complexity: Amortized O(1)
    internal func moveBackward() {
        precondition(!isAtStart)
        position -= 1
        let node = path.last!
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
            precondition(path.count > 0)
            assert(!path.last!.isLeaf)
            var node = pushToPath()
            while !node.isLeaf {
                let slot = node.children.count - 1
                slots.append(slot)
                node = pushToPath()
            }
            slots.append(node.keys.count - 1)
        }
    }

    /// Position this cursor to the start of the b-tree.
    ///
    /// - Complexity: O(log(`position`))
    internal func moveToStart() {
        moveToPosition(0)
    }

    /// Position this cursor to the end of the b-tree.
    ///
    /// - Complexity: O(log(`count` - `position`))
    internal func moveToEnd() {
        popFromSlots()
        while self.count > self.position + path.last!.count {
            popFromPath()
            popFromSlots()
        }
        self.descendToPosition(self.count)
    }

    /// Move this cursor to the specified position in the b-tree.
    ///
    /// - Complexity: O(log(*distance*)), where *distance* is the absolute difference between the desired and current
    ///   positions.
    internal func moveToPosition(position: Int) {
        precondition(isValid && position >= 0 && position <= count)
        if position == count {
            moveToEnd()
            return
        }
        // Pop to ancestor whose subtree contains the desired position.
        popFromSlots()
        while position < self.position - path.last!.count || position >= self.position {
            popFromPath()
            popFromSlots()
        }
        self.descendToPosition(position)
    }

    private func descendToPosition(position: Int) {
        assert(position >= self.position - path.last!.count && position <= self.position)
        assert(self.path.count == self.slots.count + 1)
        var node = path.last!
        var slot = node.slotOfPosition(position - (self.position - node.count))
        pushToSlots(slot.index, positionOfSlot: slot.position)
        while !slot.match {
            node = pushToPath()
            slot = node.slotOfPosition(position - (self.position - node.count))
            pushToSlots(slot.index, positionOfSlot: slot.position)
        }
        assert(self.position == position)
        assert(path.count == slots.count)
    }

    private func descendToKey(key: Key) {
        if root.isEmpty {
            pushToSlots(0)
            return
        }

        var node = root
        while !node.isLeaf {
            let slot = node.slotOf(key)
            pushToSlots(slot.index)
            if slot.match {
                return
            }
            node = pushToPath()
        }
        let slot = node.slotOf(key)
        if slot.index < node.keys.count {
            pushToSlots(slot.index)
        }
        else {
            pushToSlots(slot.index - 1)
            moveForward()
        }
    }

    //MARK: Editing

    /// Get or set the key of the currently focused element.
    /// Note that changing the key is potentially dangerous; it is the caller's responsibility to ensure that 
    /// keys remain in ascending order.
    ///
    /// - Complexity: O(1)
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
    ///
    /// - Complexity: O(1)
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
    ///
    /// - Complexity: O(1)
    internal func setPayload(payload: Payload) -> Payload {
        precondition(!self.isAtEnd)
        let node = path.last!
        let slot = slots.last!
        let old = node.payloads[slot]
        node.payloads[slot] = payload
        return old
    }

    /// Insert a new element after the cursor's current position, and position the cursor on the new element.
    ///
    /// - Complexity: amortized O(1)
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
    ///
    /// - Complexity: amortized O(1)
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

    /// Remove and return the element at the cursor's current position, and position the cursor on its successor.
    internal func remove() -> (Key, Payload) {
        precondition(!isAtEnd)
        let node = path.last!
        let slot = slots.last!
        let result = (node.keys[slot], node.payloads[slot])
        if !node.isLeaf {
            // For internal nodes, remove the (leaf) predecessor instead, then put it back in place of the element
            // that we actually want to remove.
            moveBackward()
            let surrogate = remove()
            self.key = surrogate.0
            self.payload = surrogate.1
            moveForward()
            return result
        }
        let targetPosition = self.position
        node.keys.removeAtIndex(slot)
        node.payloads.removeAtIndex(slot)
        node.count -= 1
        self.count -= 1
        popFromSlots()
        var n = node
        while n !== root && n.isTooSmall {
            popFromPath()
            n = path.last!
            let slot = popFromSlots()
            n.fixDeficiency(slot)
        }
        while targetPosition != count && targetPosition == self.position && n !== root {
            popFromPath()
            n = path.last!
            popFromSlots()
        }
        if n === root && n.keys.count == 0 && n.children.count == 1 {
            assert(path.count == 1 && slots.count == 0)
            root = n.children[0]
            path[0] = root
        }
        descendToPosition(targetPosition)
        return result
    }
}