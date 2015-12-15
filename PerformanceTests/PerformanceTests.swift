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

// Change this to shorten or lengthen the benchmarks.
let count = 100000

let randomElements: [Int] = {
    var numbers = Array((1...count))
    numbers.shuffleInPlace()
    return numbers
}()

let foo = Test(i: 0, foo: nil)
let randomValues = randomElements.map { i in Test(i: i, foo: foo) }

class Test: Comparable {
    var i: Int
    var foo: Test?

    init(i: Int, foo: Test?) {
        self.i = i
        self.foo = foo
    }
}
func ==(a: Test, b: Test) -> Bool {
    return a.i == b.i
}
func <(a: Test, b: Test) -> Bool {
    return a.i < b.i
}

class InsertionPerformanceTests: XCTestCase {

    func testAppendingToUnsortedArray() {
        var round = 1
        self.measureMetrics(self.dynamicType.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) {
            let values = randomValues
            print("Round \(round) started with \(values.count) elements")
            var array = Array<Test>()
            self.startMeasuring()
            for v in values {
                array.append(v)
            }
            self.stopMeasuring()
            print("Round \(round) ended")
            round += 1
        }
    }

    func testInsertingToInlinedSortedArray() {
        var round = 1
        self.measureMetrics(self.dynamicType.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) {
            let values = randomValues
            print("Round \(round) started with \(values.count) elements")
            var array = Array<Test>()
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
            print("Round \(round) ended")
            round += 1
            XCTAssert(array.sort { v1, v2 in v1.i < v2.i }  == array)
        }
    }

    func testInsertingToSortedArray() {
        var round = 1
        self.measureMetrics(self.dynamicType.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) {
            let values = randomValues
            print("Round \(round) started with \(values.count) elements")
            var array = SortedArray<Int, Test>()
            self.startMeasuring()
            for v in values {
                array[v.i] = v
            }
            self.stopMeasuring()
            print("Round \(round) ended")
            round += 1
        }
    }

    func testInsertingIntoUnsortedDictionary() {
        var round = 1
        self.measureMetrics(self.dynamicType.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) {
            let values = randomValues
            print("Round \(round) started with \(values.count) elements")
            var dict = Dictionary<Int, Test>()
            self.startMeasuring()
            for v in values {
                dict[v.i] = v
            }
            self.stopMeasuring()
            print("Round \(round) ended")
            round += 1
        }
    }

    func testInsertingIntoMap() {
        var round = 1
        self.measureMetrics(self.dynamicType.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) {
            let values = randomValues
            print("Round \(round) started with \(values.count) elements")
            var map = Map<Int, Test>()
            self.startMeasuring()
            for v in values {
                map[v.i] = v
            }
            self.stopMeasuring()
            
            print("Round \(round) ended, info: \(map.debugInfo)")
            round += 1
        }
    }

    func testAppendingToList() {
        return
        var round = 1
        self.measureMetrics(self.dynamicType.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) {
            let values = randomValues
            print("Round \(round) started with \(values.count) elements")
            var list = List<Test>()
            self.startMeasuring()
            for v in values {
                list.append(v)
            }
            self.stopMeasuring()

            print("Round \(round) ended, info: \(list.debugInfo)")
            round += 1
        }
    }
}
