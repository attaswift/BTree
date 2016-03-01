//
//  BTreeMerger.swift
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

/// An abstraction for elementwise/subtreewise merging some of the elements from two trees into a new third tree.
///
/// Merging starts at the beginning of each tree, then proceeds in order from smaller to larger keys.
/// At each step you can decide which tree to merge elements/subtrees from next, until we reach the end of 
/// one of the trees.
struct BTreeMerger<Key: Comparable, Payload> {
    private var a: BTreeStrongPath<Key, Payload>
    private var b: BTreeStrongPath<Key, Payload>
    private var builder: BTreeBuilder<Key, Payload>

    /// This flag is set to `true` when we've reached the end of one of the trees.
    /// When this flag is set, you may only call `appendFirst` and/or `appendSecond` to append the remaining parts
    /// of whichever tree has elements left, or you may call `finish` to stop merging.
    internal var done: Bool

    /// Construct a new merger starting at the starts of the specified two trees.
    init(first: BTree<Key, Payload>, second: BTree<Key, Payload>) {
        precondition(first.order == second.order)
        self.a = BTreeStrongPath(startOf: first.root)
        self.b = BTreeStrongPath(startOf: second.root)
        self.builder = BTreeBuilder(order: first.order, keysPerNode: first.root.maxKeys)
        self.done = false // Can't use a/b until eveything has been initialized. :-/

        self.done = a.isAtEnd || b.isAtEnd
    }

    /// Stop merging and return the merged result.
    mutating func finish() -> BTree<Key, Payload> {
        return BTree(builder.finish())
    }

    /// Append the rest of the first tree to the end of the result tree, jump to the end of the first tree, and
    /// set `done` to true.
    ///
    /// You may call this method even when `done` has been set to true by an earlier operation. It does nothing
    /// if the merger has already reached the end of the first tree.
    ///
    /// - Complexity: O(log(first.count))
    mutating func appendFirst() {
        guard !a.isAtEnd else { return }
        builder.append(a.element)
        builder.append(a.suffix().root)
        a.moveToEnd()
        done = true
    }

    /// Append the rest of the second tree to the end of the result tree, jump to the end of the second tree, and
    /// set `done` to true.
    ///
    /// You may call this method even when `done` has been set to true by an earlier operation. It does nothing
    /// if the merger has already reached the end of the second tree.
    ///
    /// - Complexity: O(log(first.count))
    mutating func appendSecond() {
        guard !b.isAtEnd else { return }
        builder.append(b.element)
        builder.append(b.suffix().root)
        b.moveToEnd()
        done = true
    }

    /// Copy elements from the first tree (starting at the current position) that are less than (or, when `limit`
    /// is `.IncludingOtherKey`, less than or equal to) the key in the second tree at its the current position.
    ///
    /// This method will link entire subtrees to the result whenever possible, which can considerably speed up the operation.
    ///
    /// This method does nothing if `done` has been set to `true` by an earlier operation. It sets `done` to true
    /// if it reaches the end of the first tree.
    ///
    /// - Complexity: O(*n*) where *n* is the number of elements copied.
    mutating func copyFromFirst(limit: BTreeCopyLimit) {
        while !done && limit.match(a.key, with: b.key) {
            builder.append(a.nextPart(until: b.key, inclusive: limit.inclusive))
            done = a.isAtEnd
        }
    }

    /// Copy elements from the second tree (starting at the current position) that are less than (or, when `limit`
    /// is `.IncludingOtherKey`, less than or equal to) the key in the first tree at its the current position.
    ///
    /// This method will link entire subtrees to the result whenever possible, which can considerably speed up the operation.
    ///
    /// This method does nothing if `done` has been set to `true` by an earlier operation. It sets `done` to true
    /// if it reaches the end of the second tree.
    ///
    /// - Complexity: O(*n*) where *n* is the number of elements copied.
    mutating func copyFromSecond(limit: BTreeCopyLimit) {
        while !done && limit.match(b.key, with: a.key) {
            builder.append(b.nextPart(until: a.key, inclusive: limit.inclusive))
            done = b.isAtEnd
        }
    }

