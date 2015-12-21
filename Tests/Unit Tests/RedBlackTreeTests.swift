
//
//  RedBlackTreeTests.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-19.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import TreeCollections

public struct MockHead<Key: Comparable>: Equatable, CustomStringConvertible {
    let key: Key
    let weight: Int

    public var description: String { return "(key: \(key), weight: \(weight))" }
}
public func ==<Key: Comparable>(a: MockHead<Key>, b: MockHead<Key>) -> Bool {
    return a.key == b.key && a.weight == b.weight
}

public struct MockSummary<Key: Comparable>: SummaryProtocol, CustomStringConvertible {
    public typealias Weight = Int
    public typealias Item = MockHead<Key>
    public let min: Key?
    public let max: Key?
    public let weight: Weight
    public let count: Int

    public init() {
        self.min = nil
        self.max = nil
        self.weight = 0
        self.count = 0
    }
    public init(_ item: Item) {
        self.min = item.key
        self.max = item.key
        self.weight = item.weight
        self.count = 1
    }
    public init(_ a: MockSummary<Key>, _ b: MockSummary<Key>) {
        if let amin = a.min, bmin = b.min where amin > bmin {
            XCTFail("Out of order summation: \(a) + \(b)")
        }
        if let amax = a.max, bmax = b.max where amax > bmax {
            XCTFail("Out of order summation: \(a) + \(b)")
        }

        switch (a.min, b.min) {
        case (nil, nil):
            self.min = nil
        case(.Some(let a), nil):
            self.min = a
        case (nil, .Some(let b)):
            self.min = b
        case (.Some(let a), .Some(let b)):
            self.min = Swift.min(a, b)
        }

        switch (a.max, b.max) {
        case (nil, nil):
            self.max = nil
        case(.Some(let a), nil):
            self.max = a
        case (nil, .Some(let b)):
            self.max = b
        case (.Some(let a), .Some(let b)):
            self.max = Swift.max(a, b)
        }

        self.weight = a.weight + b.weight
        self.count = a.count + b.count
    }

    public func dump(item: Key?) -> String {
        if let item = item {
            return String(item)
        }
        else {
            return "nil"
        }
    }

    public var description: String {
        return "(min: \(dump(min)), max: \(dump(max)), weight: \(weight), count: \(count))"
    }
}
public func ==<Item: Comparable>(a: MockSummary<Item>, b: MockSummary<Item>) -> Bool {
    return a.min == b.min && a.max == b.max && a.count == b.count
}

internal enum IndexingKey<_Key: Comparable>: Comparable {
    case Key(_Key)
    case Index(Int)
    case IndexRange(Range<Int>)
    case WeightIndex(Int)
}
func ==<K: Comparable>(a: IndexingKey<K>, b: IndexingKey<K>) -> Bool {
    switch (a, b) {
    case (.Key(let ak), .Key(let bk)) where ak == bk: return true
    case (.Index(let ai), .Index(let bi)) where ai == bi: return true
    case (.IndexRange(let ar), .IndexRange(let br)) where ar == br: return true
    case (.WeightIndex(let aw), .WeightIndex(let bw)) where aw == bw: return true
    default:
        return false
    }
}
func < <K: Comparable>(a: IndexingKey<K>, b: IndexingKey<K>) -> Bool {
    switch (a, b) {
    case (.Key(let ak), .Key(let bk)): return ak < bk
    case (.Index(let ai), .Index(let bi)): return ai < bi
    case (.IndexRange(let ar), .IndexRange(let br)): return ar.intersects(br)
    case (.WeightIndex(let aw), .WeightIndex(let bw)): return aw < bw
    default:
        fatalError()
    }
}

extension Range where Element: Comparable {
    func intersects(range: Range) -> Bool {
        guard self.endIndex > range.startIndex else { return false }
        guard self.startIndex < range.endIndex else { return false }
        return true
    }
}

internal struct MockConfig<_Key: Comparable>: RedBlackConfig {
    typealias Key = IndexingKey<_Key>
    typealias Summary = MockSummary<_Key>

