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
        root.assertValid()
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

    #if false

    func testBulkLoadingOneFullNode() {
        let elements = (0 ..< order - 1).map { ($0, String($0)) }
        let tree = Node(order: order)
        tree.appendContentsOf(elements)
        tree.assertValid()
        XCTAssertElementsEqual(tree, elements)
    }

    func testBulkLoadingOneFullNodePlusOne() {
        let elements = (0 ..< order).map { ($0, String($0)) }
        let tree = Node(order: order)
        tree.appendContentsOf(elements)
        tree.assertValid()
        XCTAssertElementsEqual(tree, elements)
    }

    func testSortedBulkLoadingFullLevels() {
        let maxKeys = order - 1
        let minKeys = maxKeys / 2

        var n = maxKeys
        var sum = n
        for i in 0..<3 {
            let elements = (0 ..< sum).map { ($0, String($0)) }
            let tree = Node(order: order)
            tree.appendContentsOf(elements)
            tree.assertValid()
            XCTAssertElementsEqual(tree, elements)
            XCTAssertEqual(tree.depth, i)

            let extra = (sum + 1, String(sum + 1))
            tree.insert(extra.1, at: extra.0)
            tree.assertValid()
            XCTAssertElementsEqual(tree, elements + [extra])
            XCTAssertEqual(tree.depth, i + 1)

            n = n * (minKeys + 1)
            sum += n
        }
    }

    #endif

}
