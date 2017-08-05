//
//  MapTests.swift
//  BTreeTests
//
//  Created by Károly Lőrentey on 2015-12-15.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
@testable import BTree

class MapTests: XCTestCase {
    func testEmptyMap() {
        let map = Map<Int, Int>()

        XCTAssertEqual(map.count, 0)
        XCTAssertTrue(map.isEmpty)
        var iterator = map.makeIterator()
        XCTAssertNil(iterator.next())

        XCTAssertEqual(map.startIndex, map.endIndex)
    }

    func testSimpleMapFromDictionaryLiteral() {
        let map: Map<Int, Int> = [1: 20, 2: 40, 3: 60, 4: 80, 5: 100]
        let dict: [Int: Int] = [1: 20, 2: 40, 3: 60, 4: 80, 5: 100]

        // Check that genarator API returns elements in order.
        var lastKey: Int? = nil
        var i = 0
        var iterator = map.makeIterator()
        while let (key, _) = iterator.next() {
            if let lastKey = lastKey {
                XCTAssertLessThan(lastKey, key)
            }
            lastKey = key
            i += 1
        }
        XCTAssertEqual(i, 5)

        // Check that indexing API returns elements in order.
        lastKey = nil
        i = 0
        var index = map.startIndex
        while index != map.endIndex {
            let (key, _) = map[index]
            if let lastKey = lastKey {
                XCTAssertLessThan(lastKey, key)
            }
            lastKey = key
            map.formIndex(after: &index)
            i += 1
        }
        XCTAssertEqual(i, 5)

        // Check that keys are sorted.
        XCTAssertEqual(Array(map.keys), map.keys.sorted())
        XCTAssertEqual(dict.keys.sorted(), map.map({ key, _ in key }))
        XCTAssertEqual(dict.keys.sorted(), Array(map.keys))

        // Check that values match those in dict
        XCTAssertEqual(map.count, dict.count)
        XCTAssertEqual(dict.values.sorted(), map.map({ _, value in value }).sorted())
        XCTAssertEqual(dict.values.sorted(), map.values.sorted())
        for k in dict.keys {
            XCTAssertEqual(map[k], dict[k])
        }
    }

    func testMapForEach() {
        let m = Map<Int, String>(sortedElements: (0..<100).map { ($0, String($0)) })
        var i = 0
        m.forEach { key, value in
            XCTAssertEqual(key, i)
            XCTAssertEqual(value, String(i))
            i += 1
        }
        XCTAssertEqual(i, 100)
    }

    func testMapMap() {
        let m = Map<Int, String>(sortedElements: (0..<100).map { ($0, String($0)) })
        var i = 0
        let r = m.map { key, value -> Int in
            XCTAssertEqual(key, i)
            XCTAssertEqual(value, String(i))
            i += 1
            return key
        }
        XCTAssertEqual(i, 100)
        assertEqualElements(r, 0..<100)
    }

    func testSequenceFlatMap() {
        let m = Map<Int, String>(sortedElements: (0..<100).map { ($0, String($0)) })
        var i = 0
        let r = m.flatMap { key, value -> [Int] in
            XCTAssertEqual(key, i)
            XCTAssertEqual(value, String(i))
            i += 1
            if key & 1 == 0 {
                return [key, key]
            }
            return []
        }
        XCTAssertEqual(r, (0..<100).map { $0 & ~1 })
    }

    func testOptionalFlatMap() {
        let m = Map<Int, String>(sortedElements: (0..<100).map { ($0, String($0)) })
        var i = 0
        let r = m.flatMap { key, value -> Int? in
            XCTAssertEqual(key, i)
            XCTAssertEqual(value, String(i))
            i += 1
            return key & 1 == 0 ? key / 2 : nil
        }
        assertEqualElements(r, 0..<50)
    }

    func testReduce() {
        let m = Map<Int, String>(sortedElements: (0..<100).map { ($0, String($0)) })
        var i = 0
        let sum = m.reduce(0) { sum, element in
            XCTAssertEqual(element.0, i)
            XCTAssertEqual(element.1, String(i))
            i += 1
            return sum + element.0
        }
        XCTAssertEqual(sum, 100 * 99 / 2)
    }

    func testKeysAndValues() {
        let m = Map<Int, String>(sortedElements: (0..<100).map { ($0, String($0)) })

        assertEqualElements(m.keys, 0..<100)
        assertEqualElements(m.values, (0..<100).map { String($0) })
    }

