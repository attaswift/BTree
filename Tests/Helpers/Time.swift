//
//  Timestamp.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-20.
//  Copyright © 2015 Károly Lőrentey.
//

import Foundation

private let timeinfo: (numer: UInt64, denom: UInt64) = {
    var info = mach_timebase_info_data_t()
    mach_timebase_info(&info)
    let numer = UInt64(info.numer)
    let denom = UInt64(info.denom)
    return (numer, denom)
}()

private let referenceTimestamp = Timestamp()
private func noop<T>(value: T) {}

/// Represents a point in time. This is based on `mach_absolute_time` and is intended for benchmarking use only.
/// `Timestamp` is not a replacement for `NSDate`.
public struct Timestamp: Comparable, Hashable, CustomStringConvertible {
    private let time: UInt64 // in Mach time units

    /// Initializes a new timestamp representing the current time.
    init() { time = mach_absolute_time() }

    /// Call this on process startup to set up the reference timestamp. This is only used when printing timestamps.
    /// If you don't call `start()`, the reference will be set to the time at which it is first used.
    public static func start() { noop(referenceTimestamp) }

    public var hashValue: Int { return time.hashValue }
    public var description: String {
        let duration = self - referenceTimestamp
        if duration >= 0.0 {
            return "t+\(duration)"
        }
        else {
            return "t\(duration))"
        }
    }
}
public func == (a: Timestamp, b: Timestamp) -> Bool {
    return a.time == b.time
}
public func < (a: Timestamp, b: Timestamp) -> Bool {
    // I think mach_absolute_time's ticks never wrap around, but better be safe than sorry.
    // (Note that 2^64 nanoseconds is about 584 years.)
    return ((b.time &- a.time) & 0x80000000000000) == 0
}
/// Returns the.value between two timestamps.
public func - (a: Timestamp, b: Timestamp) -> Duration { return Duration(from: b, to: a) }


public extension Duration {
    public init(from: Timestamp, to: Timestamp) {
        let negative = (from.time > to.time)
        let diff: UInt64 = (negative ? from.time - to.time : to.time - from.time)

        //.value = diff * numer / denom / NSEC_PER_SEC
        // Let's do this in fixed point arithmetic, taking care not to overflow the product.
        let divisor = timeinfo.denom * NSEC_PER_SEC
        let rem = (diff % divisor) * timeinfo.numer
        let seconds = diff / divisor + rem / divisor
        let nanosecs = rem % divisor

        let duration = Int64(seconds * NSEC_PER_SEC + nanosecs)
        self.init(nanoseconds: negative ? -duration : duration)
    }
}
