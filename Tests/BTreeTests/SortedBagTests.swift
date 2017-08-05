//
//  SortedBagTests.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-11-06.
//  Copyright © 2016–2017 Károly Lőrentey.
//

import XCTest
@testable import BTree

private final class Test: Comparable, ExpressibleByIntegerLiteral, CustomStringConvertible {
    let value: Int

    init(_ value: Int) { self.value = value }
    init(integerLiteral value: Int) { self.value = value }

    var description: String { return "\(value)" }

    static func ==(a: Test, b: Test) -> Bool { return a.value == b.value }
    static func <(a: Test, b: Test) -> Bool { return a.value < b.value }
}

class SortedBagTests: XCTestCase {

    func test_emptyBag() {
        let bag = SortedBag<Int>()

        XCTAssertTrue(bag.isEmpty)
        XCTAssertEqual(bag.count, 0)
        XCTAssertEqual(bag.startIndex, bag.endIndex)
        assertEqualElements(bag, [])
    }

    func test_singleElement() {
        let bag = SortedBag([42])

        XCTAssertFalse(bag.isEmpty)
        XCTAssertEqual(bag.count, 1)
        XCTAssertNotEqual(bag.startIndex, bag.endIndex)
        XCTAssertEqual(bag.index(after: bag.startIndex), bag.endIndex)
        assertEqualElements(bag, [42])

        XCTAssertEqual(bag[bag.startIndex], 42)
        XCTAssertTrue(bag.contains(42))
    }

    func test_unsortedElements_uniqueItems() {
        let c = 10_000
        let bag = SortedBag((0 ..< c).reversed())

        XCTAssertEqual(bag.count, c)
        assertEqualElements(bag, 0 ..< c)
    }

    func test_unsortedElements_duplicateItems() {
        let c = 10_000
        let bag = SortedBag((0 ..< c).reversed().repeatEach(10))

        XCTAssertEqual(bag.count, 10 * c)
        assertEqualElements(bag, (0 ..< c).repeatEach(10))
    }

    func test_sortedElements_uniqueItems() {
        let c = 10_000
        let bag = SortedBag(sortedElements: 0 ..< c)

        XCTAssertEqual(bag.count, c)
        assertEqualElements(bag, 0 ..< c)
    }

    func test_sortedElements_duplicateItems() {
        let c = 10_000
        let bag = SortedBag(sortedElements: (0 ..< c).repeatEach(10))

        XCTAssertEqual(bag.count, 10 * c)
        assertEqualElements(bag, (0 ..< c).repeatEach(10))
    }

    func test_arrayLiteral() {
        let bag: SortedBag = [1, 4, 6, 4, 2, 3, 6, 5, 5, 1, 1, 4, 3, 3]

        XCTAssertEqual(bag.count, 14)
        assertEqualElements(bag, [1, 1, 1, 2, 3, 3, 3, 4, 4, 4, 5, 5, 6, 6])
    }

    func test_initWithSet() {
        let set = SortedSet(0 ..< 100)
        var bag = SortedBag(set)

        assertEqualElements(bag, set)

        bag.insert(100)
        assertEqualElements(bag, 0 ... 100)
        assertEqualElements(set, 0 ..< 100)
    }

    func test_subscriptWithIndexing() {
        let c = 10_000
        let elements = (0 ..< c).repeatEach(3)
        let bag = SortedBag(elements)
        var i = 0
        var index = bag.startIndex
        while index != bag.endIndex {
            XCTAssertEqual(bag[index], i / 3)
            XCTAssertEqual(bag.distance(from: bag.startIndex, to: index), i)
            bag.formIndex(after: &index)
            i += 1
        }
        XCTAssertEqual(i, elements.count)
    }

    func test_subscriptWithIndexRange() {
        let c = 50
        let elements = (0 ..< c).repeatEach(3)
        let bag = SortedBag(elements)
        var i = 0
        var j = elements.count
        var start = bag.startIndex
        var end = bag.endIndex
        while i <= j {
            assertEqualElements(bag[start ..< end], elements[i ..< j])
            i += 1
            bag.formIndex(after: &start)
            j -= 1
            bag.formIndex(before: &end)
        }
    }

    func test_makeIterator() {
        let c = 10_000
        let elements = (0 ..< c).repeatEach(2)
        let bag = SortedBag(elements)
        assertEqualElements(IteratorSequence(bag.makeIterator()), elements)
    }

    func test_subscriptByOffsets() {
        let c = 10_000
        let elements = (0 ..< c).repeatEach(2)
        let bag = SortedBag(elements)
        for i in 0 ..< 2 * c {
            XCTAssertEqual(bag[i], i / 2)
        }
    }

    func test_subscriptByOffsetRange() {
        let c = 50
        let elements = (0 ..< c).repeatEach(2)
        let bag = SortedBag(elements)
        for i in 0 ..< c {
            for j in i ..< c {
                assertEqualElements(bag[i ..< j], elements[i ..< j])
            }
        }
    }

