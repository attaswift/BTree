//
//  BTreeTests.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-01-13.
//  Copyright © 2015–2016 Károly Lőrentey.
//

import XCTest
@testable import BTree

extension BTree {
    func assertValid(file file: FileString = __FILE__, line: UInt = __LINE__) {
        root.assertValid(file: file, line: line)
    }
}

class BTreeTests: XCTestCase {
    typealias Tree = BTree<Int, String>
    let order = 7

    func testEmptyTree() {
        let tree = Tree(order: order)
        tree.assertValid()
        XCTAssertTrue(tree.isEmpty)
        XCTAssertEqual(tree.count, 0)
        XCTAssertEqual(tree.depth, 0)
        XCTAssertEqual(tree.order, order)
        XCTAssertElementsEqual(tree, [])
        XCTAssertEqual(tree.startIndex, tree.endIndex)
        XCTAssertNil(tree.payloadOf(1))
    }

    func testUniquing() {
        let tree = minimalTree(depth: 1, order: 7)
        var copy = tree
        copy.makeUnique()
        copy.assertValid()
        XCTAssertTrue(tree.root !== copy.root)
        XCTAssertElementsEqual(copy, tree)
    }

    func testGenerate() {
        let tree = minimalTree(depth: 2, order: 5)
        let c = tree.count
        let generator = tree.generate()
        XCTAssertElementsEqual(GeneratorSequence(generator), (0 ..< c).map { ($0, String($0)) })
    }

    func testGenerateFromIndex() {
        let tree = minimalTree(depth: 2, order: 5)
        let c = tree.count
        for i in 0 ... c {
            let index = tree.startIndex.advancedBy(i)
            let generator = tree.generate(from: index)
            XCTAssertElementsEqual(GeneratorSequence(generator), (i ..< c).map { ($0, String($0)) })
        }
    }

    func testGenerateFromPosition() {
        let tree = minimalTree(depth: 2, order: 5)
        let c = tree.count
        for i in 0 ... c {
            let generator = tree.generate(fromPosition: i)
            XCTAssertElementsEqual(GeneratorSequence(generator), (i ..< c).map { ($0, String($0)) })
        }
    }

    func testGenerateFromKeyFirst() {
        let c = 26
        let reference = (0 ... 2 * c + 1).map { ($0 & ~1, String($0)) }
        let tree = Tree(sortedElements: reference, order: 3)
        for i in 0 ... c {
            let g1 = tree.generate(from: 2 * i, choosing: .First)
            XCTAssertElementsEqual(GeneratorSequence(g1), reference.suffixFrom(2 * i))

            let g2 = tree.generate(from: 2 * i + 1, choosing: .First)
            XCTAssertElementsEqual(GeneratorSequence(g2), reference.suffixFrom(2 * i + 2))
        }
    }

    func testGenerateFromKeyLast() {
        let c = 26
        let reference = (0 ... 2 * c + 1).map { ($0 & ~1, String($0)) }
        let tree = Tree(sortedElements: reference, order: 3)
        for i in 0 ... c {
            let g1 = tree.generate(from: 2 * i, choosing: .Last)
            XCTAssertElementsEqual(GeneratorSequence(g1), reference.suffixFrom(2 * i + 1))

            let g2 = tree.generate(from: 2 * i + 1, choosing: .Last)
            XCTAssertElementsEqual(GeneratorSequence(g2), reference.suffixFrom(2 * i + 2))
        }
    }

    func testGenerateFromKeyAfter() {
        let c = 26
        let reference = (0 ... 2 * c + 1).map { ($0 & ~1, String($0)) }
        let tree = Tree(sortedElements: reference, order: 3)
        for i in 0 ... c {
            let g1 = tree.generate(from: 2 * i, choosing: .After)
            XCTAssertElementsEqual(GeneratorSequence(g1), reference.suffixFrom(2 * i + 2))

            let g2 = tree.generate(from: 2 * i + 1, choosing: .After)
            XCTAssertElementsEqual(GeneratorSequence(g2), reference.suffixFrom(2 * i + 2))
        }
    }

    func testForEach() {
        let tree = maximalTree(depth: 2, order: order)
        var values: Array<Int> = []
        tree.forEach { values.append($0.0) }
        XCTAssertElementsEqual(values, 0..<tree.count)
    }

