//
//  RedBlackTree.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-14.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

internal enum RedBlackColor {
    case Red
    case Black
}

internal struct RedBlackPayload<Value: RedBlackValue> {
    var value: Value
    var color: RedBlackColor = .Red

    init(value: Value) {
        self.value = value
    }
}

internal enum RedBlackComparisonResult<Key> {
    /// The value matches the key.
    case Found
    /// The search should continue with the child towards `direction`, using the given replacement key.
    case Descend(Direction, with: Key)
}

/// The value of a node in our red-black tree holds some state that can be compared with a key to determine if the
/// value matches the key, or if not, which direction the matching should descend further.
/// This is used to implement variants of red-black trees, with different semantics for the key.
///
/// There are three implementations of this protocol:
///
/// - `MapValue` is used to implement `Map<Key, Value>`, an ordered dictionary.
/// - `ListValue` is used to implement `List<Element>, a list with logarithmic lookup/insert/remove/append operations.
///   `List` defines a red-black tree where the "key" of a node is the current index of it in the list.
internal protocol RedBlackValue {
    typealias Key: Equatable
    typealias State = Void

    static var zeroState: State { get }
    var state: State { get }

    func compare(key: Key, children: StateAccessor<Self>, insert: Bool) -> RedBlackComparisonResult<Key>

    /// If the value augments the red-black tree, recalculate the state with the new children.
    /// Return true if this node's parent node also needs to be updated.
    mutating func updateState(children: StateAccessor<Self>) -> Bool
}

extension RedBlackValue where State == Void {
    static var zeroState: State { return () }
    var state: Void { return () }

    mutating func updateState(children: StateAccessor<Self>) -> Bool { return false }
}

struct StateAccessor<Value: RedBlackValue> {
    typealias Tree = RedBlackTree<Value>
    typealias Index = Tree.Index
    typealias State = Value.State

    private let _tree: Tree
    private let _left: Index?
    private let _right: Index?

    private init(tree: Tree, left: Index?, right: Index?) {
        self._tree = tree
        self._left = left
        self._right = right
    }

    internal var left: State { return _tree.state(_left) }
    internal var right: State { return _tree.state(_right) }
}

/// A Red-Black tree implementation with copy-on-write value semantics, optionally augmented.
/// The implementation supports augmenting the red-black tree to support positional addressing and other special effects.
internal struct RedBlackTree<Value: RedBlackValue>: SequenceType {
    // Implementation mostly follows Cormen et al.[1], with many adjustments.
    //
    // [1]: Cormen, Leiserson, Rivest, Stein: Introduction to Algorithms, 2nd ed. (MIT Press, 2001)

    internal typealias Key = Value.Key
    internal typealias Payload = RedBlackPayload<Value>
    internal typealias Tree = BinaryTree<Payload>
    internal typealias Index = Tree.Index
    internal typealias Slot = Tree.Slot

    internal private(set) var tree: Tree

    // Init

    internal init() {
        self.tree = Tree()
    }

    internal var count: Int { return tree.count }

    internal func generate() -> AnyGenerator<Value> {
        var index = first
        return anyGenerator { () -> Value? in
            guard let i = index else { return nil }
            index = self.successor(i)
            return self[i] as Value
        }
    }

    internal var root: Index? { return tree.root }

    internal subscript(index: Index) -> Value {
        get {
            return tree[index].payload.value
        }
        set(newValue) {
            // The new value must have the same key as the old.
            self.tree[index].payload.value = newValue
        }
    }
    internal subscript(index: Index?) -> Value? {
        guard let index = index else { return nil }
        return tree[index].payload.value
    }

    internal func find(key: Key) -> Index? {
        var key = key
        var index = tree.root
        while let i = index {
            switch self.compare(i, key: key, insert: false) {
            case .Found:
                return i
            case .Descend(let d, with: let k):
                key = k
                index = tree[i, d]
            }
        }
        return nil
    }

    internal var first: Index? {
        guard let r = root else { return nil }
        return minimumUnder(r)
    }

    internal var last: Index? {
        guard let r = root else { return nil }
        return maximumUnder(r)
    }

    internal func successor(index: Index) -> Index? {
        return step(index, towards: .Right)
    }

    internal func predecessor(index: Index) -> Index? {
        return step(index, towards: .Left)
    }

