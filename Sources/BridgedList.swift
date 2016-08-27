//
//  BridgedList.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-08-10.
//  Copyright © 2016. Károly Lőrentey.
//

import Foundation

extension List where Element: AnyObject {
    /// Return a view of this list as an immutable `NSArray`, without copying elements.
    /// This is useful when you want to use `List` values in Objective-C APIs.
    /// 
    /// - Complexity: O(1)
    public var arrayView: NSArray {
        return BridgedTree<EmptyKey, Element>(self.tree)
    }
}

internal final class BridgedListEnumerator<Key: Comparable, Value>: NSEnumerator {
    var iterator: BTree<Key, Value>.Iterator
    init(iterator: BTree<Key, Value>.Iterator) {
        self.iterator = iterator
        super.init()
    }

    public override func nextObject() -> Any? {
        return iterator.next()?.1
    }
}

internal class BridgedTree<Key: Comparable, Value>: NSArray {
    var tree = BTree<Key, Value>()

    override var count: Int {
        return tree.count
    }

    override func object(at index: Int) -> Any {
        return tree.element(atOffset: index).1
    }

    public override func objectEnumerator() -> NSEnumerator {
        return BridgedListEnumerator(iterator: tree.makeIterator())
    }

    public override func copy(with zone: NSZone? = nil) -> Any {
        return self
    }
}

extension BridgedTree {
    convenience init(_ tree: BTree<Key, Value>) {
        self.init()
        self.tree = tree
    }
}
