//
//  BTreeIndex.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2016-02-11.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

private enum WalkDirection {
    case Forward
    case Backward
}

/// An index into a collection that uses a b-tree for storage.
public struct BTreeIndex<Key: Comparable, Payload>: BidirectionalIndexType {
    public typealias Distance = Int
    typealias Node = BTreeNode<Key, Payload>

    internal private(set) var root: Weak<Node>
    internal private(set) var path: [Weak<Node>]
    internal private(set) var slot: Int

    internal init() {
        self.root = Weak()
        self.path = []
        self.slot = 0
    }

    internal init(startIndexOf root: Node) {
        var node = root
        var path = [Weak(root)]
        while !node.isLeaf {
            node = node.children[0]
            path.append(Weak(node))
        }
        self.root = Weak(root)
        self.path = path
        self.slot = 0
    }

    internal init(endIndexOf root: Node) {
        self.root = Weak(root)
        self.path = []
        self.slot = 0
    }

    internal init(path: [Node], slot: Int) {
        self.root = Weak(path[0])
        self.path = path.map { Weak($0) }
        self.slot = slot
    }
    internal init(path: [Weak<Node>], slot: Int) {
        self.root = path[0]
        self.path = path
        self.slot = slot
    }

    private mutating func invalidate() {
        self.root = Weak()
        self.path = []
        self.slot = 0
    }

    private mutating func ascend(direction: WalkDirection) {
        while let node = path.removeLast().value, parent = self.path.last?.value {
            guard let i = parent.slotOf(node) else {
                invalidate()
                return
            }
            if direction == .Forward && i < parent.keys.count {
                slot = i
                return
            }
            else if direction == .Backward && i > 0 {
                slot = i - 1
                return
            }
        }
        self.path = []
        self.slot = 0
    }

    private mutating func descend(direction: WalkDirection) {
        guard let n = self.path.last?.value else { invalidate(); return }
        assert(!n.isLeaf)
        var node = n.children[direction == .Forward ? slot + 1 : slot]
        path.append(Weak(node))
        while !node.isLeaf {
            node = node.children[direction == .Forward ? 0 : node.children.count - 1]
            path.append(Weak(node))
        }
        slot = direction == .Forward ? 0 : node.keys.count - 1
    }

    internal mutating func successorInPlace() {
        guard let node = self.path.last?.value else { return }
        if node.isLeaf {
            if slot < node.keys.count - 1 {
                slot += 1
            }
            else {
                ascend(.Forward)
            }
        }
        else {
            descend(.Forward)
        }
    }
    
    internal mutating func predecessorInPlace() {
        guard let node = self.path.last?.value else {
            var node = root.value!
            path.append(root)
            while !node.isLeaf {
                node = node.children.last!
                path.append(Weak(node))
            }
            slot = node.keys.count - 1
            return
        }
        if node.isLeaf {
            if slot > 0 {
                slot -= 1
            }
            else {
                ascend(.Backward)
            }
        }
        else {
            descend(.Backward)
        }
    }

    /// Return the next index after `self` in its collection.
    ///
    /// - Requires: self is valid and not the end index.
    /// - Complexity: Amortized O(1).
    public func successor() -> BTreeIndex<Key, Payload> {
        var result = self
        result.successorInPlace()
        return result
    }

    /// Return the index preceding `self` in its collection.
    ///
    /// - Requires: self is valid and not the start index.
    /// - Complexity: Amortized O(1).
    public func predecessor() -> BTreeIndex<Key, Payload> {
        var result = self
        result.predecessorInPlace()
        return result
    }
}

public func == <Key: Comparable, Payload>(a: BTreeIndex<Key, Payload>, b: BTreeIndex<Key, Payload>) -> Bool {
    // TODO: Invalid indexes may compare unequal under this definition.
    guard a.slot == b.slot else { return false }
    guard a.root.value === b.root.value else { return false }
    guard a.path.count == b.path.count else { return false }
    for i in 0 ..< a.path.count {
        guard a.path[i].value === b.path[i].value else { return false }
    }
    return true
}
