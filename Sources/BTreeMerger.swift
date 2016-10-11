//
//  BTreeMerger.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-27.
//  Copyright © 2016 Károly Lőrentey.
//

extension BTree {
    //MARK: Merging and set operations

    /// Merge all elements from two trees into a new tree, and return it.
    ///
    /// This is the non-distinct union operation: all elements from both trees are kept.
    /// The result may have duplicate keys, even if the input trees only had unique keys on their own.
    ///
    /// The elements of the two input trees may interleave and overlap in any combination.
    /// However, if there are long runs of non-interleaved elements, parts of the input trees will be entirely
    /// linked into the result instead of elementwise processing. This may drastically improve performance.
    ///
    /// This function does not perform special handling of shared nodes between the two trees, because
    /// the semantics of the operation require individual processing of all keys that appear in both trees.
    ///
    /// - SeeAlso: `distinctUnion(_:)` for the distinct variant of the same operation.
    /// - Complexity:
    ///    - O(`self.count` + `tree.count`) in general.
    ///    - O(log(`self.count` + `tree.count`)) if there are only a constant number of interleaving element runs.
    public func union(_ other: BTree) -> BTree {
        var m = BTreeMerger(first: self, second: other)
        while !m.done {
            m.copyFromFirst(.includingOtherKey)
            m.copyFromSecond(.excludingOtherKey)
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
    /// linked into the result instead of elementwise processing. This may drastically improve performance.
    ///
    /// This function also detects shared subtrees between the two trees,
    /// and links them directly into the result when possible.
    /// (Keys that appear in both trees otherwise require individual processing.)
    ///
    /// - SeeAlso: `union(_:)` for the non-distinct variant of the same operation.
    /// - Complexity:
    ///    - O(min(`self.count`, `tree.count`)) in general.
    ///    - O(log(`self.count` + `tree.count`)) if there are only a constant amount of interleaving element runs.
    public func distinctUnion(_ other: BTree) -> BTree {
        var m = BTreeMerger(first: self, second: other)
        while !m.done {
            m.copyFromFirst(.excludingOtherKey)
            m.copyFromSecond(.excludingOtherKey)
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
    /// skipped or linked into the result instead of elementwise processing. This may drastically improve performance.
    ///
    /// This function also detects and skips over shared subtrees between the two trees.
    /// (Keys that appear in both trees otherwise require individual processing.)
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `tree.count`)) in general.
    ///    - O(log(`self.count` + `tree.count`)) if there are only a constant amount of interleaving element runs.
    public func subtracting(_ other: BTree) -> BTree {
        var m = BTreeMerger(first: self, second: other)
        while !m.done {
            m.copyFromFirst(.excludingOtherKey)
            m.skipFromSecond(.excludingOtherKey)
            m.skipCommonElements()
        }
        m.appendFirst()
        return m.finish()
    }

    /// Return a tree containing those members of `first` whose keys aren't also included in `second`.
    /// For elements in `first` whose key multiplicity exceeds that of matching members in `second`,
    /// the extra elements are kept in the result.
    ///
    /// The elements of the two input trees may interleave and overlap in any combination.
    /// However, if there are long runs of non-interleaved elements, parts of the input trees will be entirely
    /// skipped or linked into the result instead of elementwise processing. This may drastically improve performance.
    ///
    /// This function also detects and skips over shared subtrees between the two trees.
    /// (Keys that appear in both trees otherwise require individual processing.)
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `tree.count`)) in general.
    ///    - O(log(`self.count` + `tree.count`)) if there are only a constant amount of interleaving element runs.
    public func bagSubtracting(_ other: BTree) -> BTree {
        var m = BTreeMerger(first: self, second: other)
        while !m.done {
            m.copyFromFirst(.excludingOtherKey)
            m.skipFromSecond(.excludingOtherKey)
            m.skipMatchingNumberOfCommonElements()
        }
        m.appendFirst()
        return m.finish()
    }

