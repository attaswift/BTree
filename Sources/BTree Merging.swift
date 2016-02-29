//
//  BTree Merging.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-27.
//  Copyright © 2016 Károly Lőrentey.
//

private extension BTreeStrongPath {
    /// The parent of `node` and the slot of `node` in its parent, or `nil` if `node` is the root node.
    private var parent: (Node, Int)? {
        guard !_path.isEmpty else { return nil }
        return (_path.last!, _slots.last!)
    }

    /// The key following the `node` at the same slot in its parent, or `nil` if there is no such key.
    private var parentKey: Key? {
        guard let parent = self.parent else { return nil }
        guard parent.1 < parent.0.elements.count else { return nil }
        return parent.0.elements[parent.1].0
    }

    /// Move sideways `n` slots to the right, skipping over subtrees along the way.
    private mutating func skipForward(n: Int) {
        if !node.isLeaf {
            for i in 0 ..< n {
                let s = slot! + i
                position += node.children[s + 1].count
            }
        }
        position += n
        slot! += n
        if position != count {
            ascendToKey()
        }
    }

    /// Remove the deepest path component, leaving the path at the element following the node that was previously focused,
    /// or the spot after all elements if the node was the rightmost child.
    mutating func ascendOneLevel() -> Bool {
        if length == 1 {
            position = count
            slot = node.elements.count
            return true
        }
        popFromSlots()
        popFromPath()
        return isAtEnd
    }

    /// If this path got to a slot at the end of a node but it hasn't reached the end of the tree yet,
    /// ascend to the ancestor that holds the key corresponding to the current position.
    mutating func ascendToKey() {
        assert(!isAtEnd)
        while slot == node.elements.count {
            slot = nil
            popFromPath()
        }
    }

    /// Return the next part in this tree that consists of elements less than `key`. If `inclusive` is true, also
    /// include elements matching `key`.
    /// The part returned is either a single element, or a range of elements in a node, including their associated subtrees.
    ///
    /// - Requires: The current position is not at the end of the tree, and the current key is matching the condition above.
    /// - Complexity: O(log(*n*)) where *n* is the number of elements in the returned part.
    mutating func nextPart(until key: Key, inclusive: Bool) -> BTreePart<Key, Payload> {
        func match(k: Key) -> Bool {
            return (inclusive && k <= key) || (!inclusive && k < key)
        }

        assert(!isAtEnd && match(self.key))

        // Find furthest ancestor whose entire leftmost subtree is guaranteed to consist of matching elements.
        assert(!isAtEnd)
        var includeLeftmostSubtree = false
        if slot == 0 && node.isLeaf {
            while slot == 0 {
                guard let pk = parentKey else { break }
                guard match(pk) else { break }
                ascendOneLevel()
                includeLeftmostSubtree = true
            }
        }
        if !includeLeftmostSubtree && !node.isLeaf {
            defer { moveForward() }
            return .Element(self.element)
        }

        // Find range of matching elements in `node`.
        assert(match(self.key))
        let startSlot = slot!
        var endSlot = startSlot + 1
        while endSlot < node.elements.count && match(node.elements[endSlot].0) {
            endSlot += 1
        }

        // See if we can include the subtree following the last matching element.
        // This is a log(n) check but it's worth it.
        let includeRightmostSubtree = node.isLeaf || match(node.children[endSlot].last!.0)
        if includeRightmostSubtree {
            defer { skipForward(endSlot - startSlot) }
            return .NodeRange(node, startSlot ..< endSlot)
        }
        // If the last subtree has non-matching elements, leave off `endSlot - 1` from the returned range.
        if endSlot == startSlot + 1 {
            let n = node.children[slot!]
            return .Node(n)
        }
        defer { skipForward(endSlot - startSlot - 1) }
        return .NodeRange(node, startSlot ..< endSlot - 1)
    }
}

internal enum BTreePart<Key: Comparable, Payload> {
    case Element((Key, Payload))
    case Node(BTreeNode<Key, Payload>)
    case NodeRange(BTreeNode<Key, Payload>, Range<Int>)
}

extension BTreeBuilder {
    mutating func append(part: BTreePart<Key, Payload>) {
        switch part {
        case .Element(let element):
            self.append(element)
        case .Node(let node):
            self.appendWithoutCloning(node.clone())
        case .NodeRange(let node, let range):
            self.appendWithoutCloning(Node(node: node, slotRange: range))
        }
    }
}

enum BTreeCopyLimit {
    case IncludingOtherKey
    case ExcludingOtherKey

    var inclusive: Bool { return self == .IncludingOtherKey }

    func match<Key: Comparable>(key: Key, with reference: Key) -> Bool {
        switch self {
        case .IncludingOtherKey:
            return key <= reference
        case .ExcludingOtherKey:
            return key < reference
        }
    }
}

