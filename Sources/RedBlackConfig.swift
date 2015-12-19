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
    typealias Summary: SummaryProtocol

    /// Returns a key that matches `head` whose preceding nodes reduce into `summary`.
    /// - Requires: `compare(key(h, after: r), to: h, after: r) == .Matched && head(key(h, after: r)) == h`.
    /// - Complexity: Must be O(1).
    static func key(head: Summary.Item, prefix summary: Summary) -> Key

    /// Returns the head value to store for a node that matches `key`.
    /// - Complexity: Must be O(1).
    static func head(key: Key) -> Summary.Item

    /// Compares `key` to a node with `head` whose preceding elements reduce into `summary`.
    /// - Complexity: Must be O(1).
    static func compare(key: Key, to head: Summary.Item, prefix summary: Summary) -> KeyMatchResult
}

public struct SimpleTreeConfig<Key: Comparable>: RedBlackConfig {
    /// We don't need to collect statistics about preceding keys.
    public typealias Summary = EmptySummary<Key>

    /// The head *is* the key in our case.
    public static func key(head: Key, prefix r: Summary) -> Key {
        return head
    }

    /// We just store the key directly in the node of the tree.
    public static func head(key: Key) -> Key {
        return key
    }

    /// Simply compare `key` to `head`, ignoring `summary`
    public static func compare(key: Key, to head: Key, prefix summary: Summary) -> KeyMatchResult {
        if key < head { return .Before }
        if key > head { return .After }
        return .Matching
    }
}

public struct IndexableTreeConfig: RedBlackConfig {
    public typealias Key = Int
    public typealias Summary = CountingSummary<Void>

    public static func key(head: Void, prefix summary: Summary) -> Key {
        return summary.count
    }

    public static func head(key: Key) -> Void {
        return ()
    }

    public static func compare(key: Int, to head: Void, prefix summary: Summary) -> KeyMatchResult {
        if key < summary.count { return .Before }
        if key > summary.count { return .After }
        return .Matching
    }
}


