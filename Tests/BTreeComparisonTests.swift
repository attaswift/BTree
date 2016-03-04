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

private func makeTree<S: SequenceType where S.Generator.Element == Int>(s: S, order: Int = 5, keysPerNode: Int? = nil) -> Tree {
    var b = Builder(order: order, keysPerNode: keysPerNode ?? order - 1)
    for i in s {
        b.append((i, ()))
    }
    return Tree(b.finish())
}

class BTreeComparisonTests: XCTestCase {
    private func elements(range: Range<Int>) -> [Element] {
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

        XCTAssertTrue(a.elementsEqual(a, isEquivalent: { $0.0 == $1.0 }))
        XCTAssertTrue(a.elementsEqual(b, isEquivalent: { $0.0 == $1.0 }))
        XCTAssertFalse(a.elementsEqual(c, isEquivalent: { $0.0 == $1.0 }))
        XCTAssertFalse(a.elementsEqual(d, isEquivalent: { $0.0 == $1.0 }))
        XCTAssertTrue(b.elementsEqual(a, isEquivalent: { $0.0 == $1.0 }))
        XCTAssertFalse(c.elementsEqual(a, isEquivalent: { $0.0 == $1.0 }))
        XCTAssertFalse(d.elementsEqual(a, isEquivalent: { $0.0 == $1.0 }))
    }

    func test_elementsEqual_SharedNodes() {
        let a = makeTree(0 ..< 100)
        var b = a
        b.withCursorAtStart { $0.key = 0 }
        var c = a
        c.withCursorAtPosition(99) { $0.key = 99 }

        XCTAssertTrue(a.elementsEqual(b, isEquivalent: { $0.0 == $1.0 }))
        XCTAssertTrue(a.elementsEqual(c, isEquivalent: { $0.0 == $1.0 }))
        XCTAssertTrue(b.elementsEqual(a, isEquivalent: { $0.0 == $1.0 }))
        XCTAssertTrue(b.elementsEqual(c, isEquivalent: { $0.0 == $1.0 }))
        XCTAssertTrue(c.elementsEqual(a, isEquivalent: { $0.0 == $1.0 }))
        XCTAssertTrue(c.elementsEqual(b, isEquivalent: { $0.0 == $1.0 }))
    }

    func test_elementsEqual_ShiftedSharedNodes() {
        let reference = Array(count: 100, repeatedValue: 42)
        let a = makeTree(reference)
        for i in 0 ..< 100 {
            var b = a
            b.withCursorAtPosition(i) {
                $0.remove()
                $0.moveToEnd()
                $0.insert((42, ()))
            }
            var c = a
            c.withCursorAtPosition(i) {
                $0.insert((42, ()))
                $0.moveToEnd()
                $0.moveBackward()
                $0.remove()
            }
            XCTAssertTrue(a.elementsEqual(b, isEquivalent: { $0.0 == $1.0 }))
            XCTAssertTrue(a.elementsEqual(c, isEquivalent: { $0.0 == $1.0 }))
            XCTAssertTrue(b.elementsEqual(a, isEquivalent: { $0.0 == $1.0 }))
            XCTAssertTrue(b.elementsEqual(c, isEquivalent: { $0.0 == $1.0 }))
            XCTAssertTrue(c.elementsEqual(a, isEquivalent: { $0.0 == $1.0 }))
            XCTAssertTrue(c.elementsEqual(b, isEquivalent: { $0.0 == $1.0 }))

            XCTAssertElementsEqual(a.map { $0.0 }, reference)
        }
    }

