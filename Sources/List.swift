//
//  List.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-11.
//  Copyright © 2015–2016 Károly Lőrentey.
//

/// A random-access collection of arbitrary elements.
/// `List` works like an `Array`, but lookup, insertion and removal of elements at any index have
/// logarithmic complexity. (`Array` has O(1) lookup, but removal/insertion at an arbitrary index costs O(count).)
///
/// `List` is a struct with copy-on-write value semantics, like Swift's standard collection types.
/// It uses an in-memory B-tree for element storage, whose individual nodes may be shared with other lists.
/// Mutating a list whose storage is (partially or completely) shared requires copying of only O(log(`count`)) elements.
/// (Thus, mutation of shared lists may be relatively cheaper than arrays, which need to copy all elements.)
///
/// Lookup, insertion and removal of individual elements anywhere in a list have logarithmic complexity.
/// Using the batch operations provided by `List` can often be much faster than processing individual elements
/// one by one. For example, splitting a list or concatenating two lists can be done in O(log(n)) time.
///
/// - Note: While `List` implements all formal requirements of `CollectionType`, it violates the semantic requirement 
///   that indexing has O(1) complexity: subscripting a `List` costs `O(log(`count`))`. Collection algorithms that
///   rely on subscripting will have higher complexity than expected. (This does not affect algorithms that use
///   generate() to iterate over elements.)
///
public struct List<Element> {
    internal typealias Tree = BTree<EmptyKey, Element>

    /// The B-tree that serves as storage.
    internal private(set) var tree: Tree

    private init(_ tree: Tree) {
        self.tree = tree
    }
    
    /// Initialize an empty list.
    public init() {
        self.tree = Tree()
    }
}

/// A dummy, zero-size key that is useful in B-trees that don't need key-based lookup.
internal struct EmptyKey: Comparable { }
internal func ==(a: EmptyKey, b: EmptyKey) -> Bool { return true }
internal func <(a: EmptyKey, b: EmptyKey) -> Bool { return false }

extension List {
    //MARK: Initializers

    /// Initialize a new list from the given elements.
    ///
    /// - Complexity: O(*n*) where *n* is the number of elements in the sequence.
    public init<S: SequenceType where S.Generator.Element == Element>(_ elements: S) {
        self.init(Tree(sortedElements: elements.lazy.map { (EmptyKey(), $0) }))
    }
}

extension List: ArrayLiteralConvertible {
    //MARK: Conversion from an array literal

    /// Initialize a new list from the given elements.
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension List: CustomStringConvertible {
    //MARK: String conversion

    /// A textual representation of this list.
    public var description: String {
        let contents = self.map { element in String(reflecting: element) }
        return "[" + contents.joinWithSeparator(", ") + "]"
    }
}

extension List: CustomDebugStringConvertible {
    /// A textual representation of this list, suitable for debugging.
    public var debugDescription: String {
        let contents = self.map { element in String(reflecting: element) }
        return "[" + contents.joinWithSeparator(", ") + "]"
    }
}

extension List: MutableCollectionType {
    //MARK: CollectionType
    
    public typealias Index = Int
    public typealias Generator = BTreePayloadGenerator<Element>
    public typealias SubSequence = List<Element>

    /// Always zero, which is the index of the first element when non-empty.
    public var startIndex: Int {
        return 0
    }

    /// The "past-the-end" element index; the successor of the last valid subscript argument.
    public var endIndex: Int {
        return tree.count
    }

    /// The number of elements in this list.
    public var count: Int {
        return tree.count
    }

    /// True iff this list has no elements.
    public var isEmpty: Bool {
        return tree.count == 0
    }

    /// Get or set the element at the given index.
    ///
    /// - Complexity: O(log(`count`))
    public subscript(index: Int) -> Element {
        get {
            return tree.elementAtOffset(index).1
        }
        set {
            tree.setPayloadAt(index, to: newValue)
        }
    }