    func test_indexing() {
        let s = SortedBag(sortedElements: (0..<10))
        var index = s.startIndex
        XCTAssertEqual(s.index(after: index), s.index(ofOffset: 1))
        XCTAssertEqual(s.index(index, offsetBy: 5), s.index(ofOffset: 5))

        s.formIndex(after: &index)
        XCTAssertEqual(s.offset(of: index), 1)
        s.formIndex(&index, offsetBy: 5)
        XCTAssertEqual(s.offset(of: index), 6)

        XCTAssertEqual(s.index(before: index), s.index(ofOffset: 5))
        XCTAssertEqual(s.index(index, offsetBy: -4), s.index(ofOffset: 2))

        s.formIndex(before: &index)
        XCTAssertEqual(s.offset(of: index), 5)
        s.formIndex(&index, offsetBy: -3)
        XCTAssertEqual(s.offset(of: index), 2)

        XCTAssertNil(s.index(index, offsetBy: 4, limitedBy: s.index(ofOffset: 5)))
        XCTAssertEqual(s.index(index, offsetBy: 4, limitedBy: s.index(ofOffset: 8)), s.index(ofOffset: 6))

        XCTAssertFalse(s.formIndex(&index, offsetBy: 4, limitedBy: s.index(ofOffset: 5)))
        XCTAssertEqual(s.offset(of: index), 5)

        XCTAssertTrue(s.formIndex(&index, offsetBy: -2, limitedBy: s.index(ofOffset: 2)))
        XCTAssertEqual(s.offset(of: index), 3)

        XCTAssertEqual(s.distance(from: s.index(ofOffset: 3), to: s.index(ofOffset: 8)), 5)
    }

    func test_offsetOfMember() {
        let s = SortedBag(sortedElements: (0 ..< 10).map { 2 * $0 }.repeatEach(2))
        for m in 0 ..< 20 {
            if m & 1 == 0 {
                XCTAssertEqual(s.offset(of: m), m)
            }
            else {
                XCTAssertNil(s.offset(of: m))
            }
        }
        XCTAssertNil(s.offset(of: -2))
        XCTAssertNil(s.offset(of: -1))
        XCTAssertNil(s.offset(of: 20))
    }

    func test_forEach() {
        let c = 10_000
        let bag = SortedBag(0 ..< c)
        var i = 0
        bag.forEach { n in
            XCTAssertEqual(n, i)
            i += 1
        }
    }

    func test_map() {
        let c = 10_000
        let bag = SortedBag(0 ..< c)
        var i = 0
        let r = bag.map { (n: Int) -> Int in
            XCTAssertEqual(n, i)
            i += 1
            return n
        }
        assertEqualElements(r, 0 ..< c)
    }

    func test_flatMap_Sequence() {
        let c = 1000
        let bag = SortedBag(0 ..< c)
        let r = bag.flatMap { [$0, $0, $0] }
        assertEqualElements(r, (0 ..< c).repeatEach(3))
    }

    func test_flatMap_Optional() {
        let c = 1000
        let bag = SortedBag(0 ..< c)
        let r = bag.flatMap { $0 & 1 == 0 ? $0 / 2 : nil }
        assertEqualElements(r, 0 ..< 500)
    }

    func test_filter() {
        let c = 1000
        let bag = SortedBag(0 ..< c)
        let r = bag.filter { $0 & 1 == 0 }
        assertEqualElements(r, (0 ..< 500).map { 2 * $0 })
    }

    func test_reduce() {
        let c = 1000
        let bag = SortedBag(0 ..< c)
        let r = bag.reduce(0) { $0 + $1 }
        XCTAssertEqual(r, (c - 1) * c / 2)
    }

    func test_boundaries() {
        let c = 1000
        let bag = SortedBag(0 ..< c)
        XCTAssertEqual(bag.first, 0)
        XCTAssertEqual(bag.last, c - 1)
        XCTAssertEqual(bag.min(), 0)
        XCTAssertEqual(bag.max(), c - 1)
    }

    func test_drop() {
        let c = 50
        let elements = (0 ..< c).repeatEach(2)
        let bag = SortedBag(elements)
        assertEqualElements(bag.dropFirst(), elements.dropFirst())
        assertEqualElements(bag.dropLast(), elements.dropLast())
        for i in 0 ..< 2 * c {
            assertEqualElements(bag.dropFirst(i), elements.dropFirst(i))
            assertEqualElements(bag.dropLast(i), elements.dropLast(i))
        }
    }

    func test_prefix() {
        let c = 50
        let elements = (0 ..< c).repeatEach(2)
        let bag = SortedBag(elements)
        var index = bag.startIndex

        assertEqualElements(bag.prefix(upTo: -c), [])
        assertEqualElements(bag.prefix(through: -c), [])
        assertEqualElements(bag.prefix(upTo: -1), [])
        assertEqualElements(bag.prefix(through: -1), [])

        for i in 0 ..< 2 * c {
            assertEqualElements(bag.prefix(i), elements.prefix(i))
            assertEqualElements(bag.prefix(through: index), elements.prefix(through: i))
            assertEqualElements(bag.prefix(through: i / 2), elements.prefix(through: i | 1))
            assertEqualElements(bag.prefix(upTo: index), elements.prefix(upTo: i))
            assertEqualElements(bag.prefix(upTo: i / 2), elements.prefix(upTo: i & ~1))
            bag.formIndex(after: &index)
        }
        XCTAssertEqual(index, bag.endIndex)
        assertEqualElements(bag.prefix(bag.count), elements)
        assertEqualElements(bag.prefix(through: c), elements)
        assertEqualElements(bag.prefix(upTo: bag.endIndex), elements)

        assertEqualElements(bag.prefix(upTo: c), elements)
        assertEqualElements(bag.prefix(upTo: c + 1), elements)
        assertEqualElements(bag.prefix(upTo: 2 * c), elements)
    }

