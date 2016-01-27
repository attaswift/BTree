//
//  Deque.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2016-01-20.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import Foundation

//MARK: Deque

/// A double-ended queue type. `Deque` is an `Array`-like random-access collection of arbitrary elements
/// that provides efficient insertion and deletion at both ends.
///
/// Like arrays, deques are value types with copy-on-write semantics. `Deque` allocates a single buffer for
/// element storage, using an exponential growth strategy.
///
public struct Deque<Element> {
    /// The storage for this deque.
    internal private(set) var buffer: DequeBuffer<Element>

    /// Initializes an empty deque.
    public init() {
        buffer = DequeBuffer()
    }
    /// Initializes an empty deque that is able to store at least `minimumCapacity` items without reallocating its storage.
    public init(minimumCapacity: Int) {
        buffer = DequeBuffer(capacity: minimumCapacity)
    }

    /// Initialize a new deque from the elements of any sequence.
    public init<S: SequenceType where S.Generator.Element == Element>(_ elements: S) {
        self.init(minimumCapacity: elements.underestimateCount())
        appendContentsOf(elements)
    }

    /// Initialize a deque of `count` elements, each initialized to `repeatedValue`.
    public init(count: Int, repeatedValue: Element) {
        buffer = DequeBuffer(count: count, repeatedValue: repeatedValue)
    }
}

//MARK: Uniqueness and Capacity

extension Deque {
    /// The maximum number of items this deque can store without reallocating its storage.
    var capacity: Int { return buffer.capacity }

    private func grow(capacity: Int) -> Int {
        guard capacity > self.capacity else { return self.capacity }
        return max(capacity, 2 * self.capacity)
    }

    /// Ensure that this deque is capable of storing at least `minimumCapacity` items without reallocating its storage.
    public mutating func reserveCapacity(minimumCapacity: Int) {
        guard buffer.capacity < minimumCapacity else { return }
        if isUniquelyReferenced(&buffer) {
            buffer = buffer.realloc(minimumCapacity)
        }
        else {
            let new = DequeBuffer<Element>(capacity: minimumCapacity)
            new.insertContentsOf(buffer, at: 0)
            buffer = new
        }
    }

    internal var isUnique: Bool { mutating get { return isUniquelyReferenced(&buffer) } }

    private mutating func makeUnique() {
        self.makeUniqueWithCapacity(buffer.capacity)
    }

    private mutating func makeUniqueWithCapacity(capacity: Int) {
        guard !isUnique || buffer.capacity < capacity else { return }
        let copy = DequeBuffer<Element>(capacity: capacity)
        copy.insertContentsOf(buffer, at: 0)
        buffer = copy
    }
}

//MARK: MutableCollectionType

extension Deque: MutableCollectionType {
    public typealias Index = Int
    public typealias Generator = IndexingGenerator<Deque<Element>>
    public typealias SubSequence = MutableSlice<Deque<Element>>

    /// The number of elements currently stored in this deque.
    public var count: Int { return buffer.count }
    /// The position of the first element in a non-empty deque (this is always zero).
    public var startIndex: Int { return 0 }
    /// The index after the last element in a non-empty deque (this is always the element count).
    public var endIndex: Int { return count }

    /// `true` iff this deque is empty.
    public var isEmpty: Bool { return count == 0 }

    @inline(__always)
    private func checkSubscript(index: Int) {
        precondition(index >= 0 && index < count)
    }

    // Returns or changes the element at `index`.
    public subscript(index: Int) -> Element {
        get {
            checkSubscript(index)
            return buffer[index]
        }
        set(value) {
            checkSubscript(index)
            buffer[index] = value
        }
    }
}

//MARK: ArrayLiteralConvertible

extension Deque: ArrayLiteralConvertible {
    public init(arrayLiteral elements: Element...) {
        self.buffer = DequeBuffer(capacity: elements.count)
        buffer.insertContentsOf(elements, at: 0)
    }
}

//MARK: CustomStringConvertible

