//
//  DictionaryType.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-15.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// A protocol for things that work like a `Dictionary`.
public protocol AssociativeCollectionType: CollectionType, DictionaryLiteralConvertible, CustomStringConvertible, CustomDebugStringConvertible {
    typealias Key
    typealias Value
    typealias Generator: GeneratorType /* where Generator.Element == (Key, Value) */

    init()
    var count: Int { get }
    var startIndex: Index { get } // With default implementation for Index == Int
    var endIndex: Index { get } // With default implementation for Index == Int

    subscript(position: Index) -> (Key, Value) { get }
    subscript(key: Key) -> Value? { get set }

    func indexForKey(key: Key) -> Index?
    mutating func updateValue(value: Value, forKey key: Key) -> Value?
    mutating func removeAtIndex(index: Index) -> (Key, Value)
    mutating func removeValueForKey(key: Key) -> Value?
    mutating func removeAll()
}

extension AssociativeCollectionType {
    public typealias Element = (Key, Value)

    public init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(elements)
    }

    public init<S: SequenceType where S.Generator.Element == Element>(_ elements: S) {
        self.init()
        for (key, value) in elements {
            self[key] = value
        }
    }
    
    public var isEmpty: Bool {
        return count == 0
    }
}

// This extension should match all AssociativeCollectionTypes.
extension AssociativeCollectionType where Generator.Element == (Key, Value) {

    public var keys: LazyMapCollection<Self, Key> {
        return LazyMapCollection(self) { key, _ in key }
    }

    public var values: LazyMapCollection<Self, Value> {
        return LazyMapCollection(self) { _, value in value }
    }

    public var description: String {
        let contents = self.map { (key, value) -> String in
            let ks = String(key)
            let vs = String(value)
            return "\(ks): \(vs)"
        }
        return "[" + contents.joinWithSeparator(", ") + "]"
    }

    public var debugDescription: String {
        let contents = self.map { (key, value) -> String in
            let ks = String(reflecting: key)
            let vs = String(reflecting: value)
            return "\(ks): \(vs)"
        }
        return "[" + contents.joinWithSeparator(", ") + "]"
    }
}

extension AssociativeCollectionType where Index == Int {
    public var startIndex: Index { return 0 }
    public var endIndex: Index { return count }

    public func generate() -> IndexingGenerator<Self> {
        return IndexingGenerator(self)
    }
}