    func test_suffix() {
        let c = 50
        let elements = (0 ..< c).repeatEach(2)
        let bag = SortedBag(elements)
        var index = bag.startIndex

        assertEqualElements(bag.suffix(from: -c), elements)
        assertEqualElements(bag.suffix(from: -1), elements)

        for i in 0 ..< 2 * c {
            assertEqualElements(bag.suffix(i), elements.suffix(i))
            assertEqualElements(bag.suffix(from: index), elements.suffix(from: i))
            assertEqualElements(bag.suffix(from: i / 2), elements.suffix(from: i & ~1))
            bag.formIndex(after: &index)
        }
        XCTAssertEqual(index, bag.endIndex)
        assertEqualElements(bag.suffix(bag.count), elements)
        assertEqualElements(bag.suffix(from: bag.endIndex), [])
        assertEqualElements(bag.suffix(from: c), [])
        assertEqualElements(bag.suffix(from: c + 1), [])
        assertEqualElements(bag.suffix(from: 2 * c), [])
    }

    func test_description() {
        let bag = SortedBag([0, 1, 1, 2, 3, 3, 3, 4])
        XCTAssertEqual(String(describing: bag), "[0, 1, 1, 2, 3, 3, 3, 4]")
        XCTAssertEqual(String(reflecting: bag), "SortedBag([0, 1, 1, 2, 3, 3, 3, 4])")
    }

    func test_contains() {
        let bag = SortedBag((0 ..< 500).map { 2 * $0 }.repeatEach(2))
        for i in 0 ..< 500 {
            XCTAssertEqual(bag.contains(i), i & 1 == 0)
        }
    }

    func test_countOf() {
        let bag = SortedBag((0 ..< 500).map { 2 * $0 }.repeatEach(2))
        for i in 0 ..< 500 {
            if i & 1 == 0 {
                XCTAssertEqual(bag.count(of: i), 2)
            }
            else {
                XCTAssertEqual(bag.count(of: i), 0)
            }
        }
    }

    func test_indexOf() {
        let c = 100
        let bag = SortedBag((0 ..< c).map { 2 * $0 }.repeatEach(3))
        for i in 0 ..< 2 * c {
            let index = bag.index(of: i)
            if i & 1 == 0 {
                XCTAssertEqual(index, bag.index(bag.startIndex, offsetBy: i / 2 * 3))
                XCTAssertEqual(bag[index!], i)
            }
            else {
                XCTAssertNil(index)
            }
        }
    }

    func test_indexOfFirstElementAfter() {
        let c = 100
        let bag = SortedBag((0 ..< c).map { 2 * $0 }.repeatEach(3))

        for i in 0 ..< 2 * c {
            let index = bag.indexOfFirstElement(after: i)
            if i < 2 * (c - 1) {
                XCTAssertNotNil(index)
                guard let index = index else { continue }
                XCTAssertEqual(bag.offset(of: index), 3 * (i / 2 + 1))
                XCTAssertEqual(bag[index], 2 * (i / 2 + 1))
            }
            else {
                XCTAssertNil(index)
            }
        }
    }

    func test_indexOfFirstElementNotBefore() {
        let c = 100
        let bag = SortedBag((0 ..< c).map { 2 * $0 }.repeatEach(3))

        for i in 0 ..< 2 * c {
            let index = bag.indexOfFirstElement(notBefore: i)
            if i < 2 * c - 1 {
                XCTAssertNotNil(index)
                guard let index = index else { continue }
                let offset = bag.offset(of: index)
                let element = bag[index]
                if i & 1 == 0 {
                    XCTAssertEqual(offset, 3 * (i / 2))
                    XCTAssertEqual(element, i)
                }
                else {
                    XCTAssertEqual(offset, 3 * (i / 2 + 1))
                    XCTAssertEqual(element, i + 1)
                }
            }
            else {
                XCTAssertNil(index)
            }
        }
    }

    func test_indexOfLastElementBefore() {
        let c = 100
        let bag = SortedBag((0 ..< c).map { 2 * $0 }.repeatEach(3))

        for i in -2 ..< 2 * c {
            let index = bag.indexOfLastElement(before: i)
            if i > 0 {
                XCTAssertNotNil(index)
                guard let index = index else { continue }
                let offset = bag.offset(of: index)
                let element = bag[index]
                if i & 1 == 0 {
                    XCTAssertEqual(offset, 3 * (i / 2) - 1)
                    XCTAssertEqual(element, i - 2)
                }
                else {
                    XCTAssertEqual(offset, 3 * (i / 2) + 2)
                    XCTAssertEqual(element, i - 1)
                }
            }
            else {
                XCTAssertNil(index)
            }
        }
    }

