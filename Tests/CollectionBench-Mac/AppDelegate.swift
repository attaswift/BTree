//
//  AppDelegate.swift
//  CollectionBenchmark
//
//  Created by Károly Lőrentey on 2015-12-21.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Cocoa

let benchmark = CollectionBenchmarks.orderOptimizer

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!

    func benchmarkDidFinish(benchmark: BenchmarkProtocol, result: BenchmarkResult) {
        do {
            let file = try result.saveTSVToDesktop()
            NSWorkspace.sharedWorkspace().openURL(file)
        }
        catch let error {
            NSAlert(error: error as NSError).beginSheetModalForWindow(self.window) { response in
                print("Well OK then")
            }
        }

        result.summary().forEach { print($0) }
    }

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        let activity = NSProcessInfo.processInfo().beginActivityWithOptions([NSActivityOptions.IdleSystemSleepDisabled, .LatencyCritical], reason: "Benchmark")
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
            let result = benchmark.run()
            dispatch_async(dispatch_get_main_queue()) {
                self.benchmarkDidFinish(benchmark, result: result)
                NSProcessInfo.processInfo().endActivity(activity)
            }
        }
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }


}

