//
//  BTreeGenerator.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-11.
//  Copyright © 2015–2016 Károly Lőrentey.
//

/// A generator for all elements stored in a B-tree, in ascending key order.
public struct BTreeGenerator<Key: Comparable, Payload>: GeneratorType {
    public typealias Element = (Key, Payload)
    typealias Node = BTreeNode<Key, Payload>
    typealias State = BTreeStrongPath<Key, Payload>

    var state: State

    internal init(_ state: State) {
        self.state = state
    }

    /// Advance to the next element and return it, or return `nil` if no next element exists.
    ///
    /// - Complexity: Amortized O(1)
    public mutating func next() -> Element? {
        if state.isAtEnd { return nil }
        let result = state.element
        state.moveForward()
        return result
    }
}

/// A generator for the payloads stored in a B-tree with an empty key.
public struct BTreePayloadGenerator<Payload>: GeneratorType {
    internal typealias Base = BTreeGenerator<EmptyKey, Payload>
    private var base: Base

    internal init(_ base: Base) {
        self.base = base
    }

    /// Advance to the next element and return it, or return `nil` if no next element exists.
    ///
    /// - Complexity: Amortized O(1)
    public mutating func next() -> Payload? {
        return base.next()?.1
    }
}

/// A generator for the keys stored in a B-tree without a payload.
public struct BTreeKeyGenerator<Key: Comparable>: GeneratorType {
    internal typealias Base = BTreeGenerator<Key, Void>
    private var base: Base

    internal init(_ base: Base) {
        self.base = base
    }

    /// Advance to the next element and return it, or return `nil` if no next element exists.
    ///
    /// - Complexity: Amortized O(1)
    public mutating func next() -> Key? {
        return base.next()?.0
    }
}

/// A mutable path in a B-tree, holding strong references to nodes on the path.
/// This path variant does not support modifying the tree itself; it is suitable for use in generators.
internal struct BTreeStrongPath<Key: Comparable, Payload>: BTreePath {
    typealias Node = BTreeNode<Key, Payload>

    var root: Node
    var position: Int

    var _path: [Node]
    var _slots: [Int]
    var node: Node
    var slot: Int?

    init(_ root: Node) {
        self.root = root
        self.position = root.count
        self._path = []
        self._slots = []
        self.node = root
        self.slot = nil
    }

    var count: Int { return root.count }
    var length: Int { return _path.count + 1 }

    mutating func popFromSlots() {
        assert(self.slot != nil)
        position += node.count - node.positionOfSlot(slot!)
        slot = nil
    }

    mutating func popFromPath() {
        assert(_path.count > 0 && slot == nil)
        node = _path.removeLast()
        slot = _slots.removeLast()
    }

    mutating func pushToPath() {
        assert(slot != nil)
        let child = node.children[slot!]
        _path.append(node)
        node = child
        _slots.append(slot!)
        slot = nil
    }

    mutating func pushToSlots(slot: Int, positionOfSlot: Int) {
        assert(self.slot == nil)
        position -= node.count - positionOfSlot
        self.slot = slot
    }

    func forEach(ascending ascending: Bool, @noescape body: (Node, Int) -> Void) {
        if ascending {
            body(node, slot!)
            for i in (0 ..< _path.count).reverse() {
                body(_path[i], _slots[i])
            }
        }
        else {
            for i in 0 ..< _path.count {
                body(_path[i], _slots[i])
            }
            body(node, slot!)
        }
    }

    func forEachSlot(ascending ascending: Bool, @noescape body: Int -> Void) {
        if ascending {
            body(slot!)
            _slots.reverse().forEach(body)
        }
        else {
            _slots.forEach(body)
            body(slot!)
        }
    }
}