    func test_indexOfLastElementNotAfter() {
        let c = 100
        let bag = SortedBag((0 ..< c).map { 2 * $0 }.repeatEach(3))

        for i in -2 ..< 2 * c {
            let index = bag.indexOfLastElement(notAfter: i)
            if i >= 0 {
                XCTAssertNotNil(index)
                guard let index = index else { continue }
                XCTAssertEqual(bag.offset(of: index), 3 * (i / 2) + 2)
                XCTAssertEqual(bag[index], i & ~1)
            }
            else {
                XCTAssertNil(index)
            }
        }
    }

    func test_insert() {
        var bag = SortedBag<Test>()
        let one1 = Test(1)
        let i1 = bag.insert(one1)
        XCTAssertTrue(i1.inserted)
        XCTAssertTrue(i1.memberAfterInsert === one1)

        // Inserting a duplicate behaves as if it was a new element.
        let one2 = Test(1)
        let i2 = bag.insert(one2)
        XCTAssertTrue(i2.inserted)
        XCTAssertTrue(i2.memberAfterInsert === one2)

        XCTAssertTrue(bag.first === one1)

        let four = Test(4)
        let i3 = bag.insert(four)
        XCTAssertTrue(i3.inserted)
        XCTAssertTrue(i3.memberAfterInsert === four)

        let two = Test(2)
        let i4 = bag.insert(two)
        XCTAssertTrue(i4.inserted)
        XCTAssertTrue(i4.memberAfterInsert === two)

        let three = Test(3)
        let i5 = bag.insert(three)
        XCTAssertTrue(i5.inserted)
        XCTAssertTrue(i5.memberAfterInsert === three)

        assertEqualElements(bag, [1, 1, 2, 3, 4].map { Test($0) })

        for i in 5 ... 100 {
            let element = Test(i)
            let res = bag.insert(element)
            XCTAssertTrue(res.inserted)
            XCTAssertTrue(res.memberAfterInsert === element)
            XCTAssertTrue(bag.last === element)
        }
        for i in 2 ... 100 {
            let element = Test(i)
            let res = bag.insert(element)
            XCTAssertTrue(res.inserted)
            XCTAssertTrue(res.memberAfterInsert === element)
        }
        assertEqualElements(bag, (1 ... 100).repeatEach(2).map { Test($0) })
    }

    func test_update() {
        var bag = SortedBag<Test>()
        let one1 = Test(1)
        XCTAssertNil(bag.update(with: one1))

        let one2 = Test(1)
        XCTAssertNil(bag.update(with: one2))

        XCTAssertTrue(bag.first === one2)

        let four = Test(4)
        XCTAssertNil(bag.update(with: four))
        XCTAssertTrue(bag[2] === four)

        let two = Test(2)
        XCTAssertNil(bag.update(with: two))
        XCTAssertTrue(bag[2] === two)

        let three = Test(3)
        XCTAssertNil(bag.update(with: three))
        XCTAssertTrue(bag[0] === one2)
        XCTAssertTrue(bag[1] === one1)
        XCTAssertTrue(bag[2] === two)
        XCTAssertTrue(bag[3] === three)
        XCTAssertTrue(bag[4] === four)

        assertEqualElements(bag, [1, 1, 2, 3, 4].map { Test($0) })

        for i in 5 ... 100 {
            let element = Test(i)
            XCTAssertNil(bag.update(with: element))
            XCTAssertTrue(bag.last === element)
        }
        for i in 2 ... 100 {
            let element = Test(i)
            XCTAssertNil(bag.update(with: element))
        }
        assertEqualElements(bag, (1 ... 100).repeatEach(2).map { Test($0) })
    }


    func test_remove() {
        let c = 500
        let elements = (0 ..< c).map { 2 * $0 }.repeatEach(2).map { Test($0) }
        var bag = SortedBag(sortedElements: elements)
        for i in 0 ..< 2 * c {
            if i & 1 == 0 {
                let removed = bag.remove(Test(i))
                XCTAssert(removed === elements[i], "\(i)")
            }
            else {
                XCTAssertNil(bag.remove(Test(i)))
            }
        }
        for i in 0 ..< 2 * c {
            if i & 1 == 0 {
                let removed = bag.remove(Test(i))
                XCTAssert(removed === elements[i + 1], "\(i)")
            }
            else {
                XCTAssertNil(bag.remove(Test(i)))
            }
        }
        XCTAssertTrue(bag.isEmpty)
    }

    func test_removeAll() {
        let c = 50
        let elements = (0 ..< c).map { 2 * $0 }.repeatEach(2).map { Test($0) }
        var bag = SortedBag(sortedElements: elements)
        for i in 0 ..< 2 * c {
            bag.removeAll(Test(i))
            assertEqualElements(bag, elements[2 * (i / 2 + 1) ..< 2 * c])
        }
        XCTAssertTrue(bag.isEmpty)
    }

    func test_removeAt() {
        let c = 500
        let elements = (0 ..< c).map { 2 * $0 }.repeatEach(2).map { Test($0) }
        let bag = SortedBag(sortedElements: elements)
        var index = bag.startIndex
        for i in 0 ..< elements.count {
            var copy = bag
            let removed = copy.remove(at: index)
            XCTAssertTrue(removed === elements[i])
            bag.formIndex(after: &index)
        }
        assertEqualElements(bag, elements)
    }

