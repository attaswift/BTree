//
//  Statistic.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-18.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

// Alternative names:
// - Statistic
// - Smell
// - Essence
// - Fingerprint
// - Reduction
// - Accumulator
// - Condensation
// - Distillate
// - Extract
public protocol SummaryProtocol: Equatable {
    typealias Item

    init() // Identity
    init(_ item: Item)
    init(_ a: Self, _ b: Self) // Monoid operator
}

@warn_unused_result
public func + <Summary: SummaryProtocol>(a: Summary?, b: Summary?) -> Summary {
    switch (a, b) {
    case (nil, nil):
        return Summary()
    case (nil, .Some(let b)):
        return b
    case (.Some(let a), nil):
        return a
    case (.Some(let a), .Some(let b)):
        return Summary(a, b)
    }
}

@warn_unused_result
public func + <Summary: SummaryProtocol>(a: Summary.Item?, b: Summary?) -> Summary {
    switch (a, b) {
    case (nil, nil):
        return Summary()
    case (nil, .Some(let b)):
        return b
    case (.Some(let a), nil):
        return Summary(a)
    case (.Some(let a), .Some(let b)):
        return Summary(Summary(a), b)
    }
}

@warn_unused_result
public func + <Summary: SummaryProtocol>(a: Summary?, b: Summary.Item?) -> Summary {
    switch (a, b) {
    case (nil, nil):
        return Summary()
    case (nil, .Some(let b)):
        return Summary(b)
    case (.Some(let a), nil):
        return a
    case (.Some(let a), .Some(let b)):
        return Summary(a, Summary(b))
    }
}

public func += <S: SummaryProtocol>(inout left: S, right: S.Item?) {
    left = left + right
}
public func += <S: SummaryProtocol>(inout left: S, right: S?) {
    left = left + right
}

/// The empty summary is simply a summary that is a constant empty value. 
/// The empty summary is a free summary in that it doesn't constrain the type of its items.
/// Instances of empty summarys are of zero size -- RedBlackTree relies on this to shortcut their maintenance.
public enum EmptySummary<T>: SummaryProtocol {
    public typealias Item = T

    case Null

    public init() { self = .Null }
    public init(_ item: Item) { self = .Null }
    public init(_ a: EmptySummary<Item>, _ b: EmptySummary<Item>) { self = .Null }
}
public func == <I>(a: EmptySummary<I>, b: EmptySummary<I>) -> Bool { return true }


/// The counting summary is summary that counts items. It is useful for implementing tree-based lists.
/// The counting summary is a free summary in that it doesn't constrain the type of its items.
public struct CountingSummary<Item>: SummaryProtocol {
    public let count: Int

    public init() { count = 0 }
    public init(_ item: Item) { count = 1 }
    public init(_ a: CountingSummary<Item>, _ b: CountingSummary<Item>) { count = a.count + b.count }
}
public func == <I>(a: CountingSummary<I>, b: CountingSummary<I>) -> Bool { return a.count == b.count }
