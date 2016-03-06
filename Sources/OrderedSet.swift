//
//  OrderedSet.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-25.
//  Copyright © 2016 Károly Lőrentey.
//

/// A sorted collection of unique comparable elements.
/// `OrderedSet` is like `Set` in the standard library, but it always keeps its elements in ascending order.
/// Lookup, insertion and removal of any element has logarithmic complexity.
///
/// `OrderedSet` is a struct with copy-on-write value semantics, like Swift's standard collection types.
/// It uses an in-memory b-tree for element storage, whose individual nodes may be shared with other ordered sets.
/// Mutating a set whose storage is (partially or completely) shared requires copying of only O(log(`count`)) elements.
/// (Thus, mutation of shared ordered sets may be cheaper than ordinary sets, which need to copy all elements.)
///
/// Set operations on ordered sets (such as taking the union, intersection or difference) can take as little as
/// O(log(n)) time if the elements in the source sets aren't interleaved.
public struct OrderedSet<Element: Comparable> {
    internal typealias Tree = BTree<Element, Void>

    /// The b-tree that serves as storage.
    internal private(set) var tree: Tree

    internal init(_ tree: Tree) {
        self.tree = tree
    }
}

extension OrderedSet: ArrayLiteralConvertible {
    //MARK: Initializers

    /// Create an empty set.
    public init() {
        self.tree = Tree()
    }

    /// Create a set from a finite sequence of items. The sequence need not be sorted.
    /// If the sequence contains duplicate items, only the last instance will be kept in the set.
    ///
    /// - Complexity: O(*n* * log(*n*)), where *n* is the number of items in the sequence.
    public init<S: SequenceType where S.Generator.Element == Element>(_ elements: S) {
        self.init(Tree(sortedElements: elements.sort().lazy.map { ($0, ()) }, dropDuplicates: true))
    }

    /// Create a set from a sorted finite sequence of items.
    /// If the sequence contains duplicate items, only the last instance will be kept in the set.
    ///
    /// - Complexity: O(*n*), where *n* is the number of items in the sequence.
    public init<S: SequenceType where S.Generator.Element == Element>(sortedElements elements: S) {
        self.init(Tree(sortedElements: elements.lazy.map { ($0, ()) }, dropDuplicates: true))
    }

    /// Create a set with the specified list of items.
    /// If the array literal contains duplicate items, only the last instance will be kept.
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension OrderedSet: CollectionType {
    //MARK: CollectionType

    public typealias Index = BTreeIndex<Element, Void>
    public typealias Generator = BTreeKeyGenerator<Element>
    public typealias SubSequence = OrderedSet<Element>

    /// The index of the first element when non-empty. Otherwise the same as `endIndex`.
    ///
    /// - Complexity: O(log(`count`))
    public var startIndex: Index {
        return tree.startIndex
    }

    /// The "past-the-end" element index; the successor of the last valid subscript argument.
    ///
    /// - Complexity: O(1)
    public var endIndex: Index {
        return tree.endIndex
    }

    /// The number of elements in this set.
    public var count: Int {
        return tree.count
    }

    /// True iff this collection has no elements.
    public var isEmpty: Bool {
        return count == 0
    }

    /// Returns the element at the given index.
    ///
    /// - Requires: `index` originated from an unmutated copy of this set.
    /// - Complexity: O(1)
    public subscript(index: Index) -> Element {
        return tree[index].0
    }

    /// Return the subset consisting of elements in the given range of indexes.
    ///
    /// - Requires: The indexes in `range` originated from an unmutated copy of this set.
    /// - Complexity: O(log(`count`))
    public subscript(range: Range<Index>) -> OrderedSet<Element> {
        return OrderedSet(tree[range])
    }

    /// Return a generator over all elements in this map, in ascending key order.
    @warn_unused_result
    public func generate() -> Generator {
        return Generator(tree.generate())
    }
}

extension OrderedSet {
    //MARK: Offset-based access

    /// Returns the element at `offset` from the start of the set.
    ///
    /// - Complexity: O(log(`count`))
    public subscript(offset: Int) -> Element {
        return tree.elementAtOffset(offset).0
    }

    /// Returns the subset containing elements in the specified range of offsets from the start of the set.
    ///
    /// - Complexity: O(log(`count`))
    public subscript(offsetRange: Range<Int>) -> OrderedSet<Element> {
        return OrderedSet(tree.subtree(with: offsetRange))
    }
}

extension OrderedSet {
    //MARK: Algorithms