    func test_removeAtOffset() {
        let c = 500
        let elements = (0 ..< c).map { 2 * $0 }.repeatEach(2).map { Test($0) }
        let bag = SortedBag(sortedElements: elements)
        for i in 0 ..< elements.count {
            var copy = bag
            let removed = copy.remove(atOffset: i)
            XCTAssertTrue(removed === elements[i])
        }
        assertEqualElements(bag, elements)
    }

    func test_removeFamily() {
        var bag = SortedBag(0 ..< 20)

        XCTAssertEqual(bag.removeFirst(), 0)
        assertEqualElements(bag, 1 ..< 20)

        bag.removeFirst(5)
        assertEqualElements(bag, 6 ..< 20)

        XCTAssertEqual(bag.popFirst(), 6)
        assertEqualElements(bag, 7 ..< 20)

        XCTAssertEqual(bag.removeLast(), 19)
        assertEqualElements(bag, 7 ..< 19)

        bag.removeLast(5)
        assertEqualElements(bag, 7 ..< 14)

        XCTAssertEqual(bag.popLast(), 13)
        assertEqualElements(bag, 7 ..< 13)

        bag.removeAll()
        assertEqualElements(bag, [])
    }

    func test_sorted() {
        let bag = SortedBag(0 ..< 10)
        assertEqualElements(bag.sorted(), bag)
    }

    func test_setOperations() {
        let ea = (0 ..< 30).repeatEach(2)
        let a = SortedBag(sortedElements: ea)

        let eb = (20 ..< 50).repeatEach(3)
        let b = SortedBag(sortedElements: eb)

        let union = (ea + eb).sorted()
        let intersection = (20 ..< 30).repeatEach(2)
        let aMinusB = (0 ..< 20).repeatEach(2)
        let bMinusA = (20 ..< 30).repeatEach(1) + (30 ..< 50).repeatEach(3)
        let symmetricDiff = (0 ..< 20).repeatEach(2) + (20 ..< 30).repeatEach(1) + (30 ..< 50).repeatEach(3)

        assertEqualElements(a.union(b), union)
        assertEqualElements(b.union(a), union)

        assertEqualElements(a.intersection(b), intersection)
        assertEqualElements(b.intersection(a), intersection)

        assertEqualElements(a.subtracting(b), aMinusB)
        assertEqualElements(b.subtracting(a), bMinusA)

        assertEqualElements(a.symmetricDifference(b), symmetricDiff)
        assertEqualElements(b.symmetricDifference(a), symmetricDiff)

        var x = a
        x.formUnion(b)
        assertEqualElements(x, union)

        x = b
        x.formUnion(a)
        assertEqualElements(x, union)

        x = a
        x.formIntersection(b)
        assertEqualElements(x, intersection)

        x = b
        x.formIntersection(a)
        assertEqualElements(x, intersection)

        x = a
        x.subtract(b)
        assertEqualElements(x, aMinusB)

        x = b
        x.subtract(a)
        assertEqualElements(x, bMinusA)

        x = a
        x.formSymmetricDifference(b)
        assertEqualElements(x, symmetricDiff)

        x = b
        x.formSymmetricDifference(a)
        assertEqualElements(x, symmetricDiff)
    }

    func test_elementsEqual() {
        let a = SortedBag(0 ..< 30)
        let b = SortedBag((0 ..< 30).repeatEach(2))
        let c = SortedBag(10 ..< 20)
        let d = SortedBag((20 ..< 30).repeatEach(2))

        XCTAssertTrue(a.elementsEqual(a))
        XCTAssertTrue(a.elementsEqual(SortedBag(0 ..< 30)))
        XCTAssertFalse(a.elementsEqual(b))
        XCTAssertFalse(a.elementsEqual(c))
        XCTAssertFalse(a.elementsEqual(d))
    }

    func test_equality() {
        let a = SortedBag(0 ..< 30)
        let b = SortedBag((0 ..< 30).repeatEach(2))
        let c = SortedBag(10 ..< 20)
        let d = SortedBag((20 ..< 30).repeatEach(2))

        XCTAssertTrue(a == a)
        XCTAssertTrue(a == SortedBag(0 ..< 30))
        XCTAssertFalse(a == b)
        XCTAssertFalse(a == c)
        XCTAssertFalse(a == d)
    }

    func test_isDisjointWith() {
        let a = SortedBag(0 ..< 30)
        let b = SortedBag((0 ..< 30).repeatEach(2))
        let c = SortedBag(10 ..< 20)
        let d = SortedBag((20 ..< 30).repeatEach(2))

        XCTAssertFalse(a.isDisjoint(with:a))
        XCTAssertFalse(a.isDisjoint(with:b))
        XCTAssertFalse(a.isDisjoint(with:c))
        XCTAssertFalse(a.isDisjoint(with:d))

        XCTAssertFalse(b.isDisjoint(with:a))
        XCTAssertFalse(b.isDisjoint(with:b))
        XCTAssertFalse(b.isDisjoint(with:c))
        XCTAssertFalse(b.isDisjoint(with:d))

        XCTAssertFalse(c.isDisjoint(with:a))
        XCTAssertFalse(c.isDisjoint(with:b))
        XCTAssertFalse(c.isDisjoint(with:c))
        XCTAssertTrue(c.isDisjoint(with:d))

        XCTAssertFalse(d.isDisjoint(with:a))
        XCTAssertFalse(d.isDisjoint(with:b))
        XCTAssertTrue(d.isDisjoint(with:c))
        XCTAssertFalse(d.isDisjoint(with:d))
    }

