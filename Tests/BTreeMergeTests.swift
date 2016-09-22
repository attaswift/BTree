//
//  BTreeMergeTests.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-29.
//  Copyright © 2016 Károly Lőrentey.
//

import XCTest
@testable import BTree

class BTreeMergeTests: XCTestCase {
    typealias Builder = BTreeBuilder<Int, Void>
    typealias Node = BTreeNode<Int, Void>
    typealias Tree = BTree<Int, Void>
    typealias Element = (Int, Void)

    func elements(_ range: CountableRange<Int>) -> [Element] {
        return range.map { ($0, ()) }
    }

    var empty: Tree {
        return Tree(order: 5)
    }

    func makeTree<S: Sequence>(_ s: S, order: Int = 5, keysPerNode: Int? = nil) -> Tree where S.Iterator.Element == Int {
        var b = Builder(order: order, keysPerNode: keysPerNode ?? order - 1)
        for i in s {
            b.append((i, ()))
        }
        return Tree(b.finish())
    }

    //MARK: Union

    func test_Union_simple() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))

        let u0 = empty.union(empty)
        u0.assertValid()
        u0.assertKeysEqual(empty)

        let u1 = even.union(empty)
        u1.assertValid()
        u1.assertKeysEqual(even)

        let u2 = empty.union(even)
        u2.assertValid()
        u2.assertKeysEqual(even)

        let u3 = even.union(even)
        u3.assertValid()
        u3.assertKeysEqual((0 ..< 100).map { $0 & ~1 })
    }

    func test_Union_evenOdd() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))
        let odd = makeTree(stride(from: 1, to: 100, by: 2))

        let u1 = even.union(odd)
        u1.assertValid()
        u1.assertKeysEqual(0 ..< 100)

        let u2 = odd.union(even)
        u2.assertValid()
        u2.assertKeysEqual(0 ..< 100)
    }

    func test_Union_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = first.union(second)
        u1.assertValid()
        u1.assertKeysEqual(0 ..< 100)

        let u2 = second.union(first)
        u2.assertValid()
        u2.assertKeysEqual(0 ..< 100)
    }

    func test_Union_longDuplicates() {
        let first = makeTree((0 ..< 90).repeatEach(20))
        let second = makeTree((90 ..< 200).repeatEach(20))

        let u1 = first.union(second)
        u1.assertValid()
        u1.assertKeysEqual((0 ..< 200).repeatEach(20))

        let u2 = second.union(first)
        u2.assertValid()
        u2.assertKeysEqual((0 ..< 200).repeatEach(20))
    }

    func test_Union_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = first.union(second)
        u1.assertValid()
        u1.assertKeysEqual([0, 0, 0, 0, 0, 0, 1, 1, 3, 3, 3, 4, 6, 6, 6, 6, 6, 7, 7, 8])

        let u2 = second.union(first)
        u2.assertValid()
        u2.assertKeysEqual([0, 0, 0, 0, 0, 0, 1, 1, 3, 3, 3, 4, 6, 6, 6, 6, 6, 7, 7, 8])
    }

    func test_Union_sharedNodes() {
        var first = makeTree((0 ..< 10).repeatEach(20))
        var second = first
        first.withCursor(atOffset: 140) { $0.remove(20) }
        second.withCursor(atOffset: 60) { $0.remove(20) }

        let u1 = first.union(second)
        u1.assertValid()
        u1.assertKeysEqual([0, 0, 1, 1, 2, 2, 3, 4, 4, 5, 5, 6, 6, 7, 8, 8, 9, 9].repeatEach(20))

        let u2 = second.union(first)
        u2.assertValid()
        u2.assertKeysEqual([0, 0, 1, 1, 2, 2, 3, 4, 4, 5, 5, 6, 6, 7, 8, 8, 9, 9].repeatEach(20))
    }

    //MARK: Distinct Union

    func test_DistinctUnion_simple() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))

        let u0 = empty.distinctUnion(empty)
        u0.assertValid()
        u0.assertKeysEqual(empty)

        let u1 = even.distinctUnion(empty)
        u1.assertValid()
        u1.assertKeysEqual(even)

        let u2 = empty.distinctUnion(even)
        u2.assertValid()
        u2.assertKeysEqual(even)

        let u3 = even.distinctUnion(even)
        u3.assertValid()
        u3.assertKeysEqual(stride(from: 0, to: 100, by: 2))
    }

    func test_DistinctUnion_evenOdd() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))
        let odd = makeTree(stride(from: 1, to: 100, by: 2))

        let u1 = even.distinctUnion(odd)
        u1.assertValid()
        u1.assertKeysEqual(0 ..< 100)

        let u2 = odd.distinctUnion(even)
        u2.assertValid()
        u2.assertKeysEqual(0 ..< 100)
    }

    func test_DistinctUnion_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = first.distinctUnion(second)
        u1.assertValid()
        u1.assertKeysEqual(0 ..< 100)

        let u2 = second.distinctUnion(first)
        u2.assertValid()
        u2.assertKeysEqual(0 ..< 100)
    }

    func test_DistinctUnion_longDuplicates() {
        let first = makeTree((0 ..< 100).repeatEach(20))
        let second = makeTree((100 ..< 200).repeatEach(20))

        let u1 = first.distinctUnion(second)
        u1.assertValid()
        u1.assertKeysEqual((0 ..< 200).repeatEach(20))

        let u2 = second.distinctUnion(first)
        u2.assertValid()
        u2.assertKeysEqual((0 ..< 200).repeatEach(20))
    }

    func test_DistinctUnion_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = first.distinctUnion(second)
        u1.assertValid()
        u1.assertKeysEqual([0, 0, 1, 1, 3, 3, 4, 6, 7, 7, 8])

        let u2 = second.distinctUnion(first)
        u2.assertValid()
        u2.assertKeysEqual([0, 0, 0, 0, 1, 1, 3, 4, 6, 6, 6, 6, 7, 7, 8])
    }

    func test_DistinctUnion_sharedNodes() {
        var first = makeTree((0 ..< 10).repeatEach(20))
        var second = first
        first.withCursor(atOffset: 140) { $0.remove(20) }
        second.withCursor(atOffset: 60) { $0.remove(20) }

        let u1 = first.distinctUnion(second)
        u1.assertValid()
        u1.assertKeysEqual([0, 1, 2, 3, 4, 5, 6, 7, 8, 9].repeatEach(20))

        let u2 = second.distinctUnion(first)
        u2.assertValid()
        u2.assertKeysEqual([0, 1, 2, 3, 4, 5, 6, 7, 8, 9].repeatEach(20))
    }

    //MARK: Subtract

    func test_Subtract_simple() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))

        let u0 = empty.subtracting(empty)
        u0.assertValid()
        u0.assertKeysEqual(empty)

        let u1 = even.subtracting(empty)
        u1.assertValid()
        u1.assertKeysEqual(even)

        let u2 = empty.subtracting(even)
        u2.assertValid()
        u2.assertKeysEqual(empty)

        let u3 = even.subtracting(even)
        u3.assertValid()
        u3.assertKeysEqual(empty)
    }

    func test_Subtract_evenOdd() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))
        let odd = makeTree(stride(from: 1, to: 100, by: 2))

        let u1 = even.subtracting(odd)
        u1.assertValid()
        u1.assertKeysEqual(even)

        let u2 = odd.subtracting(even)
        u2.assertValid()
        u2.assertKeysEqual(odd)
    }

    func test_Subtract_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = first.subtracting(second)
        u1.assertValid()
        u1.assertKeysEqual(first)

        let u2 = second.subtracting(first)
        u2.assertValid()
        u2.assertKeysEqual(second)
    }

    func test_Subtract_longDuplicates() {
        let keys = (0 ..< 10).repeatEach(20)
        let first = makeTree(keys[0 ..< 90])
        let second = makeTree(keys[90 ..< 200])

        let u1 = first.subtracting(second)
        u1.assertValid()
        u1.assertKeysEqual((0 ..< 4).repeatEach(20))

        let u2 = second.subtracting(first)
        u2.assertValid()
        u2.assertKeysEqual((5 ..< 10).repeatEach(20))
    }

    func test_Subtract_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = first.subtracting(second)
        u1.assertValid()
        u1.assertKeysEqual([4, 7, 7])

        let u2 = second.subtracting(first)
        u2.assertValid()
        u2.assertKeysEqual([1, 1, 8])
    }

    func test_Subtract_sharedNodes() {
        var first = makeTree((0 ..< 10).repeatEach(20))
        var second = first
        first.withCursor(atOffset: 140) { $0.remove(20) }
        second.withCursor(atOffset: 60) { $0.remove(20) }

        let u1 = first.subtracting(second)
        u1.assertValid()
        u1.assertKeysEqual([3].repeatEach(20))

        let u2 = second.subtracting(first)
        u2.assertValid()
        u2.assertKeysEqual([7].repeatEach(20))
    }
    
    //MARK: Exclusive Or

    func test_ExclusiveOr_simple() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))

        let u0 = empty.symmetricDifference(empty)
        u0.assertValid()
        u0.assertKeysEqual(empty)

        let u1 = even.symmetricDifference(empty)
        u1.assertValid()
        u1.assertKeysEqual(even)

        let u2 = empty.symmetricDifference(even)
        u2.assertValid()
        u2.assertKeysEqual(even)

        let u3 = even.symmetricDifference(even)
        u3.assertValid()
        u3.assertKeysEqual(empty)
    }

    func test_ExclusiveOr_evenOdd() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))
        let odd = makeTree(stride(from: 1, to: 100, by: 2))

        let u1 = even.symmetricDifference(odd)
        u1.assertValid()
        u1.assertKeysEqual(0 ..< 100)

        let u2 = odd.symmetricDifference(even)
        u2.assertValid()
        u2.assertKeysEqual(0 ..< 100)
    }

    func test_ExclusiveOr_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = first.symmetricDifference(second)
        u1.assertValid()
        u1.assertKeysEqual(0 ..< 100)

        let u2 = second.symmetricDifference(first)
        u2.assertValid()
        u2.assertKeysEqual(0 ..< 100)
    }

    func test_ExclusiveOr_longDuplicates() {
        let keys = (0 ..< 10).repeatEach(20)
        let first = makeTree(keys[0 ..< 90])
        let second = makeTree(keys[90 ..< 200])

        let u1 = first.symmetricDifference(second)
        u1.assertValid()
        u1.assertKeysEqual((0 ..< 4).repeatEach(20) + (5 ..< 10).repeatEach(20))

        let u2 = second.symmetricDifference(first)
        u2.assertValid()
        u2.assertKeysEqual((0 ..< 4).repeatEach(20) + (5 ..< 10).repeatEach(20))
    }

    func test_ExclusiveOr_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = first.symmetricDifference(second)
        u1.assertValid()
        u1.assertKeysEqual([1, 1, 4, 7, 7, 8])

        let u2 = second.symmetricDifference(first)
        u2.assertValid()
        u2.assertKeysEqual([1, 1, 4, 7, 7, 8])
    }

    func test_ExclusiveOr_sharedNodes() {
        var first = makeTree((0 ..< 10).repeatEach(20))
        var second = first
        first.withCursor(atOffset: 140) { $0.remove(20) }
        second.withCursor(atOffset: 60) { $0.remove(20) }

        let u1 = first.symmetricDifference(second)
        u1.assertValid()
        u1.assertKeysEqual([3, 7].repeatEach(20))

        let u2 = second.symmetricDifference(first)
        u2.assertValid()
        u2.assertKeysEqual([3, 7].repeatEach(20))
    }


    //MARK: Intersect

    func test_Intersect_simple() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))

        let u0 = empty.intersection(empty)
        u0.assertValid()
        u0.assertKeysEqual(empty)

        let u1 = even.intersection(empty)
        u1.assertValid()
        u1.assertKeysEqual(empty)

        let u2 = empty.intersection(even)
        u2.assertValid()
        u2.assertKeysEqual(empty)

        let u3 = even.intersection(even)
        u3.assertValid()
        u3.assertKeysEqual(even)
    }

    func test_Intersect_evenOdd() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))
        let odd = makeTree(stride(from: 1, to: 100, by: 2))

        let u1 = even.intersection(odd)
        u1.assertValid()
        u1.assertKeysEqual(empty)

        let u2 = odd.intersection(even)
        u2.assertValid()
        u2.assertKeysEqual(empty)
    }

    func test_Intersect_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = first.intersection(second)
        u1.assertValid()
        u1.assertKeysEqual(empty)

        let u2 = second.intersection(first)
        u2.assertValid()
        u2.assertKeysEqual(empty)
    }

    func test_Intersect_longDuplicates() {
        let keys = (0 ..< 10).repeatEach(20)
        let first = makeTree(keys[0 ..< 90])
        let second = makeTree(keys[90 ..< 200])

        let u1 = first.intersection(second)
        u1.assertValid()
        u1.assertKeysEqual([4].repeatEach(10))

        let u2 = second.intersection(first)
        u2.assertValid()
        u2.assertKeysEqual([4].repeatEach(10))
    }

    func test_Intersect_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = first.intersection(second)
        u1.assertValid()
        u1.assertKeysEqual([0, 0, 3, 3, 6])

        let u2 = second.intersection(first)
        u2.assertValid()
        u2.assertKeysEqual([0, 0, 0, 0, 3, 6, 6, 6, 6])
    }

    func test_Intersect_sharedNodes() {
        var first = makeTree((0 ..< 10).repeatEach(20))
        var second = first
        first.withCursor(atOffset: 140) { $0.remove(20) }
        second.withCursor(atOffset: 60) { $0.remove(20) }

        let u1 = first.intersection(second)
        u1.assertValid()
        u1.assertKeysEqual([0, 1, 2, 4, 5, 6, 8, 9].repeatEach(20))

        let u2 = second.intersection(first)
        u2.assertValid()
        u2.assertKeysEqual([0, 1, 2, 4, 5, 6, 8, 9].repeatEach(20))
    }

    // MARK: Sequence-based operations

    func test_subtract_sequence() {
        let tree = BTree(sortedElements: (0 ..< 100).map { ($0, String($0)) })

        assertEqualElements(tree.subtracting(sortedKeys: []), tree)
        assertEqualElements(BTree<Int, String>().subtracting(sortedKeys: [1, 2, 3]), [])

        let t1 = tree.subtracting(sortedKeys: (0 ..< 50).map { 2 * $0 })
        assertEqualElements(t1.map { $0.0 }, (0 ..< 50).map { 2 * $0 + 1 })

        let t2 = tree.subtracting(sortedKeys: 0 ..< 50)
        assertEqualElements(t2.map { $0.0 }, 50 ..< 100)

        let t3 = tree.subtracting(sortedKeys: 50 ..< 100)
        assertEqualElements(t3.map { $0.0 }, 0 ..< 50)

        let t4 = tree.subtracting(sortedKeys: 100 ..< 200)
        assertEqualElements(t4.map { $0.0 }, 0 ..< 100)
    }

    func test_intersect_sequence() {
        let tree = BTree(sortedElements: (0 ..< 100).map { ($0, String($0)) })

        assertEqualElements(tree.intersection(sortedKeys: []), [])
        assertEqualElements(BTree<Int, String>().intersection(sortedKeys: [1, 2, 3]), [])

        let t1 = tree.intersection(sortedKeys: (0 ..< 50).map { 2 * $0 })
        assertEqualElements(t1.map { $0.0 }, (0 ..< 50).map { 2 * $0 })

        let t2 = tree.intersection(sortedKeys: 0 ..< 50)
        assertEqualElements(t2.map { $0.0 }, 0 ..< 50)

        let t3 = tree.intersection(sortedKeys: 50 ..< 100)
        assertEqualElements(t3.map { $0.0 }, 50 ..< 100)

        let t4 = tree.intersection(sortedKeys: 100 ..< 200)
        assertEqualElements(t4.map { $0.0 }, [])
    }
}
