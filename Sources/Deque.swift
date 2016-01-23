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
        buffer = DequeBuffer.create()
    }
    /// Initializes an empty deque that is able to store at least `minimumCapacity` items without reallocating its storage.
    public init(minimumCapacity: Int) {
        buffer = DequeBuffer.create(capacity: minimumCapacity)
    }

    /// Initialize a new deque from the elements of any sequence.
    public init<S: SequenceType where S.Generator.Element == Element>(_ elements: S) {
        self.init(minimumCapacity: elements.underestimateCount())
        appendContentsOf(elements)
    }

    /// Initialize a deque of `count` elements, each initialized to `repeatedValue`.
    public init(count: Int, repeatedValue: Element) {
        self.init(minimumCapacity: count)
        buffer.manager.withUnsafeMutablePointers { hp, p in
            hp.memory.count = count
            var q = p
            for _ in 0..<count {
                q.initialize(repeatedValue)
                q += 1
            }
        }
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
            let new = DequeBuffer<Element>.create(capacity: minimumCapacity)
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
        let copy = DequeBuffer<Element>.create(capacity: capacity)
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
        self.buffer = DequeBuffer.create(capacity: elements.count)
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
            let b = DequeBuffer<Element>.create(capacity: grow(count + delta))
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
            var i = buffer.manager.value.bufferIndexForDequeIndex(count)
            buffer.manager.withUnsafeMutablePointerToElements { p in
                while let element = next where count < capacity {
                    p.advancedBy(i).initialize(element)
                    i += 1
                    if i == capacity { i = 0 }
                    count += 1
                    next = generator.next()
                }
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
            buffer = DequeBuffer.create()
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

//MARK: DequeBufferHeader

/// Storage buffer header for deques.
private struct DequeBufferHeader {
    /// The capacity of this storage buffer.
    var capacity: Int
    /// The number of items currently in this deque.
    var count: Int
    /// The index of the first item.
    var start: Int

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
}

//MARK: DequeBuffer

class DequeBufferBase: NonObjectiveCBase {
    private override init() {
        fatalError("")
    }
}

/// Storage buffer for a deque.
final class DequeBuffer<Element>: DequeBufferBase {
    private typealias Manager = ManagedBufferPointer<DequeBufferHeader, Element>

    private override init() {
        fatalError("")
    }

    @warn_unused_result
    internal static func create(capacity capacity: Int = 16) -> DequeBuffer<Element> {
        let manager = Manager(
            bufferClass: self,
            minimumCapacity: capacity,
            initialValue: { buffer, allocatedCount in
                DequeBufferHeader(capacity: allocatedCount(buffer), count: 0, start: 0)
            })
        return unsafeDowncast(manager.buffer)
    }

    @warn_unused_result
    internal func realloc(capacity: Int) -> DequeBuffer {
        if capacity <= self.capacity { return self }
        let buffer = DequeBuffer.create(capacity: capacity)
        buffer.count = self.count
        buffer.manager.withUnsafeMutablePointerToElements { dst in
            self.manager.withUnsafeMutablePointerToElements { src in
                let h = self.manager.value
                if h.start + h.count <= h.capacity {
                    dst.moveInitializeFrom(src.advancedBy(h.start), count: h.count)
                }
                else {
                    let c = h.capacity - h.start
                    dst.moveInitializeFrom(src.advancedBy(h.start), count: c)
                    dst.advancedBy(c).moveInitializeFrom(src, count: h.count - c)
                }
            }
        }
        self.count = 0
        return buffer
    }

    deinit {
        self.manager.withUnsafeMutablePointers { header, elements in
            let rest = header.memory.capacity - header.memory.start
            let count = header.memory.count

            elements.advancedBy(header.memory.start).destroy(min(rest, count))
            if rest < count {
                elements.destroy(count - rest)
            }
            header.destroy()
        }
    }

    private var manager: Manager { return Manager(unsafeBufferObject: self) }

    internal private(set) var count: Int {
        get { return manager.value.count }
        set { manager.withUnsafeMutablePointerToValue { $0.memory.count = newValue } }
    }

    internal var capacity: Int { return manager.value.capacity }
    internal var isFull: Bool { return count == capacity }

    internal private(set) var start: Int {
        get { return manager.value.start }
        set { manager.withUnsafeMutablePointerToValue { $0.memory.start = newValue } }
    }

    internal subscript(index: Int) -> Element {
        get {
            assert(index >= 0 && index < count)
            return manager.withUnsafeMutablePointers { hp, p in
                let i = hp.memory.bufferIndexForDequeIndex(index)
                return p.advancedBy(i).memory
            }
        }
        set {
            assert(index >= 0 && index < count)
            manager.withUnsafeMutablePointers { hp, p in
                let i = hp.memory.bufferIndexForDequeIndex(index)
                p.advancedBy(i).memory = newValue
            }
        }
    }

    internal func prepend(element: Element) {
        precondition(count < capacity)
        let i = start == 0 ? capacity - 1 : start - 1
        manager.withUnsafeMutablePointerToElements { elements in
            elements.advancedBy(i).initialize(element)
        }
        self.start = i
        self.count += 1
    }

    internal func popFirst() -> Element? {
        guard count > 0 else { return nil }
        let index = self.start
        let first = manager.withUnsafeMutablePointerToElements { elements in
            return elements.advancedBy(index).move()
        }
        self.start = manager.value.bufferIndexForDequeIndex(1)
        self.count -= 1
        return first
    }

    internal func append(element: Element) {
        precondition(count < capacity)
        let i = manager.value.bufferIndexForDequeIndex(count)
        manager.withUnsafeMutablePointerToElements { elements in
            elements.advancedBy(i).initialize(element)
        }
        self.count += 1
    }

    internal func popLast() -> Element? {
        guard count > 0 else { return nil }
        let index = manager.value.bufferIndexForDequeIndex(count - 1)
        let last = manager.withUnsafeMutablePointerToElements { elements in
            return elements.advancedBy(index).move()
        }
        self.count -= 1
        return last
    }

    /// Create a gap of `length` uninitialized slots starting at `index`.
    /// Existing elements are moved out of the way.
    /// You are expected to fill the gap by initializing all slots in it after calling this method.
    /// Note that all previously calculated buffer indexes are invalidated by this method.
    private func openGapAt(index: Int, length count: Int) {
        assert(index >= 0 && index <= self.count)
        assert(self.count + count <= capacity)
        guard count > 0 else { return }
        manager.withUnsafeMutablePointers { hp, p in
            let h = hp.memory
            let i = h.bufferIndexForDequeIndex(index)
            if index >= (h.count + 1) / 2 {
                // Make room by sliding elements at/after index to the right
                let end = h.start + h.count <= h.capacity ? h.start + h.count : h.start + h.count - h.capacity
                if i <= end { // Elements after index are not yet wrapped
                    if end + count <= h.capacity { // Neither gap nor elements after it will be wrapped
                        // ....ABCD̲EF......
                        p.advancedBy(i + count).moveInitializeBackwardFrom(p.advancedBy(i), count: end - i)
                        // ....ABC.̲..DEF...
                    }
                    else if i + count <= h.capacity { // Elements after gap will be wrapped
                        // .........ABCD̲EF. (count = 3)
                        p.moveInitializeFrom(p.advancedBy(h.capacity - count), count: end + count - h.capacity)
                        // EF.......ABCD̲...
                        p.advancedBy(i + count).moveInitializeBackwardFrom(p.advancedBy(i), count: h.capacity - i - count)
                        // EF.......ABC.̲..D
                    }
                    else { // Gap will be wrapped
                        // .........ABCD̲EF. (count = 5)
                        p.advancedBy(i + count - h.capacity).moveInitializeFrom(p.advancedBy(i), count: end - i)
                        // .DEF.....ABC.̲...
                    }
                }
                else { // Elements after index are already wrapped
                    if i + count <= h.capacity { // Gap will not be wrapped
                        // F.......ABCD̲E (count = 1)
                        p.advancedBy(count).moveInitializeBackwardFrom(p, count: end)
                        // .F......ABCD̲E
                        p.moveInitializeFrom(p.advancedBy(h.capacity - count), count: count)
                        // EF......ABCD̲.
                        p.advancedBy(i + count).moveInitializeBackwardFrom(p.advancedBy(i), count: h.capacity - i - count)
                        // EF......ABC.̲D
                    }
                    else { // Gap will be wrapped
                        // F.......ABCD̲E (count = 3)
                        p.advancedBy(count).moveInitializeBackwardFrom(p, count: end)
                        // ...F....ABCD̲E
                        p.advancedBy(i + count - h.capacity).moveInitializeFrom(p.advancedBy(i), count: h.capacity - i)
                        // .DEF....ABC.̲.
                    }
                }
                hp.memory.count += count
            }
            else {
                // Make room by sliding elements before index to the left, updating `start`.
                if i >= h.start { // Elements before index are not yet wrapped.
                    if h.start >= count { // Neither gap nor elements before it will be wrapped.
                        // ....ABCD̲EF...
                        p.advancedBy(h.start - count).moveInitializeFrom(p.advancedBy(h.start), count: i - h.start)
                        // .ABC...D̲EF...
                    }
                    else if i >= count { // Elements before the gap will be wrapped.
                        // ..ABCD̲EF....
                        p.advancedBy(h.capacity + h.start - count).moveInitializeFrom(p.advancedBy(h.start), count: count - h.start)
                        // ...BCD̲EF...A
                        p.moveInitializeFrom(p.advancedBy(count), count: i - count)
                        // BC...D̲EF...A
                    }
                    else { // Gap will be wrapped
                        // .ABCD̲EF....... (count = 5)
                        p.advancedBy(h.capacity + h.start - count).moveInitializeFrom(p.advancedBy(h.start), count: i - h.start)
                        // ....D̲EF...ABC.
                    }
                }
                else { // Elements before index are already wrapped.
                    if i >= count { // Gap will not be wrapped.
                        // BCD̲EF......A (count = 1)
                        p.advancedBy(h.start - count).moveInitializeFrom(p.advancedBy(h.start), count: h.capacity - h.start)
                        // BCD̲EF.....A.
                        p.advancedBy(h.capacity - count).moveInitializeFrom(p, count: count)
                        // .CD̲EF.....AB
                        p.moveInitializeFrom(p.advancedBy(i - count), count: i - count)
                        // C.D̲EF.....AB
                    }
                    else { // Gap will be wrapped.
                        // CD̲EF......AB
                        p.advancedBy(h.start - count).moveInitializeFrom(p.advancedBy(h.start), count: h.capacity - h.start)
                        // CD̲EF...AB...
                        p.advancedBy(h.capacity - count).moveInitializeFrom(p, count: i)
                        // .D̲EF...ABC..
                    }
                }
                hp.memory.start = h.start < count ? h.capacity + h.start - count : h.start - count
                hp.memory.count += count
            }
        }
    }

    internal func insert(element: Element, at index: Int) {
        precondition(index >= 0 && index <= count && !isFull)
        openGapAt(index, length: 1)
        let i = manager.value.bufferIndexForDequeIndex(index)
        manager.withUnsafeMutablePointerToElements { p in
            p.advancedBy(i).initialize(element)
        }
    }

    internal func insertContentsOf(buffer: DequeBuffer, at index: Int) {
        self.insertContentsOf(buffer, subRange: Range(start: 0, end: buffer.count), at: index)
    }

    internal func insertContentsOf(buffer: DequeBuffer, subRange: Range<Int>, at index: Int) {
        assert(index >= 0 && index <= count)
        assert(count + subRange.count <= capacity)
        assert(subRange.startIndex >= 0 && subRange.endIndex <= buffer.count)
        guard subRange.count > 0 else { return }
        openGapAt(index, length: subRange.count)
        self.manager.withUnsafeMutablePointers { dhp, dp in
            buffer.manager.withUnsafeMutablePointers { shp, sp in
                let dh = dhp.memory
                let sh = shp.memory

                let dstStart = dh.bufferIndexForDequeIndex(index)
                let srcStart = sh.bufferIndexForDequeIndex(subRange.startIndex)

                let srcCount = subRange.count

                let dstEnd = dh.bufferIndexForDequeIndex(index + srcCount)
                let srcEnd = sh.bufferIndexForDequeIndex(subRange.endIndex)


                if srcStart < srcEnd && dstStart < dstEnd {
                    dp.advancedBy(dstStart).initializeFrom(sp.advancedBy(srcStart), count: srcCount)
                }
                else if srcStart < srcEnd {
                    let t = dh.capacity - dstStart
                    dp.advancedBy(dstStart).initializeFrom(sp.advancedBy(srcStart), count: t)
                    dp.initializeFrom(sp.advancedBy(srcStart + t), count: srcCount - t)
                }
                else if dstStart < dstEnd {
                    let t = sh.capacity - srcStart
                    dp.advancedBy(dstStart).initializeFrom(sp.advancedBy(srcStart), count: t)
                    dp.advancedBy(dstStart + t).initializeFrom(sp, count: srcCount - t)
                }
                else {
                    let st = sh.capacity - srcStart
                    let dt = dh.capacity - dstStart

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
        }
    }

    internal func insertContentsOf<C: CollectionType where C.Generator.Element == Element>(collection: C, at index: Int) {
        assert(index >= 0 && index <= count)
        let c: Int = numericCast(collection.count)
        assert(count + c <= capacity)
        guard c > 0 else { return }
        openGapAt(index, length: c)
        manager.withUnsafeMutablePointers { hp, p in
            let h = hp.memory
            var q = p.advancedBy(h.bufferIndexForDequeIndex(index))
            let limit = p.advancedBy(h.capacity)
            for element in collection {
                q.initialize(element)
                q = q.successor()
                if q == limit {
                    q = p
                }
            }
        }
    }

    /// Destroy elements in the range (index ..< index + count) and collapse the gap by moving remaining elements.
    /// Note that all previously calculated buffer indexes are invalidated by this method.
    private func removeRange(range: Range<Int>) {
        let index = range.startIndex
        let count = range.count
        assert(range.startIndex >= 0)
        assert(range.endIndex <= self.count)
        guard range.count > 0 else { return }
        manager.withUnsafeMutablePointers { hp, p in
            let h = hp.memory
            let i = h.bufferIndexForDequeIndex(index)
            let j = i + count <= h.capacity ? i + count : i + count - h.capacity

            // Destroy items in collapsed range
            if i <= j {
                // ....ABC̲D̲E̲FG...
                p.advancedBy(i).destroy(count)
                // ....AB...FG...
            }
            else {
                // D̲E̲FG.......ABC̲
                p.advancedBy(i).destroy(h.capacity - i)
                // D̲E̲FG.......AB.
                p.destroy(j)
                // ..FG.......AB.
            }

            if h.count - index - count < index {
                let end = h.start + h.count < h.capacity ? h.start + h.count : h.start + h.count - h.capacity

                // Slide trailing items to the left
                if i <= end { // No wrap anywhere after start of collapsed range
                    // ....AB.̲..CD...
                    p.advancedBy(i).moveInitializeFrom(p.advancedBy(i + count), count: end - i - count)
                    // ....ABC̲D......
                }
                else if i + count > h.capacity { // Collapsed range is wrapped
                    if end <= count { // Result will not be wrapped
                        // .CD......AB.̲..
                        p.advancedBy(i).moveInitializeFrom(p.advancedBy(i + count - h.capacity), count: h.capacity + end - i - count)
                        // .........ABC̲D.
                    }
                    else { // Result will remain wrapped
                        // .CDEFG...AB.̲..
                        p.advancedBy(i).moveInitializeFrom(p.advancedBy(i + count - h.capacity), count: h.capacity - i)
                        // ....FG...ABC̲DE
                        p.moveInitializeFrom(p.advancedBy(count), count: end - count)
                        // FG.......ABC̲DE
                    }
                }
                else { // Wrap is after collapsed range
                    if end <= count { // Result will not be wrapped
                        // D.......AB.̲..C
                        p.advancedBy(i).moveInitializeFrom(p.advancedBy(i + count), count: h.capacity - i - count)
                        // D.......ABC̲...
                        p.advancedBy(h.capacity - count).moveInitializeFrom(p, count: end)
                        // ........ABC̲D..
                    }
                    else { // Result will remain wrapped
                        // DEFG....AB.̲..C
                        p.advancedBy(i).moveInitializeFrom(p.advancedBy(i + count), count: h.capacity - i - count)
                        // DEFG....ABC̲...
                        p.advancedBy(h.capacity - count).moveInitializeFrom(p, count: count)
                        // ...G....ABC̲DEF
                        p.moveInitializeFrom(p.advancedBy(count), count: end - count)
                        // G.......ABC̲DEF
                    }
                }
                hp.memory.count -= count
            }
            else {
                // Slide preceding items to the right
                if j >= h.start { // No wrap anywhere before end of collapsed range
                    // ...AB...C̲D...
                    p.advancedBy(h.start + count).moveInitializeBackwardFrom(p.advancedBy(h.start), count: j - h.start - count)
                    // ......ABC̲D...
                }
                else if j < count { // Collapsed range is wrapped
                    if  h.start + count >= h.capacity  { // Result will not be wrapped
                        // ...C̲D.....AB..
                        p.advancedBy(h.start + count - h.capacity).moveInitializeFrom(p.advancedBy(h.start), count: h.capacity + j - h.start - count)
                        // .ABC̲D.........
                    }
                    else { // Result will remain wrapped
                        // ..E̲F.....ABCD..
                        p.moveInitializeFrom(p.advancedBy(h.capacity - count), count: j)
                        // CDE̲F.....AB....
                        p.advancedBy(h.start + count).moveInitializeBackwardFrom(p.advancedBy(h.start), count: h.capacity - h.start - count)
                        // CDE̲F.........AB
                    }
                }
                else { // Wrap is before collapsed range
                    if h.capacity - h.start <= count { // Result will not be wrapped
                        // CD...E̲F.....AB
                        p.advancedBy(count).moveInitializeBackwardFrom(p, count: j - count)
                        // ...CDE̲F.....AB
                        p.advancedBy(h.start + count - h.capacity).moveInitializeFrom(p.advancedBy(h.start), count: h.capacity - h.start)
                        // .ABCDE̲F.......
                    }
                    else { // Result will remain wrapped
                        // EF...G̲H...ABCD
                        p.advancedBy(count).moveInitializeBackwardFrom(p, count: j - count)
                        // ...EFG̲H...ABCD
                        p.moveInitializeFrom(p.advancedBy(h.capacity) - count, count: count)
                        // BCDEFG̲H...A...
                        p.advancedBy(h.start + count).moveInitializeBackwardFrom(p.advancedBy(h.start), count: h.capacity - h.start - count)
                        // BCDEFG̲H......A
                    }
                }
                hp.memory.start = (h.start + count < h.capacity ? h.start + count : h.start + count - h.capacity)
                hp.memory.count -= count
            }
        }
    }

    internal func replaceRange<C: CollectionType where C.Generator.Element == Element>(range: Range<Int>, with newElements: C) {
        let h = manager.value
        let newCount: Int = numericCast(newElements.count)
        let delta = newCount - range.count
        assert(h.count + delta < h.capacity)
        let common = min(range.count, newCount)
        if common > 0 {
            manager.withUnsafeMutablePointerToElements { p in
                var q = p.advancedBy(h.bufferIndexForDequeIndex(range.startIndex))
                let limit = p.advancedBy(h.capacity)
                var i = common
                for element in newElements {
                    q.memory = element
                    q = q.successor()
                    if q == limit { q = p }
                    i -= 1
                    if i == 0 { break }
                }
            }
        }
        if range.count > common {
            removeRange(Range(start: range.startIndex + common, end: range.endIndex))
        }
        else if newCount > common {
            openGapAt(range.startIndex + common, length: newCount - common)
            manager.withUnsafeMutablePointerToElements { p in
                var q = p.advancedBy(h.bufferIndexForDequeIndex(range.startIndex + common))
                let limit = p.advancedBy(h.capacity)
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
}
