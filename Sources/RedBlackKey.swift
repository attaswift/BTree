//
//  RedBlackKey.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-17.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

public protocol RedBlackKey: Comparable {
    typealias Summary: SummaryProtocol

    /// Returns a key that matches a node with `head` whose preceding nodes reduce into `summary`.
    /// - Complexity: Must be O(1).
    init(summary: Summary, head: Summary.Item)
}

public protocol RedBlackInsertionKey: RedBlackKey {
    /// The head value to store in nodes that are inserted for this key.
    /// - Requires: For all summaries `s`: `h == Key(summary: s, head: h).head`
    /// - Complexity: Must be O(1).
    var head: Summary.Item { get }
}

public struct StoredKey<Summary: SummaryProtocol where Summary.Item: Comparable>: RedBlackInsertionKey {
    public typealias Head = Summary.Item

    public let head: Head

    public init(_ head: Summary.Item) {
        self.head = head
    }
    public init(summary: Summary, head: Summary.Item) {
        self.init(head)
    }
}
public func == <Summary: SummaryProtocol where Summary.Item: Comparable>(a: StoredKey<Summary>, b: StoredKey<Summary>) -> Bool {
    return a.head == b.head
}
public func < <Summary: SummaryProtocol where Summary.Item: Comparable>(a: StoredKey<Summary>, b: StoredKey<Summary>) -> Bool {
    return a.head < b.head
}
extension StoredKey: CustomStringConvertible {
    public var description: String { return "\(self.head)" }
}


public struct PositionalKey: RedBlackInsertionKey {
    public typealias Summary = CountingSummary<Void>

    public let index: Int

    public init(_ index: Int) {
        self.index = index
    }
    public init(summary: Summary, head: Summary.Item) {
        self.index = summary.count
    }

    public var head: Void { return () }
}

public func ==(a: PositionalKey, b: PositionalKey) -> Bool {
    return a.index == b.index
}
public func <(a: PositionalKey, b: PositionalKey) -> Bool {
    return a.index <  b.index
}

extension PositionalKey: CustomStringConvertible {
    public var description: String { return "\(self.index)" }
}
