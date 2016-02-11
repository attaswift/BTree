//
//  List.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2016-02-11.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

/// A random-access collection of arbitrary elements.
/// `List` works like an `Array`, but lookup, insertion and removal of elements at any index have
/// logarithmic complexity. (`Array` has O(1) lookup, but removal/insertion at an arbitrary index costs O(count).)
///
/// `List` is a struct with copy-on-write value semantics.
/// It uses an in-memory b-tree for element storage, whose individual nodes may be shared with other lists.
/// Mutating a list whose storage is (partially or completely) shared requires copying of O(log(`count`)) elements.
/// (Thus, mutation of shared lists may be cheaper than arrays, which need to copy all elements.
/// Unfortunately, this advantage is often overshadowed by the increased cost of element access.)
///
/// - Note: While `List` implements all formal requirements of `CollectionType`, it violates the semantic requirement 
///   that indexing has O(1) complexity: subscripting a `List` costs `O(log(count))`. Collection algorithms that
///   rely on subscripting will have higher complexity than expected. (This does not affect algorithms that use
///   generate() to iterate over elements.)
///
public struct List<Element> {
    internal typealias Node = BTreeNode<EmptyKey, Element>

    /// The root node.
    internal private(set) var root: Node

    /// Initialize an empty list.
    public init() {
        self.root = Node()
    }
}

internal struct EmptyKey: Comparable { }
internal func ==(a: EmptyKey, b: EmptyKey) -> Bool { return true }
internal func <(a: EmptyKey, b: EmptyKey) -> Bool { return false }

//MARK: Uniqueness

extension List {
    /// True if this list holds the only reference to its root node.
    private var isUnique: Bool {
        mutating get { return isUniquelyReferenced(&root) }
    }

    /// Ensure that this list holds the only reference to its root node, cloning it when necessary.
    private mutating func makeUnique() {
        guard !isUnique else { return }
        root = root.clone()
    }
}

//MARK: CollectionType

extension List: MutableCollectionType {
    public typealias Index = Int
    public typealias Generator = ListGenerator<Element>

    /// Always zero, which is the index of the first element when non-empty.
    public var startIndex: Int {
        return 0
    }

    /// The "past-the-end" element index; the successor of the last valid subscript argument.
    public var endIndex: Int {
        return root.count
    }

    /// The number of elements in this list.
    public var count: Int {
        return root.count
    }

    /// True iff this list has no elements.
    public var isEmpty: Bool {
        return count == 0
    }

    /// Get or set the element at the given index.
    ///
    /// - Complexity: O(log(`count`))
    public subscript(index: Int) -> Element {
        get {
            return root.elementAtPosition(index).1
        }
        set {
            makeUnique()
            root.editAtPosition(index) { node, slot, match in
                if match {
                    node.payloads[slot] = newValue
                }
            }
        }
    }

    /// Return a generator over all elements in this list.
    @warn_unused_result
    public func generate() -> Generator {
        return ListGenerator(root.generate())
    }
}

public struct ListGenerator<Element>: GeneratorType {
    private var base: BTreeGenerator<EmptyKey, Element>

    private init(_ base: BTreeGenerator<EmptyKey, Element>) {
        self.base = base
    }

    public mutating func next() -> Element? {
        return base.next()?.1
    }
}

// MARK: Algorithms

