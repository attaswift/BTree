//
//  SortedArray.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-15.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// The index into a sorted array. This is simply a wrapper around an Int that exists only to prevent conflicts when
/// the Key of the array is also an Int.
public struct SortedArrayIndex: RandomAccessIndexType {
    public typealias Distance = Int

    public let value: Int
    public init(_ value: Int) {
        self.value = value
    }

    @warn_unused_result
    public func successor() -> SortedArrayIndex { return SortedArrayIndex(value + 1) }

    @warn_unused_result
    public func predecessor() -> SortedArrayIndex { return SortedArrayIndex(value - 1) }

    @warn_unused_result
    public func distanceTo(other: SortedArrayIndex) -> Distance { return other.value - value }

    @warn_unused_result
    public func advancedBy(n: Distance) -> SortedArrayIndex { return SortedArrayIndex(value + n) }

    @warn_unused_result
    public func advancedBy(n: Distance, limit: SortedArrayIndex) -> SortedArrayIndex {
        return SortedArrayIndex(min(value + n, limit.value))
    }
}

/// A sorted associative container with copy-on-write value semantics that uses a sorted array as the backing store.
public struct SortedArray<Key: Comparable, Value>: CollectionType {
    public typealias Element = (Key, Value)
    public typealias Index = SortedArrayIndex
    public typealias Generator = IndexingGenerator<SortedArray<Key, Value>>

    private var contents: ContiguousArray<Element>

    public init() {
        contents = []
    }
    public init(minimumCapacity: Int) {
        contents = []
        contents.reserveCapacity(minimumCapacity)
    }

    public var count: Int { return contents.count }
    public var startIndex: Index { return Index(0) }
    public var endIndex: Index { return Index(count) }

    public mutating func reserveCapacity(minimumCapacity: Int) {
        contents.reserveCapacity(minimumCapacity)
    }
    
    public subscript(index: Index) -> Element {
        return contents[index.value]
    }

    public subscript(key: Key) -> Value? {
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
                self.contents.insert((key, new), atIndex: index.value)
            case (.Some(_), nil):
                self.contents.removeAtIndex(index.value)
            case (.Some(_), .Some(let new)):
                self.contents[index.value] = (key, new)
            }
        }
    }

    public func indexForKey(key: Key) -> Index? {
        switch slotOf(key) {
        case (nil, _): return nil
        case (.Some(_), let index): return index
        }
    }

    public mutating func updateValue(value: Value, forKey key: Key) -> Value? {
        let (old, index) = slotOf(key)
        if old != nil {
            contents[index.value] = (key, value)
            return old
        }
        else {
            contents.insert((key, value), atIndex: index.value)
            return nil
        }
    }

    public mutating func removeAtIndex(index: Index) -> (Key, Value) {
        return contents.removeAtIndex(index.value)
    }

    public mutating func removeValueForKey(key: Key) -> Value? {
        let (old, index) = slotOf(key)
        if old != nil {
            contents.removeAtIndex(index.value)
            return old
        }
        else {
            return nil
        }
    }

    public mutating func removeAll() {
        contents.removeAll()
    }


    private func slotOf(key: Key) -> (Value?, Index) {
        var start = startIndex.value
        var end = endIndex.value
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
                return (v, Index(start))
            }
        }
        return (nil, Index(start))
    }
}