extension Deque: CustomStringConvertible, CustomDebugStringConvertible {
    @warn_unused_result
    private func makeDescription(debug debug: Bool) -> String {
        var result = debug ? "\(String(reflecting: Deque.self))([" : "Deque["
        var first = true
        for item in self {
            if first {
                first = false
            } else {
                result += ", "
            }
            if debug {
                debugPrint(item, terminator: "", toStream: &result)
            }
            else {
                print(item, terminator: "", toStream: &result)
            }
        }
        result += debug ? "])" : "]"
        return result
    }

    public var description: String {
        return makeDescription(debug: false)
    }
    public var debugDescription: String {
        return makeDescription(debug: true)
    }
}

//MARK: RangeReplaceableCollectionType

extension Deque: RangeReplaceableCollectionType {
    /// Replace the given `range` of elements with `newElements`.
    ///
    /// - Complexity: O(`range.count`) if storage isn't shared with another live deque, 
    ///   and `range` is a constant distance from the start or the end of the deque; otherwise O(`count + range.count`).
    public mutating func replaceRange<C: CollectionType where C.Generator.Element == Element>(range: Range<Int>, with newElements: C) {
        precondition(range.startIndex >= 0 && range.endIndex <= count)
        let newCount: Int = numericCast(newElements.count)
        let delta = newCount - range.count
        if isUnique && count + delta <= capacity {
            buffer.replaceRange(range, with: newElements)
        }
        else {
            let b = DequeBuffer<Element>(capacity: grow(count + delta))
            b.insertContentsOf(self.buffer, subRange: 0 ..< range.startIndex, at: 0)
            b.insertContentsOf(newElements, at: b.count)
            b.insertContentsOf(self.buffer, subRange: range.endIndex ..< count, at: b.count)
            buffer = b
        }
    }

    /// Append `newElement` to the end of this deque.
    ///
    /// - Complexity: Amortized O(1) if storage isn't shared with another live deque; otherwise O(`count`).
    public mutating func append(newElement: Element) {
        makeUniqueWithCapacity(grow(count + 1))
        buffer.append(newElement)
    }

    /// Append `newElements` to the end of this queue.
    public mutating func appendContentsOf<S: SequenceType where S.Generator.Element == Element>(newElements: S) {
        makeUniqueWithCapacity(self.count + newElements.underestimateCount())
        var capacity = buffer.capacity
        var count = buffer.count
        var generator = newElements.generate()
        var next = generator.next()
        while next != nil {
            if capacity == count {
                reserveCapacity(grow(count + 1))
                capacity = buffer.capacity
            }
            var i = buffer.bufferIndexForDequeIndex(count)
            let p = buffer.elements
            while let element = next where count < capacity {
                p.advancedBy(i).initialize(element)
                i += 1
                if i == capacity { i = 0 }
                count += 1
                next = generator.next()
            }
            buffer.count = count
        }
    }

    /// Insert `newElement` at index `i` into this deque.
    ///
    /// - Complexity: O(`count`). Note though that complexity is O(1) if `i` is of a constant distance from the front or end of the deque.
    public mutating func insert(newElement: Element, atIndex i: Int) {
        makeUniqueWithCapacity(grow(count + 1))
        buffer.insert(newElement, at: i)
    }

    /// Insert the contents of `newElements` into this deque, starting at index `i`.
    ///
    /// - Complexity: O(`count`). Note though that complexity is O(1) if `i` is of a constant distance from the front or end of the deque.
    public mutating func insertContentsOf<C: CollectionType where C.Generator.Element == Element>(newElements: C, at i: Int) {
        makeUniqueWithCapacity(grow(count + numericCast(newElements.count)))
        buffer.insertContentsOf(newElements, at: i)
    }

    /// Remove the element at index `i` from this deque.
    ///
    /// - Complexity: O(`count`). Note though that complexity is O(1) if `i` is of a constant distance from the front or end of the deque.
    public mutating func removeAtIndex(i: Int) -> Element {
        checkSubscript(i)
        makeUnique()
        let element = buffer[i]
        buffer.removeRange(i...i)
        return element
    }

    /// Remove and return the first element from this deque.
    ///
    /// - Requires: `count > 0`
    /// - Complexity: O(1) if storage isn't shared with another live deque; otherwise O(`count`).
    public mutating func removeFirst() -> Element {
        precondition(count > 0)
        return buffer.popFirst()!
    }