    internal func insertionSlotFor(key: Key) -> (Index?, Slot) {
        guard let root = tree.root else { return (nil, .Root) }

        func slot(child: Index?, _ parent: Index?, _ direction: Direction?) -> (Index?, Slot) {
            guard let d = direction else { return (child, .Root) }
            return (child, .Toward(d, under: parent!))
        }

        var key = key
        var parent: Index? = nil
        var direction: Direction? = nil
        var child = tree.root

        while let c = child {
            switch self.compare(c, key: key, insert: true) {
            case .Found:
                return slot(c, parent, direction)
            case .Descend(let d, with: let k):
                key = k
                parent = c
                direction = d
                child = tree[c, d]
            }
        }
        return slot(nil, parent, direction)
    }

    internal mutating func insert(value: Value, into slot: Slot) -> Index {
        assert(tree.indexInSlot(slot) == nil)
        let index = tree.insert(Payload(value: value), into: slot)
        return rebalanceAfterInsert(index, slot: slot)
    }

    internal mutating func remove(index: Index) -> Value {
        let payload = tree[index].payload

        // Find the node that we will actually remove. The node has to have at most one child.
        let y: Index
        if let _ = tree[index].left, let r = tree[index].right {
            y = minimumUnder(r) // Remove node following original index
            self[index] = self[y]
            fixup(y)
        }
        else {
            y = index
        }

        let color = tree[y].payload.color
        let slot = tree.remove(y)
        if color == .Black {
            rebalanceAfterRemove(slot)
        }
        else if case .Toward(_, under: let p) = slot {
            fixup(p)
        }
        return payload.value
    }

    internal mutating func reserveCapacity(minimumCapacity: Int) {
        self.tree.reserveCapacity(minimumCapacity)
    }

    internal mutating func removeAll(keepCapacity keepCapacity: Bool = false) {
        tree.removeAll(keepCapacity: keepCapacity)
    }

    // Lookup utilites

    private func color(index: Index?) -> RedBlackColor {
        guard let index = index else { return .Black }
        return tree[index].payload.color
    }
    private func isRed(index: Index?) -> Bool {
        return color(index) == .Red
    }
    private func isBlack(index: Index?) -> Bool {
        return color(index) == .Black
    }
    private mutating func setRed(index: Index) {
        tree[index].payload.color = .Red
    }
    private mutating func setBlack(index: Index?) {
        guard let index = index else { return } // nils are already black
        tree[index].payload.color = .Black
    }
    private mutating func setColor(index: Index, _ color: RedBlackColor) {
        tree[index].payload.color = color
    }

    private func state(index: Index?) -> Value.State {
        guard sizeof(Value.State.self) > 0 else { return Value.zeroState }
        if let node = tree[index] {
            return node.payload.value.state
        }
        else {
            return Value.zeroState
        }
    }

    private func compare(index: Index, key: Key, insert: Bool) -> RedBlackComparisonResult<Key> {
        let node = tree[index]
        let result = node.payload.value.compare(key, children: StateAccessor(tree: self, left: node.left, right: node.right), insert: insert)
        return result
    }

    private mutating func fixup(index: Index?) -> Bool {
        guard sizeof(Value.State.self) > 0 else { return false }
        guard let index = index else { return false }
        var node = tree[index]
        let result = node.payload.value.updateState(StateAccessor(tree: self, left: node.left, right: node.right))
        tree[index].payload.value = node.payload.value
        return result
    }

    private mutating func fixupChain(index: Index) {
        guard sizeof(Value.State.self) > 0 else { return }
        var index: Index? = index
        while let i = index where self.fixup(i) {
            index = tree[i].parent
        }
    }

    // Private helpers

    private func step(index: Index, towards direction: Direction) -> Index? {
        if let n = tree[index, direction] {
            return tree.furthestLeafUnder(n, towards: direction.opposite)
        }
        var child = index
        var parent = tree[child].parent
        while let p = parent where child == tree[p, direction] {
            child = p
            parent = tree[child].parent
        }
        return parent
    }

    private func minimumUnder(index: Index) -> Index {
        return tree.furthestLeafUnder(index, towards: .Left)
    }

    private func maximumUnder(index: Index) -> Index {
        return tree.furthestLeafUnder(index, towards: .Right)
    }