    func testSubscriptLookup() {
        let m = Map<Int, String>(sortedElements: (0..<100).map { ($0, String($0)) })

        for k in 0..<100 {
            XCTAssertEqual(m[k], String(k))
        }
        XCTAssertNil(m[-1])
        XCTAssertNil(m[100])
    }

    func testSubscriptSetter() {
        var m = Map<Int, String>(sortedElements: [(10, "10"), (20, "20"), (30, "30"), (40, "40")])
        m[5] = "5"
        m[25] = "25"
        m[20] = nil
        m[30] = "30*"
        assertEqualElements(m, [(5, "5"), (10, "10"), (25, "25"), (30, "30*"), (40, "40")])
    }

    func testSubscriptRange() {
        let m = Map(sortedElements: (0..<10).map { ($0, String($0)) })
        let indexes = Array(m.indices) + [m.endIndex]
        assertEqualElements(m[indexes[0] ..< indexes[10]], m)
        assertEqualElements(m[indexes[2] ..< indexes[4]], [(2, "2"), (3, "3")])
        assertEqualElements(m[indexes[0] ..< indexes[3]], [(0, "0"), (1, "1"), (2, "2")])
        assertEqualElements(m[indexes[7] ..< indexes[10]], [(7, "7"), (8, "8"), (9, "9")])
    }

    func testIndexing() {
        let m = Map(sortedElements: (0..<10).map { ($0, String($0)) })
        var index = m.startIndex
        XCTAssertEqual(m.index(after: index), m.index(ofOffset: 1))
        XCTAssertEqual(m.index(index, offsetBy: 5), m.index(ofOffset: 5))

        m.formIndex(after: &index)
        XCTAssertEqual(m.offset(of: index), 1)
        m.formIndex(&index, offsetBy: 5)
        XCTAssertEqual(m.offset(of: index), 6)

        XCTAssertEqual(m.index(before: index), m.index(ofOffset: 5))
        XCTAssertEqual(m.index(index, offsetBy: -4), m.index(ofOffset: 2))

        m.formIndex(before: &index)
        XCTAssertEqual(m.offset(of: index), 5)
        m.formIndex(&index, offsetBy: -3)
        XCTAssertEqual(m.offset(of: index), 2)

        XCTAssertNil(m.index(index, offsetBy: 4, limitedBy: m.index(ofOffset: 5)))
        XCTAssertEqual(m.index(index, offsetBy: 4, limitedBy: m.index(ofOffset: 8)), m.index(ofOffset: 6))

        XCTAssertFalse(m.formIndex(&index, offsetBy: 4, limitedBy: m.index(ofOffset: 5)))
        XCTAssertEqual(m.offset(of: index), 5)

        XCTAssertTrue(m.formIndex(&index, offsetBy: -2, limitedBy: m.index(ofOffset: 2)))
        XCTAssertEqual(m.offset(of: index), 3)

        XCTAssertEqual(m.distance(from: m.index(ofOffset: 3), to: m.index(ofOffset: 8)), 5)
    }

    func testIndexForKey() {
        let m = Map<Int, String>(sortedElements: (0..<100).map { ($0, String($0)) })

        var index = m.startIndex
        for k in 0..<100 {
            let i = m.index(forKey: k)
            XCTAssertEqual(i, index)
            XCTAssertEqual(m[i!].0, k)
            m.formIndex(after: &index)
        }
        XCTAssertEqual(index, m.endIndex)

        XCTAssertNil(m.index(forKey: -1))
        XCTAssertNil(m.index(forKey: 100))
    }

    func testRemoveAtIndex() {
        var m = Map<Int, String>(sortedElements: (0..<100).map { ($0, String($0)) })
        for i in (0 ..< 100).reversed() {
            if i & 1 == 1 {
                let index = m.index(m.startIndex, offsetBy: i)
                let element = m.remove(at: index)
                XCTAssertEqual(element.0, i)
                XCTAssertEqual(element.1, String(i))
            }
        }
        assertEqualElements(m, (0..<50).map { (2 * $0, String(2 * $0)) })
    }

    func testRemoveValueForKey() {
        var m = Map<Int, String>(sortedElements: (0..<100).map { ($0, String($0)) })
        for k in (0 ..< 100).filter({ $0 & 1 == 1 }) {
            let value = m.removeValue(forKey: k)
            XCTAssertEqual(value, String(k))
        }
        assertEqualElements(m, (0..<50).map { (2 * $0, String(2 * $0)) })
    }

    func testRemoveAll() {
        var m = Map<Int, String>(sortedElements: (0..<100).map { ($0, String($0)) })
        m.removeAll()
        XCTAssertTrue(m.isEmpty)
        assertEqualElements(m, [])
    }