    /// Remove the first `n` elements from this deque.
    ///
    /// - Requires: `count >= n`
    /// - Complexity: O(`n`) if storage isn't shared with another live deque; otherwise O(`count`).
    public mutating func removeFirst(n: Int) {
        precondition(count >= n)
        buffer.removeRange(0 ..< n)
    }

    /// Remove the first `n` elements from this deque.
    ///
    /// - Requires: `count >= n`
    /// - Complexity: O(`n`) if storage isn't shared with another live deque; otherwise O(`count`).
    public mutating func removeRange(range: Range<Int>) {
        precondition(range.startIndex >= 0 && range.endIndex <= count)
        buffer.removeRange(range)
    }

    /// Remove all elements from this deque.
    ///
    /// - Complexity: O(`count`).
    public mutating func removeAll(keepCapacity keepCapacity: Bool = false) {
        if keepCapacity {
            buffer.removeRange(0..<count)
        }
        else {
            buffer = DequeBuffer()
        }
    }
}

//MARK: Miscellaneous mutators
extension Deque {
    /// Remove and return the last element from this deque.
    ///
    /// - Requires: `count > 0`
    /// - Complexity: O(1) if storage isn't shared with another live deque; otherwise O(`count`).
    public mutating func removeLast() -> Element {
        precondition(count > 0)
        return buffer.popLast()!
    }

    /// Remove and return the last `n` elements from this deque.
    ///
    /// - Requires: `count >= n`
    /// - Complexity: O(`n`) if storage isn't shared with another live deque; otherwise O(`count`).
    public mutating func removeLast(n: Int) {
        let c = count
        precondition(c >= n)
        buffer.removeRange(c - n ..< c)
    }

    /// Remove and return the first element if the deque isn't empty; otherwise return nil.
    ///
    /// - Complexity: O(1) if storage isn't shared with another live deque; otherwise O(`count`).
    public mutating func popFirst() -> Element? {
        return buffer.popFirst()
    }

    /// Remove and return the last element if the deque isn't empty; otherwise return nil.
    ///
    /// - Complexity: O(1) if storage isn't shared with another live deque; otherwise O(`count`).
    public mutating func popLast() -> Element? {
        return buffer.popLast()
    }

    /// Prepend `newElement` to the front of this deque.
    ///
    /// - Complexity: Amortized O(1) if storage isn't shared with another live deque; otherwise O(count).
    public mutating func prepend(element: Element) {
        makeUniqueWithCapacity(grow(count + 1))
        buffer.prepend(element)
    }
}

//MARK: Equality operators

@warn_unused_result
func == <Element: Equatable>(a: Deque<Element>, b: Deque<Element>) -> Bool {
    let count = a.count
    if count != b.count { return false }
    if count == 0 || a.buffer === b.buffer { return true }

    var agen = a.generate()
    var bgen = b.generate()
    while let anext = agen.next() {
        let bnext = bgen.next()
        if anext != bnext { return false }
    }
    return true
}

@warn_unused_result
func != <Element: Equatable>(a: Deque<Element>, b: Deque<Element>) -> Bool {
    return !(a == b)
}

//MARK: DequeBuffer

/// Storage buffer for a deque.
final class DequeBuffer<Element>: NonObjectiveCBase {
    /// Pointer to allocated storage.
    internal private(set) var elements: UnsafeMutablePointer<Element>
    /// The capacity of this storage buffer.
    internal let capacity: Int
    /// The number of items currently in this deque.
    internal private(set) var count: Int
    /// The index of the first item.
    internal private(set) var start: Int

    internal init(capacity: Int = 16) {
        // TODO: It would be nicer if element storage was tail-allocated after this instance.
        // ManagedBuffer is supposed to do that, but ManagedBuffer is surprisingly slow. :-/
        self.elements = UnsafeMutablePointer.alloc(capacity)
        self.capacity = capacity
        self.count = 0
        self.start = 0
    }

    internal convenience init(count: Int, repeatedValue: Element) {
        self.init(capacity: count)
        let p = elements
        self.count = count
        var q = p
        let limit = p + count
        while q != limit {
            q.initialize(repeatedValue)
            q += 1
        }
    }

