//
//  BTreeComparisonTests.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-03-04.
//  Copyright © 2016 Károly Lőrentey.
//

import XCTest
@testable import BTree

private typealias Builder = BTreeBuilder<Int, Void>
private typealias Node = BTreeNode<Int, Void>
private typealias Tree = BTree<Int, Void>
private typealias Element = (Int, Void)

private func makeTree<S: Sequence>(_ s: S, order: Int = 5, keysPerNode: Int? = nil) -> Tree where S.Iterator.Element == Int {
    var b = Builder(order: order, keysPerNode: keysPerNode ?? order - 1)
    for i in s {
        b.append((i, ()))
    }
    return Tree(b.finish())
}

class BTreeComparisonTests: XCTestCase {
    private func elements(_ range: CountableRange<Int>) -> [Element] {
        return range.map { ($0, ()) }
    }

    private var empty: Tree {
        return Tree(order: 5)
    }

    func test_elementsEqual_SimpleCases() {
        let a = makeTree(0 ..< 100)
        let b = makeTree(0 ..< 100)
        let c = makeTree(0 ..< 101)
        let d = makeTree(Array(0 ..< 99) + [0])

        XCTAssertTrue(a.elementsEqual(a, by: { $0.0 == $1.0 }))
        XCTAssertTrue(a.elementsEqual(b, by: { $0.0 == $1.0 }))
        XCTAssertFalse(a.elementsEqual(c, by: { $0.0 == $1.0 }))
        XCTAssertFalse(a.elementsEqual(d, by: { $0.0 == $1.0 }))
        XCTAssertTrue(b.elementsEqual(a, by: { $0.0 == $1.0 }))
        XCTAssertFalse(c.elementsEqual(a, by: { $0.0 == $1.0 }))
        XCTAssertFalse(d.elementsEqual(a, by: { $0.0 == $1.0 }))
    }

    func test_elementsEqual_SharedNodes() {
        let a = makeTree(0 ..< 100)
        var b = a
        b.withCursorAtStart { $0.key = 0 }
        var c = a
        c.withCursor(atOffset: 99) { $0.key = 99 }

        XCTAssertTrue(a.elementsEqual(b, by: { $0.0 == $1.0 }))
        XCTAssertTrue(a.elementsEqual(c, by: { $0.0 == $1.0 }))
        XCTAssertTrue(b.elementsEqual(a, by: { $0.0 == $1.0 }))
        XCTAssertTrue(b.elementsEqual(c, by: { $0.0 == $1.0 }))
        XCTAssertTrue(c.elementsEqual(a, by: { $0.0 == $1.0 }))
        XCTAssertTrue(c.elementsEqual(b, by: { $0.0 == $1.0 }))
    }

    func test_elementsEqual_ShiftedSharedNodes() {
        let reference = Array(repeating: 42, count: 100)
        let a = makeTree(reference)
        for i in 0 ..< 100 {
            var b = a
            b.withCursor(atOffset: i) {
                $0.remove()
                $0.moveToEnd()
                $0.insert((42, ()))
            }
            var c = a
            c.withCursor(atOffset: i) {
                $0.insert((42, ()))
                $0.moveToEnd()
                $0.moveBackward()
                $0.remove()
            }
            XCTAssertTrue(a.elementsEqual(b, by: { $0.0 == $1.0 }))
            XCTAssertTrue(a.elementsEqual(c, by: { $0.0 == $1.0 }))
            XCTAssertTrue(b.elementsEqual(a, by: { $0.0 == $1.0 }))
            XCTAssertTrue(b.elementsEqual(c, by: { $0.0 == $1.0 }))
            XCTAssertTrue(c.elementsEqual(a, by: { $0.0 == $1.0 }))
            XCTAssertTrue(c.elementsEqual(b, by: { $0.0 == $1.0 }))

            assertEqualElements(a.map { $0.0 }, reference)
        }
    }

    func test_elementsEqual_equatableValue() {
        let a = BTree<Int, String>(sortedElements: (0..<100).map { ($0, String($0)) }, order: 5)
        let b = BTree<Int, String>(sortedElements: (0..<100).map { ($0, String($0)) }, order: 7)
        var c = a
        c.setValue(atOffset: 99, to: "*")

        XCTAssertTrue(a == b)
        XCTAssertFalse(a == c)

        XCTAssertFalse(a != b)
        XCTAssertTrue(a != c)
    }