    func testInterruptibleForEach() {
        let tree = maximalTree(depth: 1, order: 5)
        for i in 0...tree.count {
            var j = 0
            tree.forEach { pair -> Bool in
                XCTAssertEqual(pair.0, j)
                XCTAssertLessThanOrEqual(j, i)
                if j == i { return false }
                j += 1
                return true
            }
            XCTAssertEqual(j, i)
        }
    }

    func testIterationUsingIndexingForward() {
        let tree = maximalTree(depth: 3, order: 3)
        var index = tree.startIndex
        var i = 0
        while index != tree.endIndex {
            XCTAssertEqual(tree[index].0, i)
            index = index.successor()
            i += 1
        }
        XCTAssertEqual(i, tree.count)
    }

    func testIterationUsingIndexingBackward() {
        let tree = maximalTree(depth: 3, order: 3)
        var index = tree.endIndex
        var i = tree.count
        while index != tree.startIndex {
            index = index.predecessor()
            i -= 1
            XCTAssertEqual(tree[index].0, i)
        }
        XCTAssertEqual(i, 0)
    }

    func testIndexAdvancedBy() {
        let tree = maximalTree(depth: 3, order: 3)
        let c = tree.count
        for i in 0 ... c {
            let i1 = tree.startIndex.advancedBy(i)
            XCTAssertEqual(i1.state.position, i)
            if i < c {
                XCTAssertEqual(i1.state.key, i)
            }

            let i2 = tree.endIndex.advancedBy(-i)
            XCTAssertEqual(i2.state.position, c - i)
            if i != 0 {
                XCTAssertEqual(i2.state.key, c - i)
            }
        }
    }

    func testIndexDistanceTo() {
        let tree = maximalTree(depth: 3, order: 3)
        let c = tree.count
        for i in 0 ... c {
            let i1 = tree.startIndex.advancedBy(i)
            var i2 = tree.startIndex
            for j in 0 ... c {
                XCTAssertEqual(i1.distanceTo(i2), j - i)
                if j < c {
                    i2 = i2.successor()
                }
            }
        }
    }

    func testIndexAdvancedByWithLimit() {
        let tree = maximalTree(depth: 3, order: 3)
        let c = tree.count
        for i in 0 ... c + 10 {
            let i1 = tree.startIndex.advancedBy(i, limit: tree.endIndex)
            XCTAssertEqual(i1.state.position, min(i, c))
            if i < c {
                XCTAssertEqual(i1.state.key, i)
            }

            let i2 = tree.endIndex.advancedBy(-i, limit: tree.startIndex)
            XCTAssertEqual(i2.state.position, max(0, c - i))
            if i != 0 {
                XCTAssertEqual(i2.state.key, max(0, c - i))
            }
        }
    }

    func testFirst() {
        XCTAssertNil(Tree().first)

        let tree = maximalTree(depth: 3, order: 3)
        XCTAssertEqual(tree.first?.0, 0)
        XCTAssertEqual(tree.first?.1, "0")
    }

    func testLast() {
        XCTAssertNil(Tree().last)

        let tree = maximalTree(depth: 3, order: 3)
        XCTAssertEqual(tree.last?.0, tree.count - 1)
        XCTAssertEqual(tree.last?.1, String(tree.count - 1))
    }

    func testElementAtPosition() {
        let tree = maximalTree(depth: 3, order: 3)
        for p in 0 ..< tree.count {
            let element = tree.elementAtPosition(p)
            XCTAssertEqual(element.0, p)
            XCTAssertEqual(element.1, String(p))
        }
    }

    func testPayloadOfKey() {
        let count = 42
        let tree = Tree(sortedElements: (0 ..< count).map { (2 * $0, String(2 * $0)) }, order: 3)

        for selector: BTreeKeySelector in [.Any, .First, .Last] {
            for k in (0 ..< count).lazy.map({ 2 * $0 }) {
                XCTAssertEqual(tree.payloadOf(k, choosing: selector), String(k), String(selector))
                XCTAssertNil(tree.payloadOf(k + 1, choosing: selector))
            }
            XCTAssertNil(tree.payloadOf(-1, choosing: selector))
            XCTAssertNil(tree.payloadOf(2 * count, choosing: selector))
        }

        for k in (0 ..< count - 1).lazy.map({ 2 * $0 }) {
            XCTAssertEqual(tree.payloadOf(k, choosing: .After), String(k + 2))
            XCTAssertEqual(tree.payloadOf(k + 1, choosing: .After), String(k + 2))
        }
        XCTAssertEqual(tree.payloadOf(-1, choosing: .After), String(0))
        XCTAssertNil(tree.payloadOf(2 * (count - 1), choosing: .After))
    }