    deinit {
        let p = self.elements
        if start + count <= capacity {
            p.advancedBy(start).destroy(count)
        }
        else {
            let c = capacity - start
            p.advancedBy(start).destroy(c)
            p.destroy(count - c)
        }
        p.dealloc(capacity)
    }

    @warn_unused_result
    internal func realloc(capacity: Int) -> DequeBuffer {
        if capacity <= self.capacity { return self }
        let buffer = DequeBuffer(capacity: capacity)
        buffer.count = self.count
        let dst = buffer.elements
        let src = self.elements
        if start + count <= capacity {
            dst.moveInitializeFrom(src.advancedBy(start), count: count)
        }
        else {
            let c = capacity - start
            dst.moveInitializeFrom(src.advancedBy(start), count: c)
            dst.advancedBy(c).moveInitializeFrom(src, count: count - c)
        }
        self.count = 0
        return buffer
    }


    /// Returns the storage buffer index for a deque index.
    private func bufferIndexForDequeIndex(index: Int) -> Int {
        let i = start + index
        if i >= capacity { return i - capacity }
        return i
    }

    /// Returns the deque index for a storage buffer index.
    private func dequeIndexForBufferIndex(i: Int) -> Int {
        if i >= start {
            return i - start
        }
        return capacity - start + i
    }

    internal var isFull: Bool { return count == capacity }

    internal subscript(index: Int) -> Element {
        get {
            assert(index >= 0 && index < count)
            let i = bufferIndexForDequeIndex(index)
            return elements.advancedBy(i).memory
        }
        set {
            assert(index >= 0 && index < count)
            let i = bufferIndexForDequeIndex(index)
            elements.advancedBy(i).memory = newValue
        }
    }

    internal func prepend(element: Element) {
        precondition(count < capacity)
        let i = start == 0 ? capacity - 1 : start - 1
        elements.advancedBy(i).initialize(element)
        self.start = i
        self.count += 1
    }

    internal func popFirst() -> Element? {
        guard count > 0 else { return nil }
        let first = elements.advancedBy(start).move()
        self.start = bufferIndexForDequeIndex(1)
        self.count -= 1
        return first
    }

    internal func append(element: Element) {
        precondition(count < capacity)
        let endIndex = bufferIndexForDequeIndex(count)
        elements.advancedBy(endIndex).initialize(element)
        self.count += 1
    }

    internal func popLast() -> Element? {
        guard count > 0 else { return nil }
        let lastIndex = bufferIndexForDequeIndex(count - 1)
        let last = elements.advancedBy(lastIndex).move()
        self.count -= 1
        return last
    }

