//
//  ArrayLikeCollectionType.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-15.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

public protocol ArrayLikeCollectionType: CollectionType, ArrayLiteralConvertible, MutableCollectionType, CustomStringConvertible, CustomDebugStringConvertible {
    typealias Index = Int // This is actually a requirement
    typealias Element = Generator.Element // This is actually a requirement

    /// Creates a new empty collection.
    init()

    /// Creates a new collection containing the same elements as a sequence, in the same order.
    init<S: SequenceType where S.Generator.Element == Generator.Element>(_ elements: S)

    /// Gets or replaces the element at position `index`.
    subscript(index: Int) -> Element { get set }

    /// Insert a new element at position `i` in the collection.
    /// - Requires: i <= count
    mutating func insert(newElement: Element, atIndex i: Int)

    /// Remove and return the element at position `i` in this collection.
    /// - Requires: i < count
    mutating func removeAtIndex(i: Int) -> Element

    /// Removes all elements from the collection, optionally keeping existing capacity for elements.
    mutating func removeAll(keepCapacity keepCapacity: Bool)

    // These are mostly from RangeReplaceableCollectionType, implemented by default in terms of `insert` and `removeAtIndex`.
    // Override them when you feel like it's worth optimizing.

    mutating func reserveCapacity(minimumCapacity: Int)

    /// Append a new element to the end of the collection.
    mutating func append(newElement: Element)

    /// Remove and return the first element of the collection.
    /// - Requires: count > 0
    mutating func removeFirst() -> Element

    /// Remove and return the last element of the collection.
    /// - Requires: count > 0
    mutating func removeLast() -> Element

    /// Remove the first `n` elements from the collection.
    /// - Requires: count >= n
    mutating func removeFirst(n: Int)

    /// Remove the last `n` elements from the collection.
    /// - Requires: count >= n
    mutating func removeLast(n: Int)

    /// If the collection is empty, return nil. Otherwise remove and return the first element of the collection.
    mutating func popFirst() -> Element?

    /// If the collection is empty, return nil. Otherwise remove and return the last element of the collection.
    mutating func popLast() -> Element?

    /// Replace elements in `range` in the collection with new elements from `elements`.
    /// The number of new elements may differ from the number of elements removed.
    /// - Requires: range.endIndex <= count
    mutating func replaceRange<S: SequenceType where S.Generator.Element == Element>(range: Range<Int>, with elements: S)

    /// Append all elements from a sequence to the end of the collection.
    mutating func appendContentsOf<S: SequenceType where S.Generator.Element == Element>(elements: S)

    /// Insert all elements from a sequence starting at position `i` in the collection.
    /// - Requires: i <= count
    mutating func insertContentsOf<S: SequenceType where S.Generator.Element == Element>(elements: S, at i: Int)

    /// Removes all elements positioned in `range` from the collection.
    /// - Requires: range.endIndex <= count
    mutating func removeRange(range: Range<Int>)
}

extension ArrayLikeCollectionType {
    public init(arrayLiteral elements: Generator.Element...) {
        self.init(elements)
    }

    public var description: String {
        let contents = self.map { element in String(element) }
        return "[" + contents.joinWithSeparator(", ") + "]"
    }

    public var debugDescription: String {
        let contents = self.map { element in String(reflecting: element) }
        return "[" + contents.joinWithSeparator(", ") + "]"
    }
}

extension ArrayLikeCollectionType where Index == Int, Element == Generator.Element {
    public init<S: SequenceType where S.Generator.Element == Element>(_ elements: S) {
        self.init()
        self.reserveCapacity(elements.underestimateCount())
        for element in elements {
            self.append(element)
        }
    }

    public var startIndex: Int {
        return 0
    }

    public var endIndex: Int {
        return count
    }
    
    public var isEmpty: Bool {
        return count == 0
    }

    public mutating func reserveCapacity(minimumCapacity: Int) {
        // Do nothing
    }

    public mutating func append(newElement: Element) {
        self.insert(newElement, atIndex: count)
    }
    public mutating func removeFirst() -> Element {
        return self.removeAtIndex(0)
    }
    public mutating func removeLast() -> Element {
        return self.removeAtIndex(count - 1)
    }
    public mutating func removeFirst(n: Int) {
        self.removeRange(0..<n)
    }
    public mutating func removeLast(n: Int) {
        self.removeRange(count - n ..< count)
    }
    public mutating func popFirst() -> Element? {
        guard count > 0 else { return nil }
        return self.removeFirst()
    }
    public mutating func popLast() -> Element? {
        guard count > 0 else { return nil }
        return self.removeLast()
    }

    public mutating func replaceRange<S: SequenceType where S.Generator.Element == Element>(range: Range<Int>, with elements: S) {
        let ec = elements.underestimateCount()
        reserveCapacity(count - range.count + ec)
        var i = range.startIndex
        for element in elements {
            if i < range.endIndex {
                self[i] = element
            }
            else {
                self.insert(element, atIndex: i)
            }
            i += 1
        }
        if range.count > ec {
            self.removeRange(range.startIndex + ec..<range.endIndex)
        }
    }

    mutating public func appendContentsOf<S: SequenceType where S.Generator.Element == Element>(elements: S) {
        self.reserveCapacity(self.count + elements.underestimateCount())
        for element in elements {
            self.append(element)
        }
    }

    public mutating func insertContentsOf<S: SequenceType where S.Generator.Element == Element>(elements: S, at i: Self.Index) {
        self.reserveCapacity(self.count + elements.underestimateCount())
        var index = i
        for element in elements {
            self.insert(element, atIndex: index)
            index += 1
        }
    }

    public mutating func removeRange(range: Range<Int>) {
        for _ in range {
            self.removeAtIndex(range.startIndex)
        }
    }
}
