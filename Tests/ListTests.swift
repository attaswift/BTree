//
//  ListTests.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-15.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import TreeCollections

class ListTests: XCTestCase {

    func testInsertingItems() {
        var list = List<Int>()

        list.insert(0, atIndex: 0)
        XCTAssertTrue(list.checkCounts())
        XCTAssertEqual(Array(list), [0])

        list.insert(1, atIndex: 1)
        XCTAssertTrue(list.checkCounts())
        XCTAssertEqual(Array(list), [0, 1])

        list.insert(2, atIndex: 2)
        XCTAssertTrue(list.checkCounts())
        XCTAssertEqual(Array(list), [0, 1, 2])
    }

    func testAppendingItemsToList() {
        let values = 1...10
        var list = List<Int>()

        for v in values {
            list.append(v)
            XCTAssertTrue(list.checkCounts())
        }

        XCTAssertEqual(list.count, values.count)
        XCTAssertTrue(list.elementsEqual(values))
    }


}
