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

public struct BTreeIndex<Key: Comparable, Payload>: BidirectionalIndexType {
    public typealias Distance = Int
    typealias Node = BTreeNode<Key, Payload>

    internal private(set) var path: [Weak<Node>]
    internal private(set) var slot: Int

    internal init() {
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
        self.path = path
        self.slot = 0
    }

    internal init(path: [Node], slot: Int) {
        self.path = path.map { Weak($0) }
        self.slot = slot
    }
    internal init(path: [Weak<Node>], slot: Int) {
        self.path = path
        self.slot = slot
    }

    private mutating func invalidate() {
        self.path = []
        self.slot = 0
    }

    private mutating func ascend(direction: WalkDirection) {
        while let node = path.removeLast().value, parent = self.path.last?.value {
            guard let i = parent.slotOf(node) else {
                break
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
        invalidate()
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

    private mutating func successorInPlace() {
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
    private mutating func predecessorInPlace() {
        guard let node = self.path.last?.value else { return }
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

    public func successor() -> BTreeIndex<Key, Payload> {
        var result = self
        result.successorInPlace()
        return result
    }

    public func predecessor() -> BTreeIndex<Key, Payload> {
        var result = self
        result.predecessorInPlace()
        return result
    }
}

public func == <Key: Comparable, Payload>(a: BTreeIndex<Key, Payload>, b: BTreeIndex<Key, Payload>) -> Bool {
    // TODO: Invalid indexes may compare unequal under this definition.
    guard a.slot == b.slot else { return false }
    guard a.path.count == b.path.count else { return false }
    for i in 0 ..< a.path.count {
        if a.path[i].value !== b.path[i].value{
            return false
        }
    }
    return true
}
