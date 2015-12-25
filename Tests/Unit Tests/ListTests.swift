//
//  ListTests.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-15.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import TreeCollections

extension List {
    func assertValid() {
        tree.assertValid()
        var i = 0
        for (key, _) in tree {
            XCTAssertEqual(key.index, i)
            i += 1
        }
    }
}

class ListTests: XCTestCase {

    func testAppendingItemsToList() {
        let values = 1...10
        var list = List<Int>()

        for v in values {
            list.append(v)
            print(list)
            list.assertValid()
        }

        XCTAssertEqual(list.count, values.count)
        XCTAssertTrue(list.elementsEqual(values))
    }

    func testInsertingItems() {
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
    
    func testRemovingItems() {
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

}
