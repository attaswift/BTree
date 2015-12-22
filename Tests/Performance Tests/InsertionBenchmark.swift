//
//  InsertionBenchmark.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-20.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation
import TreeCollections

public struct PayloadArray<Payload>: BenchmarkParameter, CustomStringConvertible {
    public typealias Input = [(Int, Payload)]
    public typealias Output = Void

    public let name: String
    public let input: Input
    public var size: Int { return input.count }

    public init(name: String, size: Int, factory: Int->Payload) {
        self.name = name

        var input: Input = []
        input.reserveCapacity(size)
        for i in 0..<size {
            input.append((i, factory(i)))
        }
        input.shuffleInPlace()

        self.input = input
    }

    public var description: String {
        return "\(input.count) items with \(name) payloads"
    }
}

public func insertionBenchmark<P>(name: String, sizes: [Int], factory: Int->P) -> Benchmark<PayloadArray<P>> {
    var benchmark = Benchmark<PayloadArray<P>>(name: "insertions")

    for size in sizes {
        benchmark.add(PayloadArray<P>(name: name, size: size, factory: factory))
    }
    benchmark.addExperiment("appending to unsorted array") { env in
        var array: [(Int, P)] = []
        env.startMeasuring()
        for (key, payload) in env.input {
            array.append((key, payload))
        }
        env.stopMeasuring()
    }
    benchmark.addExperiment("inserting to inlined sorted array") { env in
        var array: [(Int, P)] = []
        env.startMeasuring()
        for (key, payload) in env.input {
            var start = array.startIndex
            var end = array.endIndex
            while start < end {
                let mid = start + (end - start) / 2
                if array[mid].0 < key {
                    start = mid + 1
                }
                else {
                    end = mid
                }
            }
            array.insert((key, payload), atIndex: start)
        }
        env.stopMeasuring()
    }
    benchmark.addExperiment("inserting to SortedArray") { env in
        var array = SortedArray<Int, P>()
        env.startMeasuring()
        for (key, payload) in env.input {
            array[key] = payload
        }
        env.stopMeasuring()
    }
    benchmark.addExperiment("inserting to unsorted Dictionary") { env in
        var dict = Dictionary<Int, P>()
        env.startMeasuring()
        for (key, payload) in env.input {
            dict[key] = payload
        }
        env.stopMeasuring()
    }
    benchmark.addExperiment("inserting to sorted Map") { env in
        var map = Map<Int, P>()
        env.startMeasuring()
        for (key, payload) in env.input {
            map[key] = payload
        }
        env.stopMeasuring()
    }
    benchmark.addExperiment("appending to unsorted List") { env in
        var list = List<(Int, P)>()
        env.startMeasuring()
        for (key, payload) in env.input {
            list.append((key, payload))
        }
        env.stopMeasuring()
    }
    return benchmark
}