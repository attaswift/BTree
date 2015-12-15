//
//  List.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-14.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

private struct ListValue<Element>: RedBlackValue {
    typealias Key = Int

    var count: Int // Count of children
    var element: Element

    func key(@noescape left: Void->ListValue<Element>?) -> Key {
        return left()?.count ?? 0
    }

    func compare(key: Key, @noescape left: Void->ListValue<Element>?, insert: Bool) -> RedBlackComparisonResult<Int> {
        let leftCount = left()?.count ?? 0
        if !insert && key == leftCount {
            return .Found
        }
        else if key > leftCount {
            return .Descend(.Right, with: key)
        }
        else {
            // This also gets returned on a match when insert = true
            return .Descend(.Left, with: key - leftCount - 1)
        }
    }

    mutating func fixup(@noescape left: Void->ListValue<Element>?, @noescape right: Void->ListValue<Element>?) -> Bool {
        let c = count
        count = (left()?.count ?? 0) + (right()?.count ?? 0) + 1
        return c != count
    }
}

public struct List<Element>: ArrayLikeCollectionType {
    public typealias Index = Int
    public typealias Generator = IndexingGenerator<List<Element>>

    private typealias TreeValue = ListValue<Element>
    private typealias Tree = RedBlackTree<TreeValue>

    private var tree: Tree

    // Initializers.

    public init() {
        self.tree = Tree()
    }

    public init(_ elements: List<Element>) {
        self.tree = elements.tree
    }

    public init<S: SequenceType where S.Generator.Element == Element>(_ elements: S) {
        self.tree = Tree()
        for element in elements {
            self.append(element)
        }
    }

    // Variables.

    public var count: Int {
        return tree.count
    }

    // Methods.

    public subscript(index: Index) -> Element {
        get {
            let i = tree.find(index)!
            return tree[i].element
        }
        set {
            let i = tree.find(index)!
            tree[i].element = newValue
        }
    }

    public mutating func reserveCapacity(minimumCapacity: Int) {
        self.tree.reserveCapacity(minimumCapacity)
    }

    /// Inserts a new element at position `index`.
    /// - Requires: i < count
    /// - Complexity: O(log(count))
    public mutating func insert(newElement: Element, atIndex i: Int) {
        let (index, slot) = tree.insertionSlotFor(i)
        assert(index == nil)
        tree.insert(ListValue(count: 0, element: newElement), into: slot)
    }

    public mutating func removeAll(keepCapacity keepCapacity: Bool) {
        tree.removeAll(keepCapacity: keepCapacity)
    }

    /// Remove and return the element at `index`.
    /// - Requires: i >= 0 && i < count
    /// - Complexity: O(log(count))
    public mutating func removeAtIndex(index: Int) -> Element {
        let index = tree.find(index)!
        let result = tree[index].element
        tree.remove(index)
        return result
    }
}

extension List {
    public var debugInfo: Dictionary<String, Int> {
        return tree.debugInfo
    }
}