//
//  ListTests.swift
//  BTree
//
//  Created by Károly Lőrentey on 2015-12-15.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
@testable import BTree

extension List {
    func assertValid() {
        tree.root.assertValid()
    }
}

class ListTests: XCTestCase {

    func testEmptyKey() {
        let a = EmptyKey()
        let b = EmptyKey()

        XCTAssertEqual(a, b)
        XCTAssertFalse(a < b)
        XCTAssertFalse(b < a)
    }

    func testEmptyList() {
        let list = List<Int>()
        XCTAssertTrue(list.isEmpty)
        XCTAssertEqual(list.count, 0)
        XCTAssertEqual(list.startIndex, 0)
        XCTAssertEqual(list.endIndex, 0)
        assertEqualElements(list, [])
    }

    func testSimpleList() {
        let list: List<Int> = [0, 1, 2, 3, 4]
        XCTAssertFalse(list.isEmpty)
        XCTAssertEqual(list.count, 5)
        XCTAssertEqual(list.startIndex, 0)
        XCTAssertEqual(list.endIndex, 5)
        for i in 0 ..< 5 {
            XCTAssertEqual(list[i], i)
        }
        assertEqualElements(IteratorSequence(list.makeIterator()), 0..<5)
        assertEqualElements(list, 0..<5)
    }

    func testSubscriptSetter() {
        var list: List<Int> = [0, 1, 2, 3, 4]
        for i in 0 ..< 5 {
            list[i] = 2 * i
        }
        assertEqualElements(list, [0, 2, 4, 6, 8])
    }

    func testGettingSublists() {
        let count = 20
        let list = List(0..<count)
        for i in 0 ... count {
            for j in i ... count {
                assertEqualElements(list[i ..< j], i ..< j)
            }
        }
    }

    func testSettingSublists() {
        var list = List(0..<10)

        list[2..<5] = List(8..<11)
        assertEqualElements(list, [0, 1, 8, 9, 10, 5, 6, 7, 8, 9])

        list[0..<3] = List()
        assertEqualElements(list, [9, 10, 5, 6, 7, 8, 9])

        list[4..<7] = List(1 ..< 6)
        assertEqualElements(list, [9, 10, 5, 6, 1, 2, 3, 4, 5])

        list[0..<9] = List()
        assertEqualElements(list, 0 ..< 0)
    }

    func testIndexing() {
        let list = List<Int>(0 ..< 100)
        // Array-like indexing
        XCTAssertEqual(list.index(after: 50), 51)
        XCTAssertEqual(list.index(before: 50), 49)
        XCTAssertEqual(list.index(50, offsetBy: 10), 60)
        XCTAssertEqual(list.index(50, offsetBy: -10), 40)
        XCTAssertEqual(list.index(50, offsetBy: 10, limitedBy: 70), 60)
        XCTAssertEqual(list.index(50, offsetBy: 10, limitedBy: 60), 60)
        XCTAssertEqual(list.index(50, offsetBy: 10, limitedBy: 55), nil)
        XCTAssertEqual(list.index(50, offsetBy: -10, limitedBy: 30), 40)
        XCTAssertEqual(list.index(50, offsetBy: -10, limitedBy: 40), 40)
        XCTAssertEqual(list.index(50, offsetBy: -10, limitedBy: 45), nil)

        var index = 50
        list.formIndex(after: &index)
        XCTAssertEqual(index, 51)
        list.formIndex(before: &index)
        XCTAssertEqual(index, 50)
        list.formIndex(&index, offsetBy: 10)
        XCTAssertEqual(index, 60)
        list.formIndex(&index, offsetBy: -10)
        XCTAssertEqual(index, 50)

        index = 50
        XCTAssertTrue(list.formIndex(&index, offsetBy: 10, limitedBy: 70))
        XCTAssertEqual(index, 60)
        XCTAssertTrue(list.formIndex(&index, offsetBy: 10, limitedBy: 70))
        XCTAssertEqual(index, 70)
        XCTAssertFalse(list.formIndex(&index, offsetBy: 20, limitedBy: 80))
        XCTAssertEqual(index, 80)

        index = 50
        XCTAssertTrue(list.formIndex(&index, offsetBy: -10, limitedBy: 30))
        XCTAssertEqual(index, 40)
        XCTAssertTrue(list.formIndex(&index, offsetBy: -10, limitedBy: 30))
        XCTAssertEqual(index, 30)
        XCTAssertFalse(list.formIndex(&index, offsetBy: -20, limitedBy: 20))
        XCTAssertEqual(index, 20)

        XCTAssertEqual(list.distance(from: 5, to: 19), 14)
    }

