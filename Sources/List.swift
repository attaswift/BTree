//
//  List.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-14.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

internal struct ListValue<Element>: RedBlackValue {
    typealias Key = Int
    typealias State = Int

    static var zeroState: State { return 0 }
    var state: Int // Size of subtree rooted at this node.

    var element: Element

    private init(element: Element) {
        self.state = 1
        self.element = element
    }


    func compare(key: Key, children: StateAccessor<ListValue<Element>>, insert: Bool) -> RedBlackComparisonResult<Int> {
        let leftCount = children.left
        if !insert && key == leftCount {
            return .Found
        }
        else if key > leftCount {
            return .Descend(.Right, with: key - leftCount - 1)
        }
        else {
            // This also gets returned on a match when insert = true
            return .Descend(.Left, with: key)
        }
    }

    mutating func updateState(children: StateAccessor<ListValue<Element>>) -> Bool {
        let old = state
        state = children.left + children.right + 1
        return old != state
    }
}

public struct List<Element>: ArrayLikeCollectionType {
    public typealias Index = Int
    public typealias Generator = IndexingGenerator<List<Element>>

    internal typealias TreeValue = ListValue<Element>
    internal typealias Tree = RedBlackTree<TreeValue>

    internal private(set) var tree: Tree

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


    public mutating func append(newElement: Element) {
        let v = ListValue(element: newElement)
        if let last = tree.lastIndex {
            tree.insert(v, into: .Toward(.Right, under: last))
        }
        else {
            tree.insert(v, into: .Root)
        }
    }
    
    /// Inserts a new element at position `index`.
    /// - Requires: i < count
    /// - Complexity: O(log(count))
    public mutating func insert(newElement: Element, atIndex index: Int) {
        let slot: Tree.Slot
        if let first = tree.firstIndex where index == 0 {
            slot = .Toward(.Left, under: first)
        }
        else if let last = tree.lastIndex where index == count {
            slot = .Toward(.Right, under: last)
        }
        else {
            let (i, s) = tree.insertionSlotFor(index)
            assert(i == nil)
            slot = s
        }
        tree.insert(ListValue(element: newElement), into: slot)
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