    func testIndexOfKey() {
        let count = 42
        let tree = Tree(sortedElements: (0 ..< count).map { (2 * $0, String(2 * $0)) }, order: 3)
        for selector: BTreeKeySelector in [.Any, .First, .Last] {
            for k in (0 ..< count).lazy.map({ 2 * $0 }) {
                XCTAssertNil(tree.indexOf(k + 1, choosing: selector))
                guard let index = tree.indexOf(k, choosing: selector) else {
                    XCTFail("index is nil for key=\(k), selector=\(selector)")
                    continue
                }
                XCTAssertEqual(tree[index].0, k)
            }
            XCTAssertNil(tree.indexOf(-1, choosing: selector))
            XCTAssertNil(tree.indexOf(2 * count, choosing: selector))
        }

        for k in (0 ..< count - 1).lazy.map({ 2 * $0 }) {
            let even = tree.indexOf(k, choosing: .After)
            XCTAssertTrue(even != nil && tree.startIndex.distanceTo(even!) == k / 2 + 1, "\(k): \(tree.startIndex.distanceTo(even!))")
            let odd = tree.indexOf(k + 1, choosing: .After)
            XCTAssertTrue(odd != nil && tree.startIndex.distanceTo(odd!) == k / 2 + 1, "\(k): \(tree.startIndex.distanceTo(odd!))")
        }
        XCTAssertEqual(tree.indexOf(-1, choosing: .After), tree.startIndex)
        XCTAssertNil(tree.indexOf(2 * count - 2, choosing: .After))
    }

    func testPositionOfKey() {
        let count = 42
        let tree = Tree(sortedElements: (0 ..< count).map { (2 * $0, String(2 * $0)) }, order: 3)
        for selector: BTreeKeySelector in [.Any, .First, .Last] {
            for k in (0 ..< count).lazy.map({ 2 * $0 }) {
                XCTAssertNil(tree.positionOf(k + 1, choosing: selector))
                guard let position = tree.positionOf(k, choosing: selector) else {
                    XCTFail("position is nil for key=\(k), selector=\(selector)")
                    continue
                }
                XCTAssertEqual(tree.elementAtPosition(position).0, k)
            }
            XCTAssertNil(tree.positionOf(-1, choosing: selector))
        }

        for k in (0 ..< count - 1).lazy.map({ 2 * $0 }) {
            XCTAssertEqual(tree.positionOf(k, choosing: .After), k / 2 + 1)
            XCTAssertEqual(tree.positionOf(k + 1, choosing: .After), k / 2 + 1)
        }
        XCTAssertEqual(tree.positionOf(-1, choosing: .After), 0)
        XCTAssertNil(tree.positionOf(2 * count - 2, choosing: .After))
    }

    func testPositionOfIndex() {
        let count = 42
        let tree = Tree(sortedElements: (0 ..< count).map { (2 * $0, String(2 * $0)) }, order: 3)
        var index = tree.startIndex
        for position in 0 ..< count {
            XCTAssertEqual(tree[index].0, 2 * position)
            index = index.successor()
        }
        XCTAssertEqual(tree.positionOfIndex(index), count)
        XCTAssertEqual(index, tree.endIndex)
    }

    func testIndexOfPosition() {
        let count = 42
        let tree = Tree(sortedElements: (0 ..< count).map { (2 * $0, String(2 * $0)) }, order: 3)
        for position in 0 ..< count {
            let index = tree.indexOfPosition(position)
            XCTAssertEqual(tree[index].0, 2 * position)
        }
        XCTAssertEqual(tree.indexOfPosition(count), tree.endIndex)
    }