    func test_isDisjointWith_SimpleCases() {
        let firstHalf = makeTree(0 ..< 100)
        let secondHalf = makeTree(100 ..< 200)
        let even = makeTree(200.stride(to: 300, by: 2))
        let odd = makeTree(201.stride(to: 300, by: 2))
        var almostEven = makeTree(200.stride(to: 300, by: 2))
        almostEven.withCursorAt(280) { $0.key = 281 }

        XCTAssertFalse(firstHalf.isDisjointWith(firstHalf))
        XCTAssertTrue(firstHalf.isDisjointWith(secondHalf))
        XCTAssertTrue(firstHalf.isDisjointWith(even))
        XCTAssertTrue(firstHalf.isDisjointWith(odd))
        XCTAssertTrue(firstHalf.isDisjointWith(almostEven))

        XCTAssertTrue(secondHalf.isDisjointWith(firstHalf))
        XCTAssertFalse(secondHalf.isDisjointWith(secondHalf))
        XCTAssertTrue(secondHalf.isDisjointWith(even))
        XCTAssertTrue(secondHalf.isDisjointWith(odd))
        XCTAssertTrue(secondHalf.isDisjointWith(almostEven))

        XCTAssertTrue(even.isDisjointWith(firstHalf))
        XCTAssertTrue(even.isDisjointWith(secondHalf))
        XCTAssertTrue(even.isDisjointWith(odd))
        XCTAssertFalse(even.isDisjointWith(even))
        XCTAssertFalse(even.isDisjointWith(almostEven))

        XCTAssertTrue(odd.isDisjointWith(firstHalf))
        XCTAssertTrue(odd.isDisjointWith(secondHalf))
        XCTAssertFalse(odd.isDisjointWith(odd))
        XCTAssertTrue(odd.isDisjointWith(even))
        XCTAssertFalse(odd.isDisjointWith(almostEven))

        XCTAssertTrue(almostEven.isDisjointWith(firstHalf))
        XCTAssertTrue(almostEven.isDisjointWith(secondHalf))
        XCTAssertFalse(almostEven.isDisjointWith(odd))
        XCTAssertFalse(almostEven.isDisjointWith(even))
        XCTAssertFalse(almostEven.isDisjointWith(almostEven))
    }

    func test_isSubsetOf_SimpleCases() {
        let a = makeTree(0 ..< 100)
        let b = makeTree(0 ..< 100)
        let c = makeTree(1 ..< 100)
        let d = makeTree(0 ..< 101)
        let e = makeTree(Array(0 ..< 50) + Array(51 ..< 100))
        let f = makeTree([50])
        
        XCTAssertTrue(a.isSubsetOf(b))
        XCTAssertFalse(a.isSubsetOf(c))
        XCTAssertTrue(a.isSubsetOf(d))
        XCTAssertFalse(a.isSubsetOf(e))
        XCTAssertFalse(a.isSubsetOf(f))

        XCTAssertTrue(b.isSubsetOf(a))
        XCTAssertFalse(b.isSubsetOf(c))
        XCTAssertTrue(b.isSubsetOf(d))
        XCTAssertFalse(b.isSubsetOf(e))
        XCTAssertFalse(b.isSubsetOf(f))

        XCTAssertTrue(c.isSubsetOf(a))
        XCTAssertTrue(c.isSubsetOf(b))
        XCTAssertTrue(c.isSubsetOf(d))
        XCTAssertFalse(c.isSubsetOf(e))
        XCTAssertFalse(c.isSubsetOf(f))

        XCTAssertFalse(d.isSubsetOf(a))
        XCTAssertFalse(d.isSubsetOf(b))
        XCTAssertFalse(d.isSubsetOf(c))
        XCTAssertFalse(d.isSubsetOf(e))
        XCTAssertFalse(d.isSubsetOf(f))

        XCTAssertTrue(e.isSubsetOf(a))
        XCTAssertTrue(e.isSubsetOf(b))
        XCTAssertFalse(e.isSubsetOf(c))
        XCTAssertTrue(e.isSubsetOf(d))
        XCTAssertFalse(e.isSubsetOf(f))

        XCTAssertTrue(f.isSubsetOf(a))
        XCTAssertTrue(f.isSubsetOf(b))
        XCTAssertTrue(f.isSubsetOf(c))
        XCTAssertTrue(f.isSubsetOf(d))
        XCTAssertFalse(f.isSubsetOf(e))
    }