    func testIndexOfOffset() {
        let m = Map<Int, String>(sortedElements: (0..<100).map { ($0, String($0)) })
        for i in 0...100 {
            XCTAssertEqual(m.index(ofOffset: i), m.index(m.startIndex, offsetBy: i))
        }
    }

    func testOffsetOfIndex() {
        let m = Map<Int, String>(sortedElements: (0..<100).map { ($0, String($0)) })
        var index = m.startIndex
        for i in 0 ..< 100 {
            XCTAssertEqual(m.offset(of: index), i)
            m.formIndex(after: &index)
        }
        XCTAssertEqual(m.offset(of: index), m.count)
        XCTAssertEqual(index, m.endIndex)
    }

    func testOffsetOfKey() {
        let m = Map<Int, String>(sortedElements: (0..<50).map { (2 * $0, String(2 * $0)) })
        for k in 0 ..< 100 {
            let offset = m.offset(of: k)
            if k & 1 == 0 {
                XCTAssertEqual(offset, k / 2)
            }
            else {
                XCTAssertNil(offset)
            }
        }
    }

    func testElementAtOffset() {
        let m = Map<Int, String>(sortedElements: (0..<100).map { ($0, String($0)) })
        for i in 0 ..< 100 {
            let element = m.element(atOffset: i)
            XCTAssertEqual(element.0, i)
            XCTAssertEqual(element.1, String(i))
        }
    }

    func testUpdateValueAtOffset() {
        var m = Map<Int, String>(sortedElements: (0..<100).map { ($0, String($0)) })
        for i in 0 ..< 100 {
            m.updateValue(String(i) + "*", atOffset: i)
        }
        assertEqualElements(m, (0..<100).map { ($0, String($0) + "*") })
    }

    func testSubmaps() {
        let m = Map<Int, String>(sortedElements: (0..<100).map { ($0, String($0)) })
        let indexRange = m.index(m.startIndex, offsetBy: 30) ..< m.index(m.startIndex, offsetBy: 80)
        let referenceSeq = (30..<80).map { ($0, String($0)) }
        assertEqualElements(m[indexRange], referenceSeq)
        assertEqualElements(m.submap(with: indexRange), referenceSeq)
        assertEqualElements(m.submap(withOffsets: 30..<80), referenceSeq)
        assertEqualElements(m.submap(from: 30, to: 80), referenceSeq)
        assertEqualElements(m.submap(from: 30, through: 79), referenceSeq)
    }

    func testInitWithUnsortedSequence() {
        let m = Map<Int, String>([(2, "2"), (2, "2"), (2, "2"), (4, "4"), (2, "2*"), (4, "4"), (1, "1"), (1, "1*"), (3, "3*"), (0, "0"), (4, "4*"), (0, "0*")])
        assertEqualElements(m, [(0, "0*"), (1, "1*"), (2, "2*"), (3, "3*"), (4, "4*")])
    }

    func testInitWithSortedSequence() {
        let m = Map<Int, String>([(0, "0"), (0, "0*"), (1, "1"), (1, "1*"), (2, "2"), (2, "2"), (2, "2"), (2, "2*"), (4, "4"), (3, "3*"), (4, "4"), (4, "4*")])
        assertEqualElements(m, [(0, "0*"), (1, "1*"), (2, "2*"), (3, "3*"), (4, "4*")])
    }

    func testDescription() {
        var m = Map<Int, String>()
        XCTAssertEqual(m.description, "[]")
        m[0] = "0"
        XCTAssertEqual(m.description, "[0: \"0\"]")
        m[1] = "1"
        XCTAssertEqual(m.description, "[0: \"0\", 1: \"1\"]")
    }

    func testDebugDescription() {
        var m = Map<Int, String>()
        XCTAssertEqual(m.debugDescription, "[]")
        m[0] = "0"
        XCTAssertEqual(m.debugDescription, "[0: \"0\"]")
        m[1] = "1"
        XCTAssertEqual(m.debugDescription, "[0: \"0\", 1: \"1\"]")
    }