    /// Returns a key that matches `head` whose preceding nodes reduce into `summary`.
    /// - Requires: `compare(key(h, after: r), to: h, after: s) == .Matched && head(key(h, after: s)) == h`.
    /// - Complexity: Must be O(1).
    static func key(head: Summary.Item, prefix summary: Summary) -> Key {
        checkPrefix(summary, head: head)
        return .Key(head.key)
    }

    /// Returns the head value to store for a node that matches `key`.
    /// - Requires: For all s, `compare(key, to: head(key), after: s) == .Matched`
    /// - Complexity: Must be O(1).
    static func head(key: Key) -> Summary.Item {
        guard case .Key(let k) = key else { fatalError() }
        return MockHead(key: k, weight: 10)
    }

    /// Compares `key` to a node with `head` whose preceding elements reduce into `summary`.
    /// - Complexity: Must be O(1).
    static func compare(key: Key, to head: Summary.Item, prefix summary: Summary) -> KeyMatchResult {
        checkPrefix(summary, head: head)
        switch key {
        case .Key(let k):
            return k < head.key ? .Before : k > head.key ? .After : .Matching
        case .Index(let i):
            return i < summary.count ? .Before : i > summary.count ? .After : .Matching
        case .IndexRange(let r):
            return r.endIndex <= summary.count ? .Before : r.startIndex > summary.count ? .After : .Matching
        case .WeightIndex(let w):
            return w < summary.weight ? .Before : w >= summary.weight + head.weight ? .After : .Matching
        }
    }

    static func checkPrefix(summary: Summary, head: Summary.Item) {
        if summary.max > head.key {
            XCTFail("Invalid summary: \(summary) should is not before \(head)")
        }
    }
}

typealias TestTree = RedBlackTree<MockConfig<Int>, String>

class RedBlackTrivialTests: XCTestCase {
    func testPropertiesOfEmptyTree() {
        let tree = TestTree()

        tree.assertValid()
        XCTAssertEqual(tree.count, 0)
        XCTAssertTrue(tree.isEmpty)
        XCTAssertNil(tree.root)
        XCTAssertNil(tree.leftmost)
        XCTAssertNil(tree.rightmost)
        XCTAssertEqual(tree.show(), "")
        XCTAssertNil(tree.find(.Key(42)))
        var generator = tree.generate()
        XCTAssertNil(generator.next())
    }

    func testPropertiesOfTreeWithOneNode() {
        let tree = TestTree([(.Key(10), "root")])

        tree.assertValid()
        XCTAssertEqual(tree.count, 1)
        XCTAssertFalse(tree.isEmpty)
        guard let ten = tree.find(.Key(10)) else { XCTFail(); return }
        XCTAssertEqual(tree.root, ten)
        XCTAssertEqual(tree.leftmost, ten)
        XCTAssertEqual(tree.rightmost, ten)
        XCTAssertEqual(tree.show(), "(Key(10))")

        var generator = tree.generate()
        guard let first = generator.next() else { XCTFail(); return }
        XCTAssertEqual(first.0, .Key(10))
        XCTAssertEqual(first.1, "root")
    }
}

class RedBlackTreeSimpleQueryTests: XCTestCase {
    var tree = TestTree()
    override func setUp() {
        super.setUp()
        tree = TestTree()
        tree.insert("three", forKey: .Key(3))
        tree.insert("ten", forKey: .Key(10))
        tree.insert("one", forKey: .Key(1))
        tree.insert("two", forKey: .Key(2))
        tree.insert("eight", forKey: .Key(8))
        tree.insert("four", forKey: .Key(4))
        tree.insert("six", forKey: .Key(6))
        tree.insert("five", forKey: .Key(5))
        tree.insert("nine", forKey: .Key(9))
        tree.insert("seven", forKey: .Key(7))

        tree.dump()
        tree.assertValid()
    }

    func testTreeIsValid() {
        tree.assertValid()
    }

    func testLeftMost() {
        XCTAssertNotNil(tree.leftmost)
        if let leftmost = tree.leftmost {
            XCTAssertEqual(tree.keyAt(leftmost), .Key(1))
            XCTAssertEqual(tree.payloadAt(leftmost), "one")
        }
    }

    func testRightMost() {
        XCTAssertNotNil(tree.rightmost)
        if let rightmost = tree.rightmost {
            XCTAssertEqual(tree.keyAt(rightmost), .Key(10))
            XCTAssertEqual(tree.payloadAt(rightmost), "ten")
        }
    }