    func testInsertAtPosition() {
        let count = 42
        var tree = Tree(sortedElements: (0 ..< count).map { (2 * $0 + 1, String(2 * $0 + 1)) }, order: 3)
        var position = 0
        while position < count {
            let key = 2 * position
            tree.insert((key, String(key)), at: 2 * position)
            tree.assertValid()
            position += 1
        }
        XCTAssertElementsEqual(tree.map { $0.0 }, 0 ..< 2 * count)
    }

    func testSetPayloadAtPosition() {
        let count = 42
        var tree = Tree(sortedElements: (0 ..< count).map { ($0, "") }, order: 3)
        var position = 0
        while position < count {
            let old = tree.setPayloadAt(position, to: String(position))
            XCTAssertEqual(old, "")
            tree.assertValid()
            position += 1
        }
        XCTAssertElementsEqual(tree, (0 ..< count).map { ($0, String($0)) })
    }

    func testInsertElementFirst() {
        let count = 42
        var tree = Tree(order: 3)
        for i in 0 ..< count {
            tree.insert((0, String(i)), at: .First)
            tree.assertValid()
        }
        XCTAssertElementsEqual(tree, (0 ..< count).reverse().map { (0, String($0)) })
    }

    func testInsertElementLastOrAfterOrAny() {
        for selector: BTreeKeySelector in [.Last, .After, .Any] {
            let count = 42
            var tree = Tree(order: 3)
            for i in 0 ..< count {
                tree.insert((0, String(i)), at: selector)
                tree.assertValid()
            }
            XCTAssertElementsEqual(tree, (0 ..< count).map { (0, String($0)) })
        }
    }

    func testInsertOrReplaceAny() {
        let count = 42
        var tree = Tree(sortedElements: (0 ..< count).map { (2 * $0, "*\(2 * $0)") }, order: 3)
        for key in 0 ..< 2 * count {
            let old = tree.insertOrReplace((key, String(key)), at: .Any)
            tree.assertValid()
            if key & 1 == 0 {
                XCTAssertEqual(old, "*\(key)")
            }
            else {
                XCTAssertNil(old)
            }
        }
        XCTAssertElementsEqual(tree, (0 ..< 2 * count).map { ($0, String($0)) })
    }

    func testInsertOrReplaceFirst() {
        var tree = Tree(order: 3)
        for k in 0 ..< 42 {
            tree.insert((k, String(k) + "/1"))
            tree.insert((k, String(k) + "/2"))
            tree.insert((k, String(k) + "/3"))
        }
        tree.assertValid()
        for k in 0 ..< 42 {
            tree.insertOrReplace((k, String(k) + "/1*"), at: .First)
            tree.assertValid()
        }
        XCTAssertElementsEqual(tree.map { $0.1 }, (0 ..< 42).flatMap { key -> [String] in
            let ks = String(key)
            return [ks + "/1*", ks + "/2", ks + "/3"]
        })
    }

    func testInsertOrReplaceLastOrAfter() {
        for selector: BTreeKeySelector in [.Last, .After] {
            var tree = Tree(order: 3)
            for k in 0 ..< 42 {
                tree.insert((k, String(k) + "/1"))
                tree.insert((k, String(k) + "/2"))
                tree.insert((k, String(k) + "/3"))
            }
            tree.assertValid()
            for k in 0 ..< 42 {
                tree.insertOrReplace((k, String(k) + "/3*"), at: selector)
                tree.assertValid()
            }
            XCTAssertElementsEqual(tree.map { $0.1 }, (0 ..< 42).flatMap { key -> [String] in
                let ks = String(key)
                return [ks + "/1", ks + "/2", ks + "/3*"]
                })
        }
    }

    func testRemoveFirstAndLast() {
        var empty = Tree()
        XCTAssertNil(empty.popFirst())
        XCTAssertNil(empty.popLast())

        var tree = BTree(sortedElements: (0..<20).map { ($0, String($0)) }, order: 3)
        XCTAssertEqual(tree.popFirst()?.0, 0)
        tree.assertValid()
        XCTAssertEqual(tree.removeFirst().0, 1)
        tree.assertValid()
        XCTAssertEqual(tree.popLast()?.0, 19)
        tree.assertValid()
        XCTAssertEqual(tree.removeLast().0, 18)
        tree.assertValid()
        XCTAssertElementsEqual(tree, (2..<18).map { ($0, String($0)) })
    }

