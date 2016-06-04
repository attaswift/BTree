//
//  XCTest extensions.swift
//  BTree
//
//  Created by Károly Lőrentey on 2015-12-21.
//  Copyright © 2015–2016 Károly Lőrentey.
//

import Foundation

import XCTest
@testable import BTree

// This basic overload is missing from XCTest, so it upgrades everything to Optional which makes failure reports harder to read.
func XCTAssertEqual<T: Equatable>(@autoclosure expression1: () -> T, @autoclosure _ expression2: () -> T, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    let a = expression1()
    let b = expression2()
    if a != b {
        let m = message.isEmpty ? "XCTAssertEqual failed: (\"\(a)\") is not equal to (\"\(b)\")" : message
        XCTFail(m, file: file, line: line)
    }
}

func assertEqualElements<Element: Equatable, S1: Sequence, S2: Sequence where S1.Iterator.Element == Element, S2.Iterator.Element == Element>(a: S1, _ b: S2, file: StaticString = #file, line: UInt = #line) {
    let aa = Array(a)
    let ba = Array(b)
    if !aa.elementsEqual(ba) {
        XCTFail("XCTAssertEqual failed: \"\(aa)\" is not equal to \"\(ba)\"", file: file, line: line)
    }
}

func assertEqualElements<T1: Equatable, T2: Equatable, S1: Sequence, S2: Sequence where S1.Iterator.Element == (T1, T2), S2.Iterator.Element == (T1, T2)>(a: S1, _ b: S2, file: StaticString = #file, line: UInt = #line) {
    let aa = Array(a)
    let ba = Array(b)
    if !aa.elementsEqual(ba, isEquivalent: { a, b in a.0 == b.0 && a.1 == b.1 }) {
        XCTFail("XCTAssertEqual failed: \"\(aa)\" is not equal to \"\(ba)\"", file: file, line: line)
    }
}

extension BTree {
    internal func assertKeysEqual(other: BTree<Key, Value>, file: StaticString = #file, line: UInt = #line) {
        assertEqualElements(self.map { $0.0 }, other.map { $0.0 }, file: file, line: line)
    }

    internal func assertKeysEqual<S: Sequence where S.Iterator.Element == Key>(s: S, file: StaticString = #file, line: UInt = #line) {
        assertEqualElements(self.map { $0.0 }, s, file: file, line: line)
    }
}

internal extension Sequence {
    func repeatEach(count: Int) -> Array<Iterator.Element> {
        return flatMap { Array<Iterator.Element>(count: count, repeatedValue: $0) }
    }
}
