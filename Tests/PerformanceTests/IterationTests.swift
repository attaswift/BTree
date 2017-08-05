//
//  IterationTests.swift
//  PerformanceTests
//
//  Created by Károly Lőrentey on 2016-11-08.
//  Copyright © 2016–2017 Károly Lőrentey.
//

#if ENABLE_BENCHMARK_TESTS

import XCTest
import BTree

private let count = 500_000
private let arrayFixture = (0 ..< count).map { ($0, "\($0)") }
private let treeFixture = BTree<Int, String>(sortedElements: arrayFixture)

class IterationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        XCTAssertEqual(treeFixture.count, count)
    }

    func testArray() {
        measure {
            var sum = 0
            for element in arrayFixture {
                sum += element.0
            }
            XCTAssertEqual(sum, (count - 1) * count / 2)
        }
    }

    func testForEach() {
        measure {
            var sum = 0
            treeFixture.forEach { element -> Void in
                sum += element.0
            }
            XCTAssertEqual(sum, (count - 1) * count / 2)
        }
    }

    func testIterator() {
        measure {
            var sum = 0
            for element in treeFixture {
                sum += element.0
            }
            XCTAssertEqual(sum, (count - 1) * count / 2)
        }
    }

    func testIndexing() {
        measure {
            var sum = 0
            for index in treeFixture.indices {
                sum += treeFixture[index].0
            }
            XCTAssertEqual(sum, (count - 1) * count / 2)
        }
    }

    func testCursorOnSharedTree() {
        measure {
            var test = treeFixture
            test.withCursorAtStart { cursor in
                var sum = 0
                while !cursor.isAtEnd {
                    sum += cursor.key
                    cursor.moveForward()
                }
                XCTAssertEqual(sum, (count - 1) * count / 2)
            }
        }
    }

    func testCursorOnUniqueTree() {
        measureMetrics(IterationTests.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) {
            var test = BTree<Int, String>(sortedElements: (0 ..< count).lazy.map { ($0, "\($0)") })
            self.startMeasuring()
            test.withCursorAtStart { cursor in
                var sum = 0
                while !cursor.isAtEnd {
                    sum += cursor.key
                    cursor.moveForward()
                }
                XCTAssertEqual(sum, (count - 1) * count / 2)
            }
            self.stopMeasuring()
        }
    }
}

#endif