    func testRemoveAtPosition() {
        var tree = maximalTree(depth: 3, order: 3)
        let c = tree.count
        var reference = Array((0..<c).map { ($0, String($0)) })
        while tree.count > 0 {
            let p = tree.count / 2
            let element = tree.removeAt(p)
            let ref = reference.removeAtIndex(p)
            tree.assertValid()
            XCTAssertElementsEqual(tree, reference)
            XCTAssertEqual(element.0, ref.0)
            XCTAssertEqual(element.1, ref.1)
        }
    }

    func testRemoveKeyFirstOrAny() {
        for selector: BTreeKeySelector in [.First, .Any] {
            let count = 42
            var tree = Tree(order: 3)
            for k in (0 ..< count).map({ 2 * $0 }) {
                tree.insert((k, String(k) + "/1"))
                tree.insert((k, String(k) + "/2"))
                tree.insert((k, String(k) + "/3"))
            }
            tree.assertValid()

            for k in 0 ..< count {
                XCTAssertNil(tree.remove(2 * k + 1, at: selector))
                guard let old = tree.remove(2 * k, at: selector) else { XCTFail(String(2 * k)); continue }
                XCTAssertEqual(old, String(2 * k) + "/1")
                tree.assertValid()
            }

            XCTAssertElementsEqual(tree.map { $0.1 }, (0 ..< count).flatMap { key -> [String] in
                let ks = String(2 * key)
                return [ks + "/2", ks + "/3"]
                }
            )
        }
    }

    func testRemoveKeyLastOrAfter() {
        for selector: BTreeKeySelector in [.Last, .After] {
            let count = 42
            var tree = Tree(order: 3)
            for k in (0 ..< count).map({ 2 * $0 }) {
                tree.insert((k, String(k) + "/1"))
                tree.insert((k, String(k) + "/2"))
                tree.insert((k, String(k) + "/3"))
            }
            tree.assertValid()

            for k in 0 ..< count {
                XCTAssertNil(tree.remove(2 * k + 1, at: selector))
                guard let old = tree.remove(2 * k, at: selector) else { XCTFail(String(2 * k)); continue }
                XCTAssertEqual(old, String(2 * k) + "/3")
                tree.assertValid()
            }

            XCTAssertElementsEqual(tree.map { $0.1 }, (0 ..< count).flatMap { key -> [String] in
                let ks = String(2 * key)
                return [ks + "/1", ks + "/2"]
                }
            )
        }
    }

    func testPrefix() {
        let tree = maximalTree(depth: 2, order: 3)
        let count = tree.count
        let reference = (0 ..< count).map { ($0, String($0)) }
        for i in 0 ... count + 10 {
            let prefix = tree.prefix(i)
            prefix.assertValid()
            XCTAssertElementsEqual(prefix, reference.prefix(i))
        }
    }

    func testDropLast() {
        let tree = maximalTree(depth: 2, order: 3)
        let count = tree.count
        let reference = (0 ..< count).map { ($0, String($0)) }
        for i in 0 ... count + 10 {
            let remaining = tree.dropLast(i)
            remaining.assertValid()
            XCTAssertElementsEqual(remaining, reference.dropLast(i))
        }
    }

    func testPrefixUpToIndex() {
        let tree = maximalTree(depth: 2, order: 3)
        let count = tree.count
        let reference = (0 ..< count).map { ($0, String($0)) }
        for i in 0 ... count {
            let prefix = tree.prefixUpTo(tree.startIndex.advancedBy(i))
            prefix.assertValid()
            XCTAssertElementsEqual(prefix, reference.prefixUpTo(i))
        }
    }

    func testPrefixUpToKey() {
        let tree = maximalTree(depth: 2, order: 3)
        let count = tree.count
        let reference = (0 ..< count).map { ($0, String($0)) }
        for i in 0 ... count {
            let prefix = tree.prefixUpTo(i)
            prefix.assertValid()
            XCTAssertElementsEqual(prefix, reference.prefixUpTo(i))
        }
    }

    func testPrefixThroughIndex() {
        let tree = maximalTree(depth: 2, order: 3)
        let count = tree.count
        let reference = (0 ..< count).map { ($0, String($0)) }
        for i in 0 ..< count {
            let prefix = tree.prefixThrough(tree.startIndex.advancedBy(i))
            prefix.assertValid()
            XCTAssertElementsEqual(prefix, reference.prefixThrough(i))
        }
    }

