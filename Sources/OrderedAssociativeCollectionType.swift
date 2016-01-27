//
//  OrderedAssociativeCollectionType.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-15.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// An associative collection type where the generator returns elements sorted by key.
public protocol OrderedAssociativeCollectionType: AssociativeCollectionType {
    typealias Key: Comparable
}

/// Sorted associative collections can be compared simply by equating their elements.
/// - Complexity: O(count)
@warn_unused_result
public func ==<C: OrderedAssociativeCollectionType where C.Value: Equatable, C.Generator.Element == (C.Key, C.Value)>
    (a: C, b: C) -> Bool {
        guard a.count == b.count else { return false }
        return a.elementsEqual(b, isEquivalent: { ae, be in ae.0 == be.0 && ae.1 == be.1 })
}

/// Sorted associative collections can be compared simply by equating their elements.
/// - Complexity: O(count)
@warn_unused_result
public func !=<C: OrderedAssociativeCollectionType where C.Value: Equatable, C.Generator.Element == (C.Key, C.Value)>
    (a: C, b: C) -> Bool {
        return !(a == b)
}

