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
        for i in s.sorted() {
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

    func test_Union_subtrees() {
        let count = 50
        let keys = DictionaryBag((0 ..< count).repeatEach(3))
        let tree = makeTree(keys)
        tree.forEachSubtree { subtree in
            let expected = keys.union(subtree.map { $0.0 }).sorted()
            
            let u1 = subtree.union(tree)
            u1.assertKeysEqual(expected)

            let u2 = tree.union(subtree)
            u2.assertKeysEqual(expected)
        }
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

    func test_DistinctUnion_subtrees() {
        let count = 50
        let keys = DictionaryBag((0 ..< count).repeatEach(3))
        let tree = makeTree(keys)
        tree.forEachSubtree { subtree in
            let u1 = subtree.distinctUnion(tree)
            u1.assertKeysEqual(tree.map { $0.0 })

            let expected = keys.subtractingAll(subtree.map { $0.0 }).union(subtree.map { $0.0 }).sorted()
            let u2 = tree.distinctUnion(subtree)
            u2.assertKeysEqual(expected)
        }
    }

    //MARK: Subtraction

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

    func test_Subtract_subtrees() {
        let count = 50
        let keys = DictionaryBag((0 ..< count).repeatEach(3))
        let tree = makeTree(keys)
        tree.forEachSubtree { subtree in
            let u1 = subtree.subtracting(tree)
            u1.assertKeysEqual([])

            let u2 = tree.subtracting(subtree)
            u2.assertKeysEqual(keys.subtractingAll(subtree.map { $0.0 }).sorted())
        }
    }

    //MARK: Bag Subtraction

    func test_BagSubtract_simple() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))

        let u0 = empty.bagSubtracting(empty)
        u0.assertValid()
        u0.assertKeysEqual(empty)

        let u1 = even.bagSubtracting(empty)
        u1.assertValid()
        u1.assertKeysEqual(even)

        let u2 = empty.bagSubtracting(even)
        u2.assertValid()
        u2.assertKeysEqual(empty)

        let u3 = even.bagSubtracting(even)
        u3.assertValid()
        u3.assertKeysEqual(empty)
    }

    func test_BagSubtract_evenOdd() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))
        let odd = makeTree(stride(from: 1, to: 100, by: 2))

        let u1 = even.bagSubtracting(odd)
        u1.assertValid()
        u1.assertKeysEqual(even)

        let u2 = odd.bagSubtracting(even)
        u2.assertValid()
        u2.assertKeysEqual(odd)
    }

    func test_BagSubtract_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = first.bagSubtracting(second)
        u1.assertValid()
        u1.assertKeysEqual(first)

        let u2 = second.bagSubtracting(first)
        u2.assertValid()
        u2.assertKeysEqual(second)
    }

    func test_BagSubtract_longDuplicates() {
        let keys = (0 ..< 10).repeatEach(20)
        let first = makeTree(keys[0 ..< 95])
        let second = makeTree(keys[95 ..< 200])

        let u1 = first.bagSubtracting(second)
        u1.assertValid()
        u1.assertKeysEqual((0 ..< 4).repeatEach(20) + Array(repeating: 4, count: 10))

        let u2 = second.bagSubtracting(first)
        u2.assertValid()
        u2.assertKeysEqual((5 ..< 10).repeatEach(20))
    }

    func test_BagSubtract_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = first.bagSubtracting(second)
        u1.assertValid()
        u1.assertKeysEqual([0, 0, 4, 6, 6, 6, 7, 7])

        let u2 = second.bagSubtracting(first)
        u2.assertValid()
        u2.assertKeysEqual([1, 1, 3, 8])
    }

    func test_BagSubtract_sharedNodes() {
        var first = makeTree((0 ..< 10).repeatEach(20))
        var second = first
        first.withCursor(atOffset: 140) { $0.remove(20) }
        second.withCursor(atOffset: 60) { $0.remove(20) }

        let u1 = first.bagSubtracting(second)
        u1.assertValid()
        u1.assertKeysEqual([3].repeatEach(20))
        
        let u2 = second.bagSubtracting(first)
        u2.assertValid()
        u2.assertKeysEqual([7].repeatEach(20))
    }

    func test_BagSubtract_subtrees() {
        let count = 50
        let keys = DictionaryBag((0 ..< count).repeatEach(3))
        let tree = makeTree(keys)
        tree.forEachSubtree { subtree in
            let u1 = subtree.bagSubtracting(tree)
            u1.assertKeysEqual([])

            let expected = keys.subtracting(subtree.map { $0.0 }).sorted()
            let u2 = tree.bagSubtracting(subtree)
            u2.assertKeysEqual(expected)
        }
    }

    //MARK: Symmetric difference

    func test_SymmetricDifference_simple() {
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

    func test_SymmetricDifference_evenOdd() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))
        let odd = makeTree(stride(from: 1, to: 100, by: 2))

        let u1 = even.symmetricDifference(odd)
        u1.assertValid()
        u1.assertKeysEqual(0 ..< 100)

        let u2 = odd.symmetricDifference(even)
        u2.assertValid()
        u2.assertKeysEqual(0 ..< 100)
    }

    func test_SymmetricDifference_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = first.symmetricDifference(second)
        u1.assertValid()
        u1.assertKeysEqual(0 ..< 100)

        let u2 = second.symmetricDifference(first)
        u2.assertValid()
        u2.assertKeysEqual(0 ..< 100)
    }

    func test_SymmetricDifference_longDuplicates() {
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

    func test_SymmetricDifference_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = first.symmetricDifference(second)
        u1.assertValid()
        u1.assertKeysEqual([1, 1, 4, 7, 7, 8])

        let u2 = second.symmetricDifference(first)
        u2.assertValid()
        u2.assertKeysEqual([1, 1, 4, 7, 7, 8])
    }

    func test_SymmetricDifference_sharedNodes() {
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

    func test_SymmetricDifference_subtrees() {
        let count = 50
        let keys = DictionaryBag((0 ..< count).repeatEach(3))
        let tree = makeTree(keys)
        tree.forEachSubtree { subtree in
            let expectedKeys = keys.subtractingAll(subtree.map { $0.0 }).sorted()

            let u1 = subtree.symmetricDifference(tree)
            u1.assertKeysEqual(expectedKeys)

            let u2 = tree.symmetricDifference(subtree)
            u2.assertKeysEqual(expectedKeys)
        }
    }

    //MARK: Bag Symmetric Difference

    func test_BagSymmetricDifference_simple() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))

        let u0 = empty.bagSymmetricDifference(empty)
        u0.assertValid()
        u0.assertKeysEqual(empty)

        let u1 = even.bagSymmetricDifference(empty)
        u1.assertValid()
        u1.assertKeysEqual(even)

        let u2 = empty.bagSymmetricDifference(even)
        u2.assertValid()
        u2.assertKeysEqual(even)

        let u3 = even.bagSymmetricDifference(even)
        u3.assertValid()
        u3.assertKeysEqual(empty)
    }

    func test_BagSymmetricDifference_evenOdd() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))
        let odd = makeTree(stride(from: 1, to: 100, by: 2))

        let u1 = even.bagSymmetricDifference(odd)
        u1.assertValid()
        u1.assertKeysEqual(0 ..< 100)

        let u2 = odd.bagSymmetricDifference(even)
        u2.assertValid()
        u2.assertKeysEqual(0 ..< 100)
    }

    func test_BagSymmetricDifference_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = first.bagSymmetricDifference(second)
        u1.assertValid()
        u1.assertKeysEqual(0 ..< 100)

        let u2 = second.bagSymmetricDifference(first)
        u2.assertValid()
        u2.assertKeysEqual(0 ..< 100)
    }

    func test_BagSymmetricDifference_longDuplicates() {
        let keys = (0 ..< 10).repeatEach(20)
        let first = makeTree(keys[0 ..< 90])
        let second = makeTree(keys[90 ..< 200])

        let u1 = first.bagSymmetricDifference(second)
        u1.assertValid()
        u1.assertKeysEqual((0 ..< 4).repeatEach(20) + (5 ..< 10).repeatEach(20))

        let u2 = second.bagSymmetricDifference(first)
        u2.assertValid()
        u2.assertKeysEqual((0 ..< 4).repeatEach(20) + (5 ..< 10).repeatEach(20))
    }

    func test_BagSymmetricDifference_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = first.bagSymmetricDifference(second)
        u1.assertValid()
        u1.assertKeysEqual([0, 0, 1, 1, 3, 4, 6, 6, 6, 7, 7, 8])

        let u2 = second.bagSymmetricDifference(first)
        u2.assertValid()
        u2.assertKeysEqual([0, 0, 1, 1, 3, 4, 6, 6, 6, 7, 7, 8])
    }

    func test_BagSymmetricDifference_sharedNodes() {
        var first = makeTree((0 ..< 10).repeatEach(20))
        var second = first
        first.withCursor(atOffset: 140) { $0.remove(20) }
        second.withCursor(atOffset: 60) { $0.remove(20) }

        let u1 = first.bagSymmetricDifference(second)
        u1.assertValid()
        u1.assertKeysEqual([3, 7].repeatEach(20))

        let u2 = second.bagSymmetricDifference(first)
        u2.assertValid()
        u2.assertKeysEqual([3, 7].repeatEach(20))
    }

    func test_BagSymmetricDifference_subtrees() {
        let count = 50
        let keys = DictionaryBag((0 ..< count).repeatEach(3))
        let tree = makeTree(keys)
        tree.forEachSubtree { subtree in
            let expectedKeys = keys.subtracting(subtree.map { $0.0 }).sorted()

            let u1 = subtree.bagSymmetricDifference(tree)
            u1.assertKeysEqual(expectedKeys)

            let u2 = tree.bagSymmetricDifference(subtree)
            u2.assertKeysEqual(expectedKeys)
        }
    }

    //MARK: Intersection

    func test_Intersection_simple() {
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

    func test_Intersection_evenOdd() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))
        let odd = makeTree(stride(from: 1, to: 100, by: 2))

        let u1 = even.intersection(odd)
        u1.assertValid()
        u1.assertKeysEqual(empty)

        let u2 = odd.intersection(even)
        u2.assertValid()
        u2.assertKeysEqual(empty)
    }

    func test_Intersection_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = first.intersection(second)
        u1.assertValid()
        u1.assertKeysEqual(empty)

        let u2 = second.intersection(first)
        u2.assertValid()
        u2.assertKeysEqual(empty)
    }

    func test_Intersection_longDuplicates() {
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

    func test_Intersection_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = first.intersection(second)
        u1.assertValid()
        u1.assertKeysEqual([0, 0, 3, 3, 6])

        let u2 = second.intersection(first)
        u2.assertValid()
        u2.assertKeysEqual([0, 0, 0, 0, 3, 6, 6, 6, 6])
    }

    func test_Intersection_sharedNodes() {
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

    func test_Intersection_subtrees() {
        let count = 50
        let keys = DictionaryBag((0 ..< count).repeatEach(3))
        let tree = makeTree(keys)
        tree.forEachSubtree { subtree in
            let expected = Set(subtree.map { $0.0 }).sorted().repeatEach(3)
            let u1 = subtree.intersection(tree)
            u1.assertKeysEqual(expected)

            let u2 = tree.intersection(subtree)
            u2.assertKeysEqual(subtree.map { $0.0 })
        }
    }

    func test_Intersection_withModifiedSelf() {
        var tree = BTree<Int, Int>(order: 5)
        for i in 0 ..< 10 {
            for j in 0 ..< 2 {
                tree.insert((i, j))
            }
        }

        for i in 0 ..< 10 {
            var other = tree
            other.withCursor(atOffset: 2 * i) { cursor in
                cursor.remove(2)
            }
            other.assertValid()
            let test = tree.intersection(other)
            XCTAssertEqual(test.map { $0.0 }, other.map { $0.0 })
        }
    }

    //MARK: Bag Intersection

    func test_BagIntersection_simple() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))

        let u0 = empty.bagIntersection(empty)
        u0.assertValid()
        u0.assertKeysEqual(empty)

        let u1 = even.bagIntersection(empty)
        u1.assertValid()
        u1.assertKeysEqual(empty)

        let u2 = empty.bagIntersection(even)
        u2.assertValid()
        u2.assertKeysEqual(empty)

        let u3 = even.bagIntersection(even)
        u3.assertValid()
        u3.assertKeysEqual(even)
    }

    func test_BagIntersection_evenOdd() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))
        let odd = makeTree(stride(from: 1, to: 100, by: 2))

        let u1 = even.bagIntersection(odd)
        u1.assertValid()
        u1.assertKeysEqual(empty)

        let u2 = odd.bagIntersection(even)
        u2.assertValid()
        u2.assertKeysEqual(empty)
    }

    func test_BagIntersection_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = first.bagIntersection(second)
        u1.assertValid()
        u1.assertKeysEqual(empty)

        let u2 = second.bagIntersection(first)
        u2.assertValid()
        u2.assertKeysEqual(empty)
    }

    func test_BagIntersection_longDuplicates() {
        let keys = (0 ..< 10).repeatEach(20)
        let first = makeTree(keys[0 ..< 90])
        let second = makeTree(keys[90 ..< 200])

        let u1 = first.bagIntersection(second)
        u1.assertValid()
        u1.assertKeysEqual([4].repeatEach(10))

        let u2 = second.bagIntersection(first)
        u2.assertValid()
        u2.assertKeysEqual([4].repeatEach(10))
    }

    func test_BagIntersection_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = first.bagIntersection(second)
        u1.assertValid()
        u1.assertKeysEqual([0, 0, 3, 6])

        let u2 = second.bagIntersection(first)
        u2.assertValid()
        u2.assertKeysEqual([0, 0, 3, 6])
    }

    func test_BagIntersection_sharedNodes() {
        var first = makeTree((0 ..< 10).repeatEach(20))
        var second = first
        first.withCursor(atOffset: 140) { $0.remove(20) }
        second.withCursor(atOffset: 60) { $0.remove(20) }

        let u1 = first.bagIntersection(second)
        u1.assertValid()
        u1.assertKeysEqual([0, 1, 2, 4, 5, 6, 8, 9].repeatEach(20))

        let u2 = second.bagIntersection(first)
        u2.assertValid()
        u2.assertKeysEqual([0, 1, 2, 4, 5, 6, 8, 9].repeatEach(20))
    }

    func test_BagIntersection_subtrees() {
        let count = 50
        let keys = DictionaryBag((0 ..< count).repeatEach(3))
        let tree = makeTree(keys)
        tree.forEachSubtree { subtree in
            let expectedKeys = subtree.map { $0.0 }

            let u1 = subtree.bagIntersection(tree)
            u1.assertKeysEqual(expectedKeys)

            let u2 = tree.bagIntersection(subtree)
            u2.assertKeysEqual(expectedKeys)
        }
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
