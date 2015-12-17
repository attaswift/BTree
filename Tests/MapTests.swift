//
//  MapTests.swift
//  TreeCollectionsTests
//
//  Created by Károly Lőrentey on 2015-12-15.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import TreeCollections

class MapTests: XCTestCase {
    func testEmptyMap() {
        let map = Map<Int, Int>()

        XCTAssertEqual(map.count, 0)
        var generator = map.generate()
        XCTAssertNil(generator.next())
    }

    func testSimpleMapFromDictionaryLiteral() {
        let map: Map<Int, Int> = [1: 20, 2: 40, 3: 60, 4: 80, 5: 100]
        let dict: [Int: Int] = [1: 20, 2: 40, 3: 60, 4: 80, 5: 100]

        // Check that keys are sorted
        var lastKey: Int? = nil
        for (key, _) in map {
            if let lastKey = lastKey {
                XCTAssertLessThan(lastKey, key)
            }
            lastKey = key
        }

        // Check that keys are sorted.
        XCTAssertEqual(Array(map.keys), map.keys.sort())
        XCTAssertEqual(dict.keys.sort(), map.map({ key, _ in key }))
        XCTAssertEqual(dict.keys.sort(), Array(map.keys))

        // Check that values match those in dict
        XCTAssertEqual(map.count, dict.count)
        XCTAssertEqual(dict.values.sort(), map.map({ _, value in value }).sort())
        XCTAssertEqual(dict.values.sort(), map.values.sort())
        for k in dict.keys {
            XCTAssertEqual(map[k], dict[k])
        }
    }

    func testMapEquality() {
        let m1: Map<Int, Int> = [5: 100, 4: 80, 3: 60, 2: 40, 1: 20]
        let m2: Map<Int, Int> = [1: 20, 2: 40, 3: 60, 4: 80, 5: 100]

        XCTAssertTrue(m1 == m2)
        XCTAssertFalse(m1 != m2)

        let d1: Dictionary<Int, Int> = [5: 100, 4: 80, 3: 60, 2: 40, 1: 20]
        let d2: Dictionary<Int, Int> = [1: 20, 2: 40, 3: 60, 4: 80, 5: 100]

        XCTAssertTrue(d1 == d2)
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
        XCTAssertNil(m.removeValueForKey(1))

        XCTAssertNil(m.removeValueForKey(4))

        XCTAssertEqual(m.removeValueForKey(3), 6)

        XCTAssertEqual(Array(m.keys), [5, 9])
        XCTAssertEqual(Array(m.values), [10, 18])
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
}