    func test_isSubsetOf() {
        let a = SortedBag(0 ..< 30)
        let b = SortedBag((0 ..< 30).repeatEach(2))
        let c = SortedBag(10 ..< 20)
        let d = SortedBag((20 ..< 30).repeatEach(2))

        XCTAssertTrue(a.isSubset(of: a))
        XCTAssertTrue(a.isSubset(of: b))
        XCTAssertFalse(a.isSubset(of: c))
        XCTAssertFalse(a.isSubset(of: d))

        XCTAssertFalse(b.isSubset(of: a))
        XCTAssertTrue(b.isSubset(of: b))
        XCTAssertFalse(b.isSubset(of: c))
        XCTAssertFalse(b.isSubset(of: d))

        XCTAssertTrue(c.isSubset(of: a))
        XCTAssertTrue(c.isSubset(of: b))
        XCTAssertTrue(c.isSubset(of: c))
        XCTAssertFalse(c.isSubset(of: d))

        XCTAssertFalse(d.isSubset(of: a))
        XCTAssertTrue(d.isSubset(of: b))
        XCTAssertFalse(d.isSubset(of: c))
        XCTAssertTrue(d.isSubset(of: d))
    }

    func test_isStrictSubsetOf() {
        let a = SortedBag(0 ..< 30)
        let b = SortedBag((0 ..< 30).repeatEach(2))
        let c = SortedBag(10 ..< 20)
        let d = SortedBag((20 ..< 30).repeatEach(2))

        XCTAssertFalse(a.isStrictSubset(of: a))
        XCTAssertTrue(a.isStrictSubset(of: b))
        XCTAssertFalse(a.isStrictSubset(of: c))
        XCTAssertFalse(a.isStrictSubset(of: d))

        XCTAssertFalse(b.isStrictSubset(of: a))
        XCTAssertFalse(b.isStrictSubset(of: b))
        XCTAssertFalse(b.isStrictSubset(of: c))
        XCTAssertFalse(b.isStrictSubset(of: d))

        XCTAssertTrue(c.isStrictSubset(of: a))
        XCTAssertTrue(c.isStrictSubset(of: b))
        XCTAssertFalse(c.isStrictSubset(of: c))
        XCTAssertFalse(c.isStrictSubset(of: d))

        XCTAssertFalse(d.isStrictSubset(of: a))
        XCTAssertTrue(d.isStrictSubset(of: b))
        XCTAssertFalse(d.isStrictSubset(of: c))
        XCTAssertFalse(d.isStrictSubset(of: d))
    }

    func test_isSupersetOf() {
        let a = SortedBag(0 ..< 30)
        let b = SortedBag((0 ..< 30).repeatEach(2))
        let c = SortedBag(10 ..< 20)
        let d = SortedBag((20 ..< 30).repeatEach(2))

        XCTAssertTrue(a.isSuperset(of: a))
        XCTAssertFalse(a.isSuperset(of: b))
        XCTAssertTrue(a.isSuperset(of: c))
        XCTAssertFalse(a.isSuperset(of: d))

        XCTAssertTrue(b.isSuperset(of: a))
        XCTAssertTrue(b.isSuperset(of: b))
        XCTAssertTrue(b.isSuperset(of: c))
        XCTAssertTrue(b.isSuperset(of: d))

        XCTAssertFalse(c.isSuperset(of: a))
        XCTAssertFalse(c.isSuperset(of: b))
        XCTAssertTrue(c.isSuperset(of: c))
        XCTAssertFalse(c.isSuperset(of: d))

        XCTAssertFalse(d.isSuperset(of: a))
        XCTAssertFalse(d.isSuperset(of: b))
        XCTAssertFalse(d.isSuperset(of: c))
        XCTAssertTrue(d.isSuperset(of: d))
    }

    func test_isStrictSupersetOf() {
        let a = SortedBag(0 ..< 30)
        let b = SortedBag((0 ..< 30).repeatEach(2))
        let c = SortedBag(10 ..< 20)
        let d = SortedBag((20 ..< 30).repeatEach(2))

        XCTAssertFalse(a.isStrictSuperset(of: a))
        XCTAssertFalse(a.isStrictSuperset(of: b))
        XCTAssertTrue(a.isStrictSuperset(of: c))
        XCTAssertFalse(a.isStrictSuperset(of: d))

        XCTAssertTrue(b.isStrictSuperset(of: a))
        XCTAssertFalse(b.isStrictSuperset(of: b))
        XCTAssertTrue(b.isStrictSuperset(of: c))
        XCTAssertTrue(b.isStrictSuperset(of: d))

        XCTAssertFalse(c.isStrictSuperset(of: a))
        XCTAssertFalse(c.isStrictSuperset(of: b))
        XCTAssertFalse(c.isStrictSuperset(of: c))
        XCTAssertFalse(c.isStrictSuperset(of: d))

        XCTAssertFalse(d.isStrictSuperset(of: a))
        XCTAssertFalse(d.isStrictSuperset(of: b))
        XCTAssertFalse(d.isStrictSuperset(of: c))
        XCTAssertFalse(d.isStrictSuperset(of: d))
    }