extension List {
    /// Call `body` on each element in `self` in ascending key order.
    ///
    /// - Complexity: O(`count`)
    public func forEach(@noescape body: (Element) throws -> ()) rethrows {
        try root.forEach { try body($0.1) }
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

    /// Returns the first index where `predicate` returns `true` for the corresponding value, or `nil` if such value is not found.
    public func indexOf(@noescape predicate: (Element) throws -> Bool) rethrows -> Index? {
        var i = 0
        try self.root.forEach { element -> Bool in
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
    /// Returns the first index where the given element appears in `self` or `nil` if the element is not found.
    public func indexOf(element: Element) -> Index? {
        var i = 0
        self.root.forEach { e -> Bool in
            if element == e.1 {
                return false
            }
            i += 1
            return true
        }
        return i < count ? i : nil
    }

    /// Return true iff `element` is in `self`.
    public func contains(element: Element) -> Bool {
        return indexOf(element) != nil
    }
}

//MARK: Initializers

extension List {
    public init<S: SequenceType where S.Generator.Element == Element>(_ elements: S) {
        self.init()
        self.appendContentsOf(elements)
    }
}

//MARK: Literal conversion

extension List: ArrayLiteralConvertible {
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

//MARK: String conversion

extension List: CustomStringConvertible {
    public var description: String {
        let contents = self.map { element in String(element) }
        return "[" + contents.joinWithSeparator(", ") + "]"
    }
}

extension List: CustomDebugStringConvertible {
    public var debugDescription: String {
        let contents = self.map { element in String(reflecting: element) }
        return "[" + contents.joinWithSeparator(", ") + "]"
    }
}

//MARK: Insertion

extension List {
    public mutating func append(element: Element) {
        makeUnique()
        if root.count == 0 {
            root.keys.append(EmptyKey())
            root.payloads.append(element)
            root.count = 1
            return
        }
        var splinter: BTreeSplinter<EmptyKey, Element>? = nil
        root.editAtPosition(root.count - 1) { node, slot, match in
            if match {
                assert(node.isLeaf)
                node.keys.append(EmptyKey())
                node.payloads.append(element)
                node.count += 1
                if node.isTooLarge {
                    splinter = node.split()
                }
            }
            else {
                node.count += 1
                if let s = splinter {
                    node.insert(s, inSlot: slot)
                    splinter = (node.isTooLarge ? node.split() : nil)
                }
            }
        }
        if let s = splinter {
            root = BTreeNode(order: root.order, keys: [s.separator.0], payloads: [s.separator.1], children: [root, s.node])
        }
    }

    private static func insert(element: Element, at position: Int, inTree root: Node) -> BTreeSplinter<EmptyKey, Element>? {
        precondition(position >= 0 && position <= root.count)
        var splinter: BTreeSplinter<EmptyKey, Element>? = nil
        root.editAtPosition(position) { node, slot, match in
            if node.isLeaf {
                assert(match)
                node.keys.append(EmptyKey())
                node.payloads.insert(element, atIndex: slot)
                node.count += 1
                if node.isTooLarge {
                    splinter = node.split()
                }
            }
            else {
                if match {
                    assert(slot < node.payloads.count)
                    assert(splinter == nil)
                    // For internal nodes, we move the new element in place of the one that was originally at the
                    // specified index, and insert the old element in its right subtree.
                    node.count += 1
                    let old = node.payloads[slot]
                    node.payloads[slot] = element
                    node.makeChildUnique(slot + 1)
                    if let s = insert(old, at: 0, inTree: node.children[slot + 1]) {
                        node.insert(s, inSlot: slot + 1)
                        splinter = (node.isTooLarge ? node.split() : nil)
                    }
                }
                else {
                    node.count += 1
                    if let s = splinter {
                        node.insert(s, inSlot: slot)
                        splinter = (node.isTooLarge ? node.split() : nil)
                    }
                }
            }
        }
        return splinter
    }

    public mutating func insert(element: Element, atIndex index: Int) {
        makeUnique()
        if let splinter = List.insert(element, at: index, inTree: root) {
            root = Node(
                order: root.order,
                keys: [splinter.separator.0],
                payloads: [splinter.separator.1],
                children: [root, splinter.node])
        }
    }

    public mutating func appendContentsOf<S: SequenceType where S.Generator.Element == Element>(elements: S) {
        // TODO: Performance: When S is also a List, it'd be possible to splice it into self in log(count) steps.

        makeUnique()

        let order = root.order

        // Prepare tree by collecting the nodes on the rightmost path, uniquing each of them.
        var path = [root]
        while !path[0].isLeaf {
            let parent = path[0]
            let c = parent.children.count
            parent.makeChildUnique(c - 1)
            path.insert(parent.children[c - 1], atIndex: 0)
        }
        var counts = [path[0].count] // Counts of nodes on path without their rightmost subtree
        for i in 1 ..< path.count {
            counts.append(path[i].count - path[i - 1].count)
        }

        // Now go through the supplied elements one by one and append each of them to `path`.
        // This is just a nonrecursive variant of `insert`, using `path` to eliminate the recursive descend.
        for element in elements {
            path[0].keys.append(EmptyKey())
            path[0].payloads.append(element)
            path[0].count += 1
            counts[0] += 1
            var i = 0
            while path[i].isTooLarge {
                let left = path[i]
                let splinter = left.split()
                let right = splinter.node
                path[i] = right
                counts[i] -= left.count + 1
                if i == path.count - 1 {
                    // Insert new root level
                    let new = Node(
                        order: order,
                        keys: [splinter.separator.0],
                        payloads: [splinter.separator.1],
                        children: [left, right])
                    path.append(new)
                    counts.append(left.count + 1)
                    self.root = new
                }
                else {
                    path[i + 1].keys.append(splinter.separator.0)
                    path[i + 1].payloads.append(splinter.separator.1)
                    path[i + 1].children.append(right)
                    counts[i + 1] += 1 + left.count
                    path[i + 1].count = counts[i + 1] + right.count
                }
                i += 1
            }
        }
        // Finally, update counts in rightmost path to root.
        for i in 1 ..< path.count {
            path[i].count = counts[i] + path[i - 1].count
        }
    }

    public mutating func insertContentsOf<S: SequenceType where S.Generator.Element == Element>(elements: S, atIndex index: Int) {
        // TODO: Performance: Generalize appendContentsOf
        var i = index
        for element in elements {
            insert(element, atIndex: i)
            i += 1
        }
    }

    internal static func removeAtIndex(index: Int, under root: Node) -> Element {
        var result: Element? = nil
        root.editAtPosition(index) { node, slot, match in
            if node.isLeaf {
                assert(match)
                node.keys.removeLast()
                result = node.payloads.removeAtIndex(slot)
                node.count -= 1
                return
            }
            if match {
                // For internal nodes, we move the previous item in place of the removed one,
                // and remove its original slot instead. (The previous item is always in a leaf node.)
                result = node.payloads[slot]
                node.makeChildUnique(slot)
                let previous = removeAtIndex(node.children[slot].count - 1, under: node.children[slot])
                node.payloads[slot] = previous
            }
            node.count -= 1
            if node.children[slot].isTooSmall {
                node.fixDeficiency(slot)
            }
        }
        return result!
    }

    public mutating func removeAtIndex(index: Int) -> Element {
        precondition(index >= 0 && index < count)
        makeUnique()
        let result = List.removeAtIndex(index, under: root)
        if root.keys.isEmpty && root.children.count == 1 {
            root = root.children[0]
        }
        return result
    }

    public mutating func removeFirst() -> Element {
        precondition(count > 0)
        return removeAtIndex(0)
    }

    public mutating func removeFirst(n: Int) {
        precondition(n <= count)
        removeRange(0..<n)
    }

    public mutating func removeLast() -> Element {
        precondition(count > 0)
        return removeAtIndex(count - 1)
    }

    public mutating func removeLast(n: Int) {
        precondition(n <= count)
        removeRange(n - count ..< count)
    }

    public mutating func popLast() -> Element? {
        guard count > 0 else { return nil }
        return removeLast()
    }

    public mutating func popFirst() -> Element? {
        guard count > 0 else { return nil }
        return removeFirst()
    }

    public mutating func removeRange(range: Range<Int>) {
        precondition(range.startIndex >= 0 && range.endIndex <= count)
        // TODO: Performance: It is possible to splice out the range in O(log(n)) steps.
        for _ in 0 ..< range.count {
            self.removeAtIndex(range.startIndex)
        }
    }

    public mutating func removeAll() {
        root = Node()
    }

    public mutating func replaceRange<C: CollectionType where C.Generator.Element == Element>(range: Range<Int>, with elements: C) {
        precondition(range.startIndex >= 0 && range.endIndex <= count)
        makeUnique()
        let common: Int = min(range.count, numericCast(elements.count))
        var generator = elements.generate()
        var index = root.indexOfPosition(range.startIndex)
        for _ in 0 ..< common {
            root.setPayloadAt(index, payload: generator.next()!)
            index.successorInPlace()
        }

        if common < range.count {
            self.removeRange(range.startIndex + common ..< range.endIndex)
        }
        else {
            self.insertContentsOf(GeneratorSequence(generator), atIndex: range.startIndex + common)
        }
    }
}

@warn_unused_result
public func ==<Element: Equatable>(a: List<Element>, b: List<Element>) -> Bool {
    guard a.count == b.count else { return false }
    return a.elementsEqual(b)
}

@warn_unused_result
public func !=<Element: Equatable>(a: List<Element>, b: List<Element>) -> Bool {
    return !(a == b)
}

