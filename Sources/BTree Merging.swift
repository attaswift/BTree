//
//  BTree Merging.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-27.
//  Copyright © 2016 Károly Lőrentey.
//

extension BTreeStrongPath {
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

extension BTree {
    /// Merge all elements from two trees into a new tree, and return it.
    ///
    /// This is the non-distinct union operation: all elements from both trees are kept, regardless of duplicate keys.
    ///
    /// The elements of the two input trees may be freely interleaved.
    /// However, if there are long runs of non-interleaved elements, parts of the input trees will be simply
    /// linked into the result instead of copying, which can drastically improve performance.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `tree.count`)) in general.
    ///    - O(log(`self.count` + `tree.count`)) if there are only a constant amount of interleaving element runs.
    public static func union(first: BTree, _ second: BTree) -> BTree {
        precondition(first.order == second.order)
        var a = BTreeStrongPath(startOf: first.root)
        var b = BTreeStrongPath(startOf: second.root)
        var builder = BTreeBuilder<Key, Payload>(order: first.order, keysPerNode: first.root.maxKeys)
        if !a.isAtEnd && !b.isAtEnd {
            outer: while true {
                // Include elements from `a` until we take over `b`.
                while a.key <= b.key {
                    builder.append(a.nextPart(until: b.key, inclusive: true))
                    if a.isAtEnd { break outer }
                }
                // Include elements from `b` until we take over `a`.
                while b.key < a.key {
                    builder.append(b.nextPart(until: a.key, inclusive: false))
                    if b.isAtEnd { break outer }
                }
            }
        }
        let result = builder.finish()
        // Append leftover elements from either tree.
        if !a.isAtEnd {
            assert(b.isAtEnd)
            return BTree(Node.join(left: result, separator: a.element, right: a.suffix().root))
        }
        if !b.isAtEnd {
            return BTree(Node.join(left: result, separator: b.element, right: b.suffix().root))
        }
        return BTree(result)
    }

    /// Calculate the distinct union of two trees, and return the result.
    /// If the same key appears in both trees, only the matching element(s) in the second tree will be 
    /// included in the result.
    ///
    /// If neither input trees had duplicate keys on its own, the result won't have any duplicates, either.
    ///
    /// The elements of the two input trees may be freely interleaved.
    /// However, if there are long runs of non-interleaved elements, parts of the input trees will be simply 
    /// linked into the result instead of copying, which can drastically improve performance.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `tree.count`)) in general.
    ///    - O(log(`self.count` + `tree.count`)) if there are only a constant amount of interleaving element runs.
    public static func distinctUnion(first: BTree, _ second: BTree) -> BTree {
        precondition(first.order == second.order)
        var a = BTreeStrongPath(startOf: first.root)
        var b = BTreeStrongPath(startOf: second.root)
        var builder = BTreeBuilder<Key, Payload>(order: first.order, keysPerNode: first.root.maxKeys)
        if !a.isAtEnd && !b.isAtEnd {
            outer: while true {
                // Include elements in `a` whose keys aren't in `b`.
                while a.key < b.key {
                    builder.append(a.nextPart(until: b.key, inclusive: false))
                    if a.isAtEnd { break outer }
                }
                // Skip elements in `a` whose keys are in `b`.
                while a.key == b.key {
                    a.nextPart(until: b.key, inclusive: true)
                    if a.isAtEnd { break outer }
                }
                // Include elements in `b` until we catch up with `a`.
                while b.key < a.key {
                    builder.append(b.nextPart(until: a.key, inclusive: false))
                    if b.isAtEnd { break outer }
                }
            }
        }
        let result = builder.finish()
        // Append leftover elements from either tree.
        if !a.isAtEnd {
            assert(b.isAtEnd)
            return BTree(Node.join(left: result, separator: a.element, right: a.suffix().root))
        }
        if !b.isAtEnd {
            return BTree(Node.join(left: result, separator: b.element, right: b.suffix().root))
        }
        return BTree(result)
    }

