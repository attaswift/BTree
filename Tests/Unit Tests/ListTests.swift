//
//  ListTests.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-15.
//  Copyright © 2015 Károly Lőrentey.
//

import XCTest
@testable import TreeCollections

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
            print(list)
            list.assertValid()
        }

        XCTAssertEqual(list.count, values.count)
        XCTAssertElementsEqual(list, values)
    }

    func testInsert() {
        let count = 6
        for inversion in generateInversions(count) {
            print("Inversion vector = \(inversion)")
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
            print("Inversion vector = \(inversion)")
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

    func testReplaceRange() {
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

}
