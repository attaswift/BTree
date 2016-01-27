//
//  OrderOptimizerBenchmark.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2016-01-16.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import Foundation
import TreeCollections

// Note that you'll need to make BTreeNode public to run this test.

struct BTreeOrderParam<Payload>: BenchmarkParameter, CustomStringConvertible {
    typealias Input = (order: Int, values: [(Int, Payload)])
    typealias Output = Void

    var name: String { return self.description }
    let input: Input
    var size: Int { return input.order }

    init(order: Int, inputsize: Int, factory: Int->Payload) {
        var values: [(Int, Payload)] = []
        values.reserveCapacity(inputsize)
        for i in 0..<inputsize {
            values.append((i, factory(i)))
        }
        values.shuffleInPlace()

        self.input = (order, values)
    }

    var description: String {
        return "order \(input.order) with \(input.values.count) \(sizeof(Payload))-byte payloads"
    }
}

func orderOptimizerBenchmark<P>(name: String, orders: [Int], inputSizes: [Int], factory: Int->P) -> Benchmark<BTreeOrderParam<P>> {
    var benchmark = Benchmark<BTreeOrderParam<P>>(name: name)

    for order in orders {
        for inputsize in inputSizes {
            benchmark.add(BTreeOrderParam<P>(order: order, inputsize: inputsize, factory: factory))
        }
    }

    benchmark.addExperiment("insertion") { env in
        let tree = BTreeNode<Int, P>(order: env.input.order)
        env.startMeasuring()
        for (key, payload) in env.input.values {
            tree.insert(payload, at: key)
        }
        env.stopMeasuring()
    }
    
    return benchmark
}