    /// Create a gap of `length` uninitialized slots starting at `index`.
    /// Existing elements are moved out of the way.
    /// You are expected to fill the gap by initializing all slots in it after calling this method.
    /// Note that all previously calculated buffer indexes are invalidated by this method.
    private func openGapAt(index: Int, length: Int) {
        assert(index >= 0 && index <= self.count)
        assert(count + length <= capacity)
        guard length > 0 else { return }
        let i = bufferIndexForDequeIndex(index)
        if index >= (count + 1) / 2 {
            // Make room by sliding elements at/after index to the right
            let end = start + count <= capacity ? start + count : start + count - capacity
            if i <= end { // Elements after index are not yet wrapped
                if end + length <= capacity { // Neither gap nor elements after it will be wrapped
                    // ....ABCD̲EF......
                    elements.advancedBy(i + length).moveInitializeBackwardFrom(elements.advancedBy(i), count: end - i)
                    // ....ABC.̲..DEF...
                }
                else if i + length <= capacity { // Elements after gap will be wrapped
                    // .........ABCD̲EF. (count = 3)
                    elements.moveInitializeFrom(elements.advancedBy(capacity - length), count: end + length - capacity)
                    // EF.......ABCD̲...
                    elements.advancedBy(i + length).moveInitializeBackwardFrom(elements.advancedBy(i), count: capacity - i - length)
                    // EF.......ABC.̲..D
                }
                else { // Gap will be wrapped
                    // .........ABCD̲EF. (count = 5)
                    elements.advancedBy(i + length - capacity).moveInitializeFrom(elements.advancedBy(i), count: end - i)
                    // .DEF.....ABC.̲...
                }
            }
            else { // Elements after index are already wrapped
                if i + length <= capacity { // Gap will not be wrapped
                    // F.......ABCD̲E (count = 1)
                    elements.advancedBy(length).moveInitializeBackwardFrom(elements, count: end)
                    // .F......ABCD̲E
                    elements.moveInitializeFrom(elements.advancedBy(capacity - length), count: length)
                    // EF......ABCD̲.
                    elements.advancedBy(i + length).moveInitializeBackwardFrom(elements.advancedBy(i), count: capacity - i - length)
                    // EF......ABC.̲D
                }
                else { // Gap will be wrapped
                    // F.......ABCD̲E (count = 3)
                    elements.advancedBy(length).moveInitializeBackwardFrom(elements, count: end)
                    // ...F....ABCD̲E
                    elements.advancedBy(i + length - capacity).moveInitializeFrom(elements.advancedBy(i), count: capacity - i)
                    // .DEF....ABC.̲.
                }
            }
            count += length
        }
        else {
            // Make room by sliding elements before index to the left, updating `start`.
            if i >= start { // Elements before index are not yet wrapped.
                if start >= length { // Neither gap nor elements before it will be wrapped.
                    // ....ABCD̲EF...
                    elements.advancedBy(start - length).moveInitializeFrom(elements.advancedBy(start), count: i - start)
                    // .ABC...D̲EF...
                }
                else if i >= length { // Elements before the gap will be wrapped.
                    // ..ABCD̲EF....
                    elements.advancedBy(capacity + start - length).moveInitializeFrom(elements.advancedBy(start), count: length - start)
                    // ...BCD̲EF...A
                    elements.moveInitializeFrom(elements.advancedBy(length), count: i - length)
                    // BC...D̲EF...A
                }
                else { // Gap will be wrapped
                    // .ABCD̲EF....... (count = 5)
                    elements.advancedBy(capacity + start - length).moveInitializeFrom(elements.advancedBy(start), count: i - start)
                    // ....D̲EF...ABC.
                }
            }
            else { // Elements before index are already wrapped.
                if i >= length { // Gap will not be wrapped.
                    // BCD̲EF......A (count = 1)
                    elements.advancedBy(start - length).moveInitializeFrom(elements.advancedBy(start), count: capacity - start)
                    // BCD̲EF.....A.
                    elements.advancedBy(capacity - length).moveInitializeFrom(elements, count: length)
                    // .CD̲EF.....AB
                    elements.moveInitializeFrom(elements.advancedBy(i - length), count: i - length)
                    // C.D̲EF.....AB
                }
                else { // Gap will be wrapped.
                    // CD̲EF......AB
                    elements.advancedBy(start - length).moveInitializeFrom(elements.advancedBy(start), count: capacity - start)
                    // CD̲EF...AB...
                    elements.advancedBy(capacity - length).moveInitializeFrom(elements, count: i)
                    // .D̲EF...ABC..
                }
            }
            start = start < length ? capacity + start - length : start - length
            count += length
        }
    }

    internal func insert(element: Element, at index: Int) {
        precondition(index >= 0 && index <= count && !isFull)
        openGapAt(index, length: 1)
        let i = bufferIndexForDequeIndex(index)
        elements.advancedBy(i).initialize(element)
    }

    internal func insertContentsOf(buffer: DequeBuffer, at index: Int) {
        self.insertContentsOf(buffer, subRange: 0 ..< buffer.count, at: index)
    }

