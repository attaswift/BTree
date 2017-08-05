//
//  BTreeMergeTests.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-29.
//  Copyright © 2016–2017 Károly Lőrentey.
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

    func makeTree<S: Sequence>(_ s: S, order: Int = 5, keysPerNode: Int? = nil) -> Tree where S.Element == Int {
        var b = Builder(order: order, keysPerNode: keysPerNode ?? order - 1)
        for i in s.sorted() {
            b.append((i, ()))
        }
        return Tree(b.finish())
    }

    //MARK: Union by grouping matches

    func test_unionByGrouping_simple() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))

        let u0 = empty.union(empty, by: .groupingMatches)
        u0.assertValid()
        u0.assertKeysEqual(empty)

        let u1 = even.union(empty, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual(even)

        let u2 = empty.union(even, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual(even)

        let u3 = even.union(even, by: .groupingMatches)
        u3.assertValid()
        u3.assertKeysEqual(stride(from: 0, to: 100, by: 2))
    }

    func test_unionByGrouping_evenOdd() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))
        let odd = makeTree(stride(from: 1, to: 100, by: 2))

        let u1 = even.union(odd, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual(0 ..< 100)

        let u2 = odd.union(even, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual(0 ..< 100)
    }

    func test_unionByGrouping_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = first.union(second, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual(0 ..< 100)

        let u2 = second.union(first, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual(0 ..< 100)
    }

    func test_unionByGrouping_longDuplicates() {
        let first = makeTree((0 ..< 100).repeatEach(20))
        let second = makeTree((100 ..< 200).repeatEach(20))

        let u1 = first.union(second, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual((0 ..< 200).repeatEach(20))

        let u2 = second.union(first, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual((0 ..< 200).repeatEach(20))
    }

    func test_unionByGrouping_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = first.union(second, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual([0, 0, 1, 1, 3, 3, 4, 6, 7, 7, 8])

        let u2 = second.union(first, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual([0, 0, 0, 0, 1, 1, 3, 4, 6, 6, 6, 6, 7, 7, 8])
    }

    func test_unionByGrouping_sharedNodes() {
        var first = makeTree((0 ..< 10).repeatEach(20))
        var second = first
        first.withCursor(atOffset: 140) { $0.remove(20) }
        second.withCursor(atOffset: 60) { $0.remove(20) }

        let u1 = first.union(second, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual([0, 1, 2, 3, 4, 5, 6, 7, 8, 9].repeatEach(20))

        let u2 = second.union(first, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual([0, 1, 2, 3, 4, 5, 6, 7, 8, 9].repeatEach(20))
    }

    func test_unionByGrouping_subtrees() {
        let count = 50
        let keys = DictionaryBag((0 ..< count).repeatEach(3))
        let tree = makeTree(keys)
        tree.forEachSubtree { subtree in
            let u1 = subtree.union(tree, by: .groupingMatches)
            u1.assertKeysEqual(tree.map { $0.0 })

            let expected = keys.subtractingAll(subtree.map { $0.0 }).union(subtree.map { $0.0 }).sorted()
            let u2 = tree.union(subtree, by: .groupingMatches)
            u2.assertKeysEqual(expected)
        }
    }

    //MARK: Union by counting matches

    func test_unionByCounting_simple() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))

        let u0 = empty.union(empty, by: .countingMatches)
        u0.assertValid()
        u0.assertKeysEqual(empty)

        let u1 = even.union(empty, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual(even)

        let u2 = empty.union(even, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual(even)

        let u3 = even.union(even, by: .countingMatches)
        u3.assertValid()
        u3.assertKeysEqual((0 ..< 100).map { $0 & ~1 })
    }

    func test_unionByCounting_evenOdd() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))
        let odd = makeTree(stride(from: 1, to: 100, by: 2))

        let u1 = even.union(odd, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual(0 ..< 100)

        let u2 = odd.union(even, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual(0 ..< 100)
    }

    func test_unionByCounting_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = first.union(second, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual(0 ..< 100)

        let u2 = second.union(first, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual(0 ..< 100)
    }

    func test_unionByCounting_longDuplicates() {
        let first = makeTree((0 ..< 90).repeatEach(20))
        let second = makeTree((90 ..< 200).repeatEach(20))

        let u1 = first.union(second, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual((0 ..< 200).repeatEach(20))

        let u2 = second.union(first, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual((0 ..< 200).repeatEach(20))
    }

    func test_unionByCounting_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = first.union(second, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual([0, 0, 0, 0, 0, 0, 1, 1, 3, 3, 3, 4, 6, 6, 6, 6, 6, 7, 7, 8])

        let u2 = second.union(first, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual([0, 0, 0, 0, 0, 0, 1, 1, 3, 3, 3, 4, 6, 6, 6, 6, 6, 7, 7, 8])
    }

    func test_unionByCounting_sharedNodes() {
        var first = makeTree((0 ..< 10).repeatEach(20))
        var second = first
        first.withCursor(atOffset: 140) { $0.remove(20) }
        second.withCursor(atOffset: 60) { $0.remove(20) }

        let u1 = first.union(second, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual([0, 0, 1, 1, 2, 2, 3, 4, 4, 5, 5, 6, 6, 7, 8, 8, 9, 9].repeatEach(20))

        let u2 = second.union(first, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual([0, 0, 1, 1, 2, 2, 3, 4, 4, 5, 5, 6, 6, 7, 8, 8, 9, 9].repeatEach(20))
    }

    func test_unionByCounting_subtrees() {
        let count = 50
        let keys = DictionaryBag((0 ..< count).repeatEach(3))
        let tree = makeTree(keys)
        tree.forEachSubtree { subtree in
            let expected = keys.union(subtree.map { $0.0 }).sorted()
            
            let u1 = subtree.union(tree, by: .countingMatches)
            u1.assertKeysEqual(expected)

            let u2 = tree.union(subtree, by: .countingMatches)
            u2.assertKeysEqual(expected)
        }
    }

    //MARK: Subtracting by grouping matches

    func test_subtractingByGrouping_simple() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))

        let u0 = empty.subtracting(empty, by: .groupingMatches)
        u0.assertValid()
        u0.assertKeysEqual(empty)

        let u1 = even.subtracting(empty, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual(even)

        let u2 = empty.subtracting(even, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual(empty)

        let u3 = even.subtracting(even, by: .groupingMatches)
        u3.assertValid()
        u3.assertKeysEqual(empty)
    }

    func test_subtractingByGrouping_evenOdd() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))
        let odd = makeTree(stride(from: 1, to: 100, by: 2))

        let u1 = even.subtracting(odd, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual(even)

        let u2 = odd.subtracting(even, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual(odd)
    }

    func test_subtractingByGrouping_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = first.subtracting(second, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual(first)

        let u2 = second.subtracting(first, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual(second)
    }

    func test_subtractingByGrouping_longDuplicates() {
        let keys = (0 ..< 10).repeatEach(20)
        let first = makeTree(keys[0 ..< 90])
        let second = makeTree(keys[90 ..< 200])

        let u1 = first.subtracting(second, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual((0 ..< 4).repeatEach(20))

        let u2 = second.subtracting(first, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual((5 ..< 10).repeatEach(20))
    }

    func test_subtractingByGrouping_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = first.subtracting(second, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual([4, 7, 7])

        let u2 = second.subtracting(first, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual([1, 1, 8])
    }

    func test_subtractingByGrouping_sharedNodes() {
        var first = makeTree((0 ..< 10).repeatEach(20))
        var second = first
        first.withCursor(atOffset: 140) { $0.remove(20) }
        second.withCursor(atOffset: 60) { $0.remove(20) }

        let u1 = first.subtracting(second, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual([3].repeatEach(20))

        let u2 = second.subtracting(first, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual([7].repeatEach(20))
    }

    func test_subtractingByGrouping_subtrees() {
        let count = 50
        let keys = DictionaryBag((0 ..< count).repeatEach(3))
        let tree = makeTree(keys)
        tree.forEachSubtree { subtree in
            let u1 = subtree.subtracting(tree, by: .groupingMatches)
            u1.assertKeysEqual([])

            let u2 = tree.subtracting(subtree, by: .groupingMatches)
            u2.assertKeysEqual(keys.subtractingAll(subtree.map { $0.0 }).sorted())
        }
    }

    //MARK: Subtracting by counting matches

    func test_subtractingByCounting_simple() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))

        let u0 = empty.subtracting(empty, by: .countingMatches)
        u0.assertValid()
        u0.assertKeysEqual(empty)

        let u1 = even.subtracting(empty, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual(even)

        let u2 = empty.subtracting(even, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual(empty)

        let u3 = even.subtracting(even, by: .countingMatches)
        u3.assertValid()
        u3.assertKeysEqual(empty)
    }

    func test_subtractingByCounting_evenOdd() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))
        let odd = makeTree(stride(from: 1, to: 100, by: 2))

        let u1 = even.subtracting(odd, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual(even)

        let u2 = odd.subtracting(even, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual(odd)
    }

    func test_subtractingByCounting_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = first.subtracting(second, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual(first)

        let u2 = second.subtracting(first, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual(second)
    }

    func test_subtractingByCounting_longDuplicates() {
        let keys = (0 ..< 10).repeatEach(20)
        let first = makeTree(keys[0 ..< 95])
        let second = makeTree(keys[95 ..< 200])

        let u1 = first.subtracting(second, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual((0 ..< 4).repeatEach(20) + Array(repeating: 4, count: 10))

        let u2 = second.subtracting(first, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual((5 ..< 10).repeatEach(20))
    }

    func test_subtractingByCounting_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = first.subtracting(second, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual([0, 0, 4, 6, 6, 6, 7, 7])

        let u2 = second.subtracting(first, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual([1, 1, 3, 8])
    }

    func test_subtractingByCounting_sharedNodes() {
        var first = makeTree((0 ..< 10).repeatEach(20))
        var second = first
        first.withCursor(atOffset: 140) { $0.remove(20) }
        second.withCursor(atOffset: 60) { $0.remove(20) }

        let u1 = first.subtracting(second, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual([3].repeatEach(20))
        
        let u2 = second.subtracting(first, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual([7].repeatEach(20))
    }

    func test_subtractingByCounting_subtrees() {
        let count = 50
        let keys = DictionaryBag((0 ..< count).repeatEach(3))
        let tree = makeTree(keys)
        tree.forEachSubtree { subtree in
            let u1 = subtree.subtracting(tree, by: .countingMatches)
            u1.assertKeysEqual([])

            let expected = keys.subtracting(subtree.map { $0.0 }).sorted()
            let u2 = tree.subtracting(subtree, by: .countingMatches)
            u2.assertKeysEqual(expected)
        }
    }

    //MARK: Symmetric difference by grouping matches

    func test_symmetricDifferenceByGrouping_simple() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))

        let u0 = empty.symmetricDifference(empty, by: .groupingMatches)
        u0.assertValid()
        u0.assertKeysEqual(empty)

        let u1 = even.symmetricDifference(empty, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual(even)

        let u2 = empty.symmetricDifference(even, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual(even)

        let u3 = even.symmetricDifference(even, by: .groupingMatches)
        u3.assertValid()
        u3.assertKeysEqual(empty)
    }

    func test_symmetricDifferenceByGrouping_evenOdd() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))
        let odd = makeTree(stride(from: 1, to: 100, by: 2))

        let u1 = even.symmetricDifference(odd, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual(0 ..< 100)

        let u2 = odd.symmetricDifference(even, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual(0 ..< 100)
    }

    func test_symmetricDifferenceByGrouping_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = first.symmetricDifference(second, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual(0 ..< 100)

        let u2 = second.symmetricDifference(first, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual(0 ..< 100)
    }

    func test_symmetricDifferenceByGrouping_longDuplicates() {
        let keys = (0 ..< 10).repeatEach(20)
        let first = makeTree(keys[0 ..< 90])
        let second = makeTree(keys[90 ..< 200])

        let u1 = first.symmetricDifference(second, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual((0 ..< 4).repeatEach(20) + (5 ..< 10).repeatEach(20))

        let u2 = second.symmetricDifference(first, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual((0 ..< 4).repeatEach(20) + (5 ..< 10).repeatEach(20))
    }

    func test_symmetricDifferenceByGrouping_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = first.symmetricDifference(second, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual([1, 1, 4, 7, 7, 8])

        let u2 = second.symmetricDifference(first, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual([1, 1, 4, 7, 7, 8])
    }

    func test_symmetricDifferenceByGrouping_sharedNodes() {
        var first = makeTree((0 ..< 10).repeatEach(20))
        var second = first
        first.withCursor(atOffset: 140) { $0.remove(20) }
        second.withCursor(atOffset: 60) { $0.remove(20) }

        let u1 = first.symmetricDifference(second, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual([3, 7].repeatEach(20))

        let u2 = second.symmetricDifference(first, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual([3, 7].repeatEach(20))
    }

    func test_symmetricDifferenceByGrouping_subtrees() {
        let count = 50
        let keys = DictionaryBag((0 ..< count).repeatEach(3))
        let tree = makeTree(keys)
        tree.forEachSubtree { subtree in
            let expectedKeys = keys.subtractingAll(subtree.map { $0.0 }).sorted()

            let u1 = subtree.symmetricDifference(tree, by: .groupingMatches)
            u1.assertKeysEqual(expectedKeys)

            let u2 = tree.symmetricDifference(subtree, by: .groupingMatches)
            u2.assertKeysEqual(expectedKeys)
        }
    }

    //MARK: Symmetric Difference by counting matches

    func test_symmetricDifferenceByCounting_simple() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))

        let u0 = empty.symmetricDifference(empty, by: .countingMatches)
        u0.assertValid()
        u0.assertKeysEqual(empty)

        let u1 = even.symmetricDifference(empty, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual(even)

        let u2 = empty.symmetricDifference(even, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual(even)

        let u3 = even.symmetricDifference(even, by: .countingMatches)
        u3.assertValid()
        u3.assertKeysEqual(empty)
    }

    func test_symmetricDifferenceByCounting_evenOdd() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))
        let odd = makeTree(stride(from: 1, to: 100, by: 2))

        let u1 = even.symmetricDifference(odd, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual(0 ..< 100)

        let u2 = odd.symmetricDifference(even, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual(0 ..< 100)
    }

    func test_symmetricDifferenceByCounting_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = first.symmetricDifference(second, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual(0 ..< 100)

        let u2 = second.symmetricDifference(first, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual(0 ..< 100)
    }

    func test_symmetricDifferenceByCounting_longDuplicates() {
        let keys = (0 ..< 10).repeatEach(20)
        let first = makeTree(keys[0 ..< 90])
        let second = makeTree(keys[90 ..< 200])

        let u1 = first.symmetricDifference(second, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual((0 ..< 4).repeatEach(20) + (5 ..< 10).repeatEach(20))

        let u2 = second.symmetricDifference(first, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual((0 ..< 4).repeatEach(20) + (5 ..< 10).repeatEach(20))
    }

    func test_symmetricDifferenceByCounting_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = first.symmetricDifference(second, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual([0, 0, 1, 1, 3, 4, 6, 6, 6, 7, 7, 8])

        let u2 = second.symmetricDifference(first, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual([0, 0, 1, 1, 3, 4, 6, 6, 6, 7, 7, 8])
    }

    func test_symmetricDifferenceByCounting_sharedNodes() {
        var first = makeTree((0 ..< 10).repeatEach(20))
        var second = first
        first.withCursor(atOffset: 140) { $0.remove(20) }
        second.withCursor(atOffset: 60) { $0.remove(20) }

        let u1 = first.symmetricDifference(second, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual([3, 7].repeatEach(20))

        let u2 = second.symmetricDifference(first, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual([3, 7].repeatEach(20))
    }

    func test_symmetricDifferenceByCounting_subtrees() {
        let count = 50
        let keys = DictionaryBag((0 ..< count).repeatEach(3))
        let tree = makeTree(keys)
        tree.forEachSubtree { subtree in
            let expectedKeys = keys.subtracting(subtree.map { $0.0 }).sorted()

            let u1 = subtree.symmetricDifference(tree, by: .countingMatches)
            u1.assertKeysEqual(expectedKeys)

            let u2 = tree.symmetricDifference(subtree, by: .countingMatches)
            u2.assertKeysEqual(expectedKeys)
        }
    }

    //MARK: Intersection by grouping matches

    func test_IntersectionByGrouping_simple() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))

        let u0 = empty.intersection(empty, by: .groupingMatches)
        u0.assertValid()
        u0.assertKeysEqual(empty)

        let u1 = even.intersection(empty, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual(empty)

        let u2 = empty.intersection(even, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual(empty)

        let u3 = even.intersection(even, by: .groupingMatches)
        u3.assertValid()
        u3.assertKeysEqual(even)
    }

    func test_IntersectionByGrouping_evenOdd() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))
        let odd = makeTree(stride(from: 1, to: 100, by: 2))

        let u1 = even.intersection(odd, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual(empty)

        let u2 = odd.intersection(even, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual(empty)
    }

    func test_IntersectionByGrouping_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = first.intersection(second, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual(empty)

        let u2 = second.intersection(first, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual(empty)
    }

    func test_IntersectionByGrouping_longDuplicates() {
        let keys = (0 ..< 10).repeatEach(20)
        let first = makeTree(keys[0 ..< 90])
        let second = makeTree(keys[90 ..< 200])

        let u1 = first.intersection(second, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual([4].repeatEach(10))

        let u2 = second.intersection(first, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual([4].repeatEach(10))
    }

    func test_IntersectionByGrouping_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = first.intersection(second, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual([0, 0, 3, 3, 6])

        let u2 = second.intersection(first, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual([0, 0, 0, 0, 3, 6, 6, 6, 6])
    }

    func test_IntersectionByGrouping_sharedNodes() {
        var first = makeTree((0 ..< 10).repeatEach(20))
        var second = first
        first.withCursor(atOffset: 140) { $0.remove(20) }
        second.withCursor(atOffset: 60) { $0.remove(20) }

        let u1 = first.intersection(second, by: .groupingMatches)
        u1.assertValid()
        u1.assertKeysEqual([0, 1, 2, 4, 5, 6, 8, 9].repeatEach(20))

        let u2 = second.intersection(first, by: .groupingMatches)
        u2.assertValid()
        u2.assertKeysEqual([0, 1, 2, 4, 5, 6, 8, 9].repeatEach(20))
    }

    func test_IntersectionByGrouping_subtrees() {
        let count = 50
        let keys = DictionaryBag((0 ..< count).repeatEach(3))
        let tree = makeTree(keys)
        tree.forEachSubtree { subtree in
            let expected = Set(subtree.map { $0.0 }).sorted().repeatEach(3)
            let u1 = subtree.intersection(tree, by: .groupingMatches)
            u1.assertKeysEqual(expected)

            let u2 = tree.intersection(subtree, by: .groupingMatches)
            u2.assertKeysEqual(subtree.map { $0.0 })
        }
    }

    func test_IntersectionByGrouping_withModifiedSelf() {
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
            let test = tree.intersection(other, by: .groupingMatches)
            XCTAssertEqual(test.map { $0.0 }, other.map { $0.0 })
        }
    }

    //MARK: Intersection by counting matches

    func test_IntersectionByCounting_simple() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))

        let u0 = empty.intersection(empty, by: .countingMatches)
        u0.assertValid()
        u0.assertKeysEqual(empty)

        let u1 = even.intersection(empty, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual(empty)

        let u2 = empty.intersection(even, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual(empty)

        let u3 = even.intersection(even, by: .countingMatches)
        u3.assertValid()
        u3.assertKeysEqual(even)
    }

    func test_IntersectionByCounting_evenOdd() {
        let even = makeTree(stride(from: 0, to: 100, by: 2))
        let odd = makeTree(stride(from: 1, to: 100, by: 2))

        let u1 = even.intersection(odd, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual(empty)

        let u2 = odd.intersection(even, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual(empty)
    }

    func test_IntersectionByCounting_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = first.intersection(second, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual(empty)

        let u2 = second.intersection(first, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual(empty)
    }

    func test_IntersectionByCounting_longDuplicates() {
        let keys = (0 ..< 10).repeatEach(20)
        let first = makeTree(keys[0 ..< 90])
        let second = makeTree(keys[90 ..< 200])

        let u1 = first.intersection(second, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual([4].repeatEach(10))

        let u2 = second.intersection(first, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual([4].repeatEach(10))
    }

    func test_IntersectionByCounting_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = first.intersection(second, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual([0, 0, 3, 6])

        let u2 = second.intersection(first, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual([0, 0, 3, 6])
    }

    func test_IntersectionByCounting_sharedNodes() {
        var first = makeTree((0 ..< 10).repeatEach(20))
        var second = first
        first.withCursor(atOffset: 140) { $0.remove(20) }
        second.withCursor(atOffset: 60) { $0.remove(20) }

        let u1 = first.intersection(second, by: .countingMatches)
        u1.assertValid()
        u1.assertKeysEqual([0, 1, 2, 4, 5, 6, 8, 9].repeatEach(20))

        let u2 = second.intersection(first, by: .countingMatches)
        u2.assertValid()
        u2.assertKeysEqual([0, 1, 2, 4, 5, 6, 8, 9].repeatEach(20))
    }

    func test_IntersectionByCounting_subtrees() {
        let count = 50
        let keys = DictionaryBag((0 ..< count).repeatEach(3))
        let tree = makeTree(keys)
        tree.forEachSubtree { subtree in
            let expectedKeys = subtree.map { $0.0 }

            let u1 = subtree.intersection(tree, by: .countingMatches)
            u1.assertKeysEqual(expectedKeys)

            let u2 = tree.intersection(subtree, by: .countingMatches)
            u2.assertKeysEqual(expectedKeys)
        }
    }

    // MARK: Sequence-based operations

    func test_subtractingSequenceByGrouping() {
        let tree = BTree(sortedElements: (0 ..< 100).map { ($0, String($0)) })

        assertEqualElements(tree.subtracting(sortedKeys: [], by: .groupingMatches), tree)
        assertEqualElements(BTree<Int, String>().subtracting(sortedKeys: [1, 2, 3], by: .groupingMatches), [])

        let t1 = tree.subtracting(sortedKeys: (0 ..< 50).map { 2 * $0 }, by: .groupingMatches)
        assertEqualElements(t1.map { $0.0 }, (0 ..< 50).map { 2 * $0 + 1 })

        let t2 = tree.subtracting(sortedKeys: 0 ..< 50, by: .groupingMatches)
        assertEqualElements(t2.map { $0.0 }, 50 ..< 100)

        let t3 = tree.subtracting(sortedKeys: 50 ..< 100, by: .groupingMatches)
        assertEqualElements(t3.map { $0.0 }, 0 ..< 50)

        let t4 = tree.subtracting(sortedKeys: 100 ..< 200, by: .groupingMatches)
        assertEqualElements(t4.map { $0.0 }, 0 ..< 100)

        let tree2 = BTree(sortedElements: (0 ..< 100).map { ($0 / 2, String($0)) })
        let t5 = tree2.subtracting(sortedKeys: 0 ..< 50, by: .groupingMatches)
        assertEqualElements(t5.map { $0.0 }, [])
    }

    func test_subtractingSequenceByCounting() {
        let tree = BTree(sortedElements: (0 ..< 100).map { ($0, String($0)) })

        assertEqualElements(tree.subtracting(sortedKeys: [], by: .countingMatches), tree)
        assertEqualElements(BTree<Int, String>().subtracting(sortedKeys: [1, 2, 3], by: .countingMatches), [])

        let t1 = tree.subtracting(sortedKeys: (0 ..< 50).map { 2 * $0 }, by: .countingMatches)
        assertEqualElements(t1.map { $0.0 }, (0 ..< 50).map { 2 * $0 + 1 })

        let t2 = tree.subtracting(sortedKeys: 0 ..< 50, by: .countingMatches)
        assertEqualElements(t2.map { $0.0 }, 50 ..< 100)

        let t3 = tree.subtracting(sortedKeys: 50 ..< 100, by: .countingMatches)
        assertEqualElements(t3.map { $0.0 }, 0 ..< 50)

        let t4 = tree.subtracting(sortedKeys: 100 ..< 200, by: .countingMatches)
        assertEqualElements(t4.map { $0.0 }, 0 ..< 100)

        let tree2 = BTree(sortedElements: (0 ..< 100).map { ($0 / 2, String($0)) })
        let t5 = tree2.subtracting(sortedKeys: 0 ..< 50, by: .countingMatches)
        assertEqualElements(t5.map { $0.0 }, 0 ..< 50)
    }

    func test_intersectionWithSequenceByGrouping() {
        let tree = BTree(sortedElements: (0 ..< 100).map { ($0, String($0)) })

        assertEqualElements(tree.intersection(sortedKeys: [], by: .groupingMatches), [])
        assertEqualElements(BTree<Int, String>().intersection(sortedKeys: [1, 2, 3], by: .groupingMatches), [])

        let t1 = tree.intersection(sortedKeys: (0 ..< 50).map { 2 * $0 }, by: .groupingMatches)
        assertEqualElements(t1.map { $0.0 }, (0 ..< 50).map { 2 * $0 })

        let t2 = tree.intersection(sortedKeys: 0 ..< 50, by: .groupingMatches)
        assertEqualElements(t2.map { $0.0 }, 0 ..< 50)

        let t3 = tree.intersection(sortedKeys: 50 ..< 100, by: .groupingMatches)
        assertEqualElements(t3.map { $0.0 }, 50 ..< 100)

        let t4 = tree.intersection(sortedKeys: 100 ..< 200, by: .groupingMatches)
        assertEqualElements(t4.map { $0.0 }, [])

        let tree2 = BTree(sortedElements: (0 ..< 100).map { ($0 / 2, String($0)) })
        let t5 = tree2.intersection(sortedKeys: 0 ..< 50, by: .groupingMatches)
        assertEqualElements(t5.map { $0.0 }, (0 ..< 50).repeatEach(2))
    }

    func test_intersectionWithSequenceByCounting() {
        let tree = BTree(sortedElements: (0 ..< 100).map { ($0, String($0)) })

        assertEqualElements(tree.intersection(sortedKeys: [], by: .countingMatches), [])
        assertEqualElements(BTree<Int, String>().intersection(sortedKeys: [1, 2, 3], by: .countingMatches), [])

        let t1 = tree.intersection(sortedKeys: (0 ..< 50).map { 2 * $0 }, by: .countingMatches)
        assertEqualElements(t1.map { $0.0 }, (0 ..< 50).map { 2 * $0 })

        let t2 = tree.intersection(sortedKeys: 0 ..< 50, by: .countingMatches)
        assertEqualElements(t2.map { $0.0 }, 0 ..< 50)

        let t3 = tree.intersection(sortedKeys: 50 ..< 100, by: .countingMatches)
        assertEqualElements(t3.map { $0.0 }, 50 ..< 100)

        let t4 = tree.intersection(sortedKeys: 100 ..< 200, by: .countingMatches)
        assertEqualElements(t4.map { $0.0 }, [])

        let tree2 = BTree(sortedElements: (0 ..< 100).map { ($0 / 2, String($0)) })
        let t5 = tree2.intersection(sortedKeys: 0 ..< 50, by: .countingMatches)
        assertEqualElements(t5.map { $0.0 }, (0 ..< 50))
    }
}
