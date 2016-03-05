//
//  OrderedSetTests.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-03-05.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import BTree

class OrderedSetTests: XCTestCase {

    func test_emptySet() {
        let set = OrderedSet<Int>()

        XCTAssertTrue(set.isEmpty)
        XCTAssertEqual(set.count, 0)
        XCTAssertEqual(set.startIndex, set.endIndex)
        XCTAssertElementsEqual(set, [])
    }

    func test_singleElement() {
        let set = OrderedSet([42])

        XCTAssertFalse(set.isEmpty)
        XCTAssertEqual(set.count, 1)
        XCTAssertNotEqual(set.startIndex, set.endIndex)
        XCTAssertEqual(set.startIndex.successor(), set.endIndex)
        XCTAssertElementsEqual(set, [42])

        XCTAssertEqual(set[set.startIndex], 42)
        XCTAssertTrue(set.contains(42))
    }

    func test_unsortedElements_uniqueItems() {
        let c = 10_000
        let set = OrderedSet((0 ..< c).reverse())

        XCTAssertEqual(set.count, c)
        XCTAssertElementsEqual(set, 0 ..< c)
    }

    func test_unsortedElements_duplicateItems() {
        let c = 10_000
        let set = OrderedSet((0 ..< c).reverse().repeatEach(10))

        XCTAssertEqual(set.count, c)
        XCTAssertElementsEqual(set, 0 ..< c)
    }

    func test_sortedElements_uniqueItems() {
        let c = 10_000
        let set = OrderedSet(sortedElements: 0 ..< c)

        XCTAssertEqual(set.count, c)
        XCTAssertElementsEqual(set, 0 ..< c)
    }

    func test_sortedElements_duplicateItems() {
        let c = 10_000
        let set = OrderedSet(sortedElements: (0 ..< c).repeatEach(10))

        XCTAssertEqual(set.count, c)
        XCTAssertElementsEqual(set, 0 ..< c)
    }

    func test_arrayLiteral() {
        let set: OrderedSet = [1, 4, 6, 4, 2, 3, 6, 5, 5, 1, 1, 4, 3, 3]

        XCTAssertEqual(set.count, 6)
        XCTAssertElementsEqual(set, 1 ... 6)
    }

    func test_subscriptWithIndexing() {
        let c = 10_000
        let set = OrderedSet(0 ..< c)
        var i = 0
        var index = set.startIndex
        while index != set.endIndex {
            XCTAssertEqual(set[index], i)
            XCTAssertEqual(set.startIndex.distanceTo(index), i)
            index = index.successor()
            i += 1
        }
        XCTAssertEqual(i, c)
    }

    func test_subscriptWithIndexRange() {
        let c = 500
        let set = OrderedSet(0 ..< c)
        var i = 0
        var j = c
        var start = set.startIndex
        var end = set.endIndex
        while i <= j {
            XCTAssertElementsEqual(set[start ..< end], i ..< j)
            i += 1
            start = start.successor()
            j -= 1
            end = end.predecessor()
        }
    }

    func test_generate() {
        let c = 10_000
        let set = OrderedSet(0 ..< c)
        XCTAssertElementsEqual(GeneratorSequence(set.generate()), 0 ..< c)
    }

    func test_forEach() {
        let c = 10_000
        let set = OrderedSet(0 ..< c)
        var i = 0
        set.forEach { n in
            XCTAssertEqual(n, i)
            i += 1
        }
    }

    func test_map() {
        let c = 10_000
        let set = OrderedSet(0 ..< c)
        var i = 0
        let r = set.map { (n: Int) -> Int in
            XCTAssertEqual(n, i)
            i += 1
            return n
        }
        XCTAssertElementsEqual(r, 0 ..< c)
    }

    func test_flatMap_Sequence() {
        let c = 1000
        let set = OrderedSet(0 ..< c)
        let r = set.flatMap { [$0, $0, $0] }
        XCTAssertElementsEqual(r, (0 ..< c).repeatEach(3))
    }