    func testFirstAndLast() {
        let empty = List<Int>()
        let list = List<Int>(0 ..< 10)

        XCTAssertNil(empty.first)
        XCTAssertNil(empty.last)
        XCTAssertEqual(list.first, 0)
        XCTAssertEqual(list.last, 9)
    }

    func testForEach() {
        let list: List<Int> = [0, 1, 2, 3, 4]
        var i = 0
        list.forEach { n in
            XCTAssertEqual(n, i)
            i += 1
        }
        XCTAssertEqual(i, 5)
    }

    func testMap() {
        let list: List<Int> = [0, 1, 2, 3, 4]
        let r = list.map { 2 * $0 }
        assertEqualElements(r, [0, 2, 4, 6, 8])
    }

    func testFlatMapSequence() {
        let list = List<Int>(0..<100)
        let r = list.flatMap { n -> [Int] in
            if n & 1 == 1 {
                return []
            }
            else {
                return [n, n]
            }
        }
        assertEqualElements(r, (0..<100).map { $0 & ~1 })
    }

    func testFlatMapOptional() {
        let list = List<Int>(0..<100)
        let r = list.flatMap { n -> Int? in
            return n & 1 == 0 ? n / 2 : nil
        }
        assertEqualElements(r, 0..<50)
    }

    func testReduce() {
        let list = List<Int>(0..<100)
        let sum = list.reduce(0) { $0 + $1 }
        XCTAssertEqual(sum, 100 * 99 / 2)
    }

    func testFilter() {
        let list = List<Int>(0..<100)
        let r = list.filter { $0 & 1 == 0 }
        assertEqualElements(r, (0..<50).map { 2 * $0 })
    }

    func testElementsEqualWithEquivalence() {
        let list1 = List<Int>(0..<100)
        let list2 = List<Int>((0..<100).map { $0 * 8 })
        let list3 = List<Int>((0..<100).map { $0 * 3 })

        // Return true iff v1 and v2 are some multiples of 2 of the same value.
        func foo(_ v1: Int, _ v2: Int) -> Bool {
            var v1 = v1
            var v2 = v2
            while v1 > 0 && v1 & 1 == 0 { v1 = v1 >> 1 }
            while v2 > 0 && v2 & 1 == 0 { v2 = v2 >> 1 }
            return v1 == v2
        }

        XCTAssertTrue(list1.elementsEqual(list1, by: foo))
        XCTAssertTrue(list1.elementsEqual(list2, by: foo))
        XCTAssertFalse(list1.elementsEqual(list3, by: foo))
    }

    func testElementsEqual() {
        let list1 = List<Int>(0..<100)
        let list2 = List<Int>(0..<100)
        let list3 = List<Int>(Array(0..<99) + [50])

        XCTAssertTrue(list1.elementsEqual(list1))
        XCTAssertTrue(list1.elementsEqual(list2))
        XCTAssertFalse(list1.elementsEqual(list3))
    }

    func testIndexOfPredicate() {
        let list = List<Int>(0..<50)
        for v in 0 ..< 50 {
            let i = list.index { $0 == v }
            XCTAssertEqual(i, v)
        }
        XCTAssertNil(list.index { $0 == -1 })
        XCTAssertNil(list.index { $0 == 50 })
    }

    func testIndexOfValue() {
        let list = List<Int>(0..<50)
        for v in 0 ..< 50 {
            let i = list.index(of: v)
            XCTAssertEqual(i, v)
        }
        XCTAssertNil(list.index(of: -1))
        XCTAssertNil(list.index(of: 50))
    }