struct BTreeMerger<Key: Comparable, Payload> {
    var a: BTreeStrongPath<Key, Payload>
    var b: BTreeStrongPath<Key, Payload>
    var builder: BTreeBuilder<Key, Payload>
    var done: Bool

    init(first: BTree<Key, Payload>, second: BTree<Key, Payload>) {
        precondition(first.order == second.order)
        self.a = BTreeStrongPath(startOf: first.root)
        self.b = BTreeStrongPath(startOf: second.root)
        self.builder = BTreeBuilder(order: first.order, keysPerNode: first.root.maxKeys)
        self.done = false // Can't use a/b until eveything has been initialized. :-/

        self.done = a.isAtEnd || b.isAtEnd
    }

    mutating func finish() -> BTree<Key, Payload> {
        return BTree(builder.finish())
    }

    mutating func appendA() {
        guard !a.isAtEnd else { return }
        builder.append(a.element)
        builder.append(a.suffix().root)
        a.moveToEnd()
        done = true
    }

    mutating func appendB() {
        guard !b.isAtEnd else { return }
        builder.append(b.element)
        builder.append(b.suffix().root)
        b.moveToEnd()
        done = true
    }

    mutating func copyFromFirst(limit: BTreeCopyLimit) {
        while !done && limit.match(a.key, with: b.key) {
            builder.append(a.nextPart(until: b.key, inclusive: limit.inclusive))
            done = a.isAtEnd
        }
    }

    mutating func copyFromSecond(limit: BTreeCopyLimit) {
        while !done && limit.match(b.key, with: a.key) {
            builder.append(b.nextPart(until: a.key, inclusive: limit.inclusive))
            done = b.isAtEnd
        }
    }
    mutating func skipFromFirst(limit: BTreeCopyLimit) {
        while !done && limit.match(a.key, with: b.key) {
            a.nextPart(until: b.key, inclusive: limit.inclusive)
            done = a.isAtEnd
        }
    }

    mutating func skipFromSecond(limit: BTreeCopyLimit) {
        while !done && limit.match(b.key, with: a.key) {
            b.nextPart(until: a.key, inclusive: limit.inclusive)
            done = b.isAtEnd
        }
    }

    mutating func copyCommonElementsFromSecond() {
        while !done && a.key == b.key {
            if a.node === b.node && a.node.isLeaf && a.slot == 0 && b.slot == 0 {
                repeat {
                    if a.ascendOneLevel() { done = true }
                    if b.ascendOneLevel() { done = true }
                } while !done && a.node === b.node && a.slot == 0 && b.slot == 0
                builder.append(b.isAtEnd ? b.root : b.node.children[b.slot!])
                if !a.isAtEnd { a.ascendToKey() }
                if !b.isAtEnd { b.ascendToKey() }
            }
            else {
                let key = a.key
                var doneA = false
                while !doneA && a.key == key {
                    a.nextPart(until: key, inclusive: true)
                    doneA = a.isAtEnd
                }
                var doneB = false
                while !doneB && b.key == key {
                    builder.append(b.nextPart(until: key, inclusive: true))
                    doneB = b.isAtEnd
                }
                done = doneA || doneB
            }
        }
    }

    mutating func skipCommonElements() {
        while !done && a.key == b.key {
            if a.node === b.node {
                assert(a.node.isLeaf && b.node.isLeaf)
                while !done && a.node === b.node {
                    assert(a.slot == b.slot)
                    if a.ascendOneLevel() { done = true }
                    if b.ascendOneLevel() { done = true }
                }
                if !a.isAtEnd { a.ascendToKey() }
                if !b.isAtEnd { b.ascendToKey() }
            }
            else {
                let key = a.key
                var doneA = false
                while !doneA && a.key == key {
                    a.nextPart(until: key, inclusive: true)
                    doneA = a.isAtEnd
                }
                var doneB = false
                while !doneB && b.key == key {
                    b.nextPart(until: key, inclusive: true)
                    doneB = b.isAtEnd
                }
                done = doneA || doneB
            }
        }
    }
}

extension BTree {
    /// Merge all elements from two trees into a new tree, and return it.
    ///
    /// This is the non-distinct union operation: all elements from both trees are kept.
    /// The result may have duplicate keys, even if the input trees only had unique keys on their own.
    ///
    /// The elements of the two input trees may interleave and overlap in any combination.
    /// However, if there are long runs of non-interleaved elements, parts of the input trees will be entirely
    /// linked into the result instead of elementwise processing. This drastically improves performance.
    ///
    /// This function does not perform special handling of shared nodes between the two trees, because
    /// the semantics of the operation require individual processing of all keys that appear in both trees.
    ///
    /// - SeeAlso: `distinctUnion(_:)` for the distinct variant of the same operation.
    /// - Complexity:
    ///    - O(min(`self.count`, `tree.count`)) in general.
    ///    - O(log(`self.count` + `tree.count`)) if there are only a constant number of interleaving element runs.
    public func union(other: BTree) -> BTree {
        var m = BTreeMerger(first: self, second: other)
        while !m.done {
            m.copyFromFirst(.IncludingOtherKey)
            m.copyFromSecond(.ExcludingOtherKey)
        }
        m.appendA()
        m.appendB()
        return BTree(m.finish())
    }