    func testPrefixThroughKey() {
        let tree = maximalTree(depth: 2, order: 3)
        let count = tree.count
        let reference = (0 ..< count).map { ($0, String($0)) }
        for i in 0 ..< count {
            let prefix = tree.prefixThrough(i)
            prefix.assertValid()
            XCTAssertElementsEqual(prefix, reference.prefixThrough(i))
        }
    }

    func testSuffix() {
        let tree = maximalTree(depth: 2, order: 3)
        let count = tree.count
        let reference = (0 ..< count).map { ($0, String($0)) }
        for i in 0 ... count + 10 {
            let suffix = tree.suffix(i)
            suffix.assertValid()
            XCTAssertElementsEqual(suffix, reference.suffix(i))
        }
    }

    func testDropFirst() {
        let tree = maximalTree(depth: 2, order: 3)
        let count = tree.count
        let reference = (0 ..< count).map { ($0, String($0)) }
        for i in 0 ... count + 10 {
            let remaining = tree.dropFirst(i)
            remaining.assertValid()
            XCTAssertElementsEqual(remaining, reference.dropFirst(i))
        }
    }

    func testSuffixFromIndex() {
        let tree = maximalTree(depth: 2, order: 3)
        let count = tree.count
        let reference = (0 ..< count).map { ($0, String($0)) }
        for i in 0 ... count {
            let suffix = tree.suffixFrom(tree.startIndex.advancedBy(i))
            suffix.assertValid()
            XCTAssertElementsEqual(suffix, reference.suffixFrom(i))
        }
    }

    func testSuffixFromKey() {
        let tree = maximalTree(depth: 2, order: 3)
        let count = tree.count
        let reference = (0 ..< count).map { ($0, String($0)) }
        for i in 0 ... count {
            let suffix = tree.suffixFrom(i)
            suffix.assertValid()
            XCTAssertElementsEqual(suffix, reference.suffixFrom(i))
        }
    }

    func testSubtreeFromIndexRange() {
        let tree = maximalTree(depth: 2, order: 3)
        let count = tree.count
        var start = tree.startIndex
        for i in 0 ... count {
            var end = start
            for j in i ... count {
                let subtree = tree[start..<end]
                subtree.assertValid()
                XCTAssertElementsEqual(subtree, (i..<j).map { ($0, String($0)) })
                if j < count {
                    end.successorInPlace()
                }
            }
            if i < count {
                start.successorInPlace()
            }
        }
    }

    func testSubtreeFromPositionRange() {
        let tree = maximalTree(depth: 2, order: 3)
        let count = tree.count
        for i in 0 ... count {
            for j in i ... count {
                let subtree = tree.subtree(with: i ..< j)
                subtree.assertValid()
                XCTAssertElementsEqual(subtree, (i..<j).map { ($0, String($0)) })
            }
        }
    }

    func testSubtreeFromHalfOpenKeyRange() {
        let count = 28
        let tree = BTree(sortedElements: (0..<count).map { ($0 & ~1, String($0)) }, order: 3)
        for i in 0 ... count {
            for j in i ... count {
                let subtree = tree.subtree(from: i, to: j)
                subtree.assertValid()
                let ik = i & 1 == 0 ? i : min(count, i + 1)
                let jk = j & 1 == 0 ? j : min(count, j + 1)
                XCTAssertElementsEqual(subtree, (ik ..< jk).map { ($0 & ~1, String($0)) })
            }
        }
    }

    func testSubtreeFromClosedKeyRange() {
        let count = 28
        let tree = BTree(sortedElements: (0..<count).map { ($0 & ~1, String($0)) }, order: 3)
        for i in 0 ..< count {
            for j in i ..< count {
                let subtree = tree.subtree(from: i, through: j)
                subtree.assertValid()
                let ik = i & 1 == 0 ? i : min(count, i + 1)
                let jk = j & 1 == 0 ? min(count, j + 2) : min(count, j + 1)
                XCTAssertElementsEqual(subtree, (ik ..< jk).map { ($0 & ~1, String($0)) })
            }
        }
    }