    func test_flatMap_Optional() {
        let c = 1000
        let set = OrderedSet(0 ..< c)
        let r = set.flatMap { $0 & 1 == 0 ? $0 / 2 : nil }
        XCTAssertElementsEqual(r, 0 ..< 500)
    }

    func test_filter() {
        let c = 1000
        let set = OrderedSet(0 ..< c)
        let r = set.filter { $0 & 1 == 0 }
        XCTAssertElementsEqual(r, (0 ..< 500).map { 2 * $0 })
    }

    func test_reduce() {
        let c = 1000
        let set = OrderedSet(0 ..< c)
        let r = set.reduce(0) { $0 + $1 }
        XCTAssertEqual(r, (c - 1) * c / 2)
    }

    func test_boundaries() {
        let c = 1000
        let set = OrderedSet(0 ..< c)
        XCTAssertEqual(set.first, 0)
        XCTAssertEqual(set.last, c - 1)
        XCTAssertEqual(set.minElement(), 0)
        XCTAssertEqual(set.maxElement(), c - 1)
    }

    func test_drop() {
        let c = 500
        let set = OrderedSet(0 ..< c)
        XCTAssertElementsEqual(set.dropFirst(), 1 ..< c)
        XCTAssertElementsEqual(set.dropLast(), 0 ..< c - 1)
        for i in 0 ..< c {
            XCTAssertElementsEqual(set.dropFirst(i), i ..< c)
            XCTAssertElementsEqual(set.dropLast(i), 0 ..< c - i)
        }
    }

    func test_prefix() {
        let c = 200
        let set = OrderedSet(0 ..< c)
        var index = set.startIndex
        for i in 0 ..< c {
            XCTAssertElementsEqual(set.prefix(i), 0 ..< i)
            XCTAssertElementsEqual(set.prefixThrough(index), 0 ... i)
            XCTAssertElementsEqual(set.prefixThrough(i), 0 ... i)
            XCTAssertElementsEqual(set.prefixUpTo(index), 0 ..< i)
            XCTAssertElementsEqual(set.prefixUpTo(i), 0 ..< i)
            index = index.successor()
        }
        XCTAssertEqual(index, set.endIndex)
        XCTAssertElementsEqual(set.prefix(c), 0 ..< c)
        XCTAssertElementsEqual(set.prefixThrough(c), 0 ..< c)
        XCTAssertElementsEqual(set.prefixUpTo(set.endIndex), 0 ..< c)
        XCTAssertElementsEqual(set.prefixUpTo(c), 0 ..< c)

        XCTAssertElementsEqual(set.prefixUpTo(2 * c), 0 ..< c)

    }

    func test_suffix() {
        let c = 200
        let set = OrderedSet(0 ..< c)
        var index = set.startIndex
        for i in 0 ..< c {
            XCTAssertElementsEqual(set.suffix(i), c - i ..< c)
            XCTAssertElementsEqual(set.suffixFrom(index), i ..< c)
            XCTAssertElementsEqual(set.suffixFrom(i), i ..< c)
            index = index.successor()
        }
        XCTAssertEqual(index, set.endIndex)
        XCTAssertElementsEqual(set.suffix(c), 0 ..< c)
        XCTAssertElementsEqual(set.suffixFrom(set.endIndex), [])
        XCTAssertElementsEqual(set.suffixFrom(c), [])

        XCTAssertElementsEqual(set.suffixFrom(2 * c), [])
    }

    func test_description() {
        let set = OrderedSet(0 ..< 5)
        XCTAssertEqual(String(set), "[0, 1, 2, 3, 4]")
        XCTAssertEqual(String(reflecting: set), "OrderedSet([0, 1, 2, 3, 4])")
    }

    func test_contains() {
        let set = OrderedSet((0 ..< 500).map { 2 * $0 })
        for i in 0 ..< 1000 {
            XCTAssertEqual(set.contains(i), i & 1 == 0)
        }
    }

