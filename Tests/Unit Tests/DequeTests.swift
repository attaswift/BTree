//
//  DequeTests.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2016-01-20.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import TreeCollections

private final class T: IntegerLiteralConvertible, Comparable, CustomStringConvertible, CustomDebugStringConvertible {
    let value: Int

    init(_ value: Int) {
        self.value = value
    }
    required init(integerLiteral value: IntegerLiteralType) {
        self.value = numericCast(value)
    }

    var description: String { return String(value) }
    var debugDescription: String { return String(value) }
}

private func ==(a: T, b: T) -> Bool {
    return a.value == b.value
}
private func <(a: T, b: T) -> Bool {
    return a.value < b.value
}

class DequeTests: XCTestCase {
    func testEmptyDeque() {
        let deque = Deque<T>()
        XCTAssertEqual(deque.count, 0)
        XCTAssertTrue(deque.isEmpty)
        XCTAssertElementsEqual(deque, [])
    }

    func testDequeWithSingleItem() {
        let deque = Deque<T>([42])
        XCTAssertEqual(deque.count, 1)
        XCTAssertFalse(deque.isEmpty)
        XCTAssertEqual(deque[0], 42)
        XCTAssertElementsEqual(deque, [42])
    }

    func testDequeWithSomeItems() {
        let deque = Deque<T>([23, 42, 77, 111])
        XCTAssertEqual(deque.count, 4)
        XCTAssertEqual(deque[0], 23)
        XCTAssertEqual(deque[1], 42)
        XCTAssertEqual(deque[2], 77)
        XCTAssertEqual(deque[3], 111)
        XCTAssertElementsEqual(deque, [23, 42, 77, 111])
    }

    func testRepeatedValue() {
        let deque = Deque<T>(count: 4, repeatedValue: 100)
        XCTAssertEqual(deque.count, 4)
        XCTAssertEqual(deque[0], 100)
        XCTAssertEqual(deque[1], 100)
        XCTAssertEqual(deque[2], 100)
        XCTAssertEqual(deque[3], 100)
        XCTAssertElementsEqual(deque, [100, 100, 100, 100])
    }

    func testCapacity() {
        var deque = Deque<T>(minimumCapacity: 100)
        XCTAssertGreaterThanOrEqual(deque.capacity, 100)

        deque.reserveCapacity(1000)
        XCTAssertGreaterThanOrEqual(deque.capacity, 1000)

        deque.reserveCapacity(100)
        XCTAssertGreaterThanOrEqual(deque.capacity, 1000)

        let capacity = deque.capacity
        let copy = deque
        XCTAssertEqual(copy.capacity, capacity)
        deque.reserveCapacity(5000)
        XCTAssertGreaterThanOrEqual(deque.capacity, 5000)
        XCTAssertEqual(copy.capacity, capacity)
    }

    func testIsUnique() {
        var deque = Deque<T>([1, 2, 3, 4])
        XCTAssertTrue(deque.isUnique)

        var copy = deque
        XCTAssertFalse(deque.isUnique)
        XCTAssertFalse(copy.isUnique)

        copy.reserveCapacity(copy.capacity + 1)
        XCTAssertTrue(deque.isUnique)
        XCTAssertTrue(copy.isUnique)
    }

    func testSubscriptSetter() {
        var deque = Deque<T>([23, 42, 77, 111])
        deque[2] = 66
        XCTAssertElementsEqual(deque, [23, 42, 66, 111])
    }

    func testArrayLiteral() {
        let deque: Deque<T> = [1, 7, 3, 2, 6, 5, 4]
        XCTAssertElementsEqual(deque, [1, 7, 3, 2, 6, 5, 4])
    }

    func testCustomPrinting() {
        let deque: Deque<T> = [1, 7, 3, 2, 6, 5, 4]
        XCTAssertEqual(deque.description, "Deque[1, 7, 3, 2, 6, 5, 4]")
        let debug = deque.debugDescription.stringByReplacingOccurrencesOfString("<[^>]+>", withString: "<T>", options: NSStringCompareOptions.RegularExpressionSearch)
        XCTAssertEqual(debug, "TreeCollections.Deque<T>([1, 7, 3, 2, 6, 5, 4])")
    }