    /// Return a sublist of this list, or replace a sublist with another list (possibly of a different size).
    ///
    /// - Complexity: O(log(`count`)) for the getter, and O(log(`count`) + `range.count`) for the setter.
    public subscript(range: Range<Int>) -> List<Element> {
        get {
            return List(tree.subtree(with: range))
        }
        set {
            self.replaceRange(range, with: newValue)
        }
    }

    /// Return a generator over all elements in this list.
    @warn_unused_result
    public func generate() -> Generator {
        return Generator(tree.generate())
    }
}

extension List {
    // MARK: Algorithms
    
    /// Call `body` on each element in `self` in ascending key order.
    ///
    /// - Complexity: O(`count`)
    public func forEach(@noescape body: (Element) throws -> ()) rethrows {
        try tree.forEach { try body($0.1) }
    }

    /// Return an `Array` containing the results of mapping `transform` over all elements in `self`.
    /// The elements are transformed in ascending key order.
    ///
    /// - Complexity: O(`count`)
    @warn_unused_result
    public func map<T>(@noescape transform: (Element) throws -> T) rethrows -> [T] {
        var result: [T] = []
        result.reserveCapacity(self.count)
        try self.forEach {
            result.append(try transform($0))
        }
        return result
    }

    /// Return an `Array` containing the concatenated results of mapping `transform` over `self`.
    ///
    /// - Complexity: O(`result.count`)
    @warn_unused_result
    public func flatMap<S: SequenceType>(transform: (Element) throws -> S) rethrows -> [S.Generator.Element] {
        var result: [S.Generator.Element] = []
        try self.forEach { element in
            result.appendContentsOf(try transform(element))
        }
        return result
    }

    /// Return an `Array` containing the non-`nil` results of mapping `transform` over `self`.
    ///
    /// - Complexity: O(`count`)
    @warn_unused_result
    public func flatMap<T>(@noescape transform: (Element) throws -> T?) rethrows -> [T] {
        var result: [T] = []
        try self.forEach { element in
            if let t = try transform(element) {
                result.append(t)
            }
        }
        return result
    }

    /// Calculate the left fold of this list over `combine`:
    /// return the result of repeatedly calling `combine` with an accumulated value initialized to `initial`
    /// and each element of `self`, in turn.
    ///
    /// I.e., return `combine(combine(...combine(combine(initial, self[0]), self[1]),...self[count-2]), self[count-1])`.
    ///
    /// - Complexity: O(`count`)
    @warn_unused_result
    public func reduce<T>(initial: T, @noescape combine: (T, Element) throws -> T) rethrows -> T {
        var result = initial
        try self.forEach {
            result = try combine(result, $0)
        }
        return result
    }

    /// Return an `Array` containing the non-`nil` results of mapping `transform` over `self`.
    ///
    /// - Complexity: O(`count`)
    @warn_unused_result
    public func filter(@noescape includeElement: (Element) throws -> Bool) rethrows -> [Element] {
        var result: [Element] = []
        try self.forEach {
            if try includeElement($0) {
                result.append($0)
            }
        }
        return result
    }
}

public extension List {
    //MARK: Queries

    /// Return `true` iff `self` and `other` contain equivalent elements, using `isEquivalent` as the equivalence test.
    ///
    /// This method skips over shared subtrees when possible; this can drastically improve performance when the
    /// two lists are divergent mutations originating from the same value.
    ///
    /// - Requires: `isEquivalent` is an [equivalence relation].
    /// - Complexity:  O(`count`)
    ///
    /// [equivalence relation]: https://en.wikipedia.org/wiki/Equivalence_relation
    @warn_unused_result
    public func elementsEqual(other: List<Element>, @noescape isEquivalent: (Element, Element) throws -> Bool) rethrows -> Bool {
        return try self.tree.elementsEqual(other.tree, isEquivalent: { try isEquivalent($0.1, $1.1) })
    }

    /// Returns the first index where `predicate` returns `true` for the corresponding value, or `nil` if
    /// such value is not found.
    ///
    /// - Complexity: O(`count`)
    @warn_unused_result
    public func indexOf(@noescape predicate: (Element) throws -> Bool) rethrows -> Index? {
        var i = 0
        try self.tree.forEach { element -> Bool in
            if try predicate(element.1) {
                return false
            }
            i += 1
            return true
        }
        return i < count ? i : nil
    }
}

public extension List where Element: Equatable {