    internal func insertContentsOf(buffer: DequeBuffer, subRange: Range<Int>, at index: Int) {
        assert(index >= 0 && index <= count)
        assert(count + subRange.count <= capacity)
        assert(subRange.startIndex >= 0 && subRange.endIndex <= buffer.count)
        guard subRange.count > 0 else { return }
        openGapAt(index, length: subRange.count)

        let dp = self.elements
        let sp = buffer.elements

        let dstStart = self.bufferIndexForDequeIndex(index)
        let srcStart = buffer.bufferIndexForDequeIndex(subRange.startIndex)

        let srcCount = subRange.count

        let dstEnd = self.bufferIndexForDequeIndex(index + srcCount)
        let srcEnd = buffer.bufferIndexForDequeIndex(subRange.endIndex)

        if srcStart < srcEnd && dstStart < dstEnd {
            dp.advancedBy(dstStart).initializeFrom(sp.advancedBy(srcStart), count: srcCount)
        }
        else if srcStart < srcEnd {
            let t = self.capacity - dstStart
            dp.advancedBy(dstStart).initializeFrom(sp.advancedBy(srcStart), count: t)
            dp.initializeFrom(sp.advancedBy(srcStart + t), count: srcCount - t)
        }
        else if dstStart < dstEnd {
            let t = buffer.capacity - srcStart
            dp.advancedBy(dstStart).initializeFrom(sp.advancedBy(srcStart), count: t)
            dp.advancedBy(dstStart + t).initializeFrom(sp, count: srcCount - t)
        }
        else {
            let st = buffer.capacity - srcStart
            let dt = self.capacity - dstStart

            if dt < st {
                dp.advancedBy(dstStart).initializeFrom(sp.advancedBy(srcStart), count: dt)
                dp.initializeFrom(sp.advancedBy(srcStart + dt), count: st - dt)
                dp.advancedBy(st - dt).initializeFrom(sp, count: srcCount - st)
            }
            else if dt > st {
                dp.advancedBy(dstStart).initializeFrom(sp.advancedBy(srcStart), count: st)
                dp.advancedBy(dstStart + st).initializeFrom(sp, count: dt - st)
                dp.initializeFrom(sp.advancedBy(dt - st), count: srcCount - dt)
            }
            else {
                dp.advancedBy(dstStart).initializeFrom(sp.advancedBy(srcStart), count: st)
                dp.initializeFrom(sp, count: srcCount - st)
            }
        }
    }

    internal func insertContentsOf<C: CollectionType where C.Generator.Element == Element>(collection: C, at index: Int) {
        assert(index >= 0 && index <= count)
        let c: Int = numericCast(collection.count)
        assert(count + c <= capacity)
        guard c > 0 else { return }
        openGapAt(index, length: c)
        var q = elements.advancedBy(bufferIndexForDequeIndex(index))
        let limit = elements.advancedBy(capacity)
        for element in collection {
            q.initialize(element)
            q = q.successor()
            if q == limit {
                q = elements
            }
        }
    }