    /// Return a tree combining the elements of two input trees except those whose keys appear in both trees.
    ///
    /// The elements of the two input trees may interleave and overlap in any combination.
    /// However, if there are long runs of non-interleaved elements, parts of the input trees will be entirely
    /// linked into the result instead of elementwise processing. This may drastically improve performance.
    ///
    /// This function also detects and skips over shared subtrees between the two trees.
    /// (Keys that appear in both trees otherwise require individual processing.)
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `other.count`)) in general.
    ///    - O(log(`self.count` + `other.count`)) if there are only a constant amount of interleaving element runs.
    public func symmetricDifference(_ other: BTree) -> BTree {
        var m = BTreeMerger(first: self, second: other)
        while !m.done {
            m.copyFromFirst(.excludingOtherKey)
            m.copyFromSecond(.excludingOtherKey)
            m.skipCommonElements()
        }
        m.appendFirst()
        m.appendSecond()
        return m.finish()
    }

    /// Return a tree combining the elements of two input trees except those whose keys appear in both trees.
    /// For duplicate keys that have different multiplicities in the two trees, the last *d* elements with matching keys
    /// from the tree with greater multiplicity is kept in the result (where *d* is the absolute difference of multiplicities).
    ///
    /// The elements of the two input trees may interleave and overlap in any combination.
    /// However, if there are long runs of non-interleaved elements, parts of the input trees will be entirely
    /// linked into the result instead of elementwise processing. This may drastically improve performance.
    ///
    /// This function also detects and skips over shared subtrees between the two trees.
    /// (Keys that appear in both trees otherwise require individual processing.)
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `other.count`)) in general.
    ///    - O(log(`self.count` + `other.count`)) if there are only a constant amount of interleaving element runs.
    public func bagSymmetricDifference(_ other: BTree) -> BTree {
        var m = BTreeMerger(first: self, second: other)
        while !m.done {
            m.copyFromFirst(.excludingOtherKey)
            m.copyFromSecond(.excludingOtherKey)
            m.skipMatchingNumberOfCommonElements()
        }
        m.appendFirst()
        m.appendSecond()
        return m.finish()
    }

    /// Return a tree with the same elements as `other` except those whose keys are not also in `self`.
    /// The result is independent of the number of duplicate keys that match; if there is but a single member in `self`
    /// with a matching key, then all elements in `other` are kept that have the same key.
    ///
    /// The elements of the two input trees may interleave and overlap in any combination.
    /// However, if there are long runs of non-interleaved elements, parts of the input trees will be entirely
    /// skipped instead of elementwise processing. This may drastically improve performance.
    ///
    /// This function also detects shared subtrees between the two trees,
    /// and links them directly into the result when possible.
    /// (Keys that appear in both trees otherwise require individual processing.)
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `other.count`)) in general.
    ///    - O(log(`self.count` + `other.count`)) if there are only a constant amount of interleaving element runs.
    public func intersection(_ other: BTree) -> BTree {
        var m = BTreeMerger(first: self, second: other)
        while !m.done {
            m.skipFromFirst(.excludingOtherKey)
            m.skipFromSecond(.excludingOtherKey)
            m.copyCommonElementsFromSecond()
        }
        return m.finish()
    }

    /// Return a tree with those members from `other` whose key also appear in `self`.
    /// Members with duplicate keys are carefully matched in both trees; only as many members are kept from `other` as
    /// the number of elements with matching keys in `self`.
    ///
    /// The elements of the two input trees may interleave and overlap in any combination.
    /// However, if there are long runs of non-interleaved elements, parts of the input trees will be entirely
    /// skipped instead of elementwise processing. This may drastically improve performance.
    ///
    /// This function also detects shared subtrees between the two trees,
    /// and links them directly into the result when possible.
    /// (Keys that appear in both trees otherwise require individual processing.)
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `other.count`)) in general.
    ///    - O(log(`self.count` + `other.count`)) if there are only a constant amount of interleaving element runs.
    public func bagIntersection(_ other: BTree) -> BTree {
        var m = BTreeMerger(first: self, second: other)
        while !m.done {
            m.skipFromFirst(.excludingOtherKey)
            m.skipFromSecond(.excludingOtherKey)
            m.copyMatchingNumberOfCommonElementsFromSecond()
        }
        return m.finish()
    }


    /// Return a tree that contains all elements in `self` whose key is not in the supplied sorted sequence.
    ///
    /// - Requires: `sortedKeys` is sorted in ascending order.
    /// - Complexity: O(*n* * log(`count`)), where *n* is the number of keys in `sortedKeys`.
    public func subtracting<S: Sequence>(sortedKeys: S) -> BTree where S.Iterator.Element == Key {
        if self.isEmpty { return self }

        var b = BTreeBuilder<Key, Value>(order: self.order)
        var lastKey: Key? = nil
        var path = BTreeStrongPath(startOf: self.root)
        outer: for key in sortedKeys {
            precondition(lastKey == nil || lastKey! <= key)
            while path.key < key {
                b.append(path.nextPart(until: key, inclusive: false))
                if path.isAtEnd { break outer }
            }
            while path.key == key {
                path.nextPart(until: key, inclusive: true)
                if path.isAtEnd { break outer }
            }
            lastKey = key
        }
        if !path.isAtEnd {
            b.append(path.element)
            b.appendWithoutCloning(path.suffix().root)
        }
        return BTree(b.finish())
    }

    /// Return a tree that contains all elements in `self` whose key is in the supplied sorted sequence.
    ///
    /// - Requires: `sortedKeys` is sorted in ascending order.
    /// - Complexity: O(*n* * log(`count`)), where *n* is the number of keys in `sortedKeys`.
    public func intersection<S: Sequence>(sortedKeys: S) -> BTree where S.Iterator.Element == Key {
        if self.isEmpty { return self }

        var b = BTreeBuilder<Key, Value>(order: self.order)
        var lastKey: Key? = nil
        var path = BTreeStrongPath(startOf: self.root)
        outer: for key in sortedKeys {
            precondition(lastKey == nil || lastKey! <= key)
            while path.key < key {
                path.nextPart(until: key, inclusive: false)
                if path.isAtEnd { break outer }
            }
            while path.key == key {
                b.append(path.nextPart(until: key, inclusive: true))
                if path.isAtEnd { break outer }
            }
            lastKey = key
        }
        return BTree(b.finish())
    }
}