    /// Return a tree with the same elements as `first` except those whose keys are also in `second`.
    ///
    /// The elements of the two input trees may be freely interleaved.
    /// However, if there are long runs of non-interleaved elements, parts of the input trees will be simply
    /// linked into the result instead of copying, which can drastically improve performance.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `tree.count`)) in general.
    ///    - O(log(`self.count` + `tree.count`)) if there are only a constant amount of interleaving element runs.
    public static func subtract(first: BTree, _ second: BTree) -> BTree {
        precondition(first.order == second.order)
        var a = BTreeStrongPath(startOf: first.root)
        var b = BTreeStrongPath(startOf: second.root)
        var builder = BTreeBuilder<Key, Payload>(order: first.order, keysPerNode: first.root.maxKeys)
        if !a.isAtEnd && !b.isAtEnd {
            outer: while true {
                // Include elements in `a` whose keys aren't in `b`.
                while a.key < b.key {
                    builder.append(a.nextPart(until: b.key, inclusive: false))
                    if a.isAtEnd { break outer }
                }
                // Skip elements in `a` whose keys are in `b`.
                while a.key == b.key {
                    a.nextPart(until: b.key, inclusive: true)
                    if a.isAtEnd { break outer }
                }
                // Skip elements in `b` until we catch up with `a`.
                while b.key < a.key {
                    b.nextPart(until: a.key, inclusive: false)
                    if b.isAtEnd { break outer }
                }
            }
        }
        let result = builder.finish()
        // Append elements left over from `a`.
        if !a.isAtEnd {
            assert(b.isAtEnd)
            return BTree(Node.join(left: result, separator: a.element, right: a.suffix().root))
        }
        return BTree(result)
    }

    /// Return a tree combining the elements of two input trees except those whose keys appear in both inputs.
    ///
    /// The elements of the two input trees may be freely interleaved.
    /// However, if there are long runs of non-interleaved elements, parts of the input trees will be simply
    /// linked into the result instead of copying, which can drastically improve performance.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `tree.count`)) in general.
    ///    - O(log(`self.count` + `tree.count`)) if there are only a constant amount of interleaving element runs.
    public static func exclusiveOr(first: BTree, _ second: BTree) -> BTree {
        precondition(first.order == second.order)
        var a = BTreeStrongPath(startOf: first.root)
        var b = BTreeStrongPath(startOf: second.root)
        var builder = BTreeBuilder<Key, Payload>(order: first.order, keysPerNode: first.root.maxKeys)
        if !a.isAtEnd && !b.isAtEnd {
            outer: while true {
                // Include elements in `a` whose keys aren't in `b`.
                while a.key < b.key {
                    builder.append(a.nextPart(until: b.key, inclusive: false))
                    if a.isAtEnd { break outer }
                }
                // Skip over elements with matching keys in both trees.
                if a.key == b.key {
                    let key = a.key
                    repeat {
                        a.nextPart(until: key, inclusive: true)
                    } while !a.isAtEnd && a.key == key
                    repeat {
                        b.nextPart(until: key, inclusive: true)
                    } while !b.isAtEnd && b.key == key
                    if a.isAtEnd || b.isAtEnd { break outer }
                }
                // Include elements in `b` whose keys aren't in `a`.
                while b.key < a.key {
                    builder.append(b.nextPart(until: a.key, inclusive: false))
                    if b.isAtEnd { break outer }
                }
            }
        }
        let result = builder.finish()
        // Append leftover elements from either tree.
        if !a.isAtEnd {
            assert(b.isAtEnd)
            return BTree(Node.join(left: result, separator: a.element, right: a.suffix().root))
        }
        if !b.isAtEnd {
            return BTree(Node.join(left: result, separator: b.element, right: b.suffix().root))
        }
        return BTree(result)
    }


    /// Return a tree with the same elements as `second` except those whose keys are not also in `first`.
    ///
    /// The elements of the two input trees may be freely interleaved.
    /// However, if there are long runs of non-interleaved elements, parts of the input trees will be simply
    /// linked into the result instead of copying, which can drastically improve performance.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `tree.count`)) in general.
    ///    - O(log(`self.count` + `tree.count`)) if there are only a constant amount of interleaving element runs.
    public static func intersect(first: BTree, _ second: BTree) -> BTree {
        precondition(first.order == second.order)
        var a = BTreeStrongPath(startOf: first.root)
        var b = BTreeStrongPath(startOf: second.root)
        var builder = BTreeBuilder<Key, Payload>(order: first.order, keysPerNode: first.root.maxKeys)
        if !a.isAtEnd && !b.isAtEnd {
            outer: while true {
                // Skip over elements in `a` whose keys aren't in `b`.
                while a.key < b.key {
                    a.nextPart(until: b.key, inclusive: false)
                    if a.isAtEnd { break outer }
                }
                if a.key == b.key {
                    let key = a.key
                    // Skip elements in `a` whose keys are shared with `b`.
                    repeat {
                        a.nextPart(until: key, inclusive: true)
                    } while !a.isAtEnd && a.key == key
                    // Include elements in `b` whose keys are shared with `a`.
                    repeat {
                        builder.append(b.nextPart(until: key, inclusive: true))
                    } while !b.isAtEnd && b.key == key
                    if a.isAtEnd || b.isAtEnd { break outer }
                }
                // Skip over elements in `b` whose keys aren't in `a`.
                while !b.isAtEnd && b.key < a.key {
                    b.nextPart(until: a.key, inclusive: false)
                    if b.isAtEnd { break outer }
                }
            }
        }
        return BTree(builder.finish())
    }
}