    /// Destroy elements in the range (index ..< index + count) and collapse the gap by moving remaining elements.
    /// Note that all previously calculated buffer indexes are invalidated by this method.
    private func removeRange(range: Range<Int>) {
        assert(range.startIndex >= 0)
        assert(range.endIndex <= self.count)
        guard range.count > 0 else { return }
        let rc = range.count
        let p = elements
        let i = bufferIndexForDequeIndex(range.startIndex)
        let j = i + rc <= capacity ? i + rc : i + rc - capacity

        // Destroy items in collapsed range
        if i <= j {
            // ....ABC̲D̲E̲FG...
            p.advancedBy(i).destroy(rc)
            // ....AB...FG...
        }
        else {
            // D̲E̲FG.......ABC̲
            p.advancedBy(i).destroy(capacity - i)
            // D̲E̲FG.......AB.
            p.destroy(j)
            // ..FG.......AB.
        }

        if count - range.startIndex - rc < range.startIndex {
            let end = start + count < capacity ? start + count : start + count - capacity

            // Slide trailing items to the left
            if i <= end { // No wrap anywhere after start of collapsed range
                // ....AB.̲..CD...
                p.advancedBy(i).moveInitializeFrom(p.advancedBy(i + rc), count: end - i - rc)
                // ....ABC̲D......
            }
            else if i + rc > capacity { // Collapsed range is wrapped
                if end <= rc { // Result will not be wrapped
                    // .CD......AB.̲..
                    p.advancedBy(i).moveInitializeFrom(p.advancedBy(i + rc - capacity), count: capacity + end - i - rc)
                    // .........ABC̲D.
                }
                else { // Result will remain wrapped
                    // .CDEFG...AB.̲..
                    p.advancedBy(i).moveInitializeFrom(p.advancedBy(i + rc - capacity), count: capacity - i)
                    // ....FG...ABC̲DE
                    p.moveInitializeFrom(p.advancedBy(rc), count: end - rc)
                    // FG.......ABC̲DE
                }
            }
            else { // Wrap is after collapsed range
                if end <= rc { // Result will not be wrapped
                    // D.......AB.̲..C
                    p.advancedBy(i).moveInitializeFrom(p.advancedBy(i + rc), count: capacity - i - rc)
                    // D.......ABC̲...
                    p.advancedBy(capacity - rc).moveInitializeFrom(p, count: end)
                    // ........ABC̲D..
                }
                else { // Result will remain wrapped
                    // DEFG....AB.̲..C
                    p.advancedBy(i).moveInitializeFrom(p.advancedBy(i + rc), count: capacity - i - rc)
                    // DEFG....ABC̲...
                    p.advancedBy(capacity - rc).moveInitializeFrom(p, count: rc)
                    // ...G....ABC̲DEF
                    p.moveInitializeFrom(p.advancedBy(rc), count: end - rc)
                    // G.......ABC̲DEF
                }
            }
            count -= rc
        }
        else {
            // Slide preceding items to the right
            if j >= start { // No wrap anywhere before end of collapsed range
                // ...AB...C̲D...
                p.advancedBy(start + rc).moveInitializeBackwardFrom(p.advancedBy(start), count: j - start - rc)
                // ......ABC̲D...
            }
            else if j < rc { // Collapsed range is wrapped
                if  start + rc >= capacity  { // Result will not be wrapped
                    // ...C̲D.....AB..
                    p.advancedBy(start + rc - capacity).moveInitializeFrom(p.advancedBy(start), count: capacity + j - start - rc)
                    // .ABC̲D.........
                }
                else { // Result will remain wrapped
                    // ..E̲F.....ABCD..
                    p.moveInitializeFrom(p.advancedBy(capacity - rc), count: j)
                    // CDE̲F.....AB....
                    p.advancedBy(start + rc).moveInitializeBackwardFrom(p.advancedBy(start), count: capacity - start - rc)
                    // CDE̲F.........AB
                }
            }
            else { // Wrap is before collapsed range
                if capacity - start <= rc { // Result will not be wrapped
                    // CD...E̲F.....AB
                    p.advancedBy(rc).moveInitializeBackwardFrom(p, count: j - rc)
                    // ...CDE̲F.....AB
                    p.advancedBy(start + rc - capacity).moveInitializeFrom(p.advancedBy(start), count: capacity - start)
                    // .ABCDE̲F.......
                }
                else { // Result will remain wrapped
                    // EF...G̲H...ABCD
                    p.advancedBy(rc).moveInitializeBackwardFrom(p, count: j - rc)
                    // ...EFG̲H...ABCD
                    p.moveInitializeFrom(p.advancedBy(capacity) - rc, count: rc)
                    // BCDEFG̲H...A...
                    p.advancedBy(start + rc).moveInitializeBackwardFrom(p.advancedBy(start), count: capacity - start - rc)
                    // BCDEFG̲H......A
                }
            }
            start = (start + rc < capacity ? start + rc : start + rc - capacity)
            count -= rc
        }
    }

    internal func replaceRange<C: CollectionType where C.Generator.Element == Element>(range: Range<Int>, with newElements: C) {
        let newCount: Int = numericCast(newElements.count)
        let delta = newCount - range.count
        assert(count + delta < capacity)
        let common = min(range.count, newCount)
        if common > 0 {
            let p = elements
            var q = p.advancedBy(bufferIndexForDequeIndex(range.startIndex))
            let limit = p.advancedBy(capacity)
            var i = common
            for element in newElements {
                q.memory = element
                q = q.successor()
                if q == limit { q = p }
                i -= 1
                if i == 0 { break }
            }
        }
        if range.count > common {
            removeRange(range.startIndex + common ..< range.endIndex)
        }
        else if newCount > common {
            openGapAt(range.startIndex + common, length: newCount - common)
            let p = elements
            var q = p.advancedBy(bufferIndexForDequeIndex(range.startIndex + common))
            let limit = p.advancedBy(capacity)
            var i = newElements.startIndex.advancedBy(numericCast(common))
            while i != newElements.endIndex {
                q.initialize(newElements[i])
                i = i.successor()
                q = q.successor()
                if q == limit { q = p }
            }
        }
    }
}
