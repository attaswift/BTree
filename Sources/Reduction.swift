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
// - ReductionProtocol
// - Accumulator
// - Condensation
// - Distillate
// - Extract
public protocol ReductionProtocol: Equatable {
    typealias Item

    init() // Identity
    init(_ item: Item)
    init(_ a: Self, _ b: Self) // Monoid operator
}

@warn_unused_result
public func + <Reduction: ReductionProtocol>(a: Reduction?, b: Reduction?) -> Reduction {
    switch (a, b) {
    case (nil, nil): return Reduction()
    case (nil, .Some(let b)): return b
    case (.Some(let a), nil): return a
    case (.Some(let a), .Some(let b)): return Reduction(a, b)
    }
}

@warn_unused_result
public func + <Reduction: ReductionProtocol>(a: Reduction.Item?, b: Reduction?) -> Reduction {
    switch (a, b) {
    case (nil, nil): return Reduction()
    case (nil, .Some(let b)): return b
    case (.Some(let a), nil): return Reduction(a)
    case (.Some(let a), .Some(let b)): return Reduction(Reduction(a), b)
    }
}

@warn_unused_result
public func + <Reduction: ReductionProtocol>(a: Reduction?, b: Reduction.Item?) -> Reduction {
    switch (a, b) {
    case (nil, nil): return Reduction()
    case (nil, .Some(let b)): return Reduction(b)
    case (.Some(let a), nil): return a
    case (.Some(let a), .Some(let b)): return Reduction(a, Reduction(b))
    }
}

/// The empty reduction is simply a reduction that is a constant empty value. 
/// The empty reduction is a free reduction in that it doesn't constrain the type of its items.
/// Instances of empty reductions are of zero size -- RedBlackTree relies on this to shortcut their maintenance.
public enum EmptyReduction<T>: ReductionProtocol {
    public typealias Item = T

    case Null

    public init() { self = .Null }
    public init(_ item: Item) { self = .Null }
    public init(_ a: EmptyReduction<Item>, _ b: EmptyReduction<Item>) { self = .Null }
}
public func == <I>(a: EmptyReduction<I>, b: EmptyReduction<I>) -> Bool { return true }


/// The counting reduction is reduction that counts items. It is useful for implementing tree-based lists.
/// The counting reduction is a free reduction in that it doesn't constrain the type of its items.
public struct CountingReduction<Item>: ReductionProtocol {
    public let count: Int

    public init() { count = 0 }
    public init(_ item: Item) { count = 1 }
    public init(_ a: CountingReduction<Item>, _ b: CountingReduction<Item>) { count = a.count + b.count }
}
public func == <I>(a: CountingReduction<I>, b: CountingReduction<I>) -> Bool { return a.count == b.count }
