//
//  BTreeIndex.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-11.
//  Copyright © 2015–2016 Károly Lőrentey.
//

private enum WalkDirection {
    case Forward
    case Backward
}

/// An index into a collection that uses a b-tree for storage.
///
/// This index satisfies `CollectionType`'s requirement for O(1) access, but
/// it is only suitable for read-only processing -- most tree mutations will 
/// invalidate all existing indexes.
/// 
/// - SeeAlso: `BTreeCursor` for an efficient way to modify a batch of values in a b-tree.
public struct BTreeIndex<Key: Comparable, Payload>: BidirectionalIndexType {
    public typealias Distance = Int
    typealias Node = BTreeNode<Key, Payload>

    internal private(set) var root: Weak<Node>
    internal private(set) var path: [Weak<Node>]
    internal private(set) var slots: [Int]

    internal init(startIndexOf root: Node) {
        self.root = Weak(root)
        self.path = []
        self.slots = []
        guard !root.isEmpty else { return }
        descend(.Forward, node: root)
    }

    internal init(endIndexOf root: Node) {
        self.root = Weak(root)
        self.path = []
        self.slots = []
        path.reserveCapacity(root.depth + 1)
    }

    internal init(path: [Weak<Node>], slots: [Int]) {
        precondition(path.count == slots.count)
        precondition(path.count > 0)
        self.root = path[0]
        self.slots = slots
        self.path = path
    }

    internal func expectValid(@autoclosure expression: Void->Bool, file: StaticString = __FILE__, line: UInt = __LINE__) {
        precondition(expression(), "Invalid BTreeCursor", file: file, line: line)
    }

    @noreturn internal func invalid(file: StaticString = __FILE__, line: UInt = __LINE__) {
        preconditionFailure("Invalid BTreeCursor", file: file, line: line)
    }

    private mutating func descend(direction: WalkDirection, node: Node? = nil) {
        var node = node ?? path.last!.value!.children[slots.last!]
        path.append(Weak(node))
        while !node.isLeaf {
            let slot = direction == .Forward ? 0 : node.children.count - 1
            slots.append(slot)
            node = node.children[slot]
            path.append(Weak(node))
        }
        slots.append(direction == .Forward ? 0 : node.elements.count - 1)
    }

    private mutating func popPath() {
        guard let n = path.removeLast().value else { invalid() }
        slots.removeLast()
        if path.count > 0 {
            guard let p = path.last!.value else { invalid() }
            let s = slots.last!
            expectValid(s < p.children.count && p.children[s] === n)
        }
    }

    internal mutating func successorInPlace() {
        guard root.value != nil else { invalid() }
        guard let node = self.path.last?.value else { invalid() }
        if node.isLeaf {
            if slots.last! < node.elements.count - 1 {
                slots[slots.count - 1] += 1
            }
            else {
                // Ascend
                popPath()
                while slots.count > 0 && slots.last! == path.last!.value!.elements.count {
                    popPath()
                }
            }
        }
        else {
            slots[slots.count - 1] += 1
            descend(.Forward)
        }
    }
    
    internal mutating func predecessorInPlace() {
        expectValid(root.value != nil)
        if path.count == 0 {
            descend(.Backward, node: root.value!)
            return
        }
        guard let node = self.path.last!.value else { invalid() }
        if node.isLeaf {
            if slots.last! > 0 {
                slots[slots.count - 1] -= 1
            }
            else {
                // Ascend
                popPath()
                while slots.count > 0 && slots.last! == 0 {
                    popPath()
                }
                if slots.count > 0 {
                    slots[slots.count - 1] -= 1
                }
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
    // Invalid indexes should compare unequal to every index, including themselves.
    guard let ar = a.root.value, br = b.root.value where ar === br else { return false }
    guard a.slots == b.slots else { return false }
    for i in 0 ..< a.path.count {
        guard a.path[i].value === b.path[i].value else { return false }
    }
    return true
}