    func test_isStrictSubsetOf_SimpleCases() {
        let a = makeTree(0 ..< 100)
        let b = makeTree(0 ..< 100)
        let c = makeTree(1 ..< 100)
        let d = makeTree(0 ..< 101)
        let e = makeTree(Array(0 ..< 50) + Array(51 ..< 100))
        let f = makeTree([50])
        
        XCTAssertFalse(a.isStrictSubsetOf(b))
        XCTAssertFalse(a.isStrictSubsetOf(c))
        XCTAssertTrue(a.isStrictSubsetOf(d))
        XCTAssertFalse(a.isStrictSubsetOf(e))
        XCTAssertFalse(a.isStrictSubsetOf(f))

        XCTAssertFalse(b.isStrictSubsetOf(a))
        XCTAssertFalse(b.isStrictSubsetOf(c))
        XCTAssertTrue(b.isStrictSubsetOf(d))
        XCTAssertFalse(b.isStrictSubsetOf(e))
        XCTAssertFalse(b.isStrictSubsetOf(f))

        XCTAssertTrue(c.isStrictSubsetOf(a))
        XCTAssertTrue(c.isStrictSubsetOf(b))
        XCTAssertTrue(c.isStrictSubsetOf(d))
        XCTAssertFalse(c.isStrictSubsetOf(e))
        XCTAssertFalse(c.isStrictSubsetOf(f))

        XCTAssertFalse(d.isStrictSubsetOf(a))
        XCTAssertFalse(d.isStrictSubsetOf(b))
        XCTAssertFalse(d.isStrictSubsetOf(c))
        XCTAssertFalse(d.isStrictSubsetOf(e))
        XCTAssertFalse(d.isStrictSubsetOf(f))

        XCTAssertTrue(e.isStrictSubsetOf(a))
        XCTAssertTrue(e.isStrictSubsetOf(b))
        XCTAssertFalse(e.isStrictSubsetOf(c))
        XCTAssertTrue(e.isStrictSubsetOf(d))
        XCTAssertFalse(e.isStrictSubsetOf(f))

        XCTAssertTrue(f.isStrictSubsetOf(a))
        XCTAssertTrue(f.isStrictSubsetOf(b))
        XCTAssertTrue(f.isStrictSubsetOf(c))
        XCTAssertTrue(f.isStrictSubsetOf(d))
        XCTAssertFalse(f.isStrictSubsetOf(e))
    }

    func test_isSupersetOf_SimpleCases() {
        let a = makeTree(0 ..< 100)
        let b = makeTree(0 ..< 100)
        let c = makeTree(1 ..< 100)
        let d = makeTree(0 ..< 101)
        let e = makeTree(Array(0 ..< 50) + Array(51 ..< 100))
        let f = makeTree([50])
        
        XCTAssertTrue(a.isSupersetOf(b))
        XCTAssertTrue(a.isSupersetOf(c))
        XCTAssertFalse(a.isSupersetOf(d))
        XCTAssertTrue(a.isSupersetOf(e))
        XCTAssertTrue(a.isSupersetOf(f))

        XCTAssertTrue(b.isSupersetOf(a))
        XCTAssertTrue(b.isSupersetOf(c))
        XCTAssertFalse(b.isSupersetOf(d))
        XCTAssertTrue(b.isSupersetOf(e))
        XCTAssertTrue(b.isSupersetOf(f))

        XCTAssertFalse(c.isSupersetOf(a))
        XCTAssertFalse(c.isSupersetOf(b))
        XCTAssertFalse(c.isSupersetOf(d))
        XCTAssertFalse(c.isSupersetOf(e))
        XCTAssertTrue(c.isSupersetOf(f))

        XCTAssertTrue(d.isSupersetOf(a))
        XCTAssertTrue(d.isSupersetOf(b))
        XCTAssertTrue(d.isSupersetOf(c))
        XCTAssertTrue(d.isSupersetOf(e))
        XCTAssertTrue(d.isSupersetOf(f))

        XCTAssertFalse(e.isSupersetOf(a))
        XCTAssertFalse(e.isSupersetOf(b))
        XCTAssertFalse(e.isSupersetOf(c))
        XCTAssertFalse(e.isSupersetOf(d))
        XCTAssertFalse(e.isSupersetOf(f))

        XCTAssertFalse(f.isSupersetOf(a))
        XCTAssertFalse(f.isSupersetOf(b))
        XCTAssertFalse(f.isSupersetOf(c))
        XCTAssertFalse(f.isSupersetOf(d))
        XCTAssertFalse(f.isSupersetOf(e))
    }

