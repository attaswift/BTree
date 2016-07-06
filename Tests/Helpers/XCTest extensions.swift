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

func assertEqualElements<Element: Equatable, S1: Sequence, S2: Sequence where S1.Iterator.Element == Element, S2.Iterator.Element == Element>(_ a: S1, _ b: S2, file: StaticString = #file, line: UInt = #line) {
    let aa = Array(a)
    let ba = Array(b)
    if !aa.elementsEqual(ba) {
        XCTFail("XCTAssertEqual failed: \"\(aa)\" is not equal to \"\(ba)\"", file: file, line: line)
    }
}

func assertEqualElements<T1: Equatable, T2: Equatable, S1: Sequence, S2: Sequence where S1.Iterator.Element == (T1, T2), S2.Iterator.Element == (T1, T2)>(_ a: S1, _ b: S2, file: StaticString = #file, line: UInt = #line) {
    let aa = Array(a)
    let ba = Array(b)
    if !aa.elementsEqual(ba, isEquivalent: { a, b in a.0 == b.0 && a.1 == b.1 }) {
        XCTFail("XCTAssertEqual failed: \"\(aa)\" is not equal to \"\(ba)\"", file: file, line: line)
    }
}

extension BTree {
    internal func assertKeysEqual(_ other: BTree<Key, Value>, file: StaticString = #file, line: UInt = #line) {
        assertEqualElements(self.map { $0.0 }, other.map { $0.0 }, file: file, line: line)
    }

    internal func assertKeysEqual<S: Sequence where S.Iterator.Element == Key>(_ s: S, file: StaticString = #file, line: UInt = #line) {
        assertEqualElements(self.map { $0.0 }, s, file: file, line: line)
    }
}

internal extension Sequence {
    func repeatEach(_ count: Int) -> Array<Iterator.Element> {
        return flatMap { Array<Iterator.Element>(repeating: $0, count: count) }
    }
}