    /// Skip elements from the first tree (starting at the current position) that are less than (or, when `limit`
    /// is `.IncludingOtherKey`, less than or equal to) the key in the second tree at its the current position.
    ///
    /// This method will jump over entire subtrees to the result whenever possible, which can considerably speed up the operation.
    ///
    /// This method does nothing if `done` has been set to `true` by an earlier operation. It sets `done` to true
    /// if it reaches the end of the first tree.
    ///
    /// - Complexity: O(*n*) where *n* is the number of elements skipped.
    mutating func skipFromFirst(limit: BTreeCopyLimit) {
        while !done && limit.match(a.key, with: b.key) {
            a.nextPart(until: b.key, inclusive: limit.inclusive)
            done = a.isAtEnd
        }
    }

    /// Skip elements from the second tree (starting at the current position) that are less than (or, when `limit`
    /// is `.IncludingOtherKey`, less than or equal to) the key in the first tree at its the current position.
    ///
    /// This method will jump over entire subtrees to the result whenever possible, which can considerably speed up the operation.
    ///
    /// This method does nothing if `done` has been set to `true` by an earlier operation. It sets `done` to true
    /// if it reaches the end of the second tree.
    ///
    /// - Complexity: O(*n*) where *n* is the number of elements skipped.
    mutating func skipFromSecond(limit: BTreeCopyLimit) {
        while !done && limit.match(b.key, with: a.key) {
            b.nextPart(until: a.key, inclusive: limit.inclusive)
            done = b.isAtEnd
        }
    }

    /// Take the longest possible sequence of elements that share the same key in both trees; ignore elements from
    /// the first tree, but append elements from the second tree to the end of the result tree.
    ///
    /// This method does not care how many duplicate keys it finds for each key. For example, with
    /// `first = [0, 0, 1, 2, 2, 5, 6, 7]`, `second = [0, 1, 1, 1, 2, 2, 6, 8]`, it appends `[0, 1, 1, 1, 2, 2]`
    /// to the result, and leaves the first tree at `[5, 6, 7]` and the second at `[6, 8]`.
    ///
    /// This method recognizes nodes that are shared between the two trees, and links them to the result in one step.
    /// This can considerably speed up the operation.
    ///
    /// - Complexity: O(*n*) where *n* is the number of elements processed.
    mutating func copyCommonElementsFromSecond() {
        while !done && a.key == b.key {
            if a.node === b.node && a.node.isLeaf && a.slot == 0 && b.slot == 0 {
                /// We're at the first element of a shared subtree. Find the ancestor at which the shared subtree
                /// starts, and append it in a single step.
                ///
                /// It might happen that a shared node begins with a key that we've already fully processed in one of the trees.
                /// In this case, we cannot skip elementwise processing, since the trees are at different positions in
                /// the shared subtree. The slot & leaf checks above & below ensure that this isn't the case.
                repeat {
                    if a.ascendOneLevel() { done = true }
                    if b.ascendOneLevel() { done = true }
                } while !done && a.node === b.node && a.slot == 0 && b.slot == 0
                builder.append(b.isAtEnd ? b.root : b.node.children[b.slot!])
                if !a.isAtEnd { a.ascendToKey() }
                if !b.isAtEnd { b.ascendToKey() }
            }
            else {
                // Process the next run of equal keys in both trees, skipping them in `first`, but copying them from `second`.
                // Note that we cannot leave matching elements in either tree, even if we reach the end of the other.
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

    /// Ignore and jump over the longest possible sequence of elements that share the same key in both trees, 
    /// starting at the current positions.
    ///
    /// This method does not care how many duplicate keys it finds for each key. For example, with
    /// `first = [0, 0, 1, 2, 2, 5, 6, 7]`, `second = [0, 1, 1, 1, 2, 2, 6, 8]`, it skips to
    /// `[5, 6, 7]` in the first tree, and `[6, 8]` in the second.
    ///
    /// This method recognizes nodes that are shared between the two trees, and jumps over them in one step.
    /// This can considerably speed up the operation.
    ///
    /// - Complexity: O(*n*) where *n* is the number of elements processed.
    mutating func skipCommonElements() {
        while !done && a.key == b.key {
            if a.node === b.node {
                /// We're inside a shared subtree. Find the ancestor at which the shared subtree
                /// starts, and append it in a single step.
                /// 
                /// This variant doesn't care about where we're in the shared subtree.
                /// It assumes that if we ignore one set of common keys, we're ignoring all.
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
                // Process the next run of equal keys in both trees, skipping them in both trees.
                // Note that we cannot leave matching elements in either tree, even if we reach the end of the other.
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
        m.appendFirst()
        m.appendSecond()
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
        m.appendFirst()
        m.appendSecond()
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
        m.appendFirst()
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
        m.appendFirst()
        m.appendSecond()
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

    //MARK: Comparison

    public func elementsEqual(other: BTree, @noescape isEquivalent: (Element, Element) throws -> Bool) rethrows -> Bool {
        if self.root === other.root { return true }
        if self.count != other.count { return false }

        var a = BTreeStrongPath(startOf: self.root)
        var b = BTreeStrongPath(startOf: other.root)
        while !a.isAtEnd {
            if a.node === b.node {
                repeat {
                    a.ascendOneLevel()
                    b.ascendOneLevel()
                } while !a.isAtEnd && a.node === b.node
                if a.isAtEnd { break }
                a.ascendToKey()
                b.ascendToKey()
            }
            if try !isEquivalent(a.element, b.element) {
                return false
            }
            a.moveForward()
            b.moveForward()
        }
        return true
    }

    /// Returns true iff this tree has no elements whose keys are also in `tree`.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `tree.count`)) in general.
    ///    - O(log(`self.count` + `tree.count`)) if there are only a constant amount of interleaving element runs.
    public func isDisjointWith(tree: BTree) -> Bool {
        var a = BTreeStrongPath(startOf: self.root)
        var b = BTreeStrongPath(startOf: tree.root)
        if !a.isAtEnd && !b.isAtEnd {
            while true {
                if a.node === b.node || a.key == b.key {
                    return false
                }
                while a.key < b.key {
                    a.nextPart(until: b.key, inclusive: false)
                    if a.isAtEnd { break }
                }
                while b.key < a.key {
                    b.nextPart(until: a.key, inclusive: false)
                    if b.isAtEnd { break }
                }
            }
        }
        return true
    }

    /// Returns true iff all keys in `self` are also in `tree`.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `tree.count`)) in general.
    ///    - O(log(`self.count` + `tree.count`)) if there are only a constant amount of interleaving element runs.
    public func isSubsetOf(tree: BTree) -> Bool {
        return isSubsetOf(tree, strict: false)
    }

    /// Returns true iff all keys in `self` are also in `tree`,
    /// but `tree` contains at least one key that isn't in `self`.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `tree.count`)) in general.
    ///    - O(log(`self.count` + `tree.count`)) if there are only a constant amount of interleaving element runs.
    public func isStrictSubsetOf(tree: BTree) -> Bool {
        return isSubsetOf(tree, strict: true)
    }

    /// Returns true iff all keys in `tree` are also in `self`.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `tree.count`)) in general.
    ///    - O(log(`self.count` + `tree.count`)) if there are only a constant amount of interleaving element runs.
    public func isSupersetOf(tree: BTree) -> Bool {
        return tree.isSubsetOf(self, strict: false)
    }

    /// Returns true iff all keys in `tree` are also in `self`,
    /// but `self` contains at least one key that isn't in `tree`.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `tree.count`)) in general.
    ///    - O(log(`self.count` + `tree.count`)) if there are only a constant amount of interleaving element runs.
    public func isStrictSupersetOf(tree: BTree) -> Bool {
        return tree.isSubsetOf(self, strict: true)
    }

    internal func isSubsetOf(tree: BTree, strict: Bool) -> Bool {
        var a = BTreeStrongPath(startOf: self.root)
        var b = BTreeStrongPath(startOf: tree.root)
        var knownStrict = false
        if !a.isAtEnd && !b.isAtEnd {
            outer: while true {
                if a.key < b.key {
                    return false
                }
                while a.key == b.key {
                    let key = a.key
                    repeat {
                        a.nextPart(until: key, inclusive: true)
                    } while !a.isAtEnd && a.key == key
                    repeat {
                        b.nextPart(until: key, inclusive: true)
                    } while !b.isAtEnd && b.key == key
                    if a.isAtEnd {
                        knownStrict = knownStrict || !b.isAtEnd
                        break outer
                    }
                    if b.isAtEnd { return false }
                }
                while b.key < a.key {
                    knownStrict = true
                    b.nextPart(until: a.key, inclusive: false)
                    if b.isAtEnd { return false }
                }
            }
        }
        return !strict || knownStrict
    }
}