    /// Calculate the distinct union of two trees, and return the result.
    /// If the same key appears in both trees, only the matching element(s) in the second tree will be 
    /// included in the result.
    ///
    /// If neither input trees had duplicate keys on its own, the result won't have any duplicates, either.
    ///
    /// The elements of the two input trees may interleave and overlap in any combination.
    /// However, if there are long runs of non-interleaved elements, parts of the input trees will be entirely
    /// linked into the result instead of elementwise processing. This drastically improves performance.
    ///
    /// This function also detects shared subtrees between the two trees,
    /// and links them directly into the result when possible.
    /// (Keys that appear in both trees otherwise require individual processing.)
    ///
    /// - SeeAlso: `union(_:)` for the non-distinct variant of the same operation.
    /// - Complexity:
    ///    - O(min(`self.count`, `tree.count`)) in general.
    ///    - O(log(`self.count` + `tree.count`)) if there are only a constant amount of interleaving element runs.
    public func distinctUnion(other: BTree) -> BTree {
        var m = BTreeMerger(first: self, second: other)
        while !m.done {
            m.copyFromFirst(.ExcludingOtherKey)
            m.copyFromSecond(.ExcludingOtherKey)
            m.copyCommonElementsFromSecond()
        }
        m.appendA()
        m.appendB()
        return m.finish()
    }

    /// Return a tree with the same elements as `first` except those whose keys are also in `second`.
    ///
    /// The elements of the two input trees may interleave and overlap in any combination.
    /// However, if there are long runs of non-interleaved elements, parts of the input trees will be entirely
    /// skipped or linked into the result instead of elementwise processing. This drastically improves performance.
    ///
    /// This function also detects and skips over shared subtrees between the two trees.
    /// (Keys that appear in both trees otherwise require individual processing.)
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `tree.count`)) in general.
    ///    - O(log(`self.count` + `tree.count`)) if there are only a constant amount of interleaving element runs.
    public func subtract(other: BTree) -> BTree {
        var m = BTreeMerger(first: self, second: other)
        while !m.done {
            m.copyFromFirst(.ExcludingOtherKey)
            m.skipFromSecond(.ExcludingOtherKey)
            m.skipCommonElements()
        }
        m.appendA()
        return m.finish()
    }

    /// Return a tree combining the elements of two input trees except those whose keys appear in both inputs.
    ///
    /// The elements of the two input trees may interleave and overlap in any combination.
    /// However, if there are long runs of non-interleaved elements, parts of the input trees will be entirely
    /// linked into the result instead of elementwise processing. This drastically improves performance.
    ///
    /// This function also detects and skips over shared subtrees between the two trees.
    /// (Keys that appear in both trees otherwise require individual processing.)
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `tree.count`)) in general.
    ///    - O(log(`self.count` + `tree.count`)) if there are only a constant amount of interleaving element runs.
    public func exclusiveOr(other: BTree) -> BTree {
        var m = BTreeMerger(first: self, second: other)
        while !m.done {
            m.copyFromFirst(.ExcludingOtherKey)
            m.copyFromSecond(.ExcludingOtherKey)
            m.skipCommonElements()
        }
        m.appendA()
        m.appendB()
        return m.finish()
    }


    /// Return a tree with the same elements as `second` except those whose keys are not also in `first`.
    ///
    /// The elements of the two input trees may interleave and overlap in any combination.
    /// However, if there are long runs of non-interleaved elements, parts of the input trees will be entirely
    /// skipped instead of elementwise processing. This drastically improves performance.
    ///
    /// This function also detects shared subtrees between the two trees, 
    /// and links them directly into the result when possible.
    /// (Keys that appear in both trees otherwise require individual processing.)
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `tree.count`)) in general.
    ///    - O(log(`self.count` + `tree.count`)) if there are only a constant amount of interleaving element runs.
    public func intersect(other: BTree) -> BTree {
        var m = BTreeMerger(first: self, second: other)
        while !m.done {
            m.skipFromFirst(.ExcludingOtherKey)
            m.skipFromSecond(.ExcludingOtherKey)
            m.copyCommonElementsFromSecond()
        }
        return m.finish()
    }
}