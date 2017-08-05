//
//  XCTest extensions.swift
//  BTree
//
//  Created by Károly Lőrentey on 2015-12-21.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import Foundation

import XCTest
import BTree

func assertEqualElements<Element: Equatable, S1: Sequence, S2: Sequence>(_ a: S1, _ b: S2, file: StaticString = #file, line: UInt = #line) where S1.Element == Element, S2.Element == Element {
    let aa = Array(a)
    let ba = Array(b)
    if !aa.elementsEqual(ba) {
        XCTFail("XCTAssertEqual failed: \"\(aa)\" is not equal to \"\(ba)\"", file: file, line: line)
    }
}

func assertEqualElements<T1: Equatable, T2: Equatable, S1: Sequence, S2: Sequence>(_ a: S1, _ b: S2, file: StaticString = #file, line: UInt = #line) where S1.Element == (T1, T2), S2.Element == (T1, T2) {
    let aa = Array(a)
    let ba = Array(b)
    if !aa.elementsEqual(ba, by: { a, b in a.0 == b.0 && a.1 == b.1 }) {
        XCTFail("XCTAssertEqual failed: \"\(aa)\" is not equal to \"\(ba)\"", file: file, line: line)
    }
}

func assertEqualElements<Element: Equatable, S1: Sequence, S2: Sequence, S1W: Sequence, S2W: Sequence>(_ a: S1, _ b: S2, element: Element.Type = Element.self, file: StaticString = #file, line: UInt = #line) where S1.Element == S1W, S2.Element == S2W, S1W.Element == Element, S2W.Element == Element {
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

    internal func assertKeysEqual<S: Sequence>(_ s: S, file: StaticString = #file, line: UInt = #line) where S.Element == Key {
        assertEqualElements(self.map { $0.0 }, s, file: file, line: line)
    }
}

internal extension Sequence {
    func repeatEach(_ count: Int) -> Array<Element> {
        var result: [Element] = []
        result.reserveCapacity(count * underestimatedCount)
        for element in self {
            for _ in 0 ..< count {
                result.append(element)
            }
        }
        return result
    }
}