    func testContains() {
        let list = List<Int>(0..<50)
        for v in 0 ..< 50 {
            XCTAssertTrue(list.contains(v))
        }
        XCTAssertFalse(list.contains(-1))
        XCTAssertFalse(list.contains(50))
    }

    func testDescriptions() {
        let list: List<String> = ["2", "1", "0", "3"]
        XCTAssertEqual(list.description, "[\"2\", \"1\", \"0\", \"3\"]")
        XCTAssertEqual(list.debugDescription, "[\"2\", \"1\", \"0\", \"3\"]")
    }

    func testAppend() {
        let values = 1...10
        var list = List<Int>()

        for v in values {
            list.append(v)
            list.assertValid()
        }

        XCTAssertEqual(list.count, values.count)
        assertEqualElements(list, values)
    }

    func testInsert() {
        let count = 6
        for inversion in generateInversions(count) {
            var list = List<Int>()
            var referenceArray: [Int] = []
            for i in inversion {
                list.insert(i, at: i)
                referenceArray.insert(i, at: i)
            }
            list.assertValid()
            XCTAssertEqual(referenceArray, Array(list))
        }
    }

    func testAppendContentsOfList() {
        var l1: List<Int> = [0, 1, 2, 3, 4]
        let l2: List<Int> = [5, 6, 7, 8, 9]
        l1.append(contentsOf: l2)
        assertEqualElements(l1, 0..<10)

        let l3: List<Int> = [10, 11, 12, 13, 14]
        func appendAsSequence<E, S: Sequence>(_ list: inout List<E>, _ elements: S) where S.Element == E {
            list.append(contentsOf: elements)
        }
        appendAsSequence(&l1, l3)
        assertEqualElements(l1, 0..<15)
    }

    func testAppendContentsOfSequence() {
        var list: List<Int> = [0, 1, 2, 3, 4]
        list.append(contentsOf: 5..<10)
        assertEqualElements(list, 0..<10)
    }

    func testInsertContentsOfList() {
        let list: List<Int> = [0, 1, 2, 3, 4]
        let l: List<Int> = [5, 6, 7, 8, 9]

        for i in 0...5 {
            var copy = list
            copy.insert(contentsOf: l, at: i)

            var ref = Array(0..<5)
            ref.insert(contentsOf: l, at: i)

            assertEqualElements(copy, ref)
        }
        assertEqualElements(list, 0..<5)

        var copy = list
        func insertAsSequence<E, S: Sequence>(_ list: inout List<E>, _ elements: S, at index: Int) where S.Element == E {
            list.insert(contentsOf: elements, at: index)
        }
        insertAsSequence(&copy, l, at: copy.count)
        assertEqualElements(copy, 0 ..< 10)
    }

    func testInsertContentsOfSequence() {
        let list: List<Int> = [0, 1, 2, 3, 4]
        let s = 5..<10

        for i in 0...5 {
            var copy = list
            copy.insert(contentsOf: s, at: i)

            var ref = Array(0..<5)
            ref.insert(contentsOf: s, at: i)

            assertEqualElements(copy, ref)
        }
        assertEqualElements(list, 0..<5)
    }

    func testRemoveAtIndex() {
        let count = 6
        let list = List<Int>(1...count)
        let referenceArray = Array<Int>(1...count)

        for inversion in generateInversions(count) {
            var l = list
            var r = referenceArray

            for i in inversion.reversed() {
                let li = l.remove(at: i)
                let ai = r.remove(at: i)
                XCTAssertEqual(li, ai)
            }
            l.assertValid()
            XCTAssertEqual(r.count, 0)
            XCTAssertEqual(l.count, 0)
        }
    }

    func testRemoveFirst() {
        var list: List<Int> = [0, 1, 2, 3, 4]
        for i in 0..<5 {
            XCTAssertEqual(list.removeFirst(), i)
        }
        XCTAssertTrue(list.isEmpty)
    }

