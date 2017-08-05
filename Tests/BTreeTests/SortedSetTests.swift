//
//  SortedSetTests.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-03-05.
//  Copyright © 2016–2017 Károly Lőrentey.
//

import XCTest
import BTree

private final class Test: Comparable, ExpressibleByIntegerLiteral {
    let value: Int

    init(_ value: Int) { self.value = value }
    init(integerLiteral value: Int) { self.value = value }

    static func ==(a: Test, b: Test) -> Bool { return a.value == b.value }
    static func <(a: Test, b: Test) -> Bool { return a.value < b.value }
}

class SortedSetTests: XCTestCase {

    func test_emptySet() {
        let set = SortedSet<Int>()

        XCTAssertTrue(set.isEmpty)
        XCTAssertEqual(set.count, 0)
        XCTAssertEqual(set.startIndex, set.endIndex)
        assertEqualElements(set, [])
    }

    func test_singleElement() {
        let set = SortedSet([42])

        XCTAssertFalse(set.isEmpty)
        XCTAssertEqual(set.count, 1)
        XCTAssertNotEqual(set.startIndex, set.endIndex)
        XCTAssertEqual(set.index(after: set.startIndex), set.endIndex)
        assertEqualElements(set, [42])

        XCTAssertEqual(set[set.startIndex], 42)
        XCTAssertTrue(set.contains(42))
    }

    func test_unsortedElements_uniqueItems() {
        let c = 10_000
        let set = SortedSet((0 ..< c).reversed())

        XCTAssertEqual(set.count, c)
        assertEqualElements(set, 0 ..< c)
    }

    func test_unsortedElements_duplicateItems() {
        let c = 10_000
        let set = SortedSet((0 ..< c).reversed().repeatEach(10))

        XCTAssertEqual(set.count, c)
        assertEqualElements(set, 0 ..< c)
    }

    func test_sortedElements_uniqueItems() {
        let c = 10_000
        let set = SortedSet(sortedElements: 0 ..< c)

        XCTAssertEqual(set.count, c)
        assertEqualElements(set, 0 ..< c)
    }

    func test_sortedElements_duplicateItems() {
        let c = 10_000
        let set = SortedSet(sortedElements: (0 ..< c).repeatEach(10))

        XCTAssertEqual(set.count, c)
        assertEqualElements(set, 0 ..< c)
    }

    func test_arrayLiteral() {
        let set: SortedSet = [1, 4, 6, 4, 2, 3, 6, 5, 5, 1, 1, 4, 3, 3]

        XCTAssertEqual(set.count, 6)
        assertEqualElements(set, 1 ... 6)
    }

    func test_subscriptWithIndexing() {
        let c = 10_000
        let set = SortedSet(0 ..< c)
        var i = 0
        var index = set.startIndex
        while index != set.endIndex {
            XCTAssertEqual(set[index], i)
            XCTAssertEqual(set.distance(from: set.startIndex, to: index), i)
            set.formIndex(after: &index)
            i += 1
        }
        XCTAssertEqual(i, c)
    }

    func test_subscriptWithIndexRange() {
        let c = 500
        let set = SortedSet(0 ..< c)
        var i = 0
        var j = c
        var start = set.startIndex
        var end = set.endIndex
        while i <= j {
            assertEqualElements(set[start ..< end], i ..< j)
            i += 1
            set.formIndex(after: &start)
            j -= 1
            set.formIndex(before: &end)
        }
    }

    func test_makeIterator() {
        let c = 10_000
        let set = SortedSet(0 ..< c)
        assertEqualElements(IteratorSequence(set.makeIterator()), 0 ..< c)
    }

    func test_subscriptByOffsets() {
        let c = 10_000
        let set = SortedSet(0 ..< c)
        for i in 0 ..< c {
            XCTAssertEqual(set[i], i)
        }
    }

    func test_subscriptByOffsetRange() {
        let c = 100
        let set = SortedSet(0 ..< c)
        for i in 0 ..< c {
            for j in i ..< c {
                assertEqualElements(set[i ..< j], i ..< j)
            }
        }
    }

    func test_indexing() {
        let s = SortedSet(sortedElements: (0..<10))
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
        let s = SortedSet(sortedElements: (0 ..< 10).map { 2 * $0 })
        for m in 0 ..< 20 {
            if m & 1 == 0 {
                XCTAssertEqual(s.offset(of: m), m / 2)
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
        let set = SortedSet(0 ..< c)
        var i = 0
        set.forEach { n in
            XCTAssertEqual(n, i)
            i += 1
        }
    }

    func test_map() {
        let c = 10_000
        let set = SortedSet(0 ..< c)
        var i = 0
        let r = set.map { (n: Int) -> Int in
            XCTAssertEqual(n, i)
            i += 1
            return n
        }
        assertEqualElements(r, 0 ..< c)
    }

    func test_flatMap_Sequence() {
        let c = 1000
        let set = SortedSet(0 ..< c)
        let r = set.flatMap { [$0, $0, $0] }
        assertEqualElements(r, (0 ..< c).repeatEach(3))
    }

    func test_flatMap_Optional() {
        let c = 1000
        let set = SortedSet(0 ..< c)
        let r = set.flatMap { $0 & 1 == 0 ? $0 / 2 : nil }
        assertEqualElements(r, 0 ..< 500)
    }

    func test_filter() {
        let c = 1000
        let set = SortedSet(0 ..< c)
        let r = set.filter { $0 & 1 == 0 }
        assertEqualElements(r, (0 ..< 500).map { 2 * $0 })
    }

    func test_reduce() {
        let c = 1000
        let set = SortedSet(0 ..< c)
        let r = set.reduce(0) { $0 + $1 }
        XCTAssertEqual(r, (c - 1) * c / 2)
    }

    func test_boundaries() {
        let c = 1000
        let set = SortedSet(0 ..< c)
        XCTAssertEqual(set.first, 0)
        XCTAssertEqual(set.last, c - 1)
        XCTAssertEqual(set.min(), 0)
        XCTAssertEqual(set.max(), c - 1)
    }

    func test_drop() {
        let c = 500
        let set = SortedSet(0 ..< c)
        assertEqualElements(set.dropFirst(), 1 ..< c)
        assertEqualElements(set.dropLast(), 0 ..< c - 1)
        for i in 0 ..< c {
            assertEqualElements(set.dropFirst(i), i ..< c)
            assertEqualElements(set.dropLast(i), 0 ..< c - i)
        }
    }

    func test_prefix() {
        let c = 200
        let set = SortedSet(0 ..< c)
        var index = set.startIndex
        for i in 0 ..< c {
            assertEqualElements(set.prefix(i), 0 ..< i)
            assertEqualElements(set.prefix(through: index), 0 ... i)
            assertEqualElements(set.prefix(through: i), 0 ... i)
            assertEqualElements(set.prefix(upTo: index), 0 ..< i)
            assertEqualElements(set.prefix(upTo: i), 0 ..< i)
            set.formIndex(after: &index)
        }
        XCTAssertEqual(index, set.endIndex)
        assertEqualElements(set.prefix(c), 0 ..< c)
        assertEqualElements(set.prefix(through: c), 0 ..< c)
        assertEqualElements(set.prefix(upTo: set.endIndex), 0 ..< c)
        assertEqualElements(set.prefix(upTo: c), 0 ..< c)

        assertEqualElements(set.prefix(upTo: 2 * c), 0 ..< c)

    }

    func test_suffix() {
        let c = 200
        let set = SortedSet(0 ..< c)
        var index = set.startIndex
        for i in 0 ..< c {
            assertEqualElements(set.suffix(i), c - i ..< c)
            assertEqualElements(set.suffix(from: index), i ..< c)
            assertEqualElements(set.suffix(from: i), i ..< c)
            set.formIndex(after: &index)
        }
        XCTAssertEqual(index, set.endIndex)
        assertEqualElements(set.suffix(c), 0 ..< c)
        assertEqualElements(set.suffix(from: set.endIndex), [])
        assertEqualElements(set.suffix(from: c), [])

        assertEqualElements(set.suffix(from: 2 * c), [])
    }

    func test_description() {
        let set = SortedSet(0 ..< 5)
        XCTAssertEqual(String(describing: set), "[0, 1, 2, 3, 4]")
        XCTAssertEqual(String(reflecting: set), "SortedSet([0, 1, 2, 3, 4])")
    }

    func test_contains() {
        let set = SortedSet((0 ..< 500).map { 2 * $0 })
        for i in 0 ..< 1000 {
            XCTAssertEqual(set.contains(i), i & 1 == 0)
        }
    }

    func test_indexOf() {
        let c = 100
        let set = SortedSet((0 ..< c).map { 2 * $0 })
        for i in 0 ..< 2 * c {
            let index = set.index(of: i)
            if i & 1 == 0 {
                XCTAssertEqual(index, set.index(set.startIndex, offsetBy: i / 2))
                XCTAssertEqual(set[index!], i)
            }
            else {
                XCTAssertNil(index)
            }
        }
    }

    func test_indexOfFirstElementAfter() {
        let c = 100
        let set = SortedSet((0 ..< c).map { 2 * $0 })

        for i in 0 ..< 2 * c {
            let index = set.indexOfFirstElement(after: i)
            if i < 2 * (c - 1) {
                XCTAssertNotNil(index)
                guard let index = index else { continue }
                let element = set[index]
                if i & 1 == 0 {
                    XCTAssertEqual(element, i + 2)
                }
                else {
                    XCTAssertEqual(element, i + 1)
                }
            }
            else {
                XCTAssertNil(index)
            }
        }
    }

    func test_indexOfFirstElementNotBefore() {
        let c = 100
        let set = SortedSet((0 ..< c).map { 2 * $0 })

        for i in 0 ..< 2 * c {
            let index = set.indexOfFirstElement(notBefore: i)
            if i < 2 * c - 1 {
                XCTAssertNotNil(index)
                guard let index = index else { continue }
                let element = set[index]
                if i & 1 == 0 {
                    XCTAssertEqual(element, i)
                }
                else {
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
        let set = SortedSet((0 ..< c).map { 2 * $0 })

        for i in -2 ..< 2 * c {
            let index = set.indexOfLastElement(before: i)
            if i > 0 {
                XCTAssertNotNil(index)
                guard let index = index else { continue }
                let element = set[index]
                if i & 1 == 0 {
                    XCTAssertEqual(element, i - 2)
                }
                else {
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
        let set = SortedSet((0 ..< c).map { 2 * $0 })

        for i in -2 ..< 2 * c {
            let index = set.indexOfLastElement(notAfter: i)
            if i >= 0 {
                XCTAssertNotNil(index)
                guard let index = index else { continue }
                let element = set[index]
                if i & 1 == 0 {
                    XCTAssertEqual(element, i)
                }
                else {
                    XCTAssertEqual(element, i - 1)
                }
            }
            else {
                XCTAssertNil(index)
            }
        }
    }

    func test_insert() {
        var set = SortedSet<Test>()
        let one1 = Test(1)
        let i1 = set.insert(one1)
        XCTAssertTrue(i1.inserted)
        XCTAssertTrue(i1.memberAfterInsert === one1)

        let one2 = Test(1)
        let i2 = set.insert(one2)
        XCTAssertFalse(i2.inserted)
        XCTAssertTrue(i2.memberAfterInsert === one1)

        XCTAssertTrue(set.first === one1)

        let four = Test(4)
        let i3 = set.insert(four)
        XCTAssertTrue(i3.inserted)
        XCTAssertTrue(i3.memberAfterInsert === four)

        let two = Test(2)
        let i4 = set.insert(two)
        XCTAssertTrue(i4.inserted)
        XCTAssertTrue(i4.memberAfterInsert === two)

        let three = Test(3)
        let i5 = set.insert(three)
        XCTAssertTrue(i5.inserted)
        XCTAssertTrue(i5.memberAfterInsert === three)

        assertEqualElements(set, (1 ... 4).map { Test($0) })

        for i in 5 ... 100 {
            let element = Test(i)
            let res = set.insert(element)
            XCTAssertTrue(res.inserted)
            XCTAssertTrue(res.memberAfterInsert === element)
            XCTAssertTrue(set.last === element)
        }
        assertEqualElements(set, (1 ... 100).map { Test($0) })
    }

    func test_update() {
        var set = SortedSet<Test>()
        let one1 = Test(1)
        XCTAssertNil(set.update(with: one1))

        let one2 = Test(1)
        XCTAssertTrue(set.update(with: one2) === one1)

        XCTAssertTrue(set.first === one2)

        let four = Test(4)
        XCTAssertNil(set.update(with: four))
        XCTAssertTrue(set[1] === four)

        let two = Test(2)
        XCTAssertNil(set.update(with: two))
        XCTAssertTrue(set[1] === two)

        let three = Test(3)
        XCTAssertNil(set.update(with: three))
        XCTAssertTrue(set[0] === one2)
        XCTAssertTrue(set[1] === two)
        XCTAssertTrue(set[2] === three)
        XCTAssertTrue(set[3] === four)

        assertEqualElements(set, (1 ... 4).map { Test($0) })

        for i in 5 ... 100 {
            let element = Test(i)
            XCTAssertNil(set.update(with: element))
            XCTAssertTrue(set.last === element)
        }
        assertEqualElements(set, (1 ... 100).map { Test($0) })
    }


    func test_remove() {
        let c = 500
        var set = SortedSet((0 ..< c).map { 2 * $0 })
        for i in 0 ..< 2 * c {
            if i & 1 == 0 {
                XCTAssertEqual(set.remove(i), i)
            }
            else {
                XCTAssertNil(set.remove(i))
            }
        }
        XCTAssertTrue(set.isEmpty)
    }

    func test_removeAt() {
        let c = 500
        var set = SortedSet(0 ..< c)
        for i in 0 ..< c {
            XCTAssertEqual(set.remove(at: set.startIndex), i)
        }
    }

    func test_removeAtOffset() {
        let c = 100
        var set = SortedSet(0 ..< c)
        for offset in 0 ..< c / 2 {
            XCTAssertEqual(set.remove(atOffset: offset), 2 * offset)
        }
        assertEqualElements(set, (0 ..< c / 2).map { 2 * $0 + 1 })
    }

    func test_removeFamily() {
        var set = SortedSet(0 ..< 20)

        XCTAssertEqual(set.removeFirst(), 0)
        assertEqualElements(set, 1 ..< 20)

        set.removeFirst(5)
        assertEqualElements(set, 6 ..< 20)

        XCTAssertEqual(set.popFirst(), 6)
        assertEqualElements(set, 7 ..< 20)

        XCTAssertEqual(set.removeLast(), 19)
        assertEqualElements(set, 7 ..< 19)

        set.removeLast(5)
        assertEqualElements(set, 7 ..< 14)

        XCTAssertEqual(set.popLast(), 13)
        assertEqualElements(set, 7 ..< 13)

        set.removeAll()
        assertEqualElements(set, [])
    }

    func test_sorted() {
        let set = SortedSet(0 ..< 10)
        assertEqualElements(set.sorted(), set)
    }

    func test_setOperations() {
        let a = SortedSet(0 ..< 30)
        let b = SortedSet(20 ..< 50)

        assertEqualElements(a.union(b), 0 ..< 50)
        assertEqualElements(a.intersection(b), 20 ..< 30)
        assertEqualElements(a.subtracting(b), 0 ..< 20)
        assertEqualElements(a.symmetricDifference(b), Array(0 ..< 20) + Array(30 ..< 50))

        var x = a
        x.formUnion(b)
        assertEqualElements(x, 0 ..< 50)

        x = a
        x.formIntersection(b)
        assertEqualElements(x, 20 ..< 30)

        x = a
        x.subtract(b)
        assertEqualElements(x, 0 ..< 20)

        x = a
        x.formSymmetricDifference(b)
        assertEqualElements(x, Array(0 ..< 20) + Array(30 ..< 50))
    }

    func test_setComparisons() {
        let a = SortedSet(0 ..< 30)
        let b = SortedSet(10 ..< 20)
        let c = SortedSet(20 ..< 30)

        XCTAssertTrue(a.elementsEqual(a))
        XCTAssertTrue(a.elementsEqual(SortedSet(0 ..< 30)))
        XCTAssertFalse(a.elementsEqual(b))
        XCTAssertFalse(a.elementsEqual(c))

        XCTAssertTrue(a == a)
        XCTAssertTrue(a == SortedSet(0 ..< 30))
        XCTAssertFalse(a == b)
        XCTAssertFalse(a == c)

        XCTAssertFalse(a.isDisjoint(with:b))
        XCTAssertTrue(b.isDisjoint(with:c))

        XCTAssertTrue(b.isSubset(of: a))
        XCTAssertTrue(c.isSubset(of: a))
        XCTAssertFalse(c.isSubset(of: b))

        XCTAssertTrue(b.isStrictSubset(of: a))
        XCTAssertTrue(c.isStrictSubset(of: a))
        XCTAssertFalse(c.isStrictSubset(of: b))

        XCTAssertTrue(a.isSuperset(of: b))
        XCTAssertTrue(a.isSuperset(of: c))
        XCTAssertFalse(b.isSuperset(of: c))

        XCTAssertTrue(a.isStrictSuperset(of: b))
        XCTAssertTrue(a.isStrictSuperset(of: c))
        XCTAssertFalse(b.isStrictSuperset(of: c))
    }

    func test_countElementsInRange() {
        let s = SortedSet(sortedElements: 0 ..< 10_000)
        XCTAssertEqual(s.count(elementsIn: -100 ..< -10), 0)
        XCTAssertEqual(s.count(elementsIn: 0 ..< 100), 100)
        XCTAssertEqual(s.count(elementsIn: 3 ..< 9_999), 9_996)
        XCTAssertEqual(s.count(elementsIn: 0 ..< 10_000), 10_000)
        XCTAssertEqual(s.count(elementsIn: -100 ..< 100), 100)
        XCTAssertEqual(s.count(elementsIn: 9_900 ..< 10_100), 100)
        XCTAssertEqual(s.count(elementsIn: -100 ..< 20_000), 10_000)


        XCTAssertEqual(s.count(elementsIn: -100 ... -10), 0)
        XCTAssertEqual(s.count(elementsIn: 0 ... 100), 101)
        XCTAssertEqual(s.count(elementsIn: 3 ... 9_999), 9_997)
        XCTAssertEqual(s.count(elementsIn: 0 ... 9_999), 10_000)
        XCTAssertEqual(s.count(elementsIn: -100 ... 100), 101)
        XCTAssertEqual(s.count(elementsIn: 9_900 ... 10_100), 100)
        XCTAssertEqual(s.count(elementsIn: -100 ... 20_000), 10_000)
    }

    func test_intersectionWithRange() {
        var s = SortedSet(sortedElements: 0 ..< 10_000)
        assertEqualElements(s.intersection(elementsIn: -100 ..< -10), [])
        assertEqualElements(s.intersection(elementsIn: 100 ..< 9_900), 100 ..< 9_900)
        assertEqualElements(s.intersection(elementsIn: -100 ..< 100), 0 ..< 100)
        assertEqualElements(s.intersection(elementsIn: 9_900 ..< 10_100), 9_900 ..< 10_000)
        assertEqualElements(s.intersection(elementsIn: 10_100 ..< 10_200), [])

        assertEqualElements(s.intersection(elementsIn: -100 ... -10), [])
        assertEqualElements(s.intersection(elementsIn: 100 ... 9_900), 100 ... 9_900)
        assertEqualElements(s.intersection(elementsIn: -100 ... 100), 0 ... 100)
        assertEqualElements(s.intersection(elementsIn: 9_900 ... 10_100), 9_900 ..< 10_000)
        assertEqualElements(s.intersection(elementsIn: 10_100 ... 10_200), [])

        s.formIntersection(elementsIn: 1_000 ..< 2_000)
        assertEqualElements(s, 1_000 ..< 2_000)

        s.formIntersection(elementsIn: 1_100 ... 1_200)
        assertEqualElements(s, 1_100 ... 1_200)
    }

    func test_subtractionOfRange() {
        var s = SortedSet(sortedElements: 0 ..< 10_000)
        assertEqualElements(s.subtracting(elementsIn: -100 ..< 0), 0 ..< 10_000)
        assertEqualElements(s.subtracting(elementsIn: 100 ..< 9_900), Array(0 ..< 100) + Array(9_900 ..< 10_000))
        assertEqualElements(s.subtracting(elementsIn: -100 ..< 100), 100 ..< 10_000)
        assertEqualElements(s.subtracting(elementsIn: 9_900 ..< 10_100), 0 ..< 9_900)
        assertEqualElements(s.subtracting(elementsIn: 10_000 ..< 10_100), 0 ..< 10_000)

        assertEqualElements(s.subtracting(elementsIn: -100 ... -1), 0 ..< 10_000)
        assertEqualElements(s.subtracting(elementsIn: 100 ... 9_900), Array(0 ..< 100) + Array(9_901 ..< 10_000))
        assertEqualElements(s.subtracting(elementsIn: -100 ... 100), 101 ..< 10_000)
        assertEqualElements(s.subtracting(elementsIn: 9_900 ... 10_100), 0 ..< 9_900)
        assertEqualElements(s.subtracting(elementsIn: 10_000 ... 10_100), 0 ..< 10_000)

        s.subtract(elementsIn: 1_000 ..< 9_000)
        assertEqualElements(s, Array(0 ..< 1_000) + Array(9_000 ..< 10_000))

        s.subtract(elementsIn: 100 ... 900)
        assertEqualElements(s, Array(0 ..< 100) + Array(901 ..< 1_000) + Array(9_000 ..< 10_000))
    }

    func test_shift() {
        var a = SortedSet((0 ..< 10).map { 2 * $0 })

        a.shift(startingAt: 5, by: 5)
        assertEqualElements(a, [0, 2, 4, 11, 13, 15, 17, 19, 21, 23])

        a.shift(startingAt: 19, by: -1)
        assertEqualElements(a, [0, 2, 4, 11, 13, 15, 17, 18, 20, 22])

        a.shift(startingAt: 12, by: -10)
        assertEqualElements(a, [0, 3, 5, 7, 8, 10, 12])

        a.shift(startingAt: 1, by: 0)
        assertEqualElements(a, [0, 3, 5, 7, 8, 10, 12])

        a.shift(startingAt: 15, by: 5)
        assertEqualElements(a, [0, 3, 5, 7, 8, 10, 12])

        a.shift(startingAt: 15, by: -5)
        assertEqualElements(a, [0, 3, 5, 7, 8])
    }
}