    ////

    func testInsertingASingleKey() {
        var tree = Tree(order: order)
        tree.insert((1, "One"))
        tree.assertValid()
        XCTAssertFalse(tree.isEmpty)
        XCTAssertEqual(tree.count, 1)
        XCTAssertElementsEqual(tree, [(1, "One")])

        XCTAssertEqual(tree.payloadOf(1), "One")
        XCTAssertNil(tree.payloadOf(2))

        XCTAssertNotEqual(tree.startIndex, tree.endIndex)
        XCTAssertEqual(tree[tree.startIndex].0, 1)
        XCTAssertEqual(tree[tree.startIndex].1, "One")
    }

    func testRemovingTheSingleKey() {
        var tree = Tree(order: order)
        tree.insert((1, "One"))
        XCTAssertEqual(tree.remove(1), "One")
        tree.assertValid()

        XCTAssertTrue(tree.isEmpty)
        XCTAssertEqual(tree.count, 0)
        XCTAssertElementsEqual(tree, [])

        XCTAssertEqual(tree.startIndex, tree.endIndex)
    }

    func testInsertingAndRemovingTwoKeys() {
        var tree = Tree(order: order)
        tree.insert((1, "One"))
        tree.insert((2, "Two"))
        tree.assertValid()

        XCTAssertFalse(tree.isEmpty)
        XCTAssertEqual(tree.count, 2)
        XCTAssertElementsEqual(tree, [(1, "One"), (2, "Two")])

        XCTAssertEqual(tree.payloadOf(1), "One")
        XCTAssertEqual(tree.payloadOf(2), "Two")
        XCTAssertNil(tree.payloadOf(3))

        XCTAssertEqual(tree.remove(1), "One")
        tree.assertValid()

        XCTAssertFalse(tree.isEmpty)
        XCTAssertEqual(tree.count, 1)
        XCTAssertElementsEqual(tree, [(2, "Two")])

        XCTAssertEqual(tree.remove(2), "Two")
        tree.assertValid()

        XCTAssertTrue(tree.isEmpty)
        XCTAssertEqual(tree.count, 0)
        XCTAssertElementsEqual(tree, [])
    }

    func testSplittingRoot() {
        var tree = Tree(order: order)
        var reference = Array<(Int, String)>()
        for i in 0..<tree.order {
            tree.insert((i, "\(i)"))
            tree.assertValid()
            reference.append((i, "\(i)"))
        }

        XCTAssertFalse(tree.isEmpty)
        XCTAssertEqual(tree.count, tree.order)
        XCTAssertElementsEqual(tree, reference)
        XCTAssertEqual(tree.depth, 1)

        XCTAssertEqual(tree.root.elements.count, 1)
        XCTAssertEqual(tree.root.children.count, 2)
    }

    func testRemovingNonexistentKeys() {
        var tree = Tree(order: order)
        for i in 0..<tree.order {
            tree.insert((2 * i, "\(2 * i)"))
            tree.assertValid()
        }
        for i in 0..<tree.order {
            XCTAssertNil(tree.remove(2 * i + 1))
        }
    }

    func testCollapsingRoot() {
        var tree = Tree(order: order)
        var reference = Array<(Int, String)>()
        for i in 0..<tree.order {
            tree.insert((i, String(i)))
            tree.assertValid()
            reference.append((i, "\(i)"))
        }
        tree.remove(0)
        tree.assertValid()
        reference.removeAtIndex(0)

        XCTAssertEqual(tree.depth, 0)
        XCTAssertEqual(tree.count, tree.order - 1)
        XCTAssertElementsEqual(tree, reference)
    }

    func testSplittingInternalNode() {
        var tree = Tree(order: order)
        var reference = Array<(Int, String)>()
        let c = (3 * tree.order + 1) / 2
        for i in 0 ..< c {
            tree.insert((i, String(i)))
            tree.assertValid()
            reference.append((i, "\(i)"))
        }

        XCTAssertEqual(tree.count, c)
        XCTAssertElementsEqual(tree, reference)

        XCTAssertEqual(tree.depth, 1)
    }