    func test_isDisjointWith_SimpleCases() {
        let firstHalf = makeTree(0 ..< 100)
        let secondHalf = makeTree(100 ..< 200)
        let even = makeTree(stride(from: 200, to: 300, by: 2))
        let odd = makeTree(stride(from: 201, to: 300, by: 2))
        var almostEven = makeTree(stride(from: 200, to: 300, by: 2))
        almostEven.withCursor(onKey: 280) { $0.key = 281 }

        XCTAssertFalse(firstHalf.isDisjoint(with: firstHalf))
        XCTAssertTrue(firstHalf.isDisjoint(with: secondHalf))
        XCTAssertTrue(firstHalf.isDisjoint(with: even))
        XCTAssertTrue(firstHalf.isDisjoint(with: odd))
        XCTAssertTrue(firstHalf.isDisjoint(with: almostEven))

        XCTAssertTrue(secondHalf.isDisjoint(with: firstHalf))
        XCTAssertFalse(secondHalf.isDisjoint(with: secondHalf))
        XCTAssertTrue(secondHalf.isDisjoint(with: even))
        XCTAssertTrue(secondHalf.isDisjoint(with: odd))
        XCTAssertTrue(secondHalf.isDisjoint(with: almostEven))

        XCTAssertTrue(even.isDisjoint(with: firstHalf))
        XCTAssertTrue(even.isDisjoint(with: secondHalf))
        XCTAssertTrue(even.isDisjoint(with: odd))
        XCTAssertFalse(even.isDisjoint(with: even))
        XCTAssertFalse(even.isDisjoint(with: almostEven))

        XCTAssertTrue(odd.isDisjoint(with: firstHalf))
        XCTAssertTrue(odd.isDisjoint(with: secondHalf))
        XCTAssertFalse(odd.isDisjoint(with: odd))
        XCTAssertTrue(odd.isDisjoint(with: even))
        XCTAssertFalse(odd.isDisjoint(with: almostEven))

        XCTAssertTrue(almostEven.isDisjoint(with: firstHalf))
        XCTAssertTrue(almostEven.isDisjoint(with: secondHalf))
        XCTAssertFalse(almostEven.isDisjoint(with: odd))
        XCTAssertFalse(almostEven.isDisjoint(with: even))
        XCTAssertFalse(almostEven.isDisjoint(with: almostEven))
    }

    func test_isSubsetOf_SimpleCases() {
        let a = makeTree(0 ..< 100)
        let b = makeTree(0 ..< 100)
        let c = makeTree(1 ..< 100)
        let d = makeTree(0 ..< 101)
        let e = makeTree(Array(0 ..< 50) + Array(51 ..< 100))
        let f = makeTree([50])
        
        XCTAssertTrue(a.isSubset(of: b))
        XCTAssertFalse(a.isSubset(of: c))
        XCTAssertTrue(a.isSubset(of: d))
        XCTAssertFalse(a.isSubset(of: e))
        XCTAssertFalse(a.isSubset(of: f))

        XCTAssertTrue(b.isSubset(of: a))
        XCTAssertFalse(b.isSubset(of: c))
        XCTAssertTrue(b.isSubset(of: d))
        XCTAssertFalse(b.isSubset(of: e))
        XCTAssertFalse(b.isSubset(of: f))

        XCTAssertTrue(c.isSubset(of: a))
        XCTAssertTrue(c.isSubset(of: b))
        XCTAssertTrue(c.isSubset(of: d))
        XCTAssertFalse(c.isSubset(of: e))
        XCTAssertFalse(c.isSubset(of: f))

        XCTAssertFalse(d.isSubset(of: a))
        XCTAssertFalse(d.isSubset(of: b))
        XCTAssertFalse(d.isSubset(of: c))
        XCTAssertFalse(d.isSubset(of: e))
        XCTAssertFalse(d.isSubset(of: f))

        XCTAssertTrue(e.isSubset(of: a))
        XCTAssertTrue(e.isSubset(of: b))
        XCTAssertFalse(e.isSubset(of: c))
        XCTAssertTrue(e.isSubset(of: d))
        XCTAssertFalse(e.isSubset(of: f))

        XCTAssertTrue(f.isSubset(of: a))
        XCTAssertTrue(f.isSubset(of: b))
        XCTAssertTrue(f.isSubset(of: c))
        XCTAssertTrue(f.isSubset(of: d))
        XCTAssertFalse(f.isSubset(of: e))
    }

