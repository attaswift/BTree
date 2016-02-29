//
//  BTreeMergeTests.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-29.
//  Copyright © 2016 Károly Lőrentey.
//

import XCTest
@testable import BTree

private func assertEqual<Key: Comparable, Payload>(t1: BTree<Key, Payload>, _ t2: BTree<Key, Payload>, file: FileString = __FILE__, line: UInt = __LINE__) {
    XCTAssertElementsEqual(t1.map { $0.0 }, t2.map { $0.0 }, file: file, line: line)
}

private func assertEqual<Key: Comparable, Payload, S: SequenceType where S.Generator.Element == Key>(t1: BTree<Key, Payload>, _ s: S, file: FileString = __FILE__, line: UInt = __LINE__) {
    XCTAssertElementsEqual(t1.map { $0.0 }, s, file: file, line: line)
}

class BTreeMergeTests: XCTestCase {
    typealias Builder = BTreeBuilder<Int, Void>
    typealias Node = BTreeNode<Int, Void>
    typealias Tree = BTree<Int, Void>
    typealias Element = (Int, Void)

    func elements(range: Range<Int>) -> [Element] {
        return range.map { ($0, ()) }
    }

    var empty: Tree {
        return Tree(order: 5)
    }

    func makeTree<S: SequenceType where S.Generator.Element == Int>(s: S, order: Int = 5, keysPerNode: Int? = nil) -> Tree {
        var b = Builder(order: order, keysPerNode: keysPerNode ?? order - 1)
        for i in s {
            b.append((i, ()))
        }
        return Tree(b.finish())
    }

    //MARK: Union

    func test_Union_simple() {
        let even = makeTree(0.stride(to: 100, by: 2))

        let u0 = Tree.union(empty, empty)
        u0.assertValid()
        assertEqual(u0, empty)

        let u1 = Tree.union(even, empty)
        u1.assertValid()
        assertEqual(u1, even)

        let u2 = Tree.union(empty, even)
        u2.assertValid()
        assertEqual(u2, even)

        let u3 = Tree.union(even, even)
        u3.assertValid()
        assertEqual(u3, (0 ..< 100).map { $0 & ~1 })
    }

    func test_Union_evenOdd() {
        let even = makeTree(0.stride(to: 100, by: 2))
        let odd = makeTree(1.stride(to: 100, by: 2))

        let u1 = Tree.union(even, odd)
        u1.assertValid()
        assertEqual(u1, 0 ..< 100)

        let u2 = Tree.union(odd, even)
        u2.assertValid()
        assertEqual(u2, 0 ..< 100)
    }

    func test_Union_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = Tree.union(first, second)
        u1.assertValid()
        assertEqual(u1, 0 ..< 100)

