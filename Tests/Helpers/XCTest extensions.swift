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

func assertEqualElements<Element: Equatable, S1: Sequence, S2: Sequence>(_ a: S1, _ b: S2, file: StaticString = #file, line: UInt = #line) where S1.Iterator.Element == Element, S2.Iterator.Element == Element {
    let aa = Array(a)
    let ba = Array(b)
    if !aa.elementsEqual(ba) {
        XCTFail("XCTAssertEqual failed: \"\(aa)\" is not equal to \"\(ba)\"", file: file, line: line)
    }
}

func assertEqualElements<T1: Equatable, T2: Equatable, S1: Sequence, S2: Sequence>(_ a: S1, _ b: S2, file: StaticString = #file, line: UInt = #line) where S1.Iterator.Element == (T1, T2), S2.Iterator.Element == (T1, T2) {
    let aa = Array(a)
    let ba = Array(b)
    if !aa.elementsEqual(ba, by: { a, b in a.0 == b.0 && a.1 == b.1 }) {
        XCTFail("XCTAssertEqual failed: \"\(aa)\" is not equal to \"\(ba)\"", file: file, line: line)
    }
}

func assertEqualElements<Element: Equatable, S1: Sequence, S2: Sequence, S1W: Sequence, S2W: Sequence>(_ a: S1, _ b: S2, file: StaticString = #file, line: UInt = #line) where S1.Iterator.Element == S1W, S2.Iterator.Element == S2W, S1W.Iterator.Element == Element, S2W.Iterator.Element == Element {
    let aa = a.map { Array($0) }
    let ba = b.map { Array($0) }
    if !aa.elementsEqual(ba, by: { $0.elementsEqual($1) }) {
        XCTFail("XCTAssertEqual failed: \"\(aa)\" is not equal to \"\(ba)\"", file: file, line: line)
    }
}


extension BTree {
    internal func assertKeysEqual(_ other: BTree<Key, Value>, file: StaticString = #file, line: UInt = #line) {
        assertEqualElements(self.map { $0.0 }, other.map { $0.0 }, file: file, line: line)
    }

    internal func assertKeysEqual<S: Sequence>(_ s: S, file: StaticString = #file, line: UInt = #line) where S.Iterator.Element == Key {
        assertEqualElements(self.map { $0.0 }, s, file: file, line: line)
    }
}

internal extension Sequence {
    func repeatEach(_ count: Int) -> Array<Iterator.Element> {
        return flatMap { Array<Iterator.Element>(repeating: $0, count: count) }
    }
}