    /// Return `true` iff `self` and `other` contain equal elements.
    ///
    /// This method skips over shared subtrees when possible; this can drastically improve performance when the
    /// two lists are divergent mutations originating from the same value.
    ///
    /// - Requires: `isEquivalent` is an [equivalence relation].
    /// - Complexity:  O(`count`)
    ///
    /// [equivalence relation]: https://en.wikipedia.org/wiki/Equivalence_relation
    @warn_unused_result
    public func elementsEqual(other: List<Element>) -> Bool {
        return self.tree.elementsEqual(other.tree, isEquivalent: { $0.1 == $1.1 })
    }

    /// Returns the first index where the given element appears in `self` or `nil` if the element is not found.
    ///
    /// - Complexity: O(`count`)
    @warn_unused_result
    public func indexOf(element: Element) -> Index? {
        var i = 0
        self.tree.forEach { e -> Bool in
            if element == e.1 {
                return false
            }
            i += 1
            return true
        }
        return i < count ? i : nil
    }

    /// Return true iff `element` is in `self`.
    @warn_unused_result
    public func contains(element: Element) -> Bool {
        return indexOf(element) != nil
    }
}

extension List {
    //MARK: Insertion

    /// Append `element` to the end of this list.
    ///
    /// - Complexity: O(log(`count`))
    public mutating func append(element: Element) {
        tree.insert((EmptyKey(), element), at: tree.count)
    }

    /// Insert `element` into this list at `index`.
    ///
    /// - Complexity: O(log(`count`))
    public mutating func insert(element: Element, atIndex index: Int) {
        tree.insert((EmptyKey(), element), at: index)
    }

    /// Append `list` to the end of this list.
    ///
    /// - Complexity: O(log(`self.count + list.count`))
    public mutating func appendContentsOf(list: List<Element>) {
        tree.withCursorAtOffset(tree.count) { cursor in
            cursor.insert(list.tree)
        }
    }

    /// Append the contents of `elements` to the end of this list.
    ///
    /// - Complexity: O(log(`count`) + *n*) where *n* is the number of elements in the sequence.
    public mutating func appendContentsOf<S: SequenceType where S.Generator.Element == Element>(elements: S) {
        if let list = elements as? List<Element> {
            appendContentsOf(list)
            return
        }
        tree.withCursorAtOffset(tree.count) { cursor in
            cursor.insert(elements.lazy.map { (EmptyKey(), $0) })
        }
    }

    /// Insert `list` as a sublist of this list starting at `index`.
    ///
    /// - Complexity: O(log(`self.count + list.count`))
    public mutating func insertContentsOf(list: List<Element>, at index: Int) {
        tree.withCursorAtOffset(index) { cursor in
            cursor.insert(list.tree)
        }
    }

    /// Insert the contents of `elements` into this list starting at `index`.
    ///
    /// - Complexity: O(log(`self.count`) + *n*) where *n* is the number of elements inserted.
    public mutating func insertContentsOf<S: SequenceType where S.Generator.Element == Element>(elements: S, at index: Int) {
        if let list = elements as? List<Element> {
            insertContentsOf(list, at: index)
            return
        }
        tree.withCursorAtOffset(index) { cursor in
            cursor.insert(elements.lazy.map { (EmptyKey(), $0) })
        }
    }
}

extension List {
    //MARK: Removal

    /// Remove and return the element at `index`.
    ///
    /// - Complexity: O(log(`count`))
    public mutating func removeAtIndex(index: Int) -> Element {
        precondition(index >= 0 && index < count)
        return tree.removeAt(index).1
    }

    /// Remove and return the first element.
    ///
    /// - Complexity: O(log(`count`))
    public mutating func removeFirst() -> Element {
        precondition(count > 0)
        return tree.removeAt(0).1
    }

