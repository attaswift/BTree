//
//  XCTest extensions.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-21.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

import XCTest
@testable import TreeCollections

// This basic overload is missing from XCTest, so it upgrades everything to Optional which makes failure reports harder to read.
public func XCTAssertEqual<T : Equatable>(@autoclosure expression1: () -> T, @autoclosure _ expression2: () -> T, _ message: String = "", file: String = __FILE__, line: UInt = __LINE__) {
    let a = expression1()
    let b = expression2()
    if a != b {
        let m = message.isEmpty ? "XCTAssertEqual failed: (\"\(a)\") is not equal to (\"\(b)\")" : message
        XCTFail(m, file: file, line: line)
    }
}
