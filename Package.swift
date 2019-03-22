// swift-tools-version:4.0
//
//  Package.swift
//  BTree
//
//  Created by Károly Lőrentey on 2015-12-15.
//  Copyright © 2015-2017 Károly Lőrentey.
//

import PackageDescription

let package = Package(
    name: "BTree",
    products: [
        .library(name: "BTree", targets: ["BTree"])
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "BTree", dependencies: [], path: "Sources"),
        .testTarget(name: "BTreeTests", dependencies: ["BTree"], path: "Tests/BTreeTests")
    ],
    swiftLanguageVersions: [4]
)
