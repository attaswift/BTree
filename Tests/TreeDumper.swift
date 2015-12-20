//
//  TreeDumper.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-20.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation
@testable import TreeCollections

extension RedBlackTree {

    func dump() {
        /// - Returns: (tab level, lines), where each line is (matchkind, graphic, columns)
        func dump(handle: Handle?, prefix: Summary) -> (Int, [(KeyMatchResult, String, [String])]) {
            guard let handle = handle else { return (0, []) }

            let node = self[handle]
            let (leftTabs, leftLines) = dump(node.left, prefix: prefix)
            
            let p = prefix + self[node.left]?.summary
            let (rightTabs, rightLines) = dump(node.right, prefix: p + node.head)

            let tabs = max(leftTabs, rightTabs)

            let dot = (node.color == .Black ? "●" : "○")

            let root = [
                "\(handle):",
                "    \(Config.key(node.head, prefix: p))",
                "⟼ \(node.payload)",
                "\t☺:\(node.head)",
                "\t∑:\(node.summary)"]

            if leftLines.isEmpty && rightLines.isEmpty {
                return (tabs, [(.Matching, "\(dot)\t", root)])
            }

            var lines: [(KeyMatchResult, String, [String])] = []

            let rightIndent = (tabs - rightTabs) * "\t"
            if rightLines.isEmpty {
                lines.append((.After, "┏━\t" + "\t" + rightIndent, ["nil"]))
            }
            else {
                for (m, graphic, text) in rightLines {
                    switch m {
                    case .After:
                        lines.append((.After, "\t" + graphic + rightIndent, text))
                    case .Matching:
                        lines.append((.After, "┏━\t" + graphic + rightIndent, text))
                    case .Before:
                        lines.append((.After, "┃\t" + graphic + rightIndent, text))
                    }
                }
            }

            lines.append((.Matching, "\(dot)\t\t" + tabs * "\t", root))

            let leftIndent = (tabs - leftTabs) * "\t"
            if leftLines.isEmpty {
                lines.append((.Before, "┗━\t" + "\t" + leftIndent, ["nil"]))
            }
            else {
                for (m, graphic, text) in leftLines {
                    switch m {
                    case .After:
                        lines.append((.Before, "┃\t" + graphic + leftIndent, text))
                    case .Matching:
                        lines.append((.Before, "┗━\t" + graphic + leftIndent, text))
                    case .Before:
                        lines.append((.Before, "\t" + graphic + leftIndent, text))
                    }
                }
            }
            return (tabs + 1, lines)
        }


        let lines = dump(root, prefix: Summary()).1

        let columnCount = lines.reduce(0) { a, l in max(a, l.2.count) }
        var columnWidths = [Int](count: columnCount, repeatedValue: 0)
        lines.lazy.flatMap { $0.2.enumerate() }.forEach { i, c in
            columnWidths[i] = max(columnWidths[i], c.characters.count)
        }

        for (_, graphic, columns) in lines {
            var line = graphic
            columns.enumerate().forEach { i, c in
                line += c
                line += String(count: columnWidths[i] - c.characters.count + 1, repeatedValue: " " as Character)
            }
            print(line)
        }
    }
}