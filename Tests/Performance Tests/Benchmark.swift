//
//  Sample.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-20.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

public protocol BenchmarkParameter {
    typealias Input
    typealias Output

    var name: String { get }
    var size: Int { get }
    var input: Input { get }
}

public final class MeasurementEnvironment<Input> {
    private var start: Timestamp = Timestamp()
    private var stop: Timestamp? = nil
    private var failure: String? = nil

    public let input: Input

    private init(input: Input) {
        self.input = input
    }

    public var failed: Bool {
        return failure != nil
    }

    public func startMeasuring() {
        start = Timestamp()
    }
    public func stopMeasuring() {
        stop = Timestamp()
    }
    public func fail(message: String = "unknown error") {
        failure = failure ?? message
    }
}

public enum MeasurementOutput<Output> {
    case Success(Output)
    case Failure(String)
}

public struct Measurement<P: BenchmarkParameter> {
    public let experiment: Experiment<P>
    public let input: P.Input
    public let duration: Duration
    public let output: MeasurementOutput<P.Output>
}

public struct Experiment<P: BenchmarkParameter> {
    public typealias Block = MeasurementEnvironment<P.Input> -> P.Output

    public let name: String
    public let block: Block

    public init(name: String, block: Block) {
        self.name = name
        self.block = block
    }

    public func run(param: P) -> Measurement<P> {
        let environment = MeasurementEnvironment<P.Input>(input: param.input)

        let out = block(environment)
        let stop = environment.stop ?? Timestamp()

        let output: MeasurementOutput<P.Output>
        if let failure = environment.failure {
            output = .Failure(failure)
        }
        else {
            output = .Success(out)
        }

        return Measurement(experiment: self, input: param.input, duration: stop - environment.start, output: output)
    }
}


public struct Benchmark<P: BenchmarkParameter> {
    public let name: String
    public private(set) var experiments: [String: Experiment<P>] = [:]
    public private(set) var params: [P] = []

    public init(name: String) {
        self.name = name
    }
    public init(name: String, experiments: [Experiment<P>], params: [P]) {
        self.name = name
        for p in params { add(p) }
        for e in experiments { add(e) }
    }

    public mutating func addExperiment(name: String, block: Experiment<P>.Block) {
        self.add(Experiment<P>(name: name, block: block))
    }

    public mutating func add(e: Experiment<P>) {
        precondition(self.experiments[e.name] == nil, "Duplicate experiment name '\(e.name)'")
        self.experiments[e.name] = e
    }

    public mutating func add(param: P) {
        params.append(param)
    }

    public func run(iterations: Int) -> BenchmarkResult {
        var runs: Array<(Experiment<P>, P)> = []

        runs.reserveCapacity(experiments.count * params.count)
        for e in experiments.values {
            for p in params {
                runs.append((e, p))
            }
        }

        var results = BenchmarkResult(name: self.name, start: NSDate())

        let formatter = NSDateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        
        var progress = 0
        let count = iterations * runs.count
        let start = Timestamp()
        for _ in 1...iterations {
            runs.shuffleInPlace()
            for (experiment, param) in runs {
                let percent = progress * 100 / count
                let now = Timestamp()

                let remainingsecs = (now - start).timeInterval / max(Double(progress), 1.0) * Double(count - progress)
                let finish = formatter.stringFromDate(NSDate(timeIntervalSinceNow: remainingsecs))


//                print("\(percent)%, ETA ~\(finish): Starting '\(experiment.name)' on '\(param.name)', size \(param.size)")
                let measurement = experiment.run(param)
                if case .Failure(let explanation) = measurement.output {
                    print("\(percent)%, ETA ~\(finish): Failed '\(experiment.name)' on '\(param.name)', size \(param.size): \(explanation)")
                }
                else {
                    print("\(percent)%, ETA ~\(finish): Finished \(param.size) - \(experiment.name) - \(param.name) - \(measurement.duration.timeInterval * 1000)ms")
                }
                results.addDuration(measurement.duration, experiment: experiment.name, param: param.name, size: param.size)
                progress += 1
            }
        }
        return results
    }
}

public struct BenchmarkResultKey: Hashable, Comparable {
    public let param: String
    public let experiment: String
    public let size: Int

    public var hashValue: Int { return experiment.hashValue &* param.hashValue &* size }
}
public func ==(a: BenchmarkResultKey, b: BenchmarkResultKey) -> Bool {
    return a.experiment == b.experiment && a.param == b.param && a.size == b.size
}
public func <(a: BenchmarkResultKey, b: BenchmarkResultKey) -> Bool {
    guard a.param == b.param else { return a.param < b.param }
    guard a.experiment == b.experiment else { return a.experiment < b.experiment }
    return a.size < b.size
}

public struct BenchmarkResult {
    public typealias Key = BenchmarkResultKey

    public let name: String
    public let start: NSDate

    private var _data: Dictionary<Key, DurationSample> = [:]

    public init(name: String, start: NSDate) {
        self.name = name
        self.start = start
    }

    public mutating func addDuration(duration: Duration, experiment: String, param: String, size: Int) {
        let key = Key(param: param, experiment: experiment, size: size)
        if _data[key] == nil {
            _data[key] = DurationSample()
        }
        _data[key]!.add(duration)
    }

    public var data: [(Key, DurationSample)] {
        return _data.sort { a, b in a.0 < b.0 }
    }
}