    func testReplaceRange() {
        var deque: Deque<T> = [1, 7, 3, 2, 6, 5, 4]
        deque.replaceRange(2..<5, with: (10..<15).map { T($0) })
        XCTAssertElementsEqual(deque, [1, 7, 10, 11, 12, 13, 14, 5, 4])

        deque.replaceRange(1..<5, with: [])
        XCTAssertElementsEqual(deque, [1, 13, 14, 5, 4])

        deque.replaceRange(0..<5, with: [20, 21, 22])
        XCTAssertElementsEqual(deque, [20, 21, 22])

        deque.replaceRange(0..<3, with: [1, 2, 3, 4, 5])
        XCTAssertElementsEqual(deque, [1, 2, 3, 4, 5])
    }

    func testAppend() {
        var deque: Deque<T> = [1, 2, 3]

        deque.append(4)
        XCTAssertElementsEqual(deque, [1, 2, 3, 4])

        deque.append(5)
        XCTAssertElementsEqual(deque, [1, 2, 3, 4, 5])

        deque.append(6)
        XCTAssertElementsEqual(deque, [1, 2, 3, 4, 5, 6])
    }

    func testAppendContentsOf() {
        var deque: Deque<T> = [1, 2, 3]

        deque.appendContentsOf((4...6).map { T($0) })
        XCTAssertElementsEqual(deque, (1...6).map { T($0) })

        deque.appendContentsOf((7...100).map { T($0) })
        XCTAssertElementsEqual(deque, (1...100).map { T($0) })

        // Add a sequence with inexact underestimateCount()
        var i = 101
        deque.appendContentsOf(AnySequence<T> {
            anyGenerator {
                if i > 1000 {
                    return nil
                }
                defer { i += 1 }
                return T(i)
            }
        })
        XCTAssertElementsEqual(deque, (1...1000).map { T($0) })
    }

    func testInsert() {
        var deque: Deque<T> = [1, 2, 3, 4]

        deque.insert(10, atIndex: 2)
        XCTAssertElementsEqual(deque, [1, 2, 10, 3, 4])

        deque.insert(11, atIndex: 0)
        XCTAssertElementsEqual(deque, [11, 1, 2, 10, 3, 4])

        deque.insert(12, atIndex: 6)
        XCTAssertElementsEqual(deque, [11, 1, 2, 10, 3, 4, 12])
    }

    func testInsertContentsOf() {
        var deque: Deque<T> = [1, 2, 3]

        deque.insertContentsOf([], at: 2)
        XCTAssertElementsEqual(deque, [1, 2, 3])

        deque.insertContentsOf([10], at: 2)
        XCTAssertElementsEqual(deque, [1, 2, 10, 3])

        deque.insertContentsOf([11, 12], at: 0)
        XCTAssertElementsEqual(deque, [11, 12, 1, 2, 10, 3])

        deque.insertContentsOf([13, 14, 15], at: 6)
        XCTAssertElementsEqual(deque, [11, 12, 1, 2, 10, 3, 13, 14, 15])
    }

    func testRemoveAtIndex() {
        var deque: Deque<T> = [1, 2, 3, 4]

        deque.removeAtIndex(2)
        XCTAssertElementsEqual(deque, [1, 2, 4])

        deque.removeAtIndex(0)
        XCTAssertElementsEqual(deque, [2, 4])

        deque.removeAtIndex(1)
        XCTAssertElementsEqual(deque, [2])

        deque.removeAtIndex(0)
        XCTAssertElementsEqual(deque, [])
    }

    func testRemoveFirst() {
        var deque: Deque<T> = [1, 2, 3, 4]

        XCTAssertEqual(deque.removeFirst(), 1)
        XCTAssertElementsEqual(deque, [2, 3, 4])

        XCTAssertEqual(deque.removeFirst(), 2)
        XCTAssertElementsEqual(deque, [3, 4])

        XCTAssertEqual(deque.removeFirst(), 3)
        XCTAssertElementsEqual(deque, [4])

        XCTAssertEqual(deque.removeFirst(), 4)
        XCTAssertElementsEqual(deque, [])
    }

    func testRemoveFirstN() {
        var deque: Deque<T> = [1, 2, 3, 4, 5, 6]

        deque.removeFirst(2)
        XCTAssertElementsEqual(deque, [3, 4, 5, 6])

        deque.removeFirst(0)
        XCTAssertElementsEqual(deque, [3, 4, 5, 6])

        deque.removeFirst(4)
        XCTAssertElementsEqual(deque, [])

        deque.removeFirst(0)
        XCTAssertElementsEqual(deque, [])
    }