    /// Call `body` on each element in `self` in ascending order.
    public func forEach(@noescape body: (Element) throws -> Void) rethrows {
        return try tree.forEach { try body($0.0) }
    }

    /// Return an `Array` containing the results of mapping transform over `self`.
    @warn_unused_result
    public func map<T>(@noescape transform: (Element) throws -> T) rethrows -> [T] {
        return try tree.map { try transform($0.0) }
    }

    /// Return an `Array` containing the concatenated results of mapping `transform` over `self`.
    @warn_unused_result
    public func flatMap<S : SequenceType>(transform: (Element) throws -> S) rethrows -> [S.Generator.Element] {
        return try tree.flatMap { try transform($0.0) }
    }

    /// Return an `Array` containing the non-`nil` results of mapping `transform` over `self`.
    @warn_unused_result
    public func flatMap<T>(@noescape transform: (Element) throws -> T?) rethrows -> [T] {
        return try tree.flatMap { try transform($0.0) }
    }

    /// Return an `Array` containing the elements of `self`, in ascending order, that satisfy the predicate `includeElement`.
    @warn_unused_result
    public func filter(@noescape includeElement: (Element) throws -> Bool) rethrows -> [Element] {
        var result: [Element] = []
        try tree.forEach { e -> () in
            if try includeElement(e.0) {
                result.append(e.0)
            }
        }
        return result
    }

    /// Return the result of repeatedly calling `combine` with an accumulated value initialized to `initial`
    /// and each element of `self`, in turn.
    /// I.e., return `combine(combine(...combine(combine(initial, self[0]), self[1]),...self[count-2]), self[count-1])`.
    @warn_unused_result
    public func reduce<T>(initial: T, @noescape combine: (T, Element) throws -> T) rethrows -> T {
        return try tree.reduce(initial, combine: { try combine($0, $1.0) })
    }
}

extension OrderedSet {
    //MARK: Extractions

    /// Return the smallest element in the set, or `nil` if the set is empty.
    ///
    /// - Complexity: O(log(`count`))
    public var first: Element? { return tree.first?.0 }

    /// Return the largest element in the set, or `nil` if the set is empty.
    ///
    /// - Complexity: O(log(`count`))
    public var last: Element? { return tree.last?.0 }

    /// Return the smallest element in the set, or `nil` if the set is empty.
    ///
    /// - Complexity: O(log(`count`))
    @warn_unused_result
    public func minElement() -> Element? { return first }

    /// Return the largest element in the set, or `nil` if the set is empty.
    ///
    /// - Complexity: O(log(`count`))
    @warn_unused_result
    public func maxElement() -> Element? { return last }

    // Return a copy of this set with the smallest element removed.
    ///
    /// - Complexity: O(log(`count`))
    @warn_unused_result
    public func dropFirst() -> OrderedSet {
        return OrderedSet(tree.dropFirst())
    }

    // Return a copy of this set with the `n` smallest elements removed.
    ///
    /// - Complexity: O(log(`count`))
    @warn_unused_result
    public func dropFirst(n: Int) -> OrderedSet {
        return OrderedSet(tree.dropFirst(n))
    }

    // Return a copy of this set with the largest element removed.
    ///
    /// - Complexity: O(log(`count`))
    @warn_unused_result
    public func dropLast() -> OrderedSet {
        return OrderedSet(tree.dropLast())
    }

    // Return a copy of this set with the `n` largest elements removed.
    ///
    /// - Complexity: O(log(`count`))
    @warn_unused_result
    public func dropLast(n: Int) -> OrderedSet {
        return OrderedSet(tree.dropLast(n))
    }

    /// Returns a subset, up to `maxLength` in size, containing the smallest elements in this set.
    ///
    /// If `maxLength` exceeds `self.count`, the result contains all the elements of `self`.
    ///
    /// - Complexity: O(log(`count`))
    @warn_unused_result
    public func prefix(maxLength: Int) -> OrderedSet {
        return OrderedSet(tree.prefix(maxLength))
    }

    /// Returns a subset containing all members of this set at or before the specified index.
    ///
    /// - Complexity: O(log(`count`))
    @warn_unused_result
    public func prefixThrough(index: Index) -> OrderedSet {
        return OrderedSet(tree.prefixThrough(index))
    }

    /// Returns a subset containing all members of this set less than or equal to the specified element
    /// (which may or may not be a member of this set).
    ///
    /// - Complexity: O(log(`count`))
    @warn_unused_result
    public func prefixThrough(element: Element) -> OrderedSet {
        return OrderedSet(tree.prefixThrough(element))
    }

