//
//  Duration.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-20.
//  Copyright © 2015 Károly Lőrentey.
//

import Foundation
import BigInt

/// Represents elapsed time between two `Timestamp`s.
public struct Duration: Comparable, Hashable, FloatLiteralConvertible, CustomStringConvertible {
    private static let nsecPerSec: Int64 = Int64(NSEC_PER_SEC)
    private let value: Int64 // in nanosecs

    public init(nanoseconds: Int64) { self.value = nanoseconds }
    public init() { value = 0 }
    public init(floatLiteral seconds: FloatLiteralType) {
        value = Int64(Double(seconds) * Double(NSEC_PER_SEC))
    }

    public var nanoseconds: Int64 {
        return value
    }
    public var milliseconds: Double {
        return Double(value) / Double(NSEC_PER_MSEC)
    }
    public var microseconds: Double {
        return Double(value) / Double(NSEC_PER_USEC)
    }
    public var timeInterval: NSTimeInterval {
        return Double(value) / Double(NSEC_PER_SEC)
    }

    public var hashValue: Int { return value.hashValue }
    public var description: String { return "\(timeInterval)s" }
}
public func ==(a: Duration, b: Duration) -> Bool { return a.value == b.value }
public func <(a: Duration, b: Duration) -> Bool { return a.value < b.value }
public func +(a: Duration, b: Duration) -> Duration { return Duration(nanoseconds: a.value + b.value) }
public func -(a: Duration, b: Duration) -> Duration { return Duration(nanoseconds: a.value - b.value) }
public func *(a: Duration, b: Int) -> Duration { return Duration(nanoseconds: a.value * Int64(b)) }
public func *(a: Int, b: Duration) -> Duration { return Duration(nanoseconds: b.value * Int64(a)) }
public func /(a: Duration, b: Int) -> Duration { return Duration(nanoseconds: a.value / Int64(b)) }
public func +=(inout a: Duration, b: Duration) { a = a + b }
public func -=(inout a: Duration, b: Duration) { a = a - b }


/// Represents a sample of measured durations, providing methods for simple statistical analysis.
public struct DurationSample {
    public private(set) var durations: [Duration] = []
    public private(set) var sum: Duration = Duration()

    public init() {}

    public mutating func add(duration: Duration) {
        durations.append(duration)
        sum += duration
    }
    var average: Duration {
        guard durations.count > 0 else { return Duration() }
        return sum / durations.count
    }

    var standardDeviation: Duration {
        guard durations.count > 1 else { return Duration() }
        let average = self.average.nanoseconds
        var sum2: BigUInt = 0
        for d in durations {
            let ns = BigInt(d.nanoseconds - average)
            sum2 += ns.abs * ns.abs
        }
        let sigma2 = sum2.divideByDigit(UInt64(durations.count - 1)).div
        let sigma = sqrt(sigma2)
        if sigma.count > 1 { fatalError("Integer overflow") }
        return Duration(nanoseconds: Int64(sigma[0]))
    }

    var relativeStandardDeviation: Double {
        let rsd = standardDeviation.timeInterval / average.timeInterval
        return (1 + 1/(4 * Double(durations.count))) * rsd
    }
}