    func testRemoveFirstN() {
        var list = List<Int>(0..<100)
        for i in 0..<5 {
            list.removeFirst(20)
            assertEqualElements(list, 20 * (i + 1) ..< 100)
        }
        XCTAssertTrue(list.isEmpty)
    }

    func testRemoveLast() {
        var list: List<Int> = [0, 1, 2, 3, 4]
        for i in (0..<5).reversed() {
            XCTAssertEqual(list.removeLast(), i)
        }
        XCTAssertTrue(list.isEmpty)
    }

    func testRemoveLastN() {
        var list = List<Int>(0..<100)
        for i in (0..<5).reversed() {
            list.removeLast(20)
            assertEqualElements(list, 0 ..< i * 20)
        }
        XCTAssertTrue(list.isEmpty)
    }

    func testPopLast() {
        var list: List<Int> = [0, 1, 2, 3, 4]
        for i in (0..<5).reversed() {
            XCTAssertEqual(list.popLast(), i)
        }
        XCTAssertNil(list.popLast())
    }

    func testPopFirst() {
        var list: List<Int> = [0, 1, 2, 3, 4]
        for i in 0..<5 {
            XCTAssertEqual(list.popFirst(), i)
        }
        XCTAssertNil(list.popFirst())
    }

    func testRemoveRange() {
        var list = List(0..<10)
        list.removeSubrange(2..<8)
        assertEqualElements(list, [0, 1, 8, 9])
    }

    func testRemoveAll() {
        var list = List(0..<10)
        list.removeAll()
        assertEqualElements(list, [])
    }

    func testReplaceRangeWithList() {
        var list = List(0..<10)

        list.replaceSubrange(2..<5, with: List(8..<11))
        assertEqualElements(list, [0, 1, 8, 9, 10, 5, 6, 7, 8, 9])

        list.replaceSubrange(0..<3, with: List())
        assertEqualElements(list, [9, 10, 5, 6, 7, 8, 9])

        list.replaceSubrange(4..<7, with: List(1 ..< 6))
        assertEqualElements(list, [9, 10, 5, 6, 1, 2, 3, 4, 5])

        list.replaceSubrange(0..<9, with: List())
        assertEqualElements(list, 0 ..< 0)
    }

    func testReplaceRangeWithSequence() {
        var list = List(0..<10)
        list.replaceSubrange(2..<8, with: [10, 20, 30])
        assertEqualElements(list, [0, 1, 10, 20, 30, 8, 9])
        list.replaceSubrange(1..<3, with: [50, 51, 52, 53, 54, 55])
        assertEqualElements(list, [0, 50, 51, 52, 53, 54, 55, 20, 30, 8, 9])

        func replaceAsSequence<E, C: Collection>(_ list: inout List<E>, range: CountableRange<Int>, with elements: C) where C.Element == E {
            list.replaceSubrange(range, with: elements)
        }
        replaceAsSequence(&list, range: 1 ..< 9, with: List(1 ..< 8))
        assertEqualElements(list, 0 ..< 10)
    }

    func testListEquality() {
        let l1 = List(0..<10)
        let l2 = List(0..<5)
        let l3 = List((0..<10).reversed())

        XCTAssertTrue(l1 == l1)
        XCTAssertTrue(l2 == l2)
        XCTAssertTrue(l3 == l3)
        XCTAssertFalse(l1 == l2)
        XCTAssertFalse(l1 == l3)
        XCTAssertFalse(l2 == l3)

        XCTAssertFalse(l1 != l1)
    }

    func test_Issue3_CrashInElementwiseAppend() {
        // https://github.com/attaswift/BTree/issues/3
        var list = List<String>()
        for i in 0 ..< 1000 {
            list.append("item \(i)")
        }
        assertEqualElements(list, (0..<1000).map { "item \($0)" })
    }

    func testConcatenationOperator() {
        let l1 = List(0 ..< 10)
        let l2 = List(10 ..< 20)

        assertEqualElements(l1 + l2, 0 ..< 20)
    }
}
