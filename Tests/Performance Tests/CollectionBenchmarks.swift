//
//  CollectionBenchmarks.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2016-01-16.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import Foundation

private func smallPayloadFactory(i: Int) -> Int {
    return i
}

private let testObject = NSObject()
private func largePayloadFactory(i: Int) -> (Int, Double, String, [Int], AnyObject) {
    return (i, Double(i), String(i), [i, 2 * i, 3 * i], testObject)
}

private func voidPayloadFactory(i: Int) -> Void { return () }

struct CollectionBenchmarks {

    private static var sizes: [Int] {
        var last: Int? = nil
        let sizes = (0...18*4).map { Int(floor(pow(2, Double($0) / 4))) }.filter { i in
            guard last != i else { return false }
            last = i
            return true
        }
        return sizes
    }

    static let smallInsertion = insertionBenchmark("small", sizes: sizes, factory: smallPayloadFactory)
    static let bigInsertion = insertionBenchmark("bigger", sizes: [50000], factory: largePayloadFactory)
    static let lookup = lookupBenchmark("bigger", count: 100000, sizes: [10000], factory: largePayloadFactory)
    static let removal = removalBenchmark("bigger", sizes: [10000], factory: largePayloadFactory)
    static let orderOptimizer = orderOptimizerBenchmark("order optimizer", orders: [511, 1023, 1535, 2047, 2559, 3071, 3583, 4095], inputSizes: [128, 1024, 16384, 131072, 524288], factory: voidPayloadFactory)
}