    func test_isStrictSubsetOf_SimpleCases() {
        let a = makeTree(0 ..< 100)
        let b = makeTree(0 ..< 100)
        let c = makeTree(1 ..< 100)
        let d = makeTree(0 ..< 101)
        let e = makeTree(Array(0 ..< 50) + Array(51 ..< 100))
        let f = makeTree([50])
        
        XCTAssertFalse(a.isStrictSubset(of: b))
        XCTAssertFalse(a.isStrictSubset(of: c))
        XCTAssertTrue(a.isStrictSubset(of: d))
        XCTAssertFalse(a.isStrictSubset(of: e))
        XCTAssertFalse(a.isStrictSubset(of: f))

        XCTAssertFalse(b.isStrictSubset(of: a))
        XCTAssertFalse(b.isStrictSubset(of: c))
        XCTAssertTrue(b.isStrictSubset(of: d))
        XCTAssertFalse(b.isStrictSubset(of: e))
        XCTAssertFalse(b.isStrictSubset(of: f))

        XCTAssertTrue(c.isStrictSubset(of: a))
        XCTAssertTrue(c.isStrictSubset(of: b))
        XCTAssertTrue(c.isStrictSubset(of: d))
        XCTAssertFalse(c.isStrictSubset(of: e))
        XCTAssertFalse(c.isStrictSubset(of: f))

        XCTAssertFalse(d.isStrictSubset(of: a))
        XCTAssertFalse(d.isStrictSubset(of: b))
        XCTAssertFalse(d.isStrictSubset(of: c))
        XCTAssertFalse(d.isStrictSubset(of: e))
        XCTAssertFalse(d.isStrictSubset(of: f))

        XCTAssertTrue(e.isStrictSubset(of: a))
        XCTAssertTrue(e.isStrictSubset(of: b))
        XCTAssertFalse(e.isStrictSubset(of: c))
        XCTAssertTrue(e.isStrictSubset(of: d))
        XCTAssertFalse(e.isStrictSubset(of: f))

        XCTAssertTrue(f.isStrictSubset(of: a))
        XCTAssertTrue(f.isStrictSubset(of: b))
        XCTAssertTrue(f.isStrictSubset(of: c))
        XCTAssertTrue(f.isStrictSubset(of: d))
        XCTAssertFalse(f.isStrictSubset(of: e))
    }

    func test_isSupersetOf_SimpleCases() {
        let a = makeTree(0 ..< 100)
        let b = makeTree(0 ..< 100)
        let c = makeTree(1 ..< 100)
        let d = makeTree(0 ..< 101)
        let e = makeTree(Array(0 ..< 50) + Array(51 ..< 100))
        let f = makeTree([50])
        
        XCTAssertTrue(a.isSuperset(of: b))
        XCTAssertTrue(a.isSuperset(of: c))
        XCTAssertFalse(a.isSuperset(of: d))
        XCTAssertTrue(a.isSuperset(of: e))
        XCTAssertTrue(a.isSuperset(of: f))

        XCTAssertTrue(b.isSuperset(of: a))
        XCTAssertTrue(b.isSuperset(of: c))
        XCTAssertFalse(b.isSuperset(of: d))
        XCTAssertTrue(b.isSuperset(of: e))
        XCTAssertTrue(b.isSuperset(of: f))

        XCTAssertFalse(c.isSuperset(of: a))
        XCTAssertFalse(c.isSuperset(of: b))
        XCTAssertFalse(c.isSuperset(of: d))
        XCTAssertFalse(c.isSuperset(of: e))
        XCTAssertTrue(c.isSuperset(of: f))

        XCTAssertTrue(d.isSuperset(of: a))
        XCTAssertTrue(d.isSuperset(of: b))
        XCTAssertTrue(d.isSuperset(of: c))
        XCTAssertTrue(d.isSuperset(of: e))
        XCTAssertTrue(d.isSuperset(of: f))

        XCTAssertFalse(e.isSuperset(of: a))
        XCTAssertFalse(e.isSuperset(of: b))
        XCTAssertFalse(e.isSuperset(of: c))
        XCTAssertFalse(e.isSuperset(of: d))
        XCTAssertFalse(e.isSuperset(of: f))

        XCTAssertFalse(f.isSuperset(of: a))
        XCTAssertFalse(f.isSuperset(of: b))
        XCTAssertFalse(f.isSuperset(of: c))
        XCTAssertFalse(f.isSuperset(of: d))
        XCTAssertFalse(f.isSuperset(of: e))
    }

