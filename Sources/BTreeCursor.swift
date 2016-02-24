//
//  BTreeCursor.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-12.
//  Copyright © 2015–2016 Károly Lőrentey.
//

//MARK: Cursors

extension BTree {
    public typealias Cursor = BTreeCursor<Key, Payload>

    /// Call `body` with a cursor at `position` in this tree.
    ///
    /// - Warning: Do not rely on anything about `self` (the `BTree` that is the target of this method) during the
    ///   execution of body: it will not appear to have the correct value.
    ///   Instead, use only the supplied cursor to manipulate the tree.
    ///
    public mutating func withCursorAtPosition(position: Int, @noescape body: Cursor throws -> Void) rethrows {
        precondition(position >= 0 && position <= count)
        makeUnique()
        let cursor = BTreeCursor(root)
        cursor.descendToPosition(position)
        root = Node()
        defer { self = cursor.finish() }
        try body(cursor)
    }

    /// Call `body` with a cursor at the start of this tree.
    ///
    /// - Warning: Do not rely on anything about `self` (the `BTree` that is the target of this method) during the
    ///   execution of body: it will not appear to have the correct value.
    ///   Instead, use only the supplied cursor to manipulate the tree.
    ///
    public mutating func withCursorAtStart(@noescape body: Cursor throws -> Void) rethrows {
        try withCursorAtPosition(0, body: body)
    }

    /// Call `body` with a cursor at the end of this tree.
    ///
    /// - Warning: Do not rely on anything about `self` (the `BTree` that is the target of this method) during the
    ///   execution of body: it will not appear to have the correct value.
    ///   Instead, use only the supplied cursor to manipulate the tree.
    ///
    public mutating func withCursorAtEnd(@noescape body: Cursor throws -> Void) rethrows {
        try withCursorAtPosition(count, body: body)
    }

    /// Call `body` with a cursor positioned at `key` in this tree.
    /// If there are multiple elements with the same key, `selector` indicates which matching element to find.
    ///
    /// - Warning: Do not rely on anything about `self` (the `BTree` that is the target of this method) during the
    ///   execution of body: it will not appear to have the correct value.
    ///   Instead, use only the supplied cursor to manipulate the tree.
    ///
    public mutating func withCursorAt(key: Key, choosing selector: BTreeKeySelector = .Any, @noescape body: Cursor throws -> Void) rethrows {
        makeUnique()
        let cursor = BTreeCursor(root)
        cursor.descendToKey(key, choosing: selector)
        root = Node()
        defer { self = cursor.finish() }
        try body(cursor)
    }

    /// Call `body` with a cursor positioned at `index` in this tree.
    ///
    /// - Warning: Do not rely on anything about `self` (the `BTree` that is the target of this method) during the
    ///   execution of body: it will not appear to have the correct value.
    ///   Instead, use only the supplied cursor to manipulate the tree.
    ///
    public mutating func withCursorAt(index: Index, @noescape body: Cursor throws -> Void) rethrows {
        makeUnique()
        let cursor = BTreeCursor(root)
        cursor.descendToSlots(index.slots)
        root = Node()
        defer { self = cursor.finish() }
        try body(cursor)
    }
}

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
public final class BTreeCursor<Key: Comparable, Payload> {
    public typealias Element = (Key, Payload)
    public typealias Tree = BTree<Key, Payload>
    internal typealias Node = BTreeNode<Key, Payload>

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
    public private(set) var count: Int

    /// The position of the currently focused element in the tree.
    private var _position: Int

    /// The position of the currently focused element in the tree.
    ///
    /// - Complexity: O(1) for the getter, O(log(`count`)) for the setter.
    public var position: Int {
        get {
            return _position
        }
        set {
            moveToPosition(newValue)
        }
    }

    //MARK: Simple properties

    public var isValid: Bool { return !path.isEmpty }
    public var isAtStart: Bool { return _position == 0 }
    public var isAtEnd: Bool { return _position == count }

    //MARK: Initializers

    private init(_ root: Node) {
        self.root = root
        self.count = root.count
        self._position = root.count
        self.path = [root]
        self.slots = []
    }

    //MARK: Reset

