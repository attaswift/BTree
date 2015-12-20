//
//  List2.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-17.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

public struct List<Element>: ArrayLikeCollectionType {
    public typealias Index = Int
    public typealias Generator = ListGenerator<Element>

    internal typealias Config = IndexableTreeConfig
    internal typealias Tree = RedBlackTree<Config, Element>

    internal private(set) var tree: Tree

    // Initializers

    public init() {
        self.tree = Tree()
    }

    public init(_ elements: List<Element>) {
        self.tree = elements.tree
    }

    public init<S: SequenceType where S.Generator.Element == Element>(_ elements: S) {
        self.tree = Tree()
        tree.reserveCapacity(elements.underestimateCount())
        for element in elements {
            tree.insert(element, forKey: tree.count, after: tree.rightmost)
        }
    }

    // Subscripting

    public subscript(index: Index) -> Element {
        get {
            let handle = tree.find(index)!
            return tree.payloadAt(handle)
        }
        set(element) {
            let handle = tree.find(index)!
            tree.setPayloadAt(handle, to: element)
        }
    }

    // Properties

    public var count: Int {
        return tree.count
    }

    // Methods

    public func generate() -> Generator {
        return Generator(tree: tree, direction: .Right, handle: tree.leftmost)
    }

    // Mutators

    public mutating func reserveCapacity(minimumCapacity: Int) {
        self.tree.reserveCapacity(minimumCapacity)
    }

    public mutating func append(newElement: Element) {
        tree.insert(newElement, forKey: tree.count, after: tree.rightmost)
    }

    /// Inserts a new element at position `index`.
    /// - Requires: i < count
    /// - Complexity: O(log(count))
    public mutating func insert(newElement: Element, atIndex index: Int) {
        precondition(index >= 0 && index <= count)
        if index == 0 {
            tree.insert(newElement, forKey: index, before: tree.leftmost)
        }
        else if index == count {
            tree.insert(newElement, forKey: index, after: tree.rightmost)
        }
        else {
            tree.insert(newElement, forKey: index, before: tree.find(index)!)
        }
    }

    public mutating func removeAll(keepCapacity keepCapacity: Bool) {
        tree.removeAll(keepCapacity: keepCapacity)
    }

    /// Remove and return the element at `index`.
    /// - Requires: i >= 0 && i < count
    /// - Complexity: O(log(count))
    public mutating func removeAtIndex(index: Int) -> Element {
        return tree.remove(tree.find(index)!)
    }
}

public struct ListGenerator<Element>: GeneratorType {
    internal typealias Config = IndexableTreeConfig
    internal typealias Tree = RedBlackTree<Config, Element>

    private let tree: Tree
    private let direction: RedBlackDirection
    private var handle: Tree.Handle?

    public mutating func next() -> Element? {
        guard let handle = handle else { return nil }
        self.handle = tree.step(handle, toward: direction)
        return tree.payloadAt(handle)
    }
}