    func testCreatingMinimalTreeWithThreeLevels() {
        var tree = Tree(order: order)
        var reference = Array<(Int, String)>()
        let c = (tree.order * tree.order - 1) / 2 + tree.order
        for i in 0 ..< c {
            tree.insert((i, String(i)))
            tree.assertValid()
            reference.append((i, "\(i)"))
        }

        XCTAssertEqual(tree.count, c)
        XCTAssertElementsEqual(tree, reference)

        XCTAssertEqual(tree.depth, 2)

        XCTAssertEqual(tree.payloadOf(c / 2), "\(c / 2)")
        XCTAssertEqual(tree.payloadOf(c / 2 + 1), "\(c / 2 + 1)")
    }

    func testRemovingKeysFromMinimalTreeWithThreeLevels() {
        var tree = Tree(order: order)
        let c = (tree.order * tree.order - 1) / 2 + tree.order
        for i in 0 ..< c {
            tree.insert((i, String(i)))
            tree.assertValid()
        }

        for i in 0 ..< c {
            XCTAssertEqual(tree.remove(i), "\(i)")
            tree.assertValid()
        }
        XCTAssertElementsEqual(tree, [])
    }

    func testRemovingRootFromMinimalTreeWithThreeLevels() {
        var tree = Tree(order: order)
        let c = (tree.order * tree.order - 1) / 2 + tree.order
        for i in 0 ..< c {
            tree.insert((i, String(i)))
            tree.assertValid()
        }
        XCTAssertEqual(tree.remove(c / 2), "\(c/2)")
        tree.assertValid()
        XCTAssertEqual(tree.depth, 1)
    }

    func testMaximalTreeOfDepth() {
        for depth in 0..<3 {
            let tree = maximalTree(depth: depth, order: order)
            tree.assertValid()
            XCTAssertEqual(tree.depth, depth)
            XCTAssertEqual(tree.count, (0...depth).reduce(1, combine: { p, _ in p * tree.order }) - 1)
        }
    }

    func testRemovingFromBeginningOfMaximalTreeWithThreeLevels() {
        // This test exercises left rotations.
        var tree = maximalTree(depth: 2, order: order)
        for key in 0..<tree.count {
            XCTAssertEqual(tree.remove(key), String(key))
            tree.assertValid()
        }
        XCTAssertTrue(tree.isEmpty)
    }
    
    func testRemovingFromEndOfMaximalTreeWithThreeLevels() {
        // This test exercises right rotations.
        var tree = maximalTree(depth: 2, order: order)
        for key in (0..<tree.count).reverse() {
            XCTAssertEqual(tree.remove(key), String(key))
            tree.assertValid()
        }
        XCTAssertTrue(tree.isEmpty)
    }

    func testSequenceConversion() {
        func check(range: Range<Int>, file: FileString = __FILE__, line: UInt = __LINE__) {
            let order = 5
            let sequence = range.map { ($0, String($0)) }
            let tree = Tree(sortedElements: sequence, order: order)
            tree.assertValid(file: file, line: line)
            XCTAssertElementsEqual(tree, sequence, file: file, line: line)
        }
        check(0..<0)
        check(0..<1)
        check(0..<4)
        check(0..<5)
        check(0..<10)
        check(0..<100)
        check(0..<200)
    }

    func testUnsortedSequenceConversion() {
        let tree = Tree(elements: [(3, "3"), (1, "1"), (4, "4"), (2, "2"), (0, "0")])
        tree.assertValid()
        XCTAssertElementsEqual(tree, [(0, "0"), (1, "1"), (2, "2"), (3, "3"), (4, "4")])
    }

    func testSequenceConversionToMaximalTrees() {
        func checkDepth(depth: Int, file: FileString = __FILE__, line: UInt = __LINE__) {
            let order = 5
            let keysPerNode = order - 1
            var count = keysPerNode
            for _ in 0 ..< depth {
                count = count * (keysPerNode + 1) + keysPerNode
            }
            let sequence = (0 ..< count).map { ($0, String($0)) }
            let tree = Tree(sortedElements: sequence, order: order, fillFactor: 1.0)
            tree.assertValid(file: file, line: line)
            tree.root.forEachNode { node in
                XCTAssertEqual(node.elements.count, keysPerNode, file: file, line: line)
            }
        }

        checkDepth(0)
        checkDepth(1)
        checkDepth(2)
        checkDepth(3)
    }
}