    func testRoot() {
        XCTAssertNotNil(tree.root)
    }

    func testCount() {
        XCTAssertEqual(tree.count, 10)
    }

    func testIsEmpty() {
        XCTAssertFalse(tree.isEmpty)
    }

    func testFind() {
        XCTAssertNil(tree.find(.Key(0)))
        XCTAssertNotNil(tree.find(.Key(1)))
        XCTAssertNotNil(tree.find(.Key(2)))
        XCTAssertNotNil(tree.find(.Key(3)))
        XCTAssertNotNil(tree.find(.Key(4)))
        XCTAssertNotNil(tree.find(.Key(5)))
        XCTAssertNotNil(tree.find(.Key(6)))
        XCTAssertNotNil(tree.find(.Key(7)))
        XCTAssertNotNil(tree.find(.Key(8)))
        XCTAssertNotNil(tree.find(.Key(9)))
        XCTAssertNotNil(tree.find(.Key(10)))
        XCTAssertNil(tree.find(.Key(11)))
    }

    func testPayloadAt() {
        let handles = (1...10).flatMap { tree.find(.Key($0)) }
        let payloads = handles.map { tree.payloadAt($0) }
        XCTAssertEqual(payloads, ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"])
    }


    func testSummaryOfAllNodesBefore()  {
        for i in 1...10 {
            guard let handle = tree.find(.Key(i)) else { XCTFail(); continue }
            let summary = tree.summaryOfAllNodesBefore(handle)

            XCTAssertEqual(summary.min, i > 1 ? 1 : nil)
            XCTAssertEqual(summary.max, i > 1 ? i - 1 : nil)
            XCTAssertEqual(summary.count, i - 1)
        }
    }

    func testKeyAt() {
        let handles = (1...10).flatMap { tree.find(.Key($0)) }
        let keys = handles.map { tree.keyAt($0) }
        XCTAssertEqual(keys, [IndexingKey.Key(1), .Key(2), .Key(3), .Key(4), .Key(5), .Key(6), .Key(7), .Key(8), .Key(9), .Key(10)])
    }

    func testElementAt() {
        let handles = (1...10).flatMap { tree.find(.Key($0)) }
        let expectedElements = [(IndexingKey.Key(1), "one"), (.Key(2), "two"), (.Key(3), "three"), (.Key(4), "four"), (.Key(5), "five"), (.Key(6), "six"), (.Key(7), "seven"), (.Key(8), "eight"), (.Key(9), "nine"), (.Key(10), "ten")]

        let elements = handles.map { tree.elementAt($0) }
        XCTAssertTrue(elements.elementsEqual(expectedElements, isEquivalent: { e1, e2 in e1.0 == e2.0 && e1.1 == e2.1 }))
    }

    func testHeadAt() {
        let handles = (1...10).flatMap { tree.find(.Key($0)) }
        let expectedHeadKeys = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        let heads = handles.map { tree.headAt($0) }
        XCTAssertEqual(heads.map { $0.key }, expectedHeadKeys)
    }

    func testSuccessor() {
        let handles = (1...10).flatMap { tree.find(.Key($0)) }

        var next: TestTree.Handle? = nil
        for handle in handles.reverse() {
            XCTAssertEqual(tree.successor(handle), next)
            next = handle
        }
    }

    func testPredecessor() {
        let handles = (1...10).flatMap { tree.find(.Key($0)) }

        var previous: TestTree.Handle? = nil
        for handle in handles {
            XCTAssertEqual(tree.predecessor(handle), previous)
            previous = handle
        }
    }

    func testStep() {
        let handles = (1...10).flatMap { tree.find(.Key($0)) }

        for handle in handles {
            XCTAssertEqual(tree.step(handle, toward: .Left), tree.predecessor(handle))
            XCTAssertEqual(tree.step(handle, toward: .Right), tree.successor(handle))
        }
    }

    func testHandleOfLeftmostNodeUnder() {
        XCTAssertEqual(tree.handleOfLeftmostNodeUnder(tree.root!), tree.leftmost)

        let handles = (1...10).flatMap { tree.find(.Key($0)) }

        for handle in handles {
            let key = tree.keyAt(handle)
            let minHandle = tree.handleOfLeftmostNodeUnder(handle)
            let minKey = tree.keyAt(minHandle)

            XCTAssertLessThanOrEqual(minKey, key)
        }
    }

    func testHandleOfRightmostNodeUnder() {
        XCTAssertEqual(tree.handleOfRightmostNodeUnder(tree.root!), tree.rightmost)

        let handles = (1...10).flatMap { tree.find(.Key($0)) }

        for handle in handles {
            let key = tree.keyAt(handle)
            let maxHandle = tree.handleOfRightmostNodeUnder(handle)
            let maxKey = tree.keyAt(maxHandle)

            XCTAssertGreaterThanOrEqual(maxKey, key)
        }
    }

    func testFurthestNodeUnder() {
        let handles = (1...10).flatMap { tree.find(.Key($0)) }

        for handle in handles {
            let min = tree.handleOfLeftmostNodeUnder(handle)
            let max = tree.handleOfRightmostNodeUnder(handle)
            XCTAssertEqual(tree.handleOfFurthestNodeUnder(handle, toward: .Left), min)
            XCTAssertEqual(tree.handleOfFurthestNodeUnder(handle, toward: .Right), max)
        }
    }

    func testGenerate() {
        let expectedElements = [(IndexingKey.Key(1), "one"), (.Key(2), "two"), (.Key(3), "three"), (.Key(4), "four"), (.Key(5), "five"), (.Key(6), "six"), (.Key(7), "seven"), (.Key(8), "eight"), (.Key(9), "nine"), (.Key(10), "ten")]

        var elements = Array<TestTree.Element>()
        var generator = tree.generate()
        while let element = generator.next() {
            elements.append(element)
        }

        XCTAssertTrue(expectedElements.elementsEqual(elements, isEquivalent: { e1, e2 in e1.0 == e2.0 && e1.1 == e2.1 }))
    }

    func testSequenceType() {
        let expectedElements = [(IndexingKey.Key(1), "one"), (.Key(2), "two"), (.Key(3), "three"), (.Key(4), "four"), (.Key(5), "five"), (.Key(6), "six"), (.Key(7), "seven"), (.Key(8), "eight"), (.Key(9), "nine"), (.Key(10), "ten")]

        var elements = Array<TestTree.Element>()
        for element in tree {
            elements.append(element)
        }

        XCTAssertTrue(expectedElements.elementsEqual(elements, isEquivalent: { e1, e2 in e1.0 == e2.0 && e1.1 == e2.1 }))
    }

    func testGenerateFrom() {
        let expectedElements = [(IndexingKey.Key(1), "one"), (.Key(2), "two"), (.Key(3), "three"), (.Key(4), "four"), (.Key(5), "five"), (.Key(6), "six"), (.Key(7), "seven"), (.Key(8), "eight"), (.Key(9), "nine"), (.Key(10), "ten")]

        for i in 1...10 {
            guard let handle = tree.find(.Key(i)) else { XCTFail(); continue }
            var elements = Array<TestTree.Element>()
            var generator = tree.generateFrom(handle)
            while let e = generator.next() {
                elements.append(e)
            }

            XCTAssertTrue(expectedElements[i-1...9].elementsEqual(elements, isEquivalent: { e1, e2 in e1.0 == e2.0 && e1.1 == e2.1 }))
        }
    }

    func testHandleSearches() {
        for i in 1...10 {
            guard let handle = tree.find(.Key(i)) else { XCTFail(); continue }

            let topmostMatching = tree.handleOfTopmostNodeMatching(.Key(i))
            XCTAssertEqual(handle, topmostMatching)

            let leftmostMatching = tree.handleOfLeftmostNodeMatching(.Key(i))
            XCTAssertEqual(leftmostMatching, handle)

            let leftmostMatchingOrAfter = tree.handleOfLeftmostNodeMatchingOrAfter(.Key(i))
            XCTAssertEqual(leftmostMatchingOrAfter, handle)

            let leftmostAfter = tree.handleOfLeftmostNodeAfter(.Key(i))
            XCTAssertEqual(leftmostAfter, tree.successor(handle))

            let rightmostBefore = tree.handleOfRightmostNodeBefore(.Key(i))
            XCTAssertEqual(rightmostBefore, tree.predecessor(handle))

            let rightmostBeforeOrMatching = tree.handleOfRightmostNodeBeforeOrMatching(.Key(i))
            XCTAssertEqual(rightmostBeforeOrMatching, handle)

            let rightmostMatching = tree.handleOfRightmostNodeMatching(.Key(i))
            XCTAssertEqual(rightmostMatching, handle)
        }
    }

    func testDescription() {
        XCTAssertEqual(tree.description, "RedBlackTree with 10 nodes")
        let handle = tree.find(.Key(1))!
        XCTAssertTrue(handle.description.hasPrefix("#"))
    }
}

class RedBlackTreeSimpleMutatorTests: XCTestCase {
    var tree = TestTree()
    override func setUp() {
        super.setUp()
        tree = TestTree()
        tree.insert("three", forKey: .Key(3))
        tree.insert("ten", forKey: .Key(10))
        tree.insert("one", forKey: .Key(1))
        tree.insert("two", forKey: .Key(2))
        tree.insert("eight", forKey: .Key(8))
        tree.insert("four", forKey: .Key(4))
        tree.insert("six", forKey: .Key(6))
        tree.insert("five", forKey: .Key(5))
        tree.insert("nine", forKey: .Key(9))
        tree.insert("seven", forKey: .Key(7))


        tree.dump()
        XCTAssertEqual(tree.map { $0.1 }, ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"])
        XCTAssertEqual(tree.map { $0.0 }, [IndexingKey.Key(1), .Key(2), .Key(3), .Key(4), .Key(5), .Key(6), .Key(7), .Key(8), .Key(9), .Key(10)])
        tree.assertValid()
    }

    func testSetPayloadAt() {
        guard let handle = tree.find(.Key(4)) else { XCTFail(); return }

        let old = tree.setPayloadAt(handle, to: "FOUR")
        XCTAssertEqual(old, "four")
        tree.assertValid()

        XCTAssertEqual(tree.map { $0.1 }, ["one", "two", "three", "FOUR", "five", "six", "seven", "eight", "nine", "ten"])
    }

    func testSetHeadAt() {
        XCTAssertEqual(tree.find(.WeightIndex(29)), tree.find(.Key(3)))
        XCTAssertEqual(tree.find(.WeightIndex(30)), tree.find(.Key(4)))
        XCTAssertEqual(tree.find(.WeightIndex(31)), tree.find(.Key(4)))
        XCTAssertEqual(tree.find(.WeightIndex(40)), tree.find(.Key(5)))
        XCTAssertEqual(tree.find(.WeightIndex(50)), tree.find(.Key(6)))
        XCTAssertEqual(tree.find(.WeightIndex(59)), tree.find(.Key(6)))
        XCTAssertEqual(tree.find(.WeightIndex(60)), tree.find(.Key(7)))
        XCTAssertEqual(tree.find(.WeightIndex(61)), tree.find(.Key(7)))

        guard let handle = tree.find(.Key(4)) else { XCTFail(); return }
        let old = tree.setHeadAt(handle, to: MockHead(key: 4, weight: 30))
        XCTAssertEqual(old, MockHead(key: 4, weight: 10))
        tree.assertValid()

        XCTAssertEqual(tree.find(.WeightIndex(29)), tree.find(.Key(3)))
        XCTAssertEqual(tree.find(.WeightIndex(30)), tree.find(.Key(4)))
        XCTAssertEqual(tree.find(.WeightIndex(31)), tree.find(.Key(4)))
        XCTAssertEqual(tree.find(.WeightIndex(40)), tree.find(.Key(4)))
        XCTAssertEqual(tree.find(.WeightIndex(50)), tree.find(.Key(4)))
        XCTAssertEqual(tree.find(.WeightIndex(59)), tree.find(.Key(4)))
        XCTAssertEqual(tree.find(.WeightIndex(60)), tree.find(.Key(5)))
        XCTAssertEqual(tree.find(.WeightIndex(61)), tree.find(.Key(5)))

        XCTAssertEqual(tree.map { $0.0 }, [IndexingKey.Key(1), .Key(2), .Key(3), .Key(4), .Key(5), .Key(6), .Key(7), .Key(8), .Key(9), .Key(10)])
    }

    func testSetPayloadOf() {

        let (h1, p1) = tree.setPayloadOf(.Key(5), to: "FIVE")
        XCTAssertEqual(h1, tree.find(.Key(5)))
        XCTAssertEqual(p1, "five")
        tree.assertValid()

        let (h2, p2) = tree.setPayloadOf(.Index(2), to: "second")
        XCTAssertEqual(h2, tree.find(.Key(3)))
        XCTAssertEqual(p2, "three")
        tree.assertValid()

        let (h3, p3) = tree.setPayloadOf(.Key(0), to: "zero")
        XCTAssertEqual(h3, tree.find(.Key(0)))
        XCTAssertNil(p3)
        tree.assertValid()

        XCTAssertEqual(tree.map { $0.1 }, ["zero", "one", "two", "second", "four", "FIVE", "six", "seven", "eight", "nine", "ten"])
    }

    func testInsert() {

        for i in (20...25).reverse() {
            let h = tree.insert("\(i)", forKey: .Key(i))
            XCTAssertEqual(h, tree.find(.Key(i)))
            tree.assertValid()
        }
        XCTAssertEqual(tree.map { $0.1 }, ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "20", "21", "22", "23", "24", "25"])
    }