    private mutating func rebalanceAfterInsert(new: Index, slot: Slot) -> Index {
        var new = new
        var child = new
        while case .Toward(let dir, under: let parent) = tree.slotOf(child) {
            guard isRed(parent) else {
                fixupChain(parent)
                break
            }
            fixup(parent)
            guard case .Toward(let pdir, under: let grandparent) = tree.slotOf(parent) else  { fatalError("Invalid tree with red root") }
            let popp = pdir.opposite

            if let aunt = tree[grandparent, popp] where isRed(aunt) {
                setBlack(parent)
                setBlack(aunt)
                setRed(grandparent)
                child = grandparent
            }
            else {
                if dir == popp {
                    self.rotate(parent, pdir)
                    if child == new {
                        new = parent // new node moved up a level
                    }
                }
                self.rotate(grandparent, popp)
                if parent == new {
                    new = grandparent // new node moved up a level
                }
                setBlack(grandparent)
                setRed(parent)
            }
        }
        tree[tree.root!].payload.color = .Black
        return new
    }

    private mutating func rebalanceAfterRemove(slot: Slot) {
        var slot = slot
        while case .Toward(let dir, under: let parent) = slot {
            let opp = dir.opposite
            let sibling = tree[parent, opp]! // we've removed a black node, so it definitely has a sibling.
            if isRed(sibling) { // (1)
                setBlack(sibling)
                setRed(parent)
                self.rotate(parent, dir)
                // Repeat with the new parent, which is the previous sibling.
                // Note that a red sibling must have had two non-nil children, so a sibling will still exist in the next iteration.
                slot = .Toward(dir, under: sibling)
                continue
            }
            let farNephew = tree[sibling, opp]
            if isRed(farNephew) { // (4)
                setColor(sibling, self.color(parent))
                setBlack(farNephew)
                setBlack(parent)
                self.rotate(parent, dir)
                break // We're done!
            }
            let closeNephew = tree[sibling, dir]
            if isRed(closeNephew) { // (3)
                setBlack(closeNephew)
                setRed(sibling)
                self.rotate(sibling, opp)
                // The previously red child of sibling has become the new sibling now.
                continue
            }
            else { // (2)
                // Both nephews are black. We are allowed to paint the sibling red.
                setRed(sibling)
                // There is now a missing black in both subtrees of parent. 
                if isRed(parent) { // We can finish this right now.
                    setBlack(parent)
                    fixupChain(parent)
                    return
                }
                // Repeat one level higher.
                slot = tree.slotOf(parent)
                fixup(parent)
            }
        }
        self.setBlack(self.root)
    }

    private mutating func rotate(parent: Index, _ direction: Direction) {
        let child = self.tree.rotate(parent, direction)
        fixup(child)
        fixup(parent)
    }
}

internal struct RedBlackInfo<Value: RedBlackValue>: CustomStringConvertible {
    let depths: Range<Int>
    let ranks: Range<Int>
    let invalidRedNodes: [RedBlackTree<Value>.Index]

    var isValidRedBlackTree: Bool {
        return ranks.count == 1 && invalidRedNodes.isEmpty
    }

    var description: String {
        return "[depth: \(depths.startIndex)...\(depths.endIndex - 1), rank: \(ranks.startIndex)...\(ranks.endIndex - 1), bad reds: \(invalidRedNodes)]"
    }
}
extension RedBlackTree {

    internal var debugInfo: RedBlackInfo<Value> {
        func walk(index: Index?, shouldBeBlack: Bool) -> RedBlackInfo<Value> {
            if let index = index {
                let color = self.color(index)
                let i1 = walk(tree[index].left, shouldBeBlack: color == .Red)
                let i2 = walk(tree[index].right, shouldBeBlack: color == .Red)
                let b = color == .Black ? 1 : 0

                let colorError: [Index] = (color == .Red && shouldBeBlack ? [index] : [])

                return RedBlackInfo(
                    depths: Range(
                        start: min(i1.depths.startIndex, i2.depths.startIndex) + 1,
                        end: max(i1.depths.endIndex, i2.depths.endIndex) + 1),
                    ranks: Range(
                        start: min(i1.ranks.startIndex, i2.ranks.startIndex) + b,
                        end: max(i1.ranks.endIndex, i2.ranks.endIndex) + b),
                    invalidRedNodes: i1.invalidRedNodes + i2.invalidRedNodes + colorError)
            }
            else {
                return RedBlackInfo(
                    depths: Range(start: 0, end: 1),
                    ranks: Range(start: 0, end: 1),
                    invalidRedNodes: [])
            }
        }
        return walk(tree.root, shouldBeBlack: true)
    }
}
