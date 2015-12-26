//
//  AppDelegate.swift
//  CollectionBenchmark
//
//  Created by Károly Lőrentey on 2015-12-21.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!

    func benchmarkDidFinish(name: String, result: BenchmarkResult) {
        var file = ""
        file += "Parameter\tExperiment\tSize\tData\n"
        for (key, data) in result.data {
            for d in data.durations {
                file += key.param
                file += "\t"
                file += key.experiment
                file += "\t"
                file += String(key.size)
                file += "\t"
                file += String(d.timeInterval * 1000)
//                file += String(data.average.timeInterval * 1000)
//                file += "\t"
//                file += String(data.relativeStandardDeviation) + "%"
                file += "\n"
            }
        }

        let fm = NSFileManager.defaultManager()
        let ws = NSWorkspace.sharedWorkspace()
        do {
            let formatter = NSDateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH.mm.ss" // Can't use ISO8601 because filesystems :-(
            let startDate = formatter.stringFromDate(result.start)

            let desktop = try fm.URLForDirectory(.DesktopDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
            let filename = "benchmark - \(startDate) - \(result.name).tsv"
            let outputfile = desktop.URLByAppendingPathComponent(filename, isDirectory: false)
            try (file as NSString).writeToURL(outputfile, atomically: true, encoding: NSUTF8StringEncoding)
            ws.openURL(outputfile)
            
        }
        catch let error {
            NSAlert(error: error as NSError).beginSheetModalForWindow(self.window) { response in
                print("Well OK then")
            }
        }


        var lines: [[String]] = []
        lines.append(["Parameter", "Experiment", "Size", "Average", "RSD"])
        for (key, data) in result.data {
            lines.append([key.param, key.experiment, String(key.size), String(data.average.milliseconds) + "ms", String(data.relativeStandardDeviation)])
        }
        layoutColumns(lines).forEach { print($0) }

        let columnCount = lines.reduce(0) { a, l in max(a, l.count) }
        var columnWidths = [Int](count: columnCount, repeatedValue: 0)
        lines.lazy.flatMap { $0.enumerate() }.forEach { i, c in
            columnWidths[i] = max(columnWidths[i], c.characters.count)
        }
    }

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {

            var last: Int? = nil
            let sizes = (0...18*4).map { Int(floor(pow(2, Double($0) / 4))) }.filter { i in
                guard last != i else { return false }
                last = i
                return true
            }
            let b1 = insertionBenchmark("small", sizes: sizes) { i in i }
            let object = NSObject()
            let b2 = insertionBenchmark("bigger", sizes: [50000]) { i in (i, Double(i), "\(i)", [i, 2 * i, 3 * i], object) }
            let b3 = lookupBenchmark("bigger", count: 100000, sizes: [10000], factory: { i in (i, Double(i), "\(i)", [i, 2 * i, 3 * i], object) })

            let results = b2.run(10)
            dispatch_async(dispatch_get_main_queue()) {
                self.benchmarkDidFinish("Insertion", result: results)
            }
        }

    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }


}

