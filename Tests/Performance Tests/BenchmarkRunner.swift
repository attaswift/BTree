//
//  BenchmarkRunner.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2016-01-16.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import Foundation

extension BenchmarkResult {
    func summary() -> [String] {
        var lines: [[String]] = []
        lines.append(["Parameter", "Experiment", "Size", "Average", "RSD"])
        for (key, data) in self.data.sort({ $0.1.average < $1.1.average }) {
            var average = data.average.milliseconds
            if average >= 10 { average = round(average) }
            lines.append([key.param, key.experiment, String(key.size), String(average) + "ms", String(data.relativeStandardDeviation)])
        }
        return layoutColumns(lines)
    }

    func dumpIntoTSV() -> String {
        var contents = ""
        contents += "Parameter\tExperiment\tSize\tData\n"
        for (key, data) in self.data {
            for d in data.durations {
                contents += key.param
                contents += "\t"
                contents += key.experiment
                contents += "\t"
                contents += String(key.size)
                contents += "\t"
                contents += String(d.timeInterval * 1000)
                contents += "\n"
            }
        }
        return contents
    }

    #if os(OSX)
    func saveTSVToDesktop() throws -> NSURL {
        let contents = dumpIntoTSV()

        let fm = NSFileManager.defaultManager()

        let formatter = NSDateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss" // Can't use ISO8601 because filesystems :-(
        let startDate = formatter.stringFromDate(self.start)

        let desktop = try fm.URLForDirectory(.DesktopDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
        let filename = "benchmark - \(startDate) - \(self.name).tsv"
        let file = desktop.URLByAppendingPathComponent(filename, isDirectory: false)
        try (contents as NSString).writeToURL(file, atomically: true, encoding: NSUTF8StringEncoding)

        return file
    }
    #endif
}