    func testInsertAfter() {

        var prev = tree.rightmost
        for i in 20...25 {
            let h = tree.insert("\(i)", forKey: .Key(i), after: prev)
            XCTAssertEqual(h, tree.find(.Key(i)))
            tree.assertValid()
            prev = h
        }
        XCTAssertEqual(tree.map { $0.1 }, ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "20", "21", "22", "23", "24", "25"])
        tree.dump()
    }

    func testInsertBefore() {

        var prev: TestTree.Handle? = nil
        for i in (20...25).reverse() {
            let h = tree.insert("\(i)", forKey: .Key(i), before: prev)
            XCTAssertEqual(h, tree.find(.Key(i)))
            tree.assertValid()
            prev = h
        }
        XCTAssertEqual(tree.map { $0.1 }, ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "20", "21", "22", "23", "24", "25"])
        tree.dump()
    }

    func testAppend() {

        var tree2 = TestTree()
        for i in (20...25).reverse() {
            tree2.insert("\(i)", forKey: .Key(i))
        }

        tree.append(tree2)
        tree.assertValid()

        XCTAssertEqual(tree.map { $0.1 }, ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "20", "21", "22", "23", "24", "25"])
        tree.dump()
    }

    func testMerge() {

        var tree2 = TestTree()
        for i in (5..<15).reverse() {
            tree2.insert("\(i)", forKey: .Key(i))
        }
        tree.merge(tree2)
        tree.assertValid()

        XCTAssertEqual(tree.map { $0.1 }, ["one", "two", "three", "four", "five", "5", "six", "6", "seven", "7", "eight", "8", "nine", "9", "ten", "10", "11", "12", "13", "14"])
        tree.dump()
    }

    func testRemoveAll() {

        tree.removeAll()
        tree.assertValid()

        XCTAssertEqual(tree.map { $0.1 }, [])
        tree.dump()
    }

    func testRemove() {

        XCTAssertEqual(tree.remove(tree.find(.Key(9))!), "nine")
        XCTAssertNil(tree.find(.Key(9)))

        XCTAssertEqual(tree.remove(tree.find(.Key(3))!), "three")
        XCTAssertEqual(tree.remove(tree.find(.Key(1))!), "one")
        XCTAssertEqual(tree.remove(tree.find(.Key(8))!), "eight")

        XCTAssertNil(tree.find(.Key(3)))
        XCTAssertNil(tree.find(.Key(1)))
        XCTAssertNil(tree.find(.Key(8)))

        XCTAssertEqual(tree.map { $0.1 }, ["two", "four", "five", "six", "seven", "ten"])
        tree.assertValid()

        tree.dump()
    }

    func testRemoveAndReturnSuccessor() {

        let (h9, p9) = tree.removeAndReturnSuccessor(tree.find(.Key(9))!)
        XCTAssertEqual(h9, tree.find(.Key(10)))
        XCTAssertEqual(p9, "nine")
        XCTAssertNil(tree.find(.Key(9)))

        let (h3, p3) = tree.removeAndReturnSuccessor(tree.find(.Key(3))!)
        XCTAssertEqual(h3, tree.find(.Key(4)))
        XCTAssertEqual(p3, "three")
        XCTAssertNil(tree.find(.Key(3)))

        let (h1, p1) = tree.removeAndReturnSuccessor(tree.find(.Key(1))!)
        XCTAssertEqual(h1, tree.find(.Key(2)))
        XCTAssertEqual(p1, "one")
        XCTAssertNil(tree.find(.Key(1)))

        let (h8, p8) = tree.removeAndReturnSuccessor(tree.find(.Key(8))!)
        XCTAssertEqual(h8, tree.find(.Key(10)))
        XCTAssertEqual(p8, "eight")
        XCTAssertNil(tree.find(.Key(8)))

        XCTAssertEqual(tree.map { $0.1 }, ["two", "four", "five", "six", "seven", "ten"])
        tree.assertValid()

        tree.dump()
    }

}

