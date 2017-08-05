//
//  BTreeComparisonTests.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-03-04.
//  Copyright © 2016–2017 Károly Lőrentey.
//

import XCTest
@testable import BTree

private typealias Builder = BTreeBuilder<Int, Void>
private typealias Node = BTreeNode<Int, Void>
private typealias Tree = BTree<Int, Void>
private typealias Element = (Int, Void)

private func makeTree<S: Sequence>(_ s: S, order: Int = 5, keysPerNode: Int? = nil) -> Tree where S.Element == Int {
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
        let d = makeTree([0] + Array(0 ..< 99))

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

    func test_elementsEqual_Subtrees() {
        let tree = makeTree((0 ..< 100).repeatEach(3))
        tree.forEachSubtree { subtree in
            XCTAssertEqual(subtree.elementsEqual(tree, by: { $0.0 == $1.0 }), subtree.count == tree.count)
            XCTAssertEqual(tree.elementsEqual(subtree, by: { $0.0 == $1.0 }), subtree.count == tree.count)
        }
    }

    func test_elementsEqual_sharedSuffix() {
        let a = makeTree((0 ..< 100).repeatEach(3))
        var b = a
        b.removeFirst()
        b.insert((0, ()))

        XCTAssertTrue(a.elementsEqual(b, by: { $0.0 == $1.0 }))
        XCTAssertTrue(b.elementsEqual(a, by: { $0.0 == $1.0 }))
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

        for strategy in [BTreeMatchingStrategy.groupingMatches, .countingMatches] {
            XCTAssertTrue(a.isSubset(of: b, by: strategy))
            XCTAssertFalse(a.isSubset(of: c, by: strategy))
            XCTAssertTrue(a.isSubset(of: d, by: strategy))
            XCTAssertFalse(a.isSubset(of: e, by: strategy))
            XCTAssertFalse(a.isSubset(of: f, by: strategy))

            XCTAssertTrue(b.isSubset(of: a, by: strategy))
            XCTAssertFalse(b.isSubset(of: c, by: strategy))
            XCTAssertTrue(b.isSubset(of: d, by: strategy))
            XCTAssertFalse(b.isSubset(of: e, by: strategy))
            XCTAssertFalse(b.isSubset(of: f, by: strategy))

            XCTAssertTrue(c.isSubset(of: a, by: strategy))
            XCTAssertTrue(c.isSubset(of: b, by: strategy))
            XCTAssertTrue(c.isSubset(of: d, by: strategy))
            XCTAssertFalse(c.isSubset(of: e, by: strategy))
            XCTAssertFalse(c.isSubset(of: f, by: strategy))

            XCTAssertFalse(d.isSubset(of: a, by: strategy))
            XCTAssertFalse(d.isSubset(of: b, by: strategy))
            XCTAssertFalse(d.isSubset(of: c, by: strategy))
            XCTAssertFalse(d.isSubset(of: e, by: strategy))
            XCTAssertFalse(d.isSubset(of: f, by: strategy))

            XCTAssertTrue(e.isSubset(of: a, by: strategy))
            XCTAssertTrue(e.isSubset(of: b, by: strategy))
            XCTAssertFalse(e.isSubset(of: c, by: strategy))
            XCTAssertTrue(e.isSubset(of: d, by: strategy))
            XCTAssertFalse(e.isSubset(of: f, by: strategy))

            XCTAssertTrue(f.isSubset(of: a, by: strategy))
            XCTAssertTrue(f.isSubset(of: b, by: strategy))
            XCTAssertTrue(f.isSubset(of: c, by: strategy))
            XCTAssertTrue(f.isSubset(of: d, by: strategy))
            XCTAssertFalse(f.isSubset(of: e, by: strategy))
        }
    }

    func test_isStrictSubsetOf_SimpleCases() {
        let a = makeTree(0 ..< 100)
        let b = makeTree(0 ..< 100)
        let c = makeTree(1 ..< 100)
        let d = makeTree(0 ..< 101)
        let e = makeTree(Array(0 ..< 50) + Array(51 ..< 100))
        let f = makeTree([50])

        for strategy in [BTreeMatchingStrategy.groupingMatches, .countingMatches] {
            XCTAssertFalse(a.isStrictSubset(of: b, by: strategy))
            XCTAssertFalse(a.isStrictSubset(of: c, by: strategy))
            XCTAssertTrue(a.isStrictSubset(of: d, by: strategy))
            XCTAssertFalse(a.isStrictSubset(of: e, by: strategy))
            XCTAssertFalse(a.isStrictSubset(of: f, by: strategy))

            XCTAssertFalse(b.isStrictSubset(of: a, by: strategy))
            XCTAssertFalse(b.isStrictSubset(of: c, by: strategy))
            XCTAssertTrue(b.isStrictSubset(of: d, by: strategy))
            XCTAssertFalse(b.isStrictSubset(of: e, by: strategy))
            XCTAssertFalse(b.isStrictSubset(of: f, by: strategy))

            XCTAssertTrue(c.isStrictSubset(of: a, by: strategy))
            XCTAssertTrue(c.isStrictSubset(of: b, by: strategy))
            XCTAssertTrue(c.isStrictSubset(of: d, by: strategy))
            XCTAssertFalse(c.isStrictSubset(of: e, by: strategy))
            XCTAssertFalse(c.isStrictSubset(of: f, by: strategy))

            XCTAssertFalse(d.isStrictSubset(of: a, by: strategy))
            XCTAssertFalse(d.isStrictSubset(of: b, by: strategy))
            XCTAssertFalse(d.isStrictSubset(of: c, by: strategy))
            XCTAssertFalse(d.isStrictSubset(of: e, by: strategy))
            XCTAssertFalse(d.isStrictSubset(of: f, by: strategy))

            XCTAssertTrue(e.isStrictSubset(of: a, by: strategy))
            XCTAssertTrue(e.isStrictSubset(of: b, by: strategy))
            XCTAssertFalse(e.isStrictSubset(of: c, by: strategy))
            XCTAssertTrue(e.isStrictSubset(of: d, by: strategy))
            XCTAssertFalse(e.isStrictSubset(of: f, by: strategy))

            XCTAssertTrue(f.isStrictSubset(of: a, by: strategy))
            XCTAssertTrue(f.isStrictSubset(of: b, by: strategy))
            XCTAssertTrue(f.isStrictSubset(of: c, by: strategy))
            XCTAssertTrue(f.isStrictSubset(of: d, by: strategy))
            XCTAssertFalse(f.isStrictSubset(of: e, by: strategy))
        }
    }

    func test_isSupersetOf_SimpleCases() {
        let a = makeTree(0 ..< 100)
        let b = makeTree(0 ..< 100)
        let c = makeTree(1 ..< 100)
        let d = makeTree(0 ..< 101)
        let e = makeTree(Array(0 ..< 50) + Array(51 ..< 100))
        let f = makeTree([50])

        for strategy in [BTreeMatchingStrategy.groupingMatches, .countingMatches] {
            XCTAssertTrue(a.isSuperset(of: b, by: strategy))
            XCTAssertTrue(a.isSuperset(of: c, by: strategy))
            XCTAssertFalse(a.isSuperset(of: d, by: strategy))
            XCTAssertTrue(a.isSuperset(of: e, by: strategy))
            XCTAssertTrue(a.isSuperset(of: f, by: strategy))

            XCTAssertTrue(b.isSuperset(of: a, by: strategy))
            XCTAssertTrue(b.isSuperset(of: c, by: strategy))
            XCTAssertFalse(b.isSuperset(of: d, by: strategy))
            XCTAssertTrue(b.isSuperset(of: e, by: strategy))
            XCTAssertTrue(b.isSuperset(of: f, by: strategy))

            XCTAssertFalse(c.isSuperset(of: a, by: strategy))
            XCTAssertFalse(c.isSuperset(of: b, by: strategy))
            XCTAssertFalse(c.isSuperset(of: d, by: strategy))
            XCTAssertFalse(c.isSuperset(of: e, by: strategy))
            XCTAssertTrue(c.isSuperset(of: f, by: strategy))

            XCTAssertTrue(d.isSuperset(of: a, by: strategy))
            XCTAssertTrue(d.isSuperset(of: b, by: strategy))
            XCTAssertTrue(d.isSuperset(of: c, by: strategy))
            XCTAssertTrue(d.isSuperset(of: e, by: strategy))
            XCTAssertTrue(d.isSuperset(of: f, by: strategy))

            XCTAssertFalse(e.isSuperset(of: a, by: strategy))
            XCTAssertFalse(e.isSuperset(of: b, by: strategy))
            XCTAssertFalse(e.isSuperset(of: c, by: strategy))
            XCTAssertFalse(e.isSuperset(of: d, by: strategy))
            XCTAssertFalse(e.isSuperset(of: f, by: strategy))

            XCTAssertFalse(f.isSuperset(of: a, by: strategy))
            XCTAssertFalse(f.isSuperset(of: b, by: strategy))
            XCTAssertFalse(f.isSuperset(of: c, by: strategy))
            XCTAssertFalse(f.isSuperset(of: d, by: strategy))
            XCTAssertFalse(f.isSuperset(of: e, by: strategy))
        }
    }

    func test_isStrictSupersetOf_SimpleCases() {
        let a = makeTree(0 ..< 100)
        let b = makeTree(0 ..< 100)
        let c = makeTree(1 ..< 100)
        let d = makeTree(0 ..< 101)
        let e = makeTree(Array(0 ..< 50) + Array(51 ..< 100))
        let f = makeTree([50])

        for strategy in [BTreeMatchingStrategy.groupingMatches, .countingMatches] {
            XCTAssertFalse(b.isStrictSuperset(of: a, by: strategy))
            XCTAssertFalse(c.isStrictSuperset(of: a, by: strategy))
            XCTAssertTrue(d.isStrictSuperset(of: a, by: strategy))
            XCTAssertFalse(e.isStrictSuperset(of: a, by: strategy))
            XCTAssertFalse(f.isStrictSuperset(of: a, by: strategy))

            XCTAssertFalse(a.isStrictSuperset(of: b, by: strategy))
            XCTAssertFalse(c.isStrictSuperset(of: b, by: strategy))
            XCTAssertTrue(d.isStrictSuperset(of: b, by: strategy))
            XCTAssertFalse(e.isStrictSuperset(of: b, by: strategy))
            XCTAssertFalse(f.isStrictSuperset(of: b, by: strategy))

            XCTAssertTrue(a.isStrictSuperset(of: c, by: strategy))
            XCTAssertTrue(b.isStrictSuperset(of: c, by: strategy))
            XCTAssertTrue(d.isStrictSuperset(of: c, by: strategy))
            XCTAssertFalse(e.isStrictSuperset(of: c, by: strategy))
            XCTAssertFalse(f.isStrictSuperset(of: c, by: strategy))

            XCTAssertFalse(a.isStrictSuperset(of: d, by: strategy))
            XCTAssertFalse(b.isStrictSuperset(of: d, by: strategy))
            XCTAssertFalse(c.isStrictSuperset(of: d, by: strategy))
            XCTAssertFalse(e.isStrictSuperset(of: d, by: strategy))
            XCTAssertFalse(f.isStrictSuperset(of: d, by: strategy))

            XCTAssertTrue(a.isStrictSuperset(of: e, by: strategy))
            XCTAssertTrue(b.isStrictSuperset(of: e, by: strategy))
            XCTAssertFalse(c.isStrictSuperset(of: e, by: strategy))
            XCTAssertTrue(d.isStrictSuperset(of: e, by: strategy))
            XCTAssertFalse(f.isStrictSuperset(of: e, by: strategy))

            XCTAssertTrue(a.isStrictSuperset(of: f, by: strategy))
            XCTAssertTrue(b.isStrictSuperset(of: f, by: strategy))
            XCTAssertTrue(c.isStrictSuperset(of: f, by: strategy))
            XCTAssertTrue(d.isStrictSuperset(of: f, by: strategy))
            XCTAssertFalse(e.isStrictSuperset(of: f, by: strategy))
        }
    }

    func test_isSubsetOf_SharedNodes() {
        let x = makeTree(0 ..< 100)
        var y = x
        y.removeLast()
        var z = x
        z.removeFirst()

        for strategy in [BTreeMatchingStrategy.groupingMatches, .countingMatches] {
            XCTAssertTrue(x.isSubset(of: x, by: strategy))
            XCTAssertTrue(y.isSubset(of: x, by: strategy))
            XCTAssertTrue(z.isSubset(of: x, by: strategy))
        }
    }

    func test_isSubsetOf_Subtrees() {
        let tree = makeTree((0 ..< 100).repeatEach(3))
        tree.forEachSubtree { subtree in
            XCTAssertTrue(subtree.isSubset(of: tree, by: .groupingMatches))
            XCTAssertTrue(subtree.isSubset(of: tree, by: .countingMatches))

            XCTAssertEqual(tree.isSubset(of: subtree, by: .groupingMatches), subtree.count == tree.count)
            XCTAssertEqual(tree.isSubset(of: subtree, by: .countingMatches), subtree.count == tree.count)

            XCTAssertEqual(subtree.isStrictSubset(of: tree, by: .groupingMatches), subtree.count != tree.count)
            XCTAssertEqual(subtree.isStrictSubset(of: tree, by: .countingMatches), subtree.count != tree.count)
            XCTAssertFalse(tree.isStrictSubset(of: subtree, by: .groupingMatches))

            XCTAssertFalse(tree.isStrictSubset(of: subtree, by: .countingMatches))
        }
    }

    func test_isSupersetOf_Subtrees() {
        let tree = makeTree((0 ..< 100).repeatEach(3))
        tree.forEachSubtree { subtree in
            XCTAssertTrue(tree.isSuperset(of: subtree, by: .groupingMatches))
            XCTAssertTrue(tree.isSuperset(of: subtree, by: .countingMatches))

            XCTAssertEqual(subtree.isSuperset(of: tree, by: .groupingMatches), subtree.count == tree.count)
            XCTAssertEqual(subtree.isSuperset(of: tree, by: .countingMatches), subtree.count == tree.count)

            XCTAssertEqual(tree.isStrictSuperset(of: subtree, by: .groupingMatches), subtree.count != tree.count)
            XCTAssertEqual(tree.isStrictSuperset(of: subtree, by: .countingMatches), subtree.count != tree.count)

            XCTAssertFalse(subtree.isStrictSuperset(of: tree, by: .groupingMatches))
            XCTAssertFalse(subtree.isStrictSuperset(of: tree, by: .countingMatches))
        }
    }

    func test_isSubsetOf_DuplicateKey() {
        let x = makeTree([0, 0, 0, 1, 1, 1, 1, 2, 2, 2])
        let y = makeTree([0, 1, 1, 1, 2, 2, 2, 2, 2, 3])
        let z = makeTree([0, 1, 2, 3, 4])

        XCTAssertTrue(x.isSubset(of: y, by: .groupingMatches))
        XCTAssertTrue(x.isSubset(of: z, by: .groupingMatches))
        XCTAssertTrue(x.isStrictSubset(of: y, by: .groupingMatches))
        XCTAssertTrue(x.isStrictSubset(of: z, by: .groupingMatches))

        XCTAssertFalse(x.isSubset(of: y, by: .countingMatches))
        XCTAssertFalse(x.isSubset(of: z, by: .countingMatches))
        XCTAssertFalse(x.isStrictSubset(of: y, by: .countingMatches))
        XCTAssertFalse(x.isStrictSubset(of: z, by: .countingMatches))

        XCTAssertFalse(y.isSubset(of: x, by: .groupingMatches))
        XCTAssertTrue(y.isSubset(of: z, by: .groupingMatches))
        XCTAssertFalse(y.isStrictSubset(of: x, by: .groupingMatches))
        XCTAssertTrue(y.isStrictSubset(of: z, by: .groupingMatches))

        XCTAssertFalse(y.isSubset(of: x, by: .countingMatches))
        XCTAssertFalse(y.isSubset(of: z, by: .countingMatches))
        XCTAssertFalse(y.isStrictSubset(of: x, by: .countingMatches))
        XCTAssertFalse(y.isStrictSubset(of: z, by: .countingMatches))

        XCTAssertFalse(z.isSubset(of: x, by: .groupingMatches))
        XCTAssertFalse(z.isSubset(of: y, by: .groupingMatches))
        XCTAssertFalse(z.isStrictSubset(of: x, by: .groupingMatches))
        XCTAssertFalse(z.isStrictSubset(of: y, by: .groupingMatches))

        XCTAssertFalse(z.isSubset(of: x, by: .countingMatches))
        XCTAssertFalse(z.isSubset(of: y, by: .countingMatches))
        XCTAssertFalse(z.isStrictSubset(of: x, by: .countingMatches))
        XCTAssertFalse(z.isStrictSubset(of: y, by: .countingMatches))
    }

    func test_isSubsetOf_LongDuplicateKeyRuns() {
        let a1 = makeTree(Array(repeating: 0, count: 20) + Array(repeating: 1, count: 100) + Array(repeating: 2, count: 30))
        let a2 = makeTree(Array(repeating: 0, count: 20) + Array(repeating: 1, count: 100) + Array(repeating: 2, count: 30))
        let b = makeTree(Array(repeating: 0, count: 20) + Array(repeating: 1, count: 99) + Array(repeating: 2, count: 30))
        let c = makeTree(Array(repeating: 0, count: 20) + Array(repeating: 1, count: 101) + Array(repeating: 2, count: 30))

        XCTAssertTrue(a1.isSubset(of: a2, by: .groupingMatches))
        XCTAssertTrue(a1.isSubset(of: b, by: .groupingMatches))
        XCTAssertTrue(a1.isSubset(of: c, by: .groupingMatches))

        XCTAssertFalse(a1.isStrictSubset(of: a2, by: .groupingMatches))
        XCTAssertFalse(a1.isStrictSubset(of: b, by: .groupingMatches))
        XCTAssertFalse(a1.isStrictSubset(of: c, by: .groupingMatches))

        XCTAssertTrue(a1.isSubset(of: a2, by: .countingMatches))
        XCTAssertFalse(a1.isSubset(of: b, by: .countingMatches))
        XCTAssertTrue(a1.isSubset(of: c, by: .countingMatches))

        XCTAssertFalse(a1.isStrictSubset(of: a2, by: .countingMatches))
        XCTAssertFalse(a1.isStrictSubset(of: b, by: .countingMatches))
        XCTAssertTrue(a1.isStrictSubset(of: c, by: .countingMatches))
    }
}