    func test_isStrictSupersetOf_SimpleCases() {
        let a = makeTree(0 ..< 100)
        let b = makeTree(0 ..< 100)
        let c = makeTree(1 ..< 100)
        let d = makeTree(0 ..< 101)
        let e = makeTree(Array(0 ..< 50) + Array(51 ..< 100))
        let f = makeTree([50])
        
        XCTAssertFalse(b.isStrictSuperset(of: a))
        XCTAssertFalse(c.isStrictSuperset(of: a))
        XCTAssertTrue(d.isStrictSuperset(of: a))
        XCTAssertFalse(e.isStrictSuperset(of: a))
        XCTAssertFalse(f.isStrictSuperset(of: a))

        XCTAssertFalse(a.isStrictSuperset(of: b))
        XCTAssertFalse(c.isStrictSuperset(of: b))
        XCTAssertTrue(d.isStrictSuperset(of: b))
        XCTAssertFalse(e.isStrictSuperset(of: b))
        XCTAssertFalse(f.isStrictSuperset(of: b))

        XCTAssertTrue(a.isStrictSuperset(of: c))
        XCTAssertTrue(b.isStrictSuperset(of: c))
        XCTAssertTrue(d.isStrictSuperset(of: c))
        XCTAssertFalse(e.isStrictSuperset(of: c))
        XCTAssertFalse(f.isStrictSuperset(of: c))

        XCTAssertFalse(a.isStrictSuperset(of: d))
        XCTAssertFalse(b.isStrictSuperset(of: d))
        XCTAssertFalse(c.isStrictSuperset(of: d))
        XCTAssertFalse(e.isStrictSuperset(of: d))
        XCTAssertFalse(f.isStrictSuperset(of: d))

        XCTAssertTrue(a.isStrictSuperset(of: e))
        XCTAssertTrue(b.isStrictSuperset(of: e))
        XCTAssertFalse(c.isStrictSuperset(of: e))
        XCTAssertTrue(d.isStrictSuperset(of: e))
        XCTAssertFalse(f.isStrictSuperset(of: e))

        XCTAssertTrue(a.isStrictSuperset(of: f))
        XCTAssertTrue(b.isStrictSuperset(of: f))
        XCTAssertTrue(c.isStrictSuperset(of: f))
        XCTAssertTrue(d.isStrictSuperset(of: f))
        XCTAssertFalse(e.isStrictSuperset(of: f))
    }

    func test_isSubsetOf_SharedNodes() {
        let x = makeTree(0 ..< 100)
        var y = x
        y.removeLast()
        var z = x
        z.removeFirst()

        XCTAssertTrue(x.isSubset(of: x))
        XCTAssertTrue(y.isSubset(of: x))
        XCTAssertTrue(z.isSubset(of: x))
    }

    func test_isSubsetOf_DuplicateKey() {
        let x = makeTree([0, 0, 0, 1, 1, 1, 1, 2, 2, 2])
        let y = makeTree([0, 1, 1, 1, 2, 2, 2, 2, 2, 3])
        let z = makeTree([0, 1, 2, 3, 4])

        XCTAssertTrue(x.isSubset(of: y))
        XCTAssertTrue(x.isStrictSubset(of: y))
        XCTAssertTrue(x.isSubset(of: z))
        XCTAssertTrue(x.isStrictSubset(of: z))

        XCTAssertFalse(y.isSubset(of: x))
        XCTAssertFalse(y.isStrictSubset(of: x))
        XCTAssertTrue(y.isSubset(of: z))
        XCTAssertTrue(y.isStrictSubset(of: z))

        XCTAssertFalse(z.isSubset(of: x))
        XCTAssertFalse(z.isStrictSubset(of: x))
        XCTAssertFalse(z.isSubset(of: y))
        XCTAssertFalse(z.isStrictSubset(of: y))
    }

    func test_isSubsetOf_() {
        let a = makeTree([3, 4, 5])
        let b = makeTree([0, 1, 2])

        XCTAssertFalse(a.isSubset(of: b))
    }
}
