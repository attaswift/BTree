//
//  Permutations.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-21.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// Generates all permutations of length `count`.
/// - Returns: a generator that produces arrays of integers in range `0..<count`, in all possible order.
func generatePermutations(count: Int) -> AnyGenerator<[Int]> {
    if count == 0 {
        return anyGenerator(EmptyCollection<[Int]>().generate())
    }
    if count == 1 {
        return anyGenerator(CollectionOfOne([0]).generate())
    }
    if count == 2 {
        return anyGenerator([[0, 1], [1, 0]].generate())
    }
    let generator = generatePermutations(count - 1)
    var perm: [Int] = []
    var next = -1
    return anyGenerator {
        if next < 0 {
            guard let p = generator.next() else { return nil }
            perm = p
            next = p.count
        }
        var r = perm
        r.insert(count - 1, atIndex: next)
        next -= 1
        return r
    }
}

