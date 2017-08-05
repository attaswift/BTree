//
//  BridgedListTests.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-09-20.
//  Copyright © 2016–2017 Károly Lőrentey.
//

import XCTest
@testable import BTree

@objc
internal class Foo: NSObject {
    var value: Int

    init(_ value: Int) {
        self.value = value
        super.init()
    }
}

class BridgedListTests: XCTestCase {
    #if Debug
    let count = 5_000 // Make sure this is larger than the default tree order to get full code coverage
    #else
    let count = 100_000
    #endif

    func testLeaks() {
        weak var test: Foo? = nil
        do {
            let list = List((0 ..< count).lazy.map { Foo($0) })
            let arrayView = list.arrayView
            test = arrayView.object(at: 0) as? Foo
            XCTAssertNotNil(test)
        }
        XCTAssertNil(test)
    }

    func testCopy() {
        let list = List((0 ..< count).lazy.map { Foo($0) })
        let arrayView = list.arrayView
        let copy = arrayView.copy(with: nil) as AnyObject
        XCTAssertTrue(arrayView === copy)
    }

    func testArrayBaseline() {
        let array = (0 ..< count).map { Foo($0) as Any }
        measure {
            var i = 0
            for member in array {
                guard let foo = member as? Foo else { XCTFail(); break }
                XCTAssertEqual(foo.value, i)
                i += 1
            }
            XCTAssertEqual(i, self.count)
        }
    }

    func testListBaseline() {
        let list = List((0 ..< count).lazy.map { Foo($0) as Any })
        measure {
            var i = 0
            for member in list {
                guard let foo = member as? Foo else { XCTFail(); break }
                XCTAssertEqual(foo.value, i)
                i += 1
            }
            XCTAssertEqual(i, self.count)
        }
    }

    func testFastEnumeration() {
        let list = List((0 ..< count).lazy.map { Foo($0) })
        measure {
            let arrayView = list.arrayView
            var i = 0
            for member in arrayView {
                guard let foo = member as? Foo else { XCTFail(); break }
                XCTAssertEqual(foo.value, i)
                i += 1
            }
            XCTAssertEqual(i, self.count)
        }
    }

    func testObjectEnumerator() {
        let list = List((0 ..< count).lazy.map { Foo($0) })
        measure {
            let arrayView = list.arrayView
            let enumerator = arrayView.objectEnumerator()
            var i = 0
            while let member = enumerator.nextObject() {
                guard let foo = member as? Foo else { XCTFail(); break }
                XCTAssertEqual(foo.value, i)
                i += 1
            }
            XCTAssertEqual(i, self.count)
        }
    }

    func testIndexing() {
        let list = List((0 ..< count).lazy.map { Foo($0) })
        measure {
            let arrayView = list.arrayView
            for i in 0 ..< arrayView.count {
                guard let foo = arrayView.object(at: i) as? Foo else { XCTFail(); break }
                XCTAssertEqual(foo.value, i)
            }
        }
    }
}