        let u2 = Tree.union(second, first)
        u2.assertValid()
        assertEqual(u2, 0 ..< 100)
    }

    func test_Union_longDuplicates() {
        let first = makeTree((0 ..< 90).map { $0 / 20 })
        let second = makeTree((90 ..< 200).map { $0 / 20 })

        let u1 = Tree.union(first, second)
        u1.assertValid()
        assertEqual(u1, (0 ..< 200).map { $0 / 20 })

        let u2 = Tree.union(second, first)
        u2.assertValid()
        assertEqual(u2, (0 ..< 200).map { $0 / 20 })
    }

    //MARK: Distinct Union

    func test_DistinctUnion_simple() {
        let even = makeTree(0.stride(to: 100, by: 2))

        let u0 = Tree.distinctUnion(empty, empty)
        u0.assertValid()
        assertEqual(u0, empty)

        let u1 = Tree.distinctUnion(even, empty)
        u1.assertValid()
        assertEqual(u1, even)

        let u2 = Tree.distinctUnion(empty, even)
        u2.assertValid()
        assertEqual(u2, even)

        let u3 = Tree.distinctUnion(even, even)
        u3.assertValid()
        assertEqual(u3, 0.stride(to: 100, by: 2))
    }

    func test_DistinctUnion_evenOdd() {
        let even = makeTree(0.stride(to: 100, by: 2))
        let odd = makeTree(1.stride(to: 100, by: 2))

        let u1 = Tree.distinctUnion(even, odd)
        u1.assertValid()
        assertEqual(u1, 0 ..< 100)

        let u2 = Tree.distinctUnion(odd, even)
        u2.assertValid()
        assertEqual(u2, 0 ..< 100)
    }

    func test_DistinctUnion_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = Tree.distinctUnion(first, second)
        u1.assertValid()
        assertEqual(u1, 0 ..< 100)

        let u2 = Tree.distinctUnion(second, first)
        u2.assertValid()
        assertEqual(u2, 0 ..< 100)
    }

    func test_DistinctUnion_longDuplicates() {
        let first = makeTree((0 ..< 100).map { $0 / 20 })
        let second = makeTree((100 ..< 200).map { $0 / 20 })

        let u1 = Tree.distinctUnion(first, second)
        u1.assertValid()
        assertEqual(u1, (0 ..< 200).map { $0 / 20 })

        let u2 = Tree.distinctUnion(second, first)
        u2.assertValid()
        assertEqual(u2, (0 ..< 200).map { $0 / 20 })
    }

    func test_DistinctUnion_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = Tree.distinctUnion(first, second)
        u1.assertValid()
        assertEqual(u1, [0, 0, 1, 1, 3, 3, 4, 6, 7, 7, 8])

        let u2 = Tree.distinctUnion(second, first)
        u2.assertValid()
        assertEqual(u2, [0, 0, 0, 0, 1, 1, 3, 4, 6, 6, 6, 6, 7, 7, 8])
    }

    //MARK: Subtract

    func test_Subtract_simple() {
        let even = makeTree(0.stride(to: 100, by: 2))

        let u0 = Tree.subtract(empty, empty)
        u0.assertValid()
        assertEqual(u0, empty)

        let u1 = Tree.subtract(even, empty)
        u1.assertValid()
        assertEqual(u1, even)

        let u2 = Tree.subtract(empty, even)
        u2.assertValid()
        assertEqual(u2, empty)

        let u3 = Tree.subtract(even, even)
        u3.assertValid()
        assertEqual(u3, empty)
    }

    func test_Subtract_evenOdd() {
        let even = makeTree(0.stride(to: 100, by: 2))
        let odd = makeTree(1.stride(to: 100, by: 2))

        let u1 = Tree.subtract(even, odd)
        u1.assertValid()
        assertEqual(u1, even)

        let u2 = Tree.subtract(odd, even)
        u2.assertValid()
        assertEqual(u2, odd)
    }

    func test_Subtract_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = Tree.subtract(first, second)
        u1.assertValid()
        assertEqual(u1, first)

        let u2 = Tree.subtract(second, first)
        u2.assertValid()
        assertEqual(u2, second)
    }

    func test_Subtract_longDuplicates() {
        let first = makeTree((0 ..< 90).map { $0 / 20 })
        let second = makeTree((90 ..< 200).map { $0 / 20 })

        let u1 = Tree.subtract(first, second)
        u1.assertValid()
        assertEqual(u1, (0 ..< 80).map { $0 / 20 })

        let u2 = Tree.subtract(second, first)
        u2.assertValid()
        assertEqual(u2, (100 ..< 200).map { $0 / 20 })
    }

    func test_Subtract_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = Tree.subtract(first, second)
        u1.assertValid()
        assertEqual(u1, [4, 7, 7])

        let u2 = Tree.subtract(second, first)
        u2.assertValid()
        assertEqual(u2, [1, 1, 8])
    }

    //MARK: Exclusive Or

    func test_ExclusiveOr_simple() {
        let even = makeTree(0.stride(to: 100, by: 2))

        let u0 = Tree.exclusiveOr(empty, empty)
        u0.assertValid()
        assertEqual(u0, empty)

        let u1 = Tree.exclusiveOr(even, empty)
        u1.assertValid()
        assertEqual(u1, even)

        let u2 = Tree.exclusiveOr(empty, even)
        u2.assertValid()
        assertEqual(u2, even)

        let u3 = Tree.exclusiveOr(even, even)
        u3.assertValid()
        assertEqual(u3, empty)
    }

    func test_ExclusiveOr_evenOdd() {
        let even = makeTree(0.stride(to: 100, by: 2))
        let odd = makeTree(1.stride(to: 100, by: 2))

        let u1 = Tree.exclusiveOr(even, odd)
        u1.assertValid()
        assertEqual(u1, 0 ..< 100)

        let u2 = Tree.exclusiveOr(odd, even)
        u2.assertValid()
        assertEqual(u2, 0 ..< 100)
    }

    func test_ExclusiveOr_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = Tree.exclusiveOr(first, second)
        u1.assertValid()
        assertEqual(u1, 0 ..< 100)

        let u2 = Tree.exclusiveOr(second, first)
        u2.assertValid()
        assertEqual(u2, 0 ..< 100)
    }

    func test_ExclusiveOr_longDuplicates() {
        let first = makeTree((0 ..< 90).map { $0 / 20 })
        let second = makeTree((90 ..< 200).map { $0 / 20 })

        let u1 = Tree.exclusiveOr(first, second)
        u1.assertValid()
        assertEqual(u1, (0 ..< 80).map { $0 / 20 } + (100 ..< 200).map { $0 / 20 })

        let u2 = Tree.exclusiveOr(second, first)
        u2.assertValid()
        assertEqual(u2, (0 ..< 80).map { $0 / 20 } + (100 ..< 200).map { $0 / 20 })
    }

    func test_ExclusiveOr_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = Tree.exclusiveOr(first, second)
        u1.assertValid()
        assertEqual(u1, [1, 1, 4, 7, 7, 8])

        let u2 = Tree.exclusiveOr(second, first)
        u2.assertValid()
        assertEqual(u2, [1, 1, 4, 7, 7, 8])
    }

    //MARK: Intersect

    func test_Intersect_simple() {
        let even = makeTree(0.stride(to: 100, by: 2))

        let u0 = Tree.intersect(empty, empty)
        u0.assertValid()
        assertEqual(u0, empty)

        let u1 = Tree.intersect(even, empty)
        u1.assertValid()
        assertEqual(u1, empty)

        let u2 = Tree.intersect(empty, even)
        u2.assertValid()
        assertEqual(u2, empty)

        let u3 = Tree.intersect(even, even)
        u3.assertValid()
        assertEqual(u3, even)
    }

    func test_Intersect_evenOdd() {
        let even = makeTree(0.stride(to: 100, by: 2))
        let odd = makeTree(1.stride(to: 100, by: 2))

        let u1 = Tree.intersect(even, odd)
        u1.assertValid()
        assertEqual(u1, empty)

        let u2 = Tree.intersect(odd, even)
        u2.assertValid()
        assertEqual(u2, empty)
    }

    func test_Intersect_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = Tree.intersect(first, second)
        u1.assertValid()
        assertEqual(u1, empty)

        let u2 = Tree.intersect(second, first)
        u2.assertValid()
        assertEqual(u2, empty)
    }

    func test_Intersect_longDuplicates() {
        let first = makeTree((0 ..< 90).map { $0 / 20 })
        let second = makeTree((90 ..< 200).map { $0 / 20 })

        let u1 = Tree.intersect(first, second)
        u1.assertValid()
        assertEqual(u1, (90 ..< 100).map { $0 / 20 })

        let u2 = Tree.intersect(second, first)
        u2.assertValid()
        assertEqual(u2, (90 ..< 100).map { $0 / 20 })
    }

    func test_Intersect_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = Tree.intersect(first, second)
        u1.assertValid()
        assertEqual(u1, [0, 0, 3, 3, 6])

        let u2 = Tree.intersect(second, first)
        u2.assertValid()
        assertEqual(u2, [0, 0, 0, 0, 3, 6, 6, 6, 6])
    }

}