    func test_isStrictSupersetOf_SimpleCases() {
        let a = makeTree(0 ..< 100)
        let b = makeTree(0 ..< 100)
        let c = makeTree(1 ..< 100)
        let d = makeTree(0 ..< 101)
        let e = makeTree(Array(0 ..< 50) + Array(51 ..< 100))
        let f = makeTree([50])
        
        XCTAssertFalse(b.isStrictSupersetOf(a))
        XCTAssertFalse(c.isStrictSupersetOf(a))
        XCTAssertTrue(d.isStrictSupersetOf(a))
        XCTAssertFalse(e.isStrictSupersetOf(a))
        XCTAssertFalse(f.isStrictSupersetOf(a))

        XCTAssertFalse(a.isStrictSupersetOf(b))
        XCTAssertFalse(c.isStrictSupersetOf(b))
        XCTAssertTrue(d.isStrictSupersetOf(b))
        XCTAssertFalse(e.isStrictSupersetOf(b))
        XCTAssertFalse(f.isStrictSupersetOf(b))

        XCTAssertTrue(a.isStrictSupersetOf(c))
        XCTAssertTrue(b.isStrictSupersetOf(c))
        XCTAssertTrue(d.isStrictSupersetOf(c))
        XCTAssertFalse(e.isStrictSupersetOf(c))
        XCTAssertFalse(f.isStrictSupersetOf(c))

        XCTAssertFalse(a.isStrictSupersetOf(d))
        XCTAssertFalse(b.isStrictSupersetOf(d))
        XCTAssertFalse(c.isStrictSupersetOf(d))
        XCTAssertFalse(e.isStrictSupersetOf(d))
        XCTAssertFalse(f.isStrictSupersetOf(d))

        XCTAssertTrue(a.isStrictSupersetOf(e))
        XCTAssertTrue(b.isStrictSupersetOf(e))
        XCTAssertFalse(c.isStrictSupersetOf(e))
        XCTAssertTrue(d.isStrictSupersetOf(e))
        XCTAssertFalse(f.isStrictSupersetOf(e))

        XCTAssertTrue(a.isStrictSupersetOf(f))
        XCTAssertTrue(b.isStrictSupersetOf(f))
        XCTAssertTrue(c.isStrictSupersetOf(f))
        XCTAssertTrue(d.isStrictSupersetOf(f))
        XCTAssertFalse(e.isStrictSupersetOf(f))
    }

    func test_isSubsetOf_SharedNodes() {
        let x = makeTree(0 ..< 100)
        var y = x
        y.removeLast()
        var z = x
        z.removeFirst()

        XCTAssertTrue(x.isSubsetOf(x))
        XCTAssertTrue(y.isSubsetOf(x))
        XCTAssertTrue(z.isSubsetOf(x))
    }

    func test_isSubsetOf_DuplicateKey() {
        let x = makeTree([0, 0, 0, 1, 1, 1, 1, 2, 2, 2])
        let y = makeTree([0, 1, 1, 1, 2, 2, 2, 2, 2, 3])
        let z = makeTree([0, 1, 2, 3, 4])

        XCTAssertTrue(x.isSubsetOf(y))
        XCTAssertTrue(x.isStrictSubsetOf(y))
        XCTAssertTrue(x.isSubsetOf(z))
        XCTAssertTrue(x.isStrictSubsetOf(z))

        XCTAssertFalse(y.isSubsetOf(x))
        XCTAssertFalse(y.isStrictSubsetOf(x))
        XCTAssertTrue(y.isSubsetOf(z))
        XCTAssertTrue(y.isStrictSubsetOf(z))

        XCTAssertFalse(z.isSubsetOf(x))
        XCTAssertFalse(z.isStrictSubsetOf(x))
        XCTAssertFalse(z.isSubsetOf(y))
        XCTAssertFalse(z.isStrictSubsetOf(y))
    }

    func test_isSubsetOf_() {
        let a = makeTree([3, 4, 5])
        let b = makeTree([0, 1, 2])

        XCTAssertFalse(a.isSubsetOf(b))
    }
}
