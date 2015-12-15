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

    func testSimpleMap() {
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
}