    private func reset(root: Node) {
        self.root = root
        self.count = root.count
        self._position = root.count
        self.path = [root]
        self.slots = []
    }

    internal func reset(startOf root: Node) {
        reset(root: root, position: 0)
    }

    internal func reset(endOf root: Node) {
        reset(root: root, position: root.count)
    }

    internal func reset(root root: Node, position: Int) {
        precondition(position >= 0 && position <= root.count)
        reset(root)
        descendToPosition(position)
    }

    internal func reset(root root: Node, key: Key, choosing selector: BTreeKeySelector = .Any) {
        reset(root)
        descendToKey(key, choosing: selector)
    }

    //MARK: Finishing

    /// Finalize editing the tree and return it, deactivating this cursor.
    /// You'll need to create a new cursor to continue editing the tree.
    ///
    /// - Complexity: O(log(`count`))
    @warn_unused_result
    internal func finish() -> Tree {
        var childCount = 0
        while !path.isEmpty {
            let node = path.removeLast()
            node.count += childCount
            childCount = node.count
        }
        assert(root.count == count)
        defer { invalidate() }
        return Tree(root)
    }

    /// Cut the tree into two separate b-trees and a separator at the current position.
    /// This operation deactivates the current cursor.
    ///
    /// - Complexity: O(log(`count`))
    @warn_unused_result
    internal func finishByCutting() -> (left: Tree, separator: Element, right: Tree) {
        precondition(!isAtEnd)

        var left = path.removeLast()
        var (separator, right) = left.split(slots.removeLast()).exploded
        if left.children.count == 1 {
            left = left.makeChildUnique(0)
        }
        if right.children.count == 1 {
            right = right.makeChildUnique(0)
        }

        while !path.isEmpty {
            let node = path.removeLast()
            let slot = slots.removeLast()
            if slot >= 1 {
                let l = slot == 1 ? node.makeChildUnique(0) : Node(node: node, slotRange: 0 ..< slot - 1)
                let s = node.elements[slot - 1]
                left = Node.join(left: l, separator: s, right: left)
            }
            let c = node.elements.count
            if slot <= c - 1 {
                let r = slot == c - 1 ? node.makeChildUnique(c) : Node(node: node, slotRange: slot + 1 ..< c)
                let s = node.elements[slot]
                right = Node.join(left: right, separator: s, right: r)
            }
        }

        return (Tree(left), separator, Tree(right))
    }

    /// Discard elements at or after the current position and return the resulting b-tree.
    /// This operation deactivates the current cursor.
    ///
    /// - Complexity: O(log(`count`))
    @warn_unused_result
    internal func finishAndKeepPrefix() -> Tree {
        precondition(!isAtEnd)
        var left = path.removeLast()
        _ = left.split(slots.removeLast())
        if left.children.count == 1 {
            left = left.makeChildUnique(0)
        }
        while !path.isEmpty {
            let node = path.removeLast()
            let slot = slots.removeLast()
            if slot >= 1 {
                let l = slot == 1 ? node.makeChildUnique(0) : Node(node: node, slotRange: 0 ..< slot - 1)
                let s = node.elements[slot - 1]
                left = Node.join(left: l, separator: s, right: left)
            }
        }
        return Tree(left)
    }

    /// Discard elements at or before the current position and return the resulting b-tree.
    /// This operation destroys the current cursor.
    ///
    /// - Complexity: O(log(`count`))
    @warn_unused_result
    internal func finishAndKeepSuffix() -> Tree {
        precondition(!isAtEnd)
        var right = path.removeLast().split(slots.removeLast()).node
        if right.children.count == 1 {
            right = right.makeChildUnique(0)
        }
        while !path.isEmpty {
            let node = path.removeLast()
            let slot = slots.removeLast()
            let c = node.elements.count
            if slot <= c - 1 {
                let r = slot == c - 1 ? node.makeChildUnique(c) : Node(node: node, slotRange: slot + 1 ..< c)
                let s = node.elements[slot]
                right = Node.join(left: right, separator: s, right: r)
            }
        }
        return Tree(right)
    }

    //MARK: Navigation

    /// Invalidate this cursor.
    private func invalidate() {
        self.root = Node()
        self.count = 0
        self._position = 0
        self.path = []
        self.slots = []
    }

