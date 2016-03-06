//
//  ListTests.swift
//  BTree
//
//  Created by Károly Lőrentey on 2015-12-15.
//  Copyright © 2015–2016 Károly Lőrentey.
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
        XCTAssertElementsEqual(list, [])
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
        XCTAssertElementsEqual(GeneratorSequence(list.generate()), 0..<5)
        XCTAssertElementsEqual(list, 0..<5)
    }

    func testSubscriptSetter() {
        var list: List<Int> = [0, 1, 2, 3, 4]
        for i in 0 ..< 5 {
            list[i] = 2 * i
        }
        XCTAssertElementsEqual(list, [0, 2, 4, 6, 8])
    }

    func testGettingSublists() {
        let count = 20
        let list = List(0..<count)
        for i in 0 ... count {
            for j in i ... count {
                XCTAssertElementsEqual(list[i ..< j], i ..< j)
            }
        }
    }

    func testSettingSublists() {
        var list = List(0..<10)

        list[2..<5] = List(8..<11)
        XCTAssertElementsEqual(list, [0, 1, 8, 9, 10, 5, 6, 7, 8, 9])

        list[0..<3] = List()
        XCTAssertElementsEqual(list, [9, 10, 5, 6, 7, 8, 9])

        list[4..<7] = List(1 ..< 6)
        XCTAssertElementsEqual(list, [9, 10, 5, 6, 1, 2, 3, 4, 5])

        list[0..<9] = List()
        XCTAssertElementsEqual(list, 0 ..< 0)
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
        XCTAssertElementsEqual(r, [0, 2, 4, 6, 8])
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
        XCTAssertElementsEqual(r, (0..<100).map { $0 & ~1 })
    }

    func testFlatMapOptional() {
        let list = List<Int>(0..<100)
        let r = list.flatMap { n -> Int? in
            return n & 1 == 0 ? n / 2 : nil
        }
        XCTAssertElementsEqual(r, 0..<50)
    }

    func testReduce() {
        let list = List<Int>(0..<100)
        let sum = list.reduce(0) { $0 + $1 }
        XCTAssertEqual(sum, 100 * 99 / 2)
    }

    func testFilter() {
        let list = List<Int>(0..<100)
        let r = list.filter { $0 & 1 == 0 }
        XCTAssertElementsEqual(r, (0..<50).map { 2 * $0 })
    }

    func testElementsEqualWithEquivalence() {
        let list1 = List<Int>(0..<100)
        let list2 = List<Int>((0..<100).map { $0 * 8 })
        let list3 = List<Int>((0..<100).map { $0 * 3 })

            // Return true iff v1 and v2 are some multiples of 2 of the same value.
        func foo(v1: Int, _ v2: Int) -> Bool {
            var v1 = v1
            var v2 = v2
            while v1 > 0 && v1 & 1 == 0 { v1 = v1 >> 1 }
            while v2 > 0 && v2 & 1 == 0 { v2 = v2 >> 1 }
            return v1 == v2
        }

        XCTAssertTrue(list1.elementsEqual(list1, isEquivalent: foo))
        XCTAssertTrue(list1.elementsEqual(list2, isEquivalent: foo))
        XCTAssertFalse(list1.elementsEqual(list3, isEquivalent: foo))
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
            let i = list.indexOf { $0 == v }
            XCTAssertEqual(i, v)
        }
        XCTAssertNil(list.indexOf { $0 == -1 })
        XCTAssertNil(list.indexOf { $0 == 50 })
    }

    func testIndexOfValue() {
        let list = List<Int>(0..<50)
        for v in 0 ..< 50 {
            let i = list.indexOf(v)
            XCTAssertEqual(i, v)
        }
        XCTAssertNil(list.indexOf(-1))
        XCTAssertNil(list.indexOf(50))
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
        XCTAssertElementsEqual(list, values)
    }

    func testInsert() {
        let count = 6
        for inversion in generateInversions(count) {
            var list = List<Int>()
            var referenceArray: [Int] = []
            for i in inversion {
                list.insert(i, atIndex: i)
                referenceArray.insert(i, atIndex: i)
            }
            list.assertValid()
            XCTAssertEqual(referenceArray, Array(list))
        }
    }

    func testAppendContentsOfList() {
        var l1: List<Int> = [0, 1, 2, 3, 4]
        let l2: List<Int> = [5, 6, 7, 8, 9]
        l1.appendContentsOf(l2)
        XCTAssertElementsEqual(l1, 0..<10)
    }

    func testAppendContentsOfSequence() {
        var list: List<Int> = [0, 1, 2, 3, 4]
        list.appendContentsOf(5..<10)
        XCTAssertElementsEqual(list, 0..<10)
    }

    func testInsertContentsOfList() {
        let list: List<Int> = [0, 1, 2, 3, 4]
        let l: List<Int> = [5, 6, 7, 8, 9]

        for i in 0...5 {
            var copy = list
            copy.insertContentsOf(l, at: i)

            var ref = Array(0..<5)
            ref.insertContentsOf(l, at: i)

            XCTAssertElementsEqual(copy, ref)
        }
        XCTAssertElementsEqual(list, 0..<5)
    }

    func testInsertContentsOfSequence() {
        let list: List<Int> = [0, 1, 2, 3, 4]
        let s = 5..<10

        for i in 0...5 {
            var copy = list
            copy.insertContentsOf(s, at: i)

            var ref = Array(0..<5)
            ref.insertContentsOf(s, at: i)

            XCTAssertElementsEqual(copy, ref)
        }
        XCTAssertElementsEqual(list, 0..<5)
    }

    func testRemoveAtIndex() {
        let count = 6
        let list = List<Int>(1...count)
        let referenceArray = Array<Int>(1...count)

        for inversion in generateInversions(count) {
            var l = list
            var r = referenceArray

            for i in inversion.reverse() {
                let li = l.removeAtIndex(i)
                let ai = r.removeAtIndex(i)
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
            XCTAssertElementsEqual(list, 20 * (i + 1) ..< 100)
        }
        XCTAssertTrue(list.isEmpty)
    }

    func testRemoveLast() {
        var list: List<Int> = [0, 1, 2, 3, 4]
        for i in (0..<5).reverse() {
            XCTAssertEqual(list.removeLast(), i)
        }
        XCTAssertTrue(list.isEmpty)
    }

    func testRemoveLastN() {
        var list = List<Int>(0..<100)
        for i in (0..<5).reverse() {
            list.removeLast(20)
            XCTAssertElementsEqual(list, 0 ..< i * 20)
        }
        XCTAssertTrue(list.isEmpty)
    }

    func testPopLast() {
        var list: List<Int> = [0, 1, 2, 3, 4]
        for i in (0..<5).reverse() {
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
        list.removeRange(2..<8)
        XCTAssertElementsEqual(list, [0, 1, 8, 9])
    }

    func testRemoveAll() {
        var list = List(0..<10)
        list.removeAll()
        XCTAssertElementsEqual(list, [])
    }

    func testReplaceRangeWithList() {
        var list = List(0..<10)

        list.replaceRange(2..<5, with: List(8..<11))
        XCTAssertElementsEqual(list, [0, 1, 8, 9, 10, 5, 6, 7, 8, 9])

        list.replaceRange(0..<3, with: List())
        XCTAssertElementsEqual(list, [9, 10, 5, 6, 7, 8, 9])

        list.replaceRange(4..<7, with: List(1 ..< 6))
        XCTAssertElementsEqual(list, [9, 10, 5, 6, 1, 2, 3, 4, 5])

        list.replaceRange(0..<9, with: List())
        XCTAssertElementsEqual(list, 0 ..< 0)
    }

    func testReplaceRangeWithSequence() {
        var list = List(0..<10)
        list.replaceRange(2..<8, with: [10, 20, 30])
        XCTAssertElementsEqual(list, [0, 1, 10, 20, 30, 8, 9])
        list.replaceRange(1..<3, with: [50, 51, 52, 53, 54, 55])
        XCTAssertElementsEqual(list, [0, 50, 51, 52, 53, 54, 55, 20, 30, 8, 9])
    }

    func testListEquality() {
        let l1 = List(0..<10)
        let l2 = List(0..<5)
        let l3 = List((0..<10).reverse())

        XCTAssertTrue(l1 == l1)
        XCTAssertTrue(l2 == l2)
        XCTAssertTrue(l3 == l3)
        XCTAssertFalse(l1 == l2)
        XCTAssertFalse(l1 == l3)
        XCTAssertFalse(l2 == l3)

        XCTAssertFalse(l1 != l1)
    }

    func test_Issue3_CrashInElementwiseAppend() {
        // https://github.com/lorentey/BTree/issues/3
        var list = List<String>()
        for i in 0 ..< 1000 {
            list.append("item \(i)")
        }
        XCTAssertElementsEqual(list, (0..<1000).map { "item \($0)" })
    }

    func testConcatenationOperator() {
        let l1 = List(0 ..< 10)
        let l2 = List(10 ..< 20)

        XCTAssertElementsEqual(l1 + l2, 0 ..< 20)
    }
}
