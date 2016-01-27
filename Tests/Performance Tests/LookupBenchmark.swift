//
//  LookupBenchmark.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-21.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation
import TreeCollections

public func lookupBenchmark<P>(name: String, count: Int, sizes: [Int], factory: Int->P) -> Benchmark<PayloadArray<P>> {
    var benchmark = Benchmark<PayloadArray<P>>(name: "lookups")

    for size in sizes {
        benchmark.add(PayloadArray<P>(name: name, size: size, factory: factory))
    }
    benchmark.addExperiment("search in unsorted Array") { env in
        var array: [(Int, P)] = []
        for (key, payload) in env.input {
            array.append((key, payload))
        }

        let keys = (0..<count).map { _ in random(env.input.count) }

        var c = 0
        env.startMeasuring()
        for key in keys {
            for (k, _) in array {
                if k == key {
                    c += 1
                    break
                }
            }
        }
        env.stopMeasuring()

        if c != count { env.fail("Count is \(c), expected \(count)") }
    }
    
    benchmark.addExperiment("search in unsorted Deque") { env in
        var deque: Deque<(Int, P)> = []
        for (key, payload) in env.input {
            deque.append((key, payload))
        }

        let keys = (0..<count).map { _ in random(env.input.count) }

        var c = 0
        env.startMeasuring()
        for key in keys {
            for (k, _) in deque {
                if k == key {
                    c += 1
                    break
                }
            }
        }
        env.stopMeasuring()

        if c != count { env.fail("Count is \(c), expected \(count)") }
    }


    benchmark.addExperiment("lookup in SortedArray") { env in
        var array: SortedArray<Int, P> = [:]
        for (key, payload) in env.input {
            array[key] = payload
        }

        let keys = (0..<count).map { _ in random(env.input.count) }

        var c = 0
        env.startMeasuring()
        for key in keys {
            if let _ = array[key] {
                c += 1
            }
        }
        env.stopMeasuring()

        if c != count { env.fail("Count is \(c), expected \(count)") }
    }

    benchmark.addExperiment("lookup in Map") { env in
        var map: Map<Int, P> = [:]
        for (key, payload) in env.input {
            map[key] = payload
        }

        let keys = (0..<count).map { _ in random(env.input.count) }

        var c = 0
        env.startMeasuring()
        for key in keys {
            if let _ = map[key] {
                c += 1
            }
        }
        env.stopMeasuring()

        if c != count { env.fail("Count is \(c), expected \(count)") }
    }

    benchmark.addExperiment("lookup in Dictionary") { env in
        var dict: Dictionary<Int, P> = [:]
        for (key, payload) in env.input {
            dict[key] = payload
        }

        let keys = (0..<count).map { _ in random(env.input.count) }

        var c = 0
        env.startMeasuring()
        for key in keys {
            if let _ = dict[key] {
                c += 1
            }
        }
        env.stopMeasuring()

        if c != count { env.fail("Count is \(c), expected \(count)") }
    }

    return benchmark
}