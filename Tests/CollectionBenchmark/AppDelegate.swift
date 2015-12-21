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
            let desktop = try fm.URLForDirectory(.DesktopDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
            let outputfile = desktop.URLByAppendingPathComponent("benchmark.tsv", isDirectory: false)
            try (file as NSString).writeToURL(outputfile, atomically: true, encoding: NSUTF8StringEncoding)
            ws.openURL(outputfile)
            
        }
        catch let error {
            NSAlert(error: error as NSError).beginSheetModalForWindow(self.window) { response in
                print("Well OK then")
            }
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
            let b2 = insertionBenchmark("bigger", sizes: sizes) { i in (i, Double(i), "\(i)", [i, 2 * i, 3 * i], object) }

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

