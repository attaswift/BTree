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

private extension SequenceType {
    func repeatEach(count: Int) -> Array<Generator.Element> {
        return flatMap { Array<Generator.Element>(count: count, repeatedValue: $0) }
    }
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

        let u0 = empty.union(empty)
        u0.assertValid()
        assertEqual(u0, empty)

        let u1 = even.union(empty)
        u1.assertValid()
        assertEqual(u1, even)

        let u2 = empty.union(even)
        u2.assertValid()
        assertEqual(u2, even)

        let u3 = even.union(even)
        u3.assertValid()
        assertEqual(u3, (0 ..< 100).map { $0 & ~1 })
    }

    func test_Union_evenOdd() {
        let even = makeTree(0.stride(to: 100, by: 2))
        let odd = makeTree(1.stride(to: 100, by: 2))

        let u1 = even.union(odd)
        u1.assertValid()
        assertEqual(u1, 0 ..< 100)

        let u2 = odd.union(even)
        u2.assertValid()
        assertEqual(u2, 0 ..< 100)
    }

    func test_Union_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = first.union(second)
        u1.assertValid()
        assertEqual(u1, 0 ..< 100)

        let u2 = second.union(first)
        u2.assertValid()
        assertEqual(u2, 0 ..< 100)
    }

    func test_Union_longDuplicates() {
        let first = makeTree((0 ..< 90).repeatEach(20))
        let second = makeTree((90 ..< 200).repeatEach(20))

        let u1 = first.union(second)
        u1.assertValid()
        assertEqual(u1, (0 ..< 200).repeatEach(20))

        let u2 = second.union(first)
        u2.assertValid()
        assertEqual(u2, (0 ..< 200).repeatEach(20))
    }

    func test_Union_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = first.union(second)
        u1.assertValid()
        assertEqual(u1, [0, 0, 0, 0, 0, 0, 1, 1, 3, 3, 3, 4, 6, 6, 6, 6, 6, 7, 7, 8])

        let u2 = second.union(first)
        u2.assertValid()
        assertEqual(u2, [0, 0, 0, 0, 0, 0, 1, 1, 3, 3, 3, 4, 6, 6, 6, 6, 6, 7, 7, 8])
    }

    func test_Union_sharedNodes() {
        var first = makeTree((0 ..< 10).repeatEach(20))
        var second = first
        first.withCursorAtPosition(140) { $0.remove(20) }
        second.withCursorAtPosition(60) { $0.remove(20) }

        let u1 = first.union(second)
        u1.assertValid()
        assertEqual(u1, [0, 0, 1, 1, 2, 2, 3, 4, 4, 5, 5, 6, 6, 7, 8, 8, 9, 9].repeatEach(20))

        let u2 = second.union(first)
        u2.assertValid()
        assertEqual(u2, [0, 0, 1, 1, 2, 2, 3, 4, 4, 5, 5, 6, 6, 7, 8, 8, 9, 9].repeatEach(20))
    }

    //MARK: Distinct Union

    func test_DistinctUnion_simple() {
        let even = makeTree(0.stride(to: 100, by: 2))

        let u0 = empty.distinctUnion(empty)
        u0.assertValid()
        assertEqual(u0, empty)

        let u1 = even.distinctUnion(empty)
        u1.assertValid()
        assertEqual(u1, even)

        let u2 = empty.distinctUnion(even)
        u2.assertValid()
        assertEqual(u2, even)

        let u3 = even.distinctUnion(even)
        u3.assertValid()
        assertEqual(u3, 0.stride(to: 100, by: 2))
    }

    func test_DistinctUnion_evenOdd() {
        let even = makeTree(0.stride(to: 100, by: 2))
        let odd = makeTree(1.stride(to: 100, by: 2))

        let u1 = even.distinctUnion(odd)
        u1.assertValid()
        assertEqual(u1, 0 ..< 100)

        let u2 = odd.distinctUnion(even)
        u2.assertValid()
        assertEqual(u2, 0 ..< 100)
    }

    func test_DistinctUnion_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = first.distinctUnion(second)
        u1.assertValid()
        assertEqual(u1, 0 ..< 100)

        let u2 = second.distinctUnion(first)
        u2.assertValid()
        assertEqual(u2, 0 ..< 100)
    }

    func test_DistinctUnion_longDuplicates() {
        let first = makeTree((0 ..< 100).repeatEach(20))
        let second = makeTree((100 ..< 200).repeatEach(20))

        let u1 = first.distinctUnion(second)
        u1.assertValid()
        assertEqual(u1, (0 ..< 200).repeatEach(20))

        let u2 = second.distinctUnion(first)
        u2.assertValid()
        assertEqual(u2, (0 ..< 200).repeatEach(20))
    }

    func test_DistinctUnion_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = first.distinctUnion(second)
        u1.assertValid()
        assertEqual(u1, [0, 0, 1, 1, 3, 3, 4, 6, 7, 7, 8])

        let u2 = second.distinctUnion(first)
        u2.assertValid()
        assertEqual(u2, [0, 0, 0, 0, 1, 1, 3, 4, 6, 6, 6, 6, 7, 7, 8])
    }

    func test_DistinctUnion_sharedNodes() {
        var first = makeTree((0 ..< 10).repeatEach(20))
        var second = first
        first.withCursorAtPosition(140) { $0.remove(20) }
        second.withCursorAtPosition(60) { $0.remove(20) }

        let u1 = first.distinctUnion(second)
        u1.assertValid()
        assertEqual(u1, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].repeatEach(20))

        let u2 = second.distinctUnion(first)
        u2.assertValid()
        assertEqual(u2, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].repeatEach(20))
    }

    //MARK: Subtract

    func test_Subtract_simple() {
        let even = makeTree(0.stride(to: 100, by: 2))

        let u0 = empty.subtract(empty)
        u0.assertValid()
        assertEqual(u0, empty)

        let u1 = even.subtract(empty)
        u1.assertValid()
        assertEqual(u1, even)

        let u2 = empty.subtract(even)
        u2.assertValid()
        assertEqual(u2, empty)

        let u3 = even.subtract(even)
        u3.assertValid()
        assertEqual(u3, empty)
    }

    func test_Subtract_evenOdd() {
        let even = makeTree(0.stride(to: 100, by: 2))
        let odd = makeTree(1.stride(to: 100, by: 2))

        let u1 = even.subtract(odd)
        u1.assertValid()
        assertEqual(u1, even)

        let u2 = odd.subtract(even)
        u2.assertValid()
        assertEqual(u2, odd)
    }

    func test_Subtract_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = first.subtract(second)
        u1.assertValid()
        assertEqual(u1, first)

        let u2 = second.subtract(first)
        u2.assertValid()
        assertEqual(u2, second)
    }

    func test_Subtract_longDuplicates() {
        let keys = (0 ..< 10).repeatEach(20)
        let first = makeTree(keys[0 ..< 90])
        let second = makeTree(keys[90 ..< 200])

        let u1 = first.subtract(second)
        u1.assertValid()
        assertEqual(u1, (0 ..< 4).repeatEach(20))

        let u2 = second.subtract(first)
        u2.assertValid()
        assertEqual(u2, (5 ..< 10).repeatEach(20))
    }

    func test_Subtract_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = first.subtract(second)
        u1.assertValid()
        assertEqual(u1, [4, 7, 7])

        let u2 = second.subtract(first)
        u2.assertValid()
        assertEqual(u2, [1, 1, 8])
    }

    func test_Subtract_sharedNodes() {
        var first = makeTree((0 ..< 10).repeatEach(20))
        var second = first
        first.withCursorAtPosition(140) { $0.remove(20) }
        second.withCursorAtPosition(60) { $0.remove(20) }

        let u1 = first.subtract(second)
        u1.assertValid()
        assertEqual(u1, [3].repeatEach(20))

        let u2 = second.subtract(first)
        u2.assertValid()
        assertEqual(u2, [7].repeatEach(20))
    }
    
    //MARK: Exclusive Or

    func test_ExclusiveOr_simple() {
        let even = makeTree(0.stride(to: 100, by: 2))

        let u0 = empty.exclusiveOr(empty)
        u0.assertValid()
        assertEqual(u0, empty)

        let u1 = even.exclusiveOr(empty)
        u1.assertValid()
        assertEqual(u1, even)

        let u2 = empty.exclusiveOr(even)
        u2.assertValid()
        assertEqual(u2, even)

        let u3 = even.exclusiveOr(even)
        u3.assertValid()
        assertEqual(u3, empty)
    }

    func test_ExclusiveOr_evenOdd() {
        let even = makeTree(0.stride(to: 100, by: 2))
        let odd = makeTree(1.stride(to: 100, by: 2))

        let u1 = even.exclusiveOr(odd)
        u1.assertValid()
        assertEqual(u1, 0 ..< 100)

        let u2 = odd.exclusiveOr(even)
        u2.assertValid()
        assertEqual(u2, 0 ..< 100)
    }

    func test_ExclusiveOr_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = first.exclusiveOr(second)
        u1.assertValid()
        assertEqual(u1, 0 ..< 100)

        let u2 = second.exclusiveOr(first)
        u2.assertValid()
        assertEqual(u2, 0 ..< 100)
    }

    func test_ExclusiveOr_longDuplicates() {
        let keys = (0 ..< 10).repeatEach(20)
        let first = makeTree(keys[0 ..< 90])
        let second = makeTree(keys[90 ..< 200])

        let u1 = first.exclusiveOr(second)
        u1.assertValid()
        assertEqual(u1, (0 ..< 4).repeatEach(20) + (5 ..< 10).repeatEach(20))

        let u2 = second.exclusiveOr(first)
        u2.assertValid()
        assertEqual(u2, (0 ..< 4).repeatEach(20) + (5 ..< 10).repeatEach(20))
    }

    func test_ExclusiveOr_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = first.exclusiveOr(second)
        u1.assertValid()
        assertEqual(u1, [1, 1, 4, 7, 7, 8])

        let u2 = second.exclusiveOr(first)
        u2.assertValid()
        assertEqual(u2, [1, 1, 4, 7, 7, 8])
    }

    func test_ExclusiveOr_sharedNodes() {
        var first = makeTree((0 ..< 10).repeatEach(20))
        var second = first
        first.withCursorAtPosition(140) { $0.remove(20) }
        second.withCursorAtPosition(60) { $0.remove(20) }

        let u1 = first.exclusiveOr(second)
        u1.assertValid()
        assertEqual(u1, [3, 7].repeatEach(20))

        let u2 = second.exclusiveOr(first)
        u2.assertValid()
        assertEqual(u2, [3, 7].repeatEach(20))
    }


    //MARK: Intersect

    func test_Intersect_simple() {
        let even = makeTree(0.stride(to: 100, by: 2))

        let u0 = empty.intersect(empty)
        u0.assertValid()
        assertEqual(u0, empty)

        let u1 = even.intersect(empty)
        u1.assertValid()
        assertEqual(u1, empty)

        let u2 = empty.intersect(even)
        u2.assertValid()
        assertEqual(u2, empty)

        let u3 = even.intersect(even)
        u3.assertValid()
        assertEqual(u3, even)
    }

    func test_Intersect_evenOdd() {
        let even = makeTree(0.stride(to: 100, by: 2))
        let odd = makeTree(1.stride(to: 100, by: 2))

        let u1 = even.intersect(odd)
        u1.assertValid()
        assertEqual(u1, empty)

        let u2 = odd.intersect(even)
        u2.assertValid()
        assertEqual(u2, empty)
    }

    func test_Intersect_halves() {
        let first = makeTree(0..<50)
        let second = makeTree(50..<100)

        let u1 = first.intersect(second)
        u1.assertValid()
        assertEqual(u1, empty)

        let u2 = second.intersect(first)
        u2.assertValid()
        assertEqual(u2, empty)
    }

    func test_Intersect_longDuplicates() {
        let keys = (0 ..< 10).repeatEach(20)
        let first = makeTree(keys[0 ..< 90])
        let second = makeTree(keys[90 ..< 200])

        let u1 = first.intersect(second)
        u1.assertValid()
        assertEqual(u1, [4].repeatEach(10))

        let u2 = second.intersect(first)
        u2.assertValid()
        assertEqual(u2, [4].repeatEach(10))
    }

    func test_Intersect_duplicateResolution() {
        let first = makeTree([0, 0, 0, 0, 3, 4, 6, 6, 6, 6, 7, 7])
        let second = makeTree([0, 0, 1, 1, 3, 3, 6, 8])

        let u1 = first.intersect(second)
        u1.assertValid()
        assertEqual(u1, [0, 0, 3, 3, 6])

        let u2 = second.intersect(first)
        u2.assertValid()
        assertEqual(u2, [0, 0, 0, 0, 3, 6, 6, 6, 6])
    }

    func test_Intersect_sharedNodes() {
        var first = makeTree((0 ..< 10).repeatEach(20))
        var second = first
        first.withCursorAtPosition(140) { $0.remove(20) }
        second.withCursorAtPosition(60) { $0.remove(20) }

        let u1 = first.intersect(second)
        u1.assertValid()
        assertEqual(u1, [0, 1, 2, 4, 5, 6, 8, 9].repeatEach(20))

        let u2 = second.intersect(first)
        u2.assertValid()
        assertEqual(u2, [0, 1, 2, 4, 5, 6, 8, 9].repeatEach(20))
    }
}