    func test_countElementsInRange() {
        let s = SortedBag(sortedElements: (0 ..< 10_000).repeatEach(2))
        XCTAssertEqual(s.count(elementsIn: -100 ..< -10), 0)
        XCTAssertEqual(s.count(elementsIn: 0 ..< 100), 2 * 100)
        XCTAssertEqual(s.count(elementsIn: 3 ..< 9_999), 2 * 9_996)
        XCTAssertEqual(s.count(elementsIn: 0 ..< 10_000), 2 * 10_000)
        XCTAssertEqual(s.count(elementsIn: -100 ..< 100), 2 * 100)
        XCTAssertEqual(s.count(elementsIn: 9_900 ..< 10_100), 2 * 100)
        XCTAssertEqual(s.count(elementsIn: -100 ..< 20_000), 2 * 10_000)


        XCTAssertEqual(s.count(elementsIn: -100 ... -10), 0)
        XCTAssertEqual(s.count(elementsIn: 0 ... 100), 2 * 101)
        XCTAssertEqual(s.count(elementsIn: 3 ... 9_999), 2 * 9_997)
        XCTAssertEqual(s.count(elementsIn: 0 ... 9_999), 2 * 10_000)
        XCTAssertEqual(s.count(elementsIn: -100 ... 100), 2 * 101)
        XCTAssertEqual(s.count(elementsIn: 9_900 ... 10_100), 2 * 100)
        XCTAssertEqual(s.count(elementsIn: -100 ... 20_000), 2 * 10_000)
    }

    func test_intersectionWithRange() {
        var s = SortedBag(sortedElements: (0 ..< 10_000).repeatEach(2))
        assertEqualElements(s.intersection(elementsIn: -100 ..< -10), [])
        assertEqualElements(s.intersection(elementsIn: 100 ..< 9_900), (100 ..< 9_900).repeatEach(2))
        assertEqualElements(s.intersection(elementsIn: -100 ..< 100), (0 ..< 100).repeatEach(2))
        assertEqualElements(s.intersection(elementsIn: 9_900 ..< 10_100), (9_900 ..< 10_000).repeatEach(2))
        assertEqualElements(s.intersection(elementsIn: 10_100 ..< 10_200), [])

        assertEqualElements(s.intersection(elementsIn: -100 ... -10), [])
        assertEqualElements(s.intersection(elementsIn: 100 ... 9_900), (100 ... 9_900).repeatEach(2))
        assertEqualElements(s.intersection(elementsIn: -100 ... 100), (0 ... 100).repeatEach(2))
        assertEqualElements(s.intersection(elementsIn: 9_900 ... 10_100), (9_900 ..< 10_000).repeatEach(2))
        assertEqualElements(s.intersection(elementsIn: 10_100 ... 10_200), [])

        s.formIntersection(elementsIn: 1_000 ..< 2_000)
        assertEqualElements(s, (1_000 ..< 2_000).repeatEach(2))

        s.formIntersection(elementsIn: 1_100 ... 1_200)
        assertEqualElements(s, (1_100 ... 1_200).repeatEach(2))
    }

    func test_subtractionOfRange() {
        var s = SortedBag(sortedElements: (0 ..< 10_000).repeatEach(2))
        assertEqualElements(s.subtracting(elementsIn: -100 ..< 0), (0 ..< 10_000).repeatEach(2))
        assertEqualElements(s.subtracting(elementsIn: 100 ..< 9_900), (0 ..< 100).repeatEach(2) + (9_900 ..< 10_000).repeatEach(2))
        assertEqualElements(s.subtracting(elementsIn: -100 ..< 100), (100 ..< 10_000).repeatEach(2))
        assertEqualElements(s.subtracting(elementsIn: 9_900 ..< 10_100), (0 ..< 9_900).repeatEach(2))
        assertEqualElements(s.subtracting(elementsIn: 10_000 ..< 10_100), (0 ..< 10_000).repeatEach(2))

        assertEqualElements(s.subtracting(elementsIn: -100 ... -1), (0 ..< 10_000).repeatEach(2))
        assertEqualElements(s.subtracting(elementsIn: 100 ... 9_900), (0 ..< 100).repeatEach(2) + (9_901 ..< 10_000).repeatEach(2))
        assertEqualElements(s.subtracting(elementsIn: -100 ... 100), (101 ..< 10_000).repeatEach(2))
        assertEqualElements(s.subtracting(elementsIn: 9_900 ... 10_100), (0 ..< 9_900).repeatEach(2))
        assertEqualElements(s.subtracting(elementsIn: 10_000 ... 10_100), (0 ..< 10_000).repeatEach(2))

        s.subtract(elementsIn: 1_000 ..< 9_000)
        assertEqualElements(s, (0 ..< 1_000).repeatEach(2) + (9_000 ..< 10_000).repeatEach(2))

        s.subtract(elementsIn: 100 ... 900)
        assertEqualElements(s, (0 ..< 100).repeatEach(2) + (901 ..< 1_000).repeatEach(2) + (9_000 ..< 10_000).repeatEach(2))
    }
    
    func test_shiftStartingAtElement() {
        var a = SortedBag((0 ..< 10).map { 2 * $0 }.repeatEach(2))
        
        a.shift(startingAt: 5, by: 5)
        assertEqualElements(a, [0, 0, 2, 2, 4, 4, 11, 11, 13, 13, 15, 15, 17, 17, 19, 19, 21, 21, 23, 23])
        
        a.shift(startingAt: 19, by: -1)
        assertEqualElements(a, [0, 0, 2, 2, 4, 4, 11, 11, 13, 13, 15, 15, 17, 17, 18, 18, 20, 20, 22, 22])

        a.shift(startingAt: 12, by: -10)
        assertEqualElements(a, [0, 0, 3, 3, 5, 5, 7, 7, 8, 8, 10, 10, 12, 12])

        a.shift(startingAt: 1, by: 0)
        assertEqualElements(a, [0, 0, 3, 3, 5, 5, 7, 7, 8, 8, 10, 10, 12, 12])

        a.shift(startingAt: 15, by: 5)
        assertEqualElements(a, [0, 0, 3, 3, 5, 5, 7, 7, 8, 8, 10, 10, 12, 12])

        a.shift(startingAt: 15, by: -5)
        assertEqualElements(a, [0, 0, 3, 3, 5, 5, 7, 7, 8, 8])
    }

    func test_shiftStartingAtIndex() {
        var a = SortedBag((0 ..< 10).map { 2 * $0 }.repeatEach(2))
        let copy = a
        assertEqualElements(a, [0, 0, 2, 2, 4, 4, 6, 6, 8, 8, 10, 10, 12, 12, 14, 14, 16, 16, 18, 18])

        a.shift(startingAt: a.index(ofOffset: 7), by: 5)
        assertEqualElements(a, [0, 0, 2, 2, 4, 4, 6, 11, 13, 13, 15, 15, 17, 17, 19, 19, 21, 21, 23, 23])

        a.shift(startingAt: a.index(ofOffset: 12), by: -1)
        assertEqualElements(a, [0, 0, 2, 2, 4, 4, 6, 11, 13, 13, 15, 15, 16, 16, 18, 18, 20, 20, 22, 22])

        a.shift(startingAt: a.index(ofOffset: 4), by: -1)
        assertEqualElements(a, [0, 0, 2, 2, 3, 3, 5, 10, 12, 12, 14, 14, 15, 15, 17, 17, 19, 19, 21, 21])

        a.shift(startingAt: a.index(ofOffset: 14), by: -2)
        assertEqualElements(a, [0, 0, 2, 2, 3, 3, 5, 10, 12, 12, 14, 14, 15, 15, 15, 15, 17, 17, 19, 19])

        a.shift(startingAt: 1, by: 0)
        assertEqualElements(a, [0, 0, 2, 2, 3, 3, 5, 10, 12, 12, 14, 14, 15, 15, 15, 15, 17, 17, 19, 19])

        a.shift(startingAt: a.endIndex, by: 5)
        assertEqualElements(a, [0, 0, 2, 2, 3, 3, 5, 10, 12, 12, 14, 14, 15, 15, 15, 15, 17, 17, 19, 19])

        a.shift(startingAt: a.endIndex, by: -5)
        assertEqualElements(a, [0, 0, 2, 2, 3, 3, 5, 10, 12, 12, 14, 14, 15, 15, 15, 15, 17, 17, 19, 19])

        a.shift(startingAt: a.startIndex, by: 5)
        assertEqualElements(a, [5, 5, 7, 7, 8, 8, 10, 15, 17, 17, 19, 19, 20, 20, 20, 20, 22, 22, 24, 24])

        a.shift(startingAt: a.index(ofOffset: 13), by: 5)
        assertEqualElements(a, [5, 5, 7, 7, 8, 8, 10, 15, 17, 17, 19, 19, 20, 25, 25, 25, 27, 27, 29, 29])

        a.shift(startingAt: a.index(ofOffset: 7), by: -5)
        a.shift(startingAt: a.index(ofOffset: 13), by: -5)
        a.shift(startingAt: a.index(ofOffset: 8), by: -2)
        a.shift(startingAt: a.index(ofOffset: 16), by: -2)
        a.shift(startingAt: a.index(ofOffset: 10), by: -2)
        a.shift(startingAt: a.startIndex, by: -5)
        a.shift(startingAt: a.index(ofOffset: 2), by: -2)
        a.shift(startingAt: a.index(ofOffset: 6), by: -2)
        a.shift(startingAt: a.index(ofOffset: 18), by: -2)
        a.shift(startingAt: a.index(ofOffset: 4), by: -1)
        a.shift(startingAt: a.index(ofOffset: 12), by: -1)
        assertEqualElements(a, Array(repeating: 0, count: 20))

        assertEqualElements(copy, [0, 0, 2, 2, 4, 4, 6, 6, 8, 8, 10, 10, 12, 12, 14, 14, 16, 16, 18, 18])
    }
}