    func testMapEqualityUnderEquivalence() {
        let m1 = Map<Int, Int>(sortedElements: (0 ..< 100).map { ($0, $0) })
        let m2 = Map<Int, Int>(sortedElements: (0 ..< 100).map { (8 * $0, $0) })
        let m3 = Map<Int, Int>(sortedElements: (0 ..< 100).map { (3 * $0, $0) })

        /// Return true iff `a` and `b` are some multiples of 2 of the same value.
        func eq(a: (Int, Int), b: (Int, Int)) -> Bool {
            var ak = a.0
            var bk = b.0
            while ak > 0 && ak & 1 == 0 { ak = ak >> 1 }
            while bk > 0 && bk & 1 == 0 { bk = bk >> 1 }
            return ak == bk
        }

        XCTAssertTrue(m1.elementsEqual(m2, by: eq))
        XCTAssertFalse(m1.elementsEqual(m3, by: eq))
    }

    func testMapEquality() {
        let m1: Map<Int, Int> = [5: 100, 4: 80, 3: 60, 2: 40, 1: 20]
        let m2: Map<Int, Int> = [1: 20, 2: 40, 3: 60, 4: 80, 5: 100]
        let m3: Map<Int, Int> = [1: 20, 2: 40]

        XCTAssertTrue(m1 == m2)
        XCTAssertFalse(m1 != m2)

        XCTAssertFalse(m1 == m3)
        XCTAssertFalse(m2 == m3)
        XCTAssertTrue(m3 == m3)
    }

    func testInsertions() {
        var m = Map<Int, Int>()

        m[1] = 2
        m[100] = 200
        m[34] = 68
        m[42] = 84

        XCTAssertEqual(Array(m.keys), [1, 34, 42, 100])
        XCTAssertEqual(Array(m.values), [2, 68, 84, 200])
    }

    func testRemovals() {
        var m: Map<Int, Int> = [1: 2, 5: 10, 3: 6, 9: 18]

        m[1] = nil
        XCTAssertNil(m[1])
        XCTAssertNil(m.removeValue(forKey: 1))

        XCTAssertNil(m.removeValue(forKey: 4))

        XCTAssertEqual(m.removeValue(forKey: 3), 6)

        XCTAssertEqual(Array(m.keys), [5, 9])
        XCTAssertEqual(Array(m.values), [10, 18])
    }

    func testRemoveAtOffset() {
        var m: Map<Int, Int> = [1: 2, 5: 10, 3: 6, 9: 18]

        m.remove(atOffset: 2)
        assertEqualElements(m, [(1, 2), (3, 6), (9, 18)])
    }

    func testRemoveAtOffsets() {
        var m: Map<Int, Int> = [1: 2, 5: 10, 3: 6, 9: 18]

        m.remove(atOffsets: 1 ..< 3)
        assertEqualElements(m, [(1, 2), (9, 18)])
    }


    func testReplacements() {
        var m: Map<Int, Int> = [1: 2, 5: 10, 3: 6, 9: 18]

        m[1] = 0
        XCTAssertEqual(m[1], 0)

        let old = m.updateValue(0, forKey: 3)
        XCTAssertEqual(old, 6)
        XCTAssertEqual(m[3], 0)

        XCTAssertEqual(Array(m.keys), [1, 3, 5, 9])
        XCTAssertEqual(Array(m.values), [0, 0, 10, 18])
    }

    func testMerging() {
        let m1: Map<Int, Int> = [1: 2, 2: 4, 5: 10, 6: 12]
        let m2: Map<Int, Int> = [2: 20, 3: 30, 4: 40]
        let m3: Map<Int, Int> = [1: 2, 2: 20, 3: 30, 4: 40, 5: 10, 6: 12]

        assertEqualElements(m1 + m2, m3)
    }

    func testIncluding() {
        let m = Map((0 ..< 20).map { ($0, String($0)) })

        assertEqualElements(m.including([]), [])
        assertEqualElements(m.including(5 ..< 10), (5 ..< 10).map { ($0, String($0)) })
        assertEqualElements(m.including([0, 5, 10, 15]), [0, 5, 10, 15].map { ($0, String($0)) })
        assertEqualElements(m.including(-10 ..< 30), m)
    }

    func testExcluding() {
        let m = Map((0 ..< 20).map { ($0, String($0)) })

        assertEqualElements(m.excluding([]), m)
        assertEqualElements(m.excluding(5 ..< 10), ([0 ..< 5, 10 ..< 20] as [CountableRange<Int>]).joined().map { (k) -> (Int, String) in (k, String(k)) })
        assertEqualElements(m.excluding([0, 5, 10, 15]), ([1 ..< 5, 6 ..< 10, 11 ..< 15, 16 ..< 20] as [CountableRange<Int>]).joined().map { (k) -> (Int, String) in (k, String(k)) })
        assertEqualElements(m.excluding(-10 ..< 30), [])
    }
}
