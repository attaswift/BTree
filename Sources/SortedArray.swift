//
//  SortedArray.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-15.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// A sorted associative container with copy-on-write value semantics that uses a sorted array as the backing store.
internal struct SortedArray<Key: Comparable, Value>: SortedAssociativeCollectionType {
    internal typealias Element = (Key, Value)
    internal typealias Index = Int
    internal typealias Generator = IndexingGenerator<SortedArray<Key, Value>>

    private var contents: ContiguousArray<Element>

    internal init() {
        contents = []
    }
    internal init(minimumCapacity: Int) {
        contents = []
        contents.reserveCapacity(minimumCapacity)
    }

    internal var count: Int { return contents.count }
    internal var startIndex: Int { return 0 }
    internal var endIndex: Int { return count }

    internal subscript(index: Int) -> Element {
        return contents[index]
    }

    internal subscript(key: Key) -> Value? {
        get {
            let (value, _) = slotOf(key)
            return value
        }
        set(new) {
            let (old, index) = slotOf(key)
            switch (old, new) {
            case (nil, nil):
                return
            case (nil, .Some(let new)):
                self.contents.insert((key, new), atIndex: index)
            case (.Some(_), nil):
                self.contents.removeAtIndex(index)
            case (.Some(_), .Some(let new)):
                self.contents[index] = (key, new)
            }
        }
    }

    internal func indexForKey(key: Key) -> Index? {
        switch slotOf(key) {
        case (nil, _): return nil
        case (.Some(_), let index): return index
        }
    }

    internal mutating func updateValue(value: Value, forKey key: Key) -> Value? {
        let (old, index) = slotOf(key)
        if old != nil {
            contents[index] = (key, value)
            return old
        }
        else {
            contents.insert((key, value), atIndex: index)
            return nil
        }
    }

    internal mutating func removeAtIndex(index: Index) -> (Key, Value) {
        return contents.removeAtIndex(index)
    }

    internal mutating func removeValueForKey(key: Key) -> Value? {
        let (old, index) = slotOf(key)
        if old != nil {
            contents.removeAtIndex(index)
            return old
        }
        else {
            return nil
        }
    }

    internal mutating func removeAll() {
        contents.removeAll()
    }


    private func slotOf(key: Key) -> (Value?, Int) {
        var start = startIndex
        var end = endIndex
        while start < end {
            let mid = start + (end - start) / 2
            if contents[mid].0 < key {
                start = mid + 1
            }
            else {
                end = mid
            }
        }
        if start < count {
            let (k, v) = contents[start]
            if k == key {
                return (v, start)
            }
        }
        return (nil, start)
    }
}