    func testRemoveRange() {
        var deque: Deque<T> = [1, 2, 3, 4, 5, 6]

        deque.removeRange(3 ..< 3)
        XCTAssertElementsEqual(deque, [1, 2, 3, 4, 5, 6])

        deque.removeRange(3 ..< 5)
        XCTAssertElementsEqual(deque, [1, 2, 3, 6])

        deque.removeRange(2 ..< 4)
        XCTAssertElementsEqual(deque, [1, 2])

        deque.removeRange(0 ..< 1)
        XCTAssertElementsEqual(deque, [2])

        deque.removeRange(0 ..< 1)
        XCTAssertElementsEqual(deque, [])

        deque.removeRange(0 ..< 0)
        XCTAssertElementsEqual(deque, [])
    }

    func testRemoveAllKeepingCapacity() {
        var deque = Deque<T>((0 ..< 1000).map { T($0) })
        let capacity = deque.capacity
        deque.removeAll(keepCapacity: true)
        XCTAssertElementsEqual(deque, [])
        XCTAssertEqual(deque.capacity, capacity)
    }

    func testRemoveAllNotKeepingCapacity() {
        var deque = Deque<T>((0 ..< 1000).map { T($0) })
        let capacity = deque.capacity
        deque.removeAll()
        XCTAssertElementsEqual(deque, [])
        XCTAssertLessThan(deque.capacity, capacity)
    }

    func testRemoveLast() {
        var deque: Deque<T> = [1, 2, 3]

        XCTAssertEqual(deque.removeLast(), 3)
        XCTAssertElementsEqual(deque, [1, 2])

        XCTAssertEqual(deque.removeLast(), 2)
        XCTAssertElementsEqual(deque, [1])

        XCTAssertEqual(deque.removeLast(), 1)
        XCTAssertElementsEqual(deque, [])
    }

    func testRemoveLastN() {
        var deque: Deque<T> = [1, 2, 3, 4, 5, 6, 7]

        deque.removeLast(0)
        XCTAssertElementsEqual(deque, [1, 2, 3, 4, 5, 6, 7])

        deque.removeLast(2)
        XCTAssertElementsEqual(deque, [1, 2, 3, 4, 5])

        deque.removeLast(1)
        XCTAssertElementsEqual(deque, [1, 2, 3, 4])

        deque.removeLast(4)
        XCTAssertElementsEqual(deque, [])
    }

    func testPopFirst() {
        var deque: Deque<T> = [1, 2, 3]

        XCTAssertEqual(deque.popFirst(), 1)
        XCTAssertElementsEqual(deque, [2, 3])

        XCTAssertEqual(deque.popFirst(), 2)
        XCTAssertElementsEqual(deque, [3])

        XCTAssertEqual(deque.popFirst(), 3)
        XCTAssertElementsEqual(deque, [])

        XCTAssertEqual(deque.popFirst(), nil)
    }

    func testPopLast() {
        var deque: Deque<T> = [1, 2, 3]

        XCTAssertEqual(deque.popLast(), 3)
        XCTAssertElementsEqual(deque, [1, 2])

        XCTAssertEqual(deque.popLast(), 2)
        XCTAssertElementsEqual(deque, [1])

        XCTAssertEqual(deque.popLast(), 1)
        XCTAssertElementsEqual(deque, [])

        XCTAssertEqual(deque.popFirst(), nil)
    }

    func testPrepend() {
        var deque: Deque<T> = [1, 2, 3]

        deque.prepend(-1)
        XCTAssertElementsEqual(deque, [-1, 1, 2, 3])

        deque.prepend(-2)
        XCTAssertElementsEqual(deque, [-2, -1, 1, 2, 3])

        deque.prepend(-3)
        XCTAssertElementsEqual(deque, [-3, -2, -1, 1, 2, 3])
    }

    func testEquality() {
        let a = Deque<T>([])
        let b = Deque<T>([1, 2, 3])
        let c = b
        let d = Deque<T>([1, 2, 3])
        let e = Deque<T>([1, 2, 4])

        XCTAssertTrue(a == a)
        XCTAssertTrue(b == c)
        XCTAssertTrue(b == d)
        XCTAssertFalse(a == b)
        XCTAssertFalse(b == e)

        XCTAssertFalse(a != a)
        XCTAssertFalse(b != d)
        XCTAssertTrue(a != b)
    }

