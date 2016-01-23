//
//  RemovalBenchmark.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-26.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

import TreeCollections

public func removalBenchmark<P>(name: String, sizes: [Int], factory: Int->P) -> Benchmark<PayloadArray<P>> {
    var benchmark = Benchmark<PayloadArray<P>>(name: "removals")

    for size in sizes {
        benchmark.add(PayloadArray<P>(name: name, size: size, factory: factory))
    }

    benchmark.addExperiment("removal from unsorted Array") { env in
        var array: [(Int, P)] = []
        for (key, payload) in env.input {
            array.append((key, payload))
        }

        let shuffledKeys = env.input.map { $0.0 }.shuffle()

        env.startMeasuring()
        for key in shuffledKeys { // O(n^2)
            let index = array.indexOf { $0.0 == key } // O(n)
            array.removeAtIndex(index!) // O(n)
        }
        env.stopMeasuring()
    }

    benchmark.addExperiment("removal from unsorted Deque") { env in
        var deque: Deque<(Int, P)> = []
        for (key, payload) in env.input {
            deque.append((key, payload))
        }

        let shuffledKeys = env.input.map { $0.0 }.shuffle()

        env.startMeasuring()
        for key in shuffledKeys { // O(n^2)
            let index = deque.indexOf { $0.0 == key } // O(n)
            deque.removeAtIndex(index!) // O(n)
        }
        env.stopMeasuring()
    }


    benchmark.addExperiment("removal from SortedArray") { env in
        var array: SortedArray<Int, P> = [:]
        for (key, payload) in env.input {
            array[key] = payload
        }

        let shuffledKeys = env.input.map { $0.0 }.shuffle()

        env.startMeasuring() // O(n^2)
        for key in shuffledKeys {
            let index = array.indexForKey(key) // O(log(n))
            array.removeAtIndex(index!) // O(n)
        }
        env.stopMeasuring()
    }

    benchmark.addExperiment("removal from unsorted Dictionary") { env in
        var dict: Dictionary<Int, P> = [:]
        for (key, payload) in env.input {
            dict[key] = payload
        }

        let shuffledKeys = env.input.map { $0.0 }.shuffle()

        env.startMeasuring()
        for key in shuffledKeys { // O(n)
            let index = dict.indexForKey(key) // O(1)
            dict.removeAtIndex(index!) // O(1)
        }
        env.stopMeasuring()
    }

    benchmark.addExperiment("removal from sorted Map") { env in
        var map: Map<Int, P> = [:]
        for (key, payload) in env.input {
            map[key] = payload
        }

        let shuffledKeys = env.input.map { $0.0 }.shuffle()

        env.startMeasuring()
        for key in shuffledKeys { // O(n * log(n))
            guard let index = map.indexForKey(key) else {
                env.fail("Couldn't find key \(key)")
                break
            }
            map.removeAtIndex(index) // O(log(n))
        }
        env.stopMeasuring()
    }
    
    benchmark.addExperiment("removal from B-tree") { env in
        var tree = BTree<Int, P>()
        for (key, payload) in env.input {
            tree.insert(payload, at: key)
        }

        let shuffledKeys = env.input.map { $0.0 }.shuffle()

        env.startMeasuring()
        for key in shuffledKeys {
            guard let _ = tree.remove(key) else {
                env.fail("Couldn't find key \(key)")
                break
            }
        }
        env.stopMeasuring()
    }

    return benchmark
}
