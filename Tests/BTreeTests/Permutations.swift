//
//  Permutations.swift
//  BTree
//
//  Created by Károly Lőrentey on 2015-12-21.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import Foundation

/// Generates all permutations of length `count`.
/// - Returns: an iterator that produces arrays of integers in range `0..<count`, in all possible order.
func generatePermutations(_ count: Int) -> AnyIterator<[Int]> {
    if count == 0 {
        return AnyIterator(EmptyCollection<[Int]>().makeIterator())
    }
    if count == 1 {
        return AnyIterator(CollectionOfOne([0]).makeIterator())
    }
    if count == 2 {
        return AnyIterator([[0, 1], [1, 0]].makeIterator())
    }
    let iterator = generatePermutations(count - 1)
    var perm: [Int] = []
    var next = -1
    return AnyIterator {
        if next < 0 {
            guard let p = iterator.next() else { return nil }
            perm = p
            next = p.count
        }
        var r = perm
        r.insert(count - 1, at: next)
        next -= 1
        return r
    }
}

/// Generates all inversion vectors of length `count`. The vectors returned all have an extra '0' element prepended for convenience.
func generateInversions(_ count: Int) -> AnyIterator<[Int]> {
    if count == 0 {
        return AnyIterator(EmptyCollection<[Int]>().makeIterator())
    }
    if count == 1 {
        return AnyIterator(CollectionOfOne([0]).makeIterator())
    }
    if count == 2 {
        return AnyIterator([[0, 0], [0, 1]].makeIterator())
    }
    let iterator = generateInversions(count - 1)
    var inv: [Int] = []
    var next = 1
    return AnyIterator {
        if next > inv.count {
            guard let i = iterator.next() else { return nil }
            inv = i
            next = 0
        }
        var i = inv
        i.append(next)
        next += 1
        return i
    }
}
