//
//  PerformanceTests.swift
//  PerformanceTests
//
//  Created by Károly Lőrentey on 2015-12-15.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import TreeCollections

func random(limit: Int) -> Int {
    return Int(arc4random_uniform(UInt32(limit)))
}

extension Array {
    mutating func shuffleInPlace() {
        let count = self.count
        for i in 0..<count {
            let j = random(count)
            (self[i], self[j]) = (self[j], self[i])
        }
    }
}

class Test {
    var i: Int

    init(i: Int) {
        self.i = i
    }
}

struct Payload: Comparable {
    let i: Int
//    let j: Int
//    let ref: Test

    init(_ i: Int) {
        self.i = i
//        self.j = 2 * i
//        self.ref = foo
    }
}
func ==(a: Payload, b: Payload) -> Bool { return a.i == b.i }
func <(a: Payload, b: Payload) -> Bool { return a.i < b.i }

// Change this to shorten or lengthen the benchmarks.
let count = 100000


let randomPermutation: [Int] = {
    var numbers = Array((1...count))
    numbers.shuffleInPlace()
    return numbers
}()

let foo = Test(i: 42)
let randomValues = randomPermutation.map { i in Payload(i) }


class InsertionPerformanceTests: XCTestCase {

    var round: Int = 1

    override func setUp() {
        round = 1
    }

    func measure(block: [Payload]->Void) {
        self.measureMetrics(self.dynamicType.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) {
            let values = randomValues
            print("Round \(self.round) started with \(values.count) elements")
            block(values)
            print("Round \(self.round) ended")
            self.round += 1
        }
    }

    func testAppendingToUnsortedArray() {
        self.measure { values in
            var array = Array<Payload>()

            self.startMeasuring()

            for v in values {
                array.append(v)
            }

            self.stopMeasuring()
        }
    }

    func testInsertingToInlinedSortedArray() {
        self.measure { values in

            var array = Array<Payload>()

            self.startMeasuring()

            for v in values {
                var start = array.startIndex
                var end = array.endIndex
                while start < end {
                    let mid = start + (end - start) / 2
                    if array[mid].i < v.i {
                        start = mid + 1
                    }
                    else {
                        end = mid
                    }
                }
                array.insert(v, atIndex: start)
            }

            self.stopMeasuring()

            XCTAssert(array.sort { v1, v2 in v1.i < v2.i }  == array)
        }
    }

    func testInsertingToSortedArray() {
        self.measure { values in

            var array = SortedArray<Int, Payload>()

            self.startMeasuring()

            for v in values {
                array[v.i] = v
            }

            self.stopMeasuring()
        }
    }

    func testInsertingIntoUnsortedDictionary() {
        self.measure { values in

            var dict = Dictionary<Int, Payload>()

            self.startMeasuring()

            for v in values {
                dict[v.i] = v
            }

            self.stopMeasuring()
        }
    }

    func testInsertingIntoMap() {
        self.measure { values in
            var map = Map<Int, Payload>()

            self.startMeasuring()

            for v in values {
                map[v.i] = v
            }

            self.stopMeasuring()

            print(map.tree.debugInfo)
        }
    }

    func testAppendingToList() {
        self.measure { values in

            var list = List<Payload>()

            self.startMeasuring()
            
            for v in values {
                list.append(v)
            }

            self.stopMeasuring()

            print(list.tree.debugInfo)
            XCTAssertEqual(list.count, values.count)
            XCTAssertTrue(list.elementsEqual(values))
        }
    }

}