    /// Remove the first `n` elements.
    ///
    /// - Complexity: O(log(`count`) + `n`)
    public mutating func removeFirst(n: Int) {
        precondition(n <= count)
        tree.withCursorAtOffset(0) { cursor in
            cursor.remove(n)
        }
    }

    /// Remove and return the last element.
    ///
    /// - Complexity: O(log(`count`))
    public mutating func removeLast() -> Element {
        precondition(count > 0)
        return tree.removeAt(count - 1).1
    }

    /// Remove and return the last `n` elements.
    ///
    /// - Complexity: O(log(`count`) + `n`)
    public mutating func removeLast(n: Int) {
        precondition(n <= count)
        tree.withCursorAtOffset(count - n) { cursor in
            cursor.remove(n)
        }
    }

    /// If the list is not empty, remove and return the last element. Otherwise return `nil`.
    ///
    /// - Complexity: O(log(`count`))
    public mutating func popLast() -> Element? {
        guard count > 0 else { return nil }
        return tree.removeAt(count - 1).1
    }

    /// If the list is not empty, remove and return the first element. Otherwise return `nil`.
    ///
    /// - Complexity: O(log(`count`))
    public mutating func popFirst() -> Element? {
        guard count > 0 else { return nil }
        return tree.removeAt(0).1
    }

    /// Remove elements in the specified range of indexes.
    ///
    /// - Complexity: O(log(`self.count`) + `range.count`)
    public mutating func removeRange(range: Range<Int>) {
        precondition(range.startIndex >= 0 && range.endIndex <= count)
        tree.withCursorAtOffset(range.startIndex) { cursor in
            cursor.remove(range.count)
        }
    }

    /// Remove all elements.
    ///
    /// - Complexity: O(`count`)
    public mutating func removeAll() {
        tree = Tree()
    }
}

extension List: RangeReplaceableCollectionType {
    //MARK: Range replacement

    /// Replace elements in `range` with `elements`.
    ///
    /// - Complexity: O(log(`count`) + `range.count`)
    public mutating func replaceRange(range: Range<Int>, with elements: List<Element>) {
        precondition(range.startIndex >= 0 && range.endIndex <= count)
        tree.withCursorAtOffset(range.startIndex) { cursor in
            cursor.remove(range.count)
            cursor.insert(elements.tree)
        }
    }

    /// Replace elements in `range` with `elements`.
    ///
    /// - Complexity: O(log(`count`) + `max(range.count, elements.count)`)
    public mutating func replaceRange<C: CollectionType where C.Generator.Element == Element>(range: Range<Int>, with elements: C) {
        precondition(range.startIndex >= 0 && range.endIndex <= count)
        if let list = elements as? List<Element> {
            replaceRange(range, with: list)
            return
        }
        tree.withCursorAtOffset(range.startIndex) { cursor in
            var generator = Optional(elements.generate())
            while cursor.offset < range.endIndex {
                guard let element = generator!.next() else { generator = nil; break }
                cursor.payload = element
                cursor.moveForward()
            }
            if cursor.offset < range.endIndex {
                cursor.remove(range.endIndex - cursor.offset)
            }
            else {
                cursor.insert(GeneratorSequence(generator!).lazy.map { (EmptyKey(), $0) })
            }
        }
    }
}

/// Returns true iff the two lists have the same elements in the same order.
///
/// This function skips over shared subtrees when possible; this can drastically improve performance when the
/// two lists are divergent mutations originating from the same value.
///
/// - Complexity: O(`count`)
@warn_unused_result
public func ==<Element: Equatable>(a: List<Element>, b: List<Element>) -> Bool {
    return a.elementsEqual(b)
}

/// Returns false iff the two lists do not have the same elements in the same order.
@warn_unused_result
public func !=<Element: Equatable>(a: List<Element>, b: List<Element>) -> Bool {
    return !(a == b)
}

/// Concatenate `a` with `b` and return the resulting `List`.
@warn_unused_result
public func +<Element>(a: List<Element>, b: List<Element>) -> List<Element> {
    var result = a
    result.appendContentsOf(b)
    return result
}