class RedBlackTreeHasValueSemanticsTests: XCTestCase {
    let originalKeys = [IndexingKey.Key(1), .Key(2), .Key(3), .Key(4), .Key(5), .Key(6), .Key(7), .Key(8), .Key(9), .Key(10)]
    let originalPayloads = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]

    func sampleTree() -> TestTree {
        return TestTree([(IndexingKey.Key(1), "one"), (.Key(2), "two"), (.Key(3), "three"), (.Key(4), "four"), (.Key(5), "five"), (.Key(6), "six"), (.Key(7), "seven"), (.Key(8), "eight"), (.Key(9), "nine"), (.Key(10), "ten")])
    }

    func testSetPayloadAtHasValueSemantics() {
        let tree = sampleTree()

        var copy = tree
        guard let handle = copy.find(.Key(5)) else { XCTFail(); return }
        copy.setPayloadAt(handle, to: "FIVE")

        XCTAssertEqual(copy.payloadAt(handle), "FIVE")
        XCTAssertEqual(tree.payloadAt(handle), "five")
    }

    func testSetHeadAtHasValueSemantics() {
        let tree = sampleTree()

        var copy = tree
        guard let handle = copy.find(.Key(5)) else { XCTFail(); return }
        copy.setHeadAt(handle, to: MockHead(key: 5, weight: 100))

        XCTAssertEqual(copy.headAt(handle), MockHead(key: 5, weight: 100))
        XCTAssertEqual(tree.headAt(handle), MockHead(key: 5, weight: 10))
    }

    func testInsertHasValueSemantics() {
        let tree = sampleTree()

        var copy = tree
        copy.insert("eleven", forKey:.Key(11))

        XCTAssertNotNil(copy.find(.Key(11)))
        XCTAssertNil(tree.find(.Key(11)))
    }

    func testRemoveHasValueSemantics() {
        let tree = sampleTree()

        var copy = tree
        guard let handle = tree.find(.Key(5)) else { XCTFail(); return }
        copy.remove(handle)

        XCTAssertNil(copy.find(.Key(5)))
        XCTAssertNotNil(tree.find(.Key(5)))
    }
}

class RedBlackTreeSystematicChanges: XCTestCase {

    func testInsertingSequentially() {
        var tree = TestTree()

        for i in 1...100 {
            let handle = tree.insert(String(i * 100), forKey: .Key(i))
            XCTAssertEqual(tree.find(.Key(i)), handle)
            tree.assertValid()
        }
    }

    func testRemovingSequentially() {
        var tree = TestTree()

        for i in 1...100 {
            tree.insert(String(i * 100), forKey: .Key(i))
        }
        tree.assertValid()

        for i in 1...100 {
            guard let handle = tree.find(.Key(i)) else { XCTFail(); continue }
            tree.remove(handle)
            XCTAssertNil(tree.find(.Key(i)))
            tree.assertValid()
        }
    }

    func testInsertionAndRemovalInRandomOrder() {
        var tree = TestTree()

        let permutation = Array(1...30).shuffle()
        print("Testing permutation \(permutation)")
        for i in permutation {
            let handle = tree.insert(String(i * 100), forKey: .Key(i))
            XCTAssertEqual(tree.find(.Key(i)), handle)
            tree.assertValid()
        }


    }
}