    /// Returns a subset containing all members of this set before the specified index.
    ///
    /// - Complexity: O(log(`count`))
    @warn_unused_result
    public func prefixUpTo(end: Index) -> OrderedSet {
        return OrderedSet(tree.prefixUpTo(end))
    }

    /// Returns a subset containing all members of this set less than the specified element
    /// (which may or may not be a member of this set).
    ///
    /// - Complexity: O(log(`count`))
    @warn_unused_result
    public func prefixUpTo(end: Element) -> OrderedSet {
        return OrderedSet(tree.prefixUpTo(end))
    }

    /// Returns a subset, up to `maxLength` in size, containing the largest elements in this set.
    ///
    /// If `maxLength` exceeds `self.count`, the result contains all the elements of `self`.
    ///
    /// - Complexity: O(log(`count`))
    @warn_unused_result
    public func suffix(maxLength: Int) -> OrderedSet {
        return OrderedSet(tree.suffix(maxLength))
    }

    /// Returns a subset containing all members of this set at or after the specified index.
    ///
    /// - Complexity: O(log(`count`))
    @warn_unused_result
    public func suffixFrom(index: Index) -> OrderedSet {
        return OrderedSet(tree.suffixFrom(index))
    }

    /// Returns a subset containing all members of this set greater than or equal to the specified element
    /// (which may or may not be a member of this set).
    ///
    /// - Complexity: O(log(`count`))
    @warn_unused_result
    public func suffixFrom(element: Element) -> OrderedSet {
        return OrderedSet(tree.suffixFrom(element))
    }
}

extension OrderedSet: CustomStringConvertible, CustomDebugStringConvertible {
    //MARK: Conversion to string

    /// A textual representation of this set.
    public var description: String {
        let contents = self.map { String(reflecting: $0) }
        return "[" + contents.joinWithSeparator(", ") + "]"
    }

    /// A textual representation of this set, suitable for debugging.
    public var debugDescription: String {
        return "OrderedSet(" + description + ")"
    }
}

extension OrderedSet {
    //MARK: Queries

    /// Return true if the set contains `element`.
    ///
    /// - Complexity: O(log(`count`))
    @warn_unused_result
    public func contains(element: Element) -> Bool {
        return tree.payloadOf(element) != nil
    }

    /// Returns the index of a given member, or `nil` if the member is not present in the set.
    ///
    /// - Complexity: O(log(`count`))
    @warn_unused_result
    public func indexOf(member: Element) -> BTreeIndex<Element, Void>? {
        return tree.indexOf(member)
    }
}

extension OrderedSet: Equatable {
    //MARK: Set comparions

    /// Return `true` iff `self` and `other` contain the same elements.
    ///
    /// This method skips over shared subtrees when possible; this can drastically improve performance when the
    /// two lists are divergent mutations originating from the same value.
    ///
    /// - Complexity:  O(`count`)
    @warn_unused_result
    public func elementsEqual(other: OrderedSet<Element>) -> Bool {
        return self.tree.elementsEqual(other.tree, isEquivalent: { $0.0 == $1.0 })
    }

    /// Returns `true` iff no members in this set are also included in `other`.
    ///
    /// The elements of the two input sets may be freely interleaved.
    /// However, if there are long runs of non-interleaved elements, parts of the input sets will be simply
    /// linked into the result instead of copying, which can drastically improve performance.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `other.count`)) in general.
    ///    - O(log(`self.count` + `other.count`)) if there are only a constant amount of interleaving element runs.
    @warn_unused_result
    public func isDisjointWith(other: OrderedSet<Element>) -> Bool {
        return tree.isDisjointWith(other.tree)
    }

    /// Returns `true` iff all members in this set are also included in `other`.
    ///
    /// The elements of the two input sets may be freely interleaved.
    /// However, if there are long runs of non-interleaved elements, parts of the input sets will be simply
    /// linked into the result instead of copying, which can drastically improve performance.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `other.count`)) in general.
    ///    - O(log(`self.count` + `other.count`)) if there are only a constant amount of interleaving element runs.
    @warn_unused_result
    public func isSubsetOf(other: OrderedSet<Element>) -> Bool {
        return tree.isSubsetOf(other.tree)
    }

