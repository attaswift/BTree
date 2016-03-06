//
//  BTreeComparator.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-03-04.
//  Copyright © 2016 Károly Lőrentey.
//

extension BTree {
    //MARK: Comparison

    /// Return `true` iff `self` and `other` contain equivalent elements, using `isEquivalent` as the equivalence test.
    ///
    /// This method skips over shared subtrees when possible; this can drastically improve performance when the 
    /// two trees are divergent mutations originating from the same value.
    ///
    /// - Requires: `isEquivalent` is an [equivalence relation].
    /// - Complexity:  O(`count`)
    ///
    /// [equivalence relation]: https://en.wikipedia.org/wiki/Equivalence_relation
    public func elementsEqual(other: BTree, @noescape isEquivalent: (Element, Element) throws -> Bool) rethrows -> Bool {
        if self.root === other.root { return true }
        if self.count != other.count { return false }

        var a = BTreeStrongPath(startOf: self.root)
        var b = BTreeStrongPath(startOf: other.root)
        while !a.isAtEnd {
            if a.node === b.node && a.slot == b.slot {
                // Ascend to first ancestor that isn't shared.
                repeat {
                    a.ascendOneLevel()
                    b.ascendOneLevel()
                } while !a.isAtEnd && a.node === b.node && a.slot == b.slot
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
}

extension BTree where Payload: Equatable {
    /// Return `true` iff `self` and `other` contain equal elements.
    ///
    /// This method skips over shared subtrees when possible; this can drastically improve performance when the
    /// two trees are divergent mutations originating from the same value.
    ///
    /// - Complexity:  O(`count`)
    public func elementsEqual(other: BTree) -> Bool {
        return self.elementsEqual(other, isEquivalent: { $0.0 == $1.0 && $0.1 == $1.1 })
    }
}

/// Return `true` iff `a` and `b` contain equal elements.
///
/// This method skips over shared subtrees when possible; this can drastically improve performance when the
/// two trees are divergent mutations originating from the same value.
///
/// - Complexity:  O(`count`)
public func == <Key: Comparable, Payload: Equatable>(a: BTree<Key, Payload>, b: BTree<Key, Payload>) -> Bool {
    return a.elementsEqual(b)
}

/// Return `true` iff `a` and `b` do not contain equal elements.
///
/// This method skips over shared subtrees when possible; this can drastically improve performance when the
/// two trees are divergent mutations originating from the same value.
///
/// - Complexity:  O(`count`)
public func != <Key: Comparable, Payload: Equatable>(a: BTree<Key, Payload>, b: BTree<Key, Payload>) -> Bool {
    return !(a == b)
}

extension BTree {
    /// Returns true iff this tree has no elements whose keys are also in `tree`.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `tree.count`)) in general.
    ///    - O(log(`self.count` + `tree.count`)) if there are only a constant amount of interleaving element runs.
    public func isDisjointWith(tree: BTree) -> Bool {
        var a = BTreeStrongPath(startOf: self.root)
        var b = BTreeStrongPath(startOf: tree.root)
        if !a.isAtEnd && !b.isAtEnd {
            outer: while true {
                if a.key == b.key {
                    return false
                }
                while a.key < b.key {
                    a.nextPart(until: b.key, inclusive: false)
                    if a.isAtEnd { break outer }
                }
                while b.key < a.key {
                    b.nextPart(until: a.key, inclusive: false)
                    if b.isAtEnd { break outer }
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
                    while a.node === b.node && a.slot == b.slot {
                        // Ascend to first ancestor that isn't shared.
                        repeat {
                            a.ascendOneLevel()
                            b.ascendOneLevel()
                        } while !a.isAtEnd && a.node === b.node && a.slot == b.slot
                        if a.isAtEnd { break outer }
                        a.ascendToKey()
                        b.ascendToKey()
                    }
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