enum BTreeCopyLimit {
    case includingOtherKey
    case excludingOtherKey

    var inclusive: Bool { return self == .includingOtherKey }

    func match<Key: Comparable>(_ key: Key, with reference: Key) -> Bool {
        switch self {
        case .includingOtherKey:
            return key <= reference
        case .excludingOtherKey:
            return key < reference
        }
    }
}

/// An abstraction for elementwise/subtreewise merging some of the elements from two trees into a new third tree.
///
/// Merging starts at the beginning of each tree, then proceeds in order from smaller to larger keys.
/// At each step you can decide which tree to merge elements/subtrees from next, until we reach the end of
/// one of the trees.
internal struct BTreeMerger<Key: Comparable, Value> {
    private var a: BTreeStrongPath<Key, Value>
    private var b: BTreeStrongPath<Key, Value>
    private var builder: BTreeBuilder<Key, Value>

    /// This flag is set to `true` when we've reached the end of one of the trees.
    /// When this flag is set, you may further skips and copies will do nothing. 
    /// You may call `appendFirst` and/or `appendSecond` to append the remaining parts
    /// of whichever tree has elements left, or you may call `finish` to stop merging.
    internal var done: Bool

    /// Construct a new merger starting at the starts of the specified two trees.
    init(first: BTree<Key, Value>, second: BTree<Key, Value>) {
        precondition(first.order == second.order)
        self.a = BTreeStrongPath(startOf: first.root)
        self.b = BTreeStrongPath(startOf: second.root)
        self.builder = BTreeBuilder(order: first.order, keysPerNode: first.root.maxKeys)
        self.done = first.isEmpty || second.isEmpty
    }

    /// Stop merging and return the merged result.
    mutating func finish() -> BTree<Key, Value> {
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
    /// is `.includingOtherKey`, less than or equal to) the key in the second tree at its the current position.
    ///
    /// This method will link entire subtrees to the result whenever possible, which can considerably speed up the operation.
    ///
    /// This method does nothing if `done` has been set to `true` by an earlier operation. It sets `done` to true
    /// if it reaches the end of the first tree.
    ///
    /// - Complexity: O(*n*) where *n* is the number of elements copied.
    mutating func copyFromFirst(_ limit: BTreeCopyLimit) {
        while !done && limit.match(a.key, with: b.key) {
            builder.append(a.nextPart(until: b.key, inclusive: limit.inclusive))
            done = a.isAtEnd
        }
    }

    /// Copy elements from the second tree (starting at the current position) that are less than (or, when `limit`
    /// is `.includingOtherKey`, less than or equal to) the key in the first tree at its the current position.
    ///
    /// This method will link entire subtrees to the result whenever possible, which can considerably speed up the operation.
    ///
    /// This method does nothing if `done` has been set to `true` by an earlier operation. It sets `done` to true
    /// if it reaches the end of the second tree.
    ///
    /// - Complexity: O(*n*) where *n* is the number of elements copied.
    mutating func copyFromSecond(_ limit: BTreeCopyLimit) {
        while !done && limit.match(b.key, with: a.key) {
            builder.append(b.nextPart(until: a.key, inclusive: limit.inclusive))
            done = b.isAtEnd
        }
    }

    /// Skip elements from the first tree (starting at the current position) that are less than (or, when `limit`
    /// is `.includingOtherKey`, less than or equal to) the key in the second tree at its the current position.
    ///
    /// This method will jump over entire subtrees to the result whenever possible, which can considerably speed up the operation.
    ///
    /// This method does nothing if `done` has been set to `true` by an earlier operation. It sets `done` to true
    /// if it reaches the end of the first tree.
    ///
    /// - Complexity: O(*n*) where *n* is the number of elements skipped.
    mutating func skipFromFirst(_ limit: BTreeCopyLimit) {
        while !done && limit.match(a.key, with: b.key) {
            a.nextPart(until: b.key, inclusive: limit.inclusive)
            done = a.isAtEnd
        }
    }

    /// Skip elements from the second tree (starting at the current position) that are less than (or, when `limit`
    /// is `.includingOtherKey`, less than or equal to) the key in the first tree at its the current position.
    ///
    /// This method will jump over entire subtrees to the result whenever possible, which can considerably speed up the operation.
    ///
    /// This method does nothing if `done` has been set to `true` by an earlier operation. It sets `done` to true
    /// if it reaches the end of the second tree.
    ///
    /// - Complexity: O(*n*) where *n* is the number of elements skipped.
    mutating func skipFromSecond(_ limit: BTreeCopyLimit) {
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
                /// In this case, we cannot skip elementwise processing, since the trees are at different offsets in
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

    mutating func copyMatchingNumberOfCommonElementsFromSecond() {
        while !done && a.key == b.key {
            if a.node === b.node && a.node.isLeaf && a.slot == 0 && b.slot == 0 {
                /// We're at the first element of a shared subtree. Find the ancestor at which the shared subtree
                /// starts, and append it in a single step.
                ///
                /// It might happen that a shared node begins with a key that we've already fully processed in one of the trees.
                /// In this case, we cannot skip elementwise processing, since the trees are at different offsets in
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
                // Copy one matching element from the second tree, then step forward.
                // TODO: Count the number of matching elements in a and link entire subtrees from b into the result when possible.
                builder.append(b.element)
                a.moveForward()
                b.moveForward()
                done = a.isAtEnd || b.isAtEnd
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

    mutating func skipMatchingNumberOfCommonElements() {
        while !done && a.key == b.key {
            if a.node === b.node && a.node.isLeaf && a.slot == 0 && b.slot == 0 {
                /// We're at the first element of a shared subtree. Find the ancestor at which the shared subtree
                /// starts, and append it in a single step.
                ///
                /// It might happen that a shared node begins with a key that we've already fully processed in one of the trees.
                /// In this case, we cannot skip elementwise processing, since the trees are at different offsets in
                /// the shared subtree. The slot & leaf checks above & below ensure that this isn't the case.
                repeat {
                    if a.ascendOneLevel() { done = true }
                    if b.ascendOneLevel() { done = true }
                } while !done && a.node === b.node && a.slot == 0 && b.slot == 0
                if !a.isAtEnd { a.ascendToKey() }
                if !b.isAtEnd { b.ascendToKey() }
            }
            else {
                // Skip one matching element from both trees.
                a.moveForward()
                b.moveForward()
                done = a.isAtEnd || b.isAtEnd
            }
        }
    }
}

internal enum BTreePart<Key: Comparable, Value> {
    case element((Key, Value))
    case node(BTreeNode<Key, Value>)
    case nodeRange(BTreeNode<Key, Value>, CountableRange<Int>)
}

extension BTreeBuilder {
    mutating func append(_ part: BTreePart<Key, Value>) {
        switch part {
        case .element(let element):
            self.append(element)
        case .node(let node):
            self.appendWithoutCloning(node.clone())
        case .nodeRange(let node, let range):
            self.appendWithoutCloning(Node(node: node, slotRange: range))
        }
    }
}

internal extension BTreeStrongPath {
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
    internal mutating func skipForward(_ n: Int) {
        if !node.isLeaf {
            for i in 0 ..< n {
                let s = slot! + i
                offset += node.children[s + 1].count
            }
        }
        offset += n
        slot! += n
        if offset != count {
            ascendToKey()
        }
    }

    /// Remove the deepest path component, leaving the path at the element following the node that was previously focused,
    /// or the spot after all elements if the node was the rightmost child.
    @discardableResult
    mutating func ascendOneLevel() -> Bool {
        if length == 1 {
            offset = count
            slot = node.elements.count
            return true
        }
        popFromSlots()
        popFromPath()
        return isAtEnd
    }

    /// If this path got to a slot at the end of a node but it hasn't reached the end of the tree yet,
    /// ascend to the ancestor that holds the key corresponding to the current offset.
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
    @discardableResult
    mutating func nextPart(until key: Key, inclusive: Bool) -> BTreePart<Key, Value> {
        func match(_ k: Key) -> Bool {
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
            return .element(self.element)
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
            return .nodeRange(node, startSlot ..< endSlot)
        }
        // If the last subtree has non-matching elements, leave off `endSlot - 1` from the returned range.
        if endSlot == startSlot + 1 {
            let n = node.children[slot!]
            return .node(n)
        }
        defer { skipForward(endSlot - startSlot - 1) }
        return .nodeRange(node, startSlot ..< endSlot - 1)
    }
}