    func test_indexOf() {
        let c = 100
        let set = OrderedSet((0 ..< c).map { 2 * $0 })
        for i in 0 ..< 2 * c {
            let index = set.indexOf(i)
            if i & 1 == 0 {
                XCTAssertEqual(index, set.startIndex.advancedBy(i / 2))
                XCTAssertEqual(set[index!], i)
            }
            else {
                XCTAssertNil(index)
            }
        }
    }

    func test_insert() {
        var set = OrderedSet<Int>()
        set.insert(1)
        set.insert(1)
        set.insert(4)
        set.insert(2)
        set.insert(3)
        XCTAssertElementsEqual(set, 1 ... 4)

        for i in 5 ... 100 {
            set.insert(i)
        }
        XCTAssertElementsEqual(set, 1 ... 100)
    }

    func test_remove() {
        let c = 500
        var set = OrderedSet((0 ..< c).map { 2 * $0 })
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

    func test_removeAtIndex() {
        let c = 500
        var set = OrderedSet(0 ..< c)
        for i in 0 ..< c {
            XCTAssertEqual(set.removeAtIndex(set.startIndex), i)
        }
    }

    func test_removeFamily() {
        var set = OrderedSet(0 ..< 20)

        XCTAssertEqual(set.removeFirst(), 0)
        XCTAssertElementsEqual(set, 1 ..< 20)

        set.removeFirst(5)
        XCTAssertElementsEqual(set, 6 ..< 20)

        XCTAssertEqual(set.popFirst(), 6)
        XCTAssertElementsEqual(set, 7 ..< 20)

        XCTAssertEqual(set.removeLast(), 19)
        XCTAssertElementsEqual(set, 7 ..< 19)

        set.removeLast(5)
        XCTAssertElementsEqual(set, 7 ..< 14)

        XCTAssertEqual(set.popLast(), 13)
        XCTAssertElementsEqual(set, 7 ..< 13)

        set.removeAll()
        XCTAssertElementsEqual(set, [])
    }

    func test_sort() {
        var set = OrderedSet(0 ..< 10)
        XCTAssertElementsEqual(set.sort(), set)
    }

    func test_setOperations() {
        let a = OrderedSet(0 ..< 30)
        let b = OrderedSet(20 ..< 50)

        XCTAssertElementsEqual(a.union(b), 0 ..< 50)
        XCTAssertElementsEqual(a.intersect(b), 20 ..< 30)
        XCTAssertElementsEqual(a.subtract(b), 0 ..< 20)
        XCTAssertElementsEqual(a.exclusiveOr(b), Array(0 ..< 20) + Array(30 ..< 50))

        var x = a
        x.unionInPlace(b)
        XCTAssertElementsEqual(x, 0 ..< 50)

        x = a
        x.intersectInPlace(b)
        XCTAssertElementsEqual(x, 20 ..< 30)

        x = a
        x.subtractInPlace(b)
        XCTAssertElementsEqual(x, 0 ..< 20)

        x = a
        x.exclusiveOrInPlace(b)
        XCTAssertElementsEqual(x, Array(0 ..< 20) + Array(30 ..< 50))
    }

    func test_setComparisons() {
        let a = OrderedSet(0 ..< 30)
        let b = OrderedSet(10 ..< 20)
        let c = OrderedSet(20 ..< 30)

        XCTAssertFalse(a.isDisjointWith(b))
        XCTAssertTrue(b.isDisjointWith(c))

        XCTAssertTrue(b.isSubsetOf(a))
        XCTAssertTrue(c.isSubsetOf(a))
        XCTAssertFalse(c.isSubsetOf(b))

        XCTAssertTrue(b.isStrictSubsetOf(a))
        XCTAssertTrue(c.isStrictSubsetOf(a))
        XCTAssertFalse(c.isStrictSubsetOf(b))

        XCTAssertTrue(a.isSupersetOf(b))
        XCTAssertTrue(a.isSupersetOf(c))
        XCTAssertFalse(b.isSupersetOf(c))

        XCTAssertTrue(a.isStrictSupersetOf(b))
        XCTAssertTrue(a.isStrictSupersetOf(c))
        XCTAssertFalse(b.isStrictSupersetOf(c))
    }
}