    private func popFromSlots() -> Int {
        assert(path.count == slots.count)
        let slot = slots.removeLast()
        let node = path.last!
        self._position += node.count - node.positionOfSlot(slot)
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
        self._position -= node.count - p
        self.slots.append(slot)
    }

    /// Position the cursor on the next element in the b-tree.
    ///
    /// - Requires: `!isAtEnd`
    /// - Complexity: Amortized O(1)
    public func moveForward() {
        precondition(self.position < count)
        _position += 1
        let node = path.last!
        if node.isLeaf {
            if slots.last! < node.elements.count - 1 || _position == count {
                slots[slots.count - 1] += 1
            }
            else {
                // Ascend
                repeat {
                    slots.removeLast()
                    popFromPath()
                } while slots.last! == path.last!.elements.count
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
    public func moveBackward() {
        precondition(!isAtStart)
        _position -= 1
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
            slots.append(node.elements.count - 1)
        }
    }

    /// Position this cursor to the start of the b-tree.
    ///
    /// - Complexity: O(log(`position`))
    public func moveToStart() {
        moveToPosition(0)
    }

    /// Position this cursor to the end of the b-tree.
    ///
    /// - Complexity: O(log(`count` - `position`))
    public func moveToEnd() {
        popFromSlots()
        while self.count > self.position {
            popFromPath()
            popFromSlots()
        }
        self.descendToPosition(self.count)
    }

    /// Move this cursor to the specified position in the b-tree.
    ///
    /// - Complexity: O(log(*distance*)), where *distance* is the absolute difference between the desired and current
    ///   positions.
    public func moveToPosition(position: Int) {
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

    /// Move this cursor to an element with the specified key. 
    /// If there are no such elements, the cursor is moved to a spot where .
    /// If there are multiple such elements, `selector` specified which one to find.
    ///
    /// - Complexity: O(log(`count`))
    public func moveToKey(key: Key, choosing selector: BTreeKeySelector = .Any) {
        popFromSlots()
        while path.count > 1 && !path.last!.contains(key, choosing: selector) {
            popFromPath()
            popFromSlots()
        }
        self.descendToKey(key, choosing: selector)
    }

    private func descendToSlots(slots: [Int]) {
        assert(self.path.count == self.slots.count + 1)
        for i in 0 ..< slots.count {
            let slot = slots[i]
            pushToSlots(slot)
            if i != slots.count - 1 {
                pushToPath()
            }
        }
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

    private func descendToKey(key: Key, choosing selector: BTreeKeySelector) {
        assert(self.path.count == self.slots.count + 1)
        if count == 0 {
            pushToSlots(0)
            return
        }

        var node = path.last!
        var match: (depth: Int, slot: Int)? = nil
        while true {
            let slot = node.slotOf(key, choosing: selector)
            if let m = slot.match {
                if node.isLeaf || selector == .Any {
                    pushToSlots(m)
                    return
                }
                match = (depth: path.count, slot: m)
            }
            if node.isLeaf {
                if let m = match {
                    for _ in 0 ..< path.count - m.depth {
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

    //MARK: Editing

    /// Get or set the key of the currently focused element.
    ///
    /// - Warning: Changing the key is potentially dangerous; it is the caller's responsibility to ensure that
    /// keys remain in ascending order. This is not verified at runtime.
    /// - Complexity: O(1)
    public var key: Key {
        get {
            precondition(!self.isAtEnd)
            return path.last!.elements[slots.last!].0
        }
        set {
            precondition(!self.isAtEnd)
            path.last!.elements[slots.last!].0 = newValue
        }
    }

    /// Get or set the payload of the currently focused element.
    ///
    /// - Complexity: O(1)
    public var payload: Payload {
        get {
            precondition(!self.isAtEnd)
            return path.last!.elements[slots.last!].1
        }
        set {
            precondition(!self.isAtEnd)
            path.last!.elements[slots.last!].1 = newValue
        }
    }

    /// Update the payload stored at the cursor's current position and return the previous value.
    /// This method does not change the cursor's position.
    ///
    /// - Complexity: O(1)
    public func setPayload(payload: Payload) -> Payload {
        precondition(!self.isAtEnd)
        let node = path.last!
        let slot = slots.last!
        let old = node.elements[slot].1
        node.elements[slot].1 = payload
        return old
    }

    /// Insert a new element after the cursor's current position, and position the cursor on the new element.
    ///
    /// - Complexity: amortized O(1)
    public func insertAfter(element: Element) {
        precondition(!self.isAtEnd)
        count += 1
        if path.last!.isLeaf {
            let node = path.last!
            let slot = slots.last!
            node.insert(element, inSlot: slot + 1)
            slots[slots.count - 1] = slot + 1
            _position += 1
        }
        else {
            moveForward()
            let node = path.last!
            assert(node.isLeaf && slots.last == 0)
            node.insert(element, inSlot: 0)
        }
        fixupAfterInsert()
    }

    /// Insert a new element at the cursor's current position, and leave the cursor positioned on the original element.
    ///
    /// - Complexity: amortized O(1)
    public func insert(element: Element) {
        precondition(self.isValid)
        count += 1
        if path.last!.isLeaf {
            let node = path.last!
            let slot = slots.last!
            node.insert(element, inSlot: slot)
        }
        else {
            moveBackward()
            let node = path.last!
            assert(node.isLeaf && slots.last == node.elements.count - 1)
            node.append(element)
            slots[slots.count - 1] = node.elements.count - 1
            _position += 1
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
            if slot > left.elements.count {
                // Focused element is in the new branch; adjust state accordingly.
                slots[i] = slot - left.elements.count - 1
                path[i] = right
            }
            else if slot == left.elements.count {
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
                if slot > left.elements.count {
                    // Focused element is in the new branch; update state accordingly.
                    slots[i - 1] = pslot + 1
                }
                i -= 1
            }
            else {
                // Create new root node.
                self.root = Node(left: left, separator: splinter.separator, right: right)
                path.insert(self.root, atIndex: 0)
                slots.insert(slot > left.elements.count ? 1 : 0, atIndex: 0)
            }
        }

        // Size constraints are now OK, but counts on path have become valid, so we need to restore 
        // cursor state by subtracting focused children.
        while i < path.count - 1 {
            path[i].count -= path[i + 1].count
            i += 1
        }
    }

    /// Insert the contents of `tree` before the currently focused element, keeping the cursor's position on it.
    ///
    /// - Complexity: O(log(`count + tree.count`))
    public func insert(tree: Tree) {
        let root = tree.root.clone()
        insertWithoutCloning(root)
    }

    private func insertWithoutCloning(root: Node) {
        precondition(isValid)
        let c = root.count
        if c == 0 { return }
        if c == 1 {
            insert(root.elements[0])
            return
        }
        if self.count == 0 {
            reset(endOf: root)
            return
        }

        let position = self.position
        if position == self.count {
            // Append
            moveBackward()
            let separator = remove()
            let left = finish()
            reset(endOf: Node.join(left: left.root, separator: separator, right: root))
        }
        else if position == 0 {
            // Prepend
            let separator = remove()
            let right = finish()
            reset(root: Node.join(left: root, separator: separator, right: right.root), position: position + c)
        }
        else {
            // Insert in middle
            moveBackward()
            let sep1 = remove()
            let (prefix, sep2, suffix) = finishByCutting()
            let t1 = Node.join(left: prefix.root, separator: sep1, right: root)
            let t2 = Node.join(left: t1, separator: sep2, right: suffix.root)
            reset(root: t2, position: position + c)
        }
    }

    /// Insert all elements in a sequence before the currently focused element, keeping the cursor's position on it.
    ///
    /// - Requires: `self.isValid` and `elements` is sorted by key.
    /// - Complexity: O(log(`count`) + *c*), where *c* is the number of elements in the sequence.
    public func insert<S: SequenceType where S.Generator.Element == Element>(elements: S) {
        insertWithoutCloning(BTree(sortedElements: elements).root)
    }

    /// Remove and return the element at the cursor's current position, and position the cursor on its successor.
    ///
    /// - Complexity: O(log(`count`))
    public func remove() -> Element {
        precondition(!isAtEnd)
        var node = path.last!
        let slot = slots.last!
        let result = node.elements[slot]
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
        node.elements.removeAtIndex(slot)
        node.count -= 1
        self.count -= 1
        popFromSlots()

        while node !== root && node.isTooSmall {
            popFromPath()
            node = path.last!
            let slot = popFromSlots()
            node.fixDeficiency(slot)
        }
        while targetPosition != count && targetPosition == self.position && node !== root {
            popFromPath()
            node = path.last!
            popFromSlots()
        }
        if node === root && node.elements.count == 0 && node.children.count == 1 {
            assert(path.count == 1 && slots.count == 0)
            root = node.makeChildUnique(0)
            path[0] = root
        }
        descendToPosition(targetPosition)
        return result
    }

    /// Remove `n` elements starting at the cursor's current position, and position the cursor on the successor of
    /// the last element that was removed.
    ///
    /// - Complexity: O(log(`count`))
    public func remove(n: Int) {
        precondition(isValid && n >= 0 && self.position + n <= count)
        if n == 0 { return }
        if n == 1 { remove(); return }
        if n == count { reset(Node(order: root.order)); return }

        let position = self.position
        if position == 0 {
            moveToPosition(n - 1)
            reset(startOf: finishAndKeepSuffix().root)
        }
        else if position == count - n {
            reset(endOf: finishAndKeepPrefix().root)
        }
        else {
            let (left, _, mid) = finishByCutting()
            reset(root: mid.root, position: n - 1)
            let (_, separator, right) = finishByCutting()
            reset(root: Node.join(left: left.root, separator: separator, right: right.root), position: position)
        }
    }

    /// Remove all elements.
    ///
    /// - Complexity: O(log(`count`)) if nodes of this tree are shared with other trees; O(`count`) otherwise.
    public func removeAll() {
        reset(endOf: Node(order: root.order))
    }

    /// Remove all elements before (and if `inclusive` is true, including) the current position, and
    /// position the cursor at the start of the remaining tree.
    ///
    /// - Complexity: O(log(`count`)) if nodes of this tree are shared with other trees; O(`count`) otherwise.
    public func removeAllBefore(includingCurrent inclusive: Bool) {
        if isAtEnd {
            assert(!inclusive)
            reset(endOf: Node(order: root.order))
            return
        }
        if !inclusive {
            if isAtStart {
                return
            }
            moveBackward()
        }
        reset(startOf: finishAndKeepSuffix().root)
    }

    /// Remove all elements before (and if `inclusive` is true, including) the current position, and
    /// position the cursor on the end of the remaining tree.
    ///
    /// - Complexity: O(log(`count`)) if nodes of this tree are shared with other trees; O(`count`) otherwise.
    public func removeAllAfter(includingCurrent inclusive: Bool) {
        if isAtEnd {
            assert(!inclusive)
            return
        }
        if !inclusive {
            moveForward()
            if isAtEnd {
                return
            }
        }
        if isAtStart {
            reset(endOf: Node(order: root.order))
            return
        }
        reset(endOf: finishAndKeepPrefix().root)
    }

    /// Extract `n` elements starting at the cursor's current position, and position the cursor on the successor of
    /// the last element that was removed.
    ///
    /// - Returns: The extracted elements as a new b-tree.
    /// - Complexity: O(log(`count`))
    public func extract(n: Int) -> Tree {
        precondition(isValid && n >= 0 && self.position + n <= count)
        if n == 0 {
            return Tree(order: root.order)
        }
        if n == 1 {
            let element = remove()
            var tree = Tree(order: root.order)
            tree.insert(element)
            return tree
        }
        if n == count {
            let tree = finish()
            reset(Node(order: tree.root.order))
            return tree
        }

        let position = self.position
        if position == count - n {
            var cut = finishByCutting()
            reset(root: cut.left.root, position: position)
            cut.right.insert(cut.separator, at: 0)
            return cut.right
        }
        else {
            let cut1 = finishByCutting()
            reset(root: cut1.right.root, position: n - 1)
            var cut2 = finishByCutting()
            reset(root: Node.join(left: cut1.left.root, separator: cut2.separator, right: cut2.right.root), position: position)
            cut2.left.insert(cut1.separator, at: 0)
            return cut2.left
        }
    }

}