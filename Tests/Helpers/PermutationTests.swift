//
//  PermutationTests.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-21.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation
import XCTest

class PermutationTests: XCTestCase {
    func testPermutations() {
        XCTAssertEqual(Array(generatePermutations(0)), [])
        XCTAssertEqual(Array(generatePermutations(1)), [[0]])
        XCTAssertEqual(Array(generatePermutations(2)), [[0, 1], [1, 0]])
        XCTAssertEqual(Array(generatePermutations(3)), [[0, 1, 2], [0, 2, 1], [2, 0, 1], [1, 0, 2], [1, 2, 0], [2, 1, 0]])
        var count = 0
        for p in generatePermutations(6) {
            XCTAssertEqual(p.sort(), [0, 1, 2, 3, 4, 5])
            count += 1
        }
        XCTAssertEqual(count, 6 * 5 * 4 * 3 * 2)
    }
}