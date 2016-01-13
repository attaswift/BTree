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
public func XCTAssertEqual<T: Equatable>(@autoclosure expression1: () -> T, @autoclosure _ expression2: () -> T, _ message: String = "", file: String = __FILE__, line: UInt = __LINE__) {
    let a = expression1()
    let b = expression2()
    if a != b {
        let m = message.isEmpty ? "XCTAssertEqual failed: (\"\(a)\") is not equal to (\"\(b)\")" : message
        XCTFail(m, file: file, line: line)
    }
}

public func XCTAssertEqual<T1: Equatable, T2: Equatable, S: SequenceType where S.Generator.Element == (T1, T2)>(a: S, _ b: [(T1, T2)], file: String = __FILE__, line: UInt = __LINE__) {
    let aa = Array(a)
    if !aa.elementsEqual(b, isEquivalent: { a, b in a.0 == b.0 && a.1 == b.1 }) {
        XCTFail("XCTAssertEqual failed: \"\(aa)\" is not equal to \"\(b)\"", file: file, line: line)
    }
}