    private func dequeWithElements(elements: [T], wrappedAt wrap: Int) -> Deque<T> {
        var deque = Deque<T>(minimumCapacity: max(15, 2 * elements.count))
        let capacity = deque.capacity
        precondition(wrap > -capacity && wrap < capacity)
        precondition(elements.count < capacity)

        // First, insert dummy items so that the wrap point will be at the desired place
        let desiredStart = wrap < 0 ? -wrap : wrap == 0 ? 0 : capacity - wrap
        (0 ..< desiredStart).forEach { _ in deque.append(-1) }

        // Now insert actual elements at the correct position so that wrapping occurs where desired
        var fillersGone = false
        for e in elements {
            if deque.capacity == deque.count {
                assert(!fillersGone)
                (0 ..< desiredStart).forEach { _ in deque.removeFirst() }
                fillersGone = true
            }
            deque.append(e)
        }
        if !fillersGone {
            (0 ..< desiredStart).forEach { _ in deque.removeFirst() }
        }
        XCTAssertEqual(deque.buffer.start, desiredStart)
        return deque
    }

    func testInsertionCases() {
        func testInsert(elements elements: [T], wrappedAt wrap: Int, insertionIndex: Int, insertedElements: [T], file: FileString = __FILE__, line: UInt = __LINE__) {
            var deque = dequeWithElements(elements, wrappedAt: wrap)
            var expected = elements
            expected.insertContentsOf(insertedElements, at: insertionIndex)
            deque.insertContentsOf(insertedElements, at: insertionIndex)

            XCTAssertElementsEqual(deque, expected, file: file, line: line)
        }
        // These tests exercise all cases in DequeBuffer.openGapAt(_:, length:).
        testInsert(elements: [0, 1, 2, 3, 4], wrappedAt: 0, insertionIndex: 3, insertedElements: [5, 6])
        testInsert(elements: [0, 1, 2, 3, 4, 5, 6], wrappedAt: 7, insertionIndex: 4, insertedElements: [7, 8])
        testInsert(elements: [0, 1, 2, 3, 4, 5, 6], wrappedAt: 7, insertionIndex: 4, insertedElements: [7, 8, 9, 10])
        testInsert(elements: [0, 1, 2, 3, 4, 5, 6], wrappedAt: 6, insertionIndex: 4, insertedElements: [7])
        testInsert(elements: [0, 1, 2, 3, 4, 5, 6], wrappedAt: 6, insertionIndex: 4, insertedElements: [7, 8, 9, 10])

        testInsert(elements: [0, 1, 2, 3, 4], wrappedAt: -2, insertionIndex: 2, insertedElements: [5, 6])
        testInsert(elements: [0, 1, 2, 3, 4], wrappedAt: -1, insertionIndex: 2, insertedElements: [5, 6])
        testInsert(elements: [0, 1, 2, 3, 4], wrappedAt: 0, insertionIndex: 2, insertedElements: [5, 6, 7, 8])
        testInsert(elements: [0, 1, 2, 3, 4], wrappedAt: 1, insertionIndex: 2, insertedElements: [5])
        testInsert(elements: [0, 1, 2, 3, 4], wrappedAt: 1, insertionIndex: 2, insertedElements: [5, 6, 7, 8])
    }


    func testRemovalCases() {
        func testRemove(elements elements: [T], wrappedAt wrap: Int, range: Range<Int>, file: FileString = __FILE__, line: UInt = __LINE__) {
            var deque = dequeWithElements(elements, wrappedAt: wrap)
            var expected = elements
            expected.removeRange(range)
            deque.removeRange(range)

            XCTAssertElementsEqual(deque, expected, file: file, line: line)
        }
        // These tests exercise all cases in DequeBuffer.removeRange(_:).
        testRemove(elements: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], wrappedAt: 0, range: 7..<8)
        testRemove(elements: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], wrappedAt: 8, range: 7..<10)
        testRemove(elements: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], wrappedAt: 8, range: 7..<9)
        testRemove(elements: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], wrappedAt: 10, range: 7..<9)
        testRemove(elements: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], wrappedAt: 9, range: 7..<8)

        testRemove(elements: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], wrappedAt: 0, range: 1..<2)
        testRemove(elements: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], wrappedAt: 3, range: 1..<5)
        testRemove(elements: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], wrappedAt: 3, range: 2..<4)
        testRemove(elements: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], wrappedAt: 1, range: 2..<4)
        testRemove(elements: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], wrappedAt: 2, range: 3..<4)

    }

}