    /// Returns `true` iff all members in this set are also included in `other`, but the two sets aren't equal.
    ///
    /// The elements of the two input sets may be freely interleaved.
    /// However, if there are long runs of non-interleaved elements, parts of the input sets will be simply
    /// linked into the result instead of copying, which can drastically improve performance.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `other.count`)) in general.
    ///    - O(log(`self.count` + `other.count`)) if there are only a constant amount of interleaving element runs.
    @warn_unused_result
    public func isStrictSubsetOf(other: OrderedSet<Element>) -> Bool {
        return tree.isStrictSubsetOf(other.tree)
    }

    /// Returns `true` iff all members in `other` are also included in this set.
    ///
    /// The elements of the two input sets may be freely interleaved.
    /// However, if there are long runs of non-interleaved elements, parts of the input sets will be simply
    /// linked into the result instead of copying, which can drastically improve performance.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `other.count`)) in general.
    ///    - O(log(`self.count` + `other.count`)) if there are only a constant amount of interleaving element runs.
    @warn_unused_result
    public func isSupersetOf(other: OrderedSet<Element>) -> Bool {
        return tree.isSupersetOf(other.tree)
    }

    /// Returns `true` iff all members in `other` are also included in this set, but the two sets aren't equal.
    ///
    /// The elements of the two input sets may be freely interleaved.
    /// However, if there are long runs of non-interleaved elements, parts of the input sets will be simply
    /// linked into the result instead of copying, which can drastically improve performance.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `other.count`)) in general.
    ///    - O(log(`self.count` + `other.count`)) if there are only a constant amount of interleaving element runs.
    @warn_unused_result
    public func isStrictSupersetOf(other: OrderedSet<Element>) -> Bool {
        return tree.isStrictSupersetOf(other.tree)
    }
}

/// Returns `true` iff `a` contains the same elements as `b`.
///
/// This function skips over shared subtrees when possible; this can drastically improve performance when the
/// two sets are divergent mutations originating from the same value.
///
/// - Complexity: O(`count`)
@warn_unused_result
public func == <Element: Comparable>(a: OrderedSet<Element>, b: OrderedSet<Element>) -> Bool {
    return a.elementsEqual(b)
}

extension OrderedSet {
    //MARK: Insertion

    /// Insert a member into the set.
    ///
    /// - Complexity: O(log(`count`))
    public mutating func insert(element: Element) {
        tree.insertOrReplace((element, ()))
    }
}

extension OrderedSet {
    //MARK: Removal

    /// Remove the member from the set and return it if it was present.
    ///
    /// - Complexity: O(log(`count`))
    public mutating func remove(element: Element) -> Element? {
        return tree.remove(element)?.0
    }

    /// Remove the member referenced by the given index.
    ///
    /// - Complexity: O(log(`count`))
    public mutating func removeAtIndex(index: Index) -> Element {
        return tree.removeAtIndex(index).0
    }

    /// Remove and return the smallest member in this set.
    ///
    /// - Complexity: O(log(`count`))
    mutating func removeFirst() -> Element {
        return tree.removeFirst().0
    }

    /// Remove the smallest `n` members from this set.
    ///
    /// - Complexity: O(log(`count`))
    mutating func removeFirst(n: Int) {
        tree.removeFirst(n)
    }

    /// Remove and return the smallest member in this set, or return `nil` if the set is empty.
    ///
    /// - Complexity: O(log(`count`))
    public mutating func popFirst() -> Element? {
        return tree.popFirst()?.0
    }

    /// Remove and return the largest member in this set.
    ///
    /// - Complexity: O(log(`count`))
    mutating func removeLast() -> Element {
        return tree.removeLast().0
    }

    /// Remove the largest `n` members from this set.
    ///
    /// - Complexity: O(log(`count`))
    mutating func removeLast(n: Int) {
        tree.removeLast(n)
    }

    /// Remove and return the largest member in this set, or return `nil` if the set is empty.
    ///
    /// - Complexity: O(log(`count`))
    public mutating func popLast() -> Element? {
        return tree.popLast()?.0
    }

    /// Remove all members from this set.
    public mutating func removeAll() {
        tree.removeAll()
    }
}

extension OrderedSet {
    //MARK: Sorting

    /// Return an `Array` containing the members of this set, in ascending order.
    ///
    /// `Map` already keeps its elements sorted, so this is equivalent to `Array(self)`.
    ///
    /// - Complexity: O(`count`)
    public func sort() -> [Element] {
        // The set is already sorted.
        return Array(self)
    }
}

extension OrderedSet {
    //MARK: Set operations

