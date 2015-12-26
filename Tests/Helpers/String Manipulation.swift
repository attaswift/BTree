//
//  String Manipulation.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-26.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// Left-aligned column layout.
internal func layoutColumns(lines: [[String]]) -> [String] {
    let columnCount = lines.reduce(0) { a, l in max(a, l.count) }
    var columnWidths = [Int](count: columnCount, repeatedValue: 0)
    lines.lazy.flatMap { $0.enumerate() }.forEach { i, c in
        columnWidths[i] = max(columnWidths[i], c.characters.count)
    }

    var result: [String] = []
    result.reserveCapacity(lines.count)
    for columns in lines {
        var line = ""
        columns.enumerate().forEach { i, c in
            line += c
            line += String(count: columnWidths[i] - c.characters.count + 1, repeatedValue: " " as Character)
        }
        result.append(line)
    }
    return result
}

