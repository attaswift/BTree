//
//  Random.swift
//  BTree
//
//  Created by Károly Lőrentey on 2015-12-20.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import Foundation

/// Returns a random number sampled from a uniform distribution from 0 to limit.
/// - Returns: A number in range `0..<limit`
func random(_ limit: Int) -> Int {
    return Int(arc4random_uniform(UInt32(limit)))
}

extension Array {
    /// Returns a copy of this array with all elements randomly shuffled.
    func shuffled() -> Array<Element> {
        var copy = self
        copy.shuffle()
        return copy
    }

    /// Randomly shuffles the elements of this array.
    mutating func shuffle() {
        let count = self.count
        for i in 0..<count {
            let j = random(count)
            (self[i], self[j]) = (self[j], self[i])
        }
    }
}