    /// Return a set containing all members in both this set and `other`.
    ///
    /// The elements of the two input sets may be freely interleaved.
    /// However, if there are long runs of non-interleaved elements, parts of the input sets will be simply
    /// linked into the result instead of copying, which can drastically improve performance.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `other.count`)) in general.
    ///    - O(log(`self.count` + `other.count`)) if there are only a constant amount of interleaving element runs.
    @warn_unused_result
    public func union(other: OrderedSet<Element>) -> OrderedSet<Element> {
        return OrderedSet(self.tree.distinctUnion(other.tree))
    }

    /// Add all members in `other` to this set.
    ///
    /// The elements of the two input sets may be freely interleaved.
    /// However, if there are long runs of non-interleaved elements, parts of the input sets will be simply
    /// linked into the result instead of copying, which can drastically improve performance.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `other.count`)) in general.
    ///    - O(log(`self.count` + `other.count`)) if there are only a constant amount of interleaving element runs.
    public mutating func unionInPlace(other: OrderedSet<Element>) {
        self = self.union(other)
    }

    /// Return a set consisting of all members in `other` that are also in this set.
    ///
    /// The elements of the two input sets may be freely interleaved.
    /// However, if there are long runs of non-interleaved elements, parts of the input sets will be simply
    /// linked into the result instead of copying, which can drastically improve performance.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `other.count`)) in general.
    ///    - O(log(`self.count` + `other.count`)) if there are only a constant amount of interleaving element runs.
    @warn_unused_result
    public func intersect(other: OrderedSet<Element>) -> OrderedSet<Element> {
        return OrderedSet(self.tree.intersect(other.tree))
    }

    /// Remove all members from this set that are not included in `other`.
    ///
    /// The elements of the two input sets may be freely interleaved.
    /// However, if there are long runs of non-interleaved elements, parts of the input sets will be simply
    /// linked into the result instead of copying, which can drastically improve performance.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `other.count`)) in general.
    ///    - O(log(`self.count` + `other.count`)) if there are only a constant amount of interleaving element runs.
    public mutating func intersectInPlace(other: OrderedSet<Element>) {
        self = other.intersect(self)
    }

    /// Return a set containing those members of this set that aren't also included in `other`.
    ///
    /// The elements of the two input sets may be freely interleaved.
    /// However, if there are long runs of non-interleaved elements, parts of the input sets will be simply
    /// linked into the result instead of copying, which can drastically improve performance.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `other.count`)) in general.
    ///    - O(log(`self.count` + `other.count`)) if there are only a constant amount of interleaving element runs.
    @warn_unused_result
    public func subtract(other: OrderedSet) -> OrderedSet {
        return OrderedSet(self.tree.subtract(other.tree))
    }

    /// Remove all members from this set that are also included in `other`.
    ///
    /// The elements of the two input sets may be freely interleaved.
    /// However, if there are long runs of non-interleaved elements, parts of the input sets will be simply
    /// linked into the result instead of copying, which can drastically improve performance.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `other.count`)) in general.
    ///    - O(log(`self.count` + `other.count`)) if there are only a constant amount of interleaving element runs.
    public mutating func subtractInPlace(other: OrderedSet) {
        self = self.subtract(other)
    }

    /// Return a set consisting of members from `self` and `other` that aren't in both sets at once.
    ///
    /// The elements of the two input sets may be freely interleaved.
    /// However, if there are long runs of non-interleaved elements, parts of the input sets will be simply
    /// linked into the result instead of copying, which can drastically improve performance.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `other.count`)) in general.
    ///    - O(log(`self.count` + `other.count`)) if there are only a constant amount of interleaving element runs.
    @warn_unused_result
    public func exclusiveOr(other: OrderedSet<Element>) -> OrderedSet<Element> {
        return OrderedSet(self.tree.exclusiveOr(other.tree))
    }

    /// Replace `self` with a set consisting of members from `self` and `other` that aren't in both sets at once.
    ///
    /// The elements of the two input sets may be freely interleaved.
    /// However, if there are long runs of non-interleaved elements, parts of the input sets will be simply
    /// linked into the result instead of copying, which can drastically improve performance.
    ///
    /// - Complexity:
    ///    - O(min(`self.count`, `other.count`)) in general.
    ///    - O(log(`self.count` + `other.count`)) if there are only a constant amount of interleaving element runs.
    public mutating func exclusiveOrInPlace(other: OrderedSet<Element>) {
        self = self.exclusiveOr(other)
    }
}
