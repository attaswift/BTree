//
//  XCTest extensions.swift
//  BTree
//
//  Created by Károly Lőrentey on 2015-12-21.
//  Copyright © 2015 Károly Lőrentey.
//

import Foundation

import XCTest
@testable import BTree

#if Swift22
    typealias FileString = StaticString
#else
    typealias FileString = String
#endif

// This basic overload is missing from XCTest, so it upgrades everything to Optional which makes failure reports harder to read.
func XCTAssertEqual<T: Equatable>(@autoclosure expression1: () -> T, @autoclosure _ expression2: () -> T, _ message: String = "", file: FileString = __FILE__, line: UInt = __LINE__) {
    let a = expression1()
    let b = expression2()
    if a != b {
        let m = message.isEmpty ? "XCTAssertEqual failed: (\"\(a)\") is not equal to (\"\(b)\")" : message
        XCTFail(m, file: file, line: line)
    }
}

func XCTAssertElementsEqual<Element: Equatable, S1: SequenceType, S2: SequenceType where S1.Generator.Element == Element, S2.Generator.Element == Element>(a: S1, _ b: S2, file: FileString = __FILE__, line: UInt = __LINE__) {
    let aa = Array(a)
    let ba = Array(b)
    if !aa.elementsEqual(ba) {
        XCTFail("XCTAssertEqual failed: \"\(aa)\" is not equal to \"\(ba)\"", file: file, line: line)
    }
}

func XCTAssertElementsEqual<T1: Equatable, T2: Equatable, S1: SequenceType, S2: SequenceType where S1.Generator.Element == (T1, T2), S2.Generator.Element == (T1, T2)>(a: S1, _ b: S2, file: FileString = __FILE__, line: UInt = __LINE__) {
    let aa = Array(a)
    let ba = Array(b)
    if !aa.elementsEqual(ba, isEquivalent: { a, b in a.0 == b.0 && a.1 == b.1 }) {
        XCTFail("XCTAssertEqual failed: \"\(aa)\" is not equal to \"\(b)\"", file: file, line: line)
    }
}