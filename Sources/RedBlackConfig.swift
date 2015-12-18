//
//  RedBlackConfig.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-17.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

public enum KeyMatchResult {
    case Matching
    case Before
    case After
}

public protocol RedBlackConfig {
    typealias Key
    typealias Reduction: ReductionProtocol

    /// Returns a key that matches `head` whose preceding nodes reduce into `reduction`.
    /// - Requires: `compare(key(h, after: r), to: h, after: r) == .Matched && head(key(h, after: r)) == h`.
    /// - Complexity: Must be O(1).
    static func key(head: Reduction.Item, reducedPrefix reduction: Reduction) -> Key

    /// Returns the head value to store for a node that matches `key`.
    /// - Complexity: Must be O(1).
    static func head(key: Key) -> Reduction.Item

    /// Compares `key` to a node with `head` whose preceding elements reduce into `reduction`.
    /// - Complexity: Must be O(1).
    static func compare(key: Key, to head: Reduction.Item, reducedPrefix reduction: Reduction) -> KeyMatchResult
}

public struct SimpleTreeConfig<Key: Comparable>: RedBlackConfig {
    /// We don't need to collect statistics about preceding keys.
    public typealias Reduction = EmptyReduction<Key>

    /// The head *is* the key in our case.
    public static func key(head: Key, reducedPrefix r: Reduction) -> Key {
        return head
    }

    /// We just store the key directly in the node of the tree.
    public static func head(key: Key) -> Key {
        return key
    }

    /// Simply compare `key` to `head`, ignoring `reduction`
    public static func compare(key: Key, to head: Key, reducedPrefix reduction: Reduction) -> KeyMatchResult {
        if key < head { return .Before }
        if key > head { return .After }
        return .Matching
    }
}

public struct ListTreeConfig: RedBlackConfig {
    public typealias Key = Int
    public typealias Reduction = CountingReduction<Void>

    public static func key(head: Void, reducedPrefix reduction: Reduction) -> Key {
        return reduction.count
    }

    public static func head(key: Key) -> Void {
        return ()
    }

    public static func compare(key: Int, to head: Void, reducedPrefix reduction: Reduction) -> KeyMatchResult {
        if key < reduction.count { return .Before }
        if key > reduction.count { return .After }
        return .Matching
    }
}


