//
//  TreeDumper.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-20.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation
@testable import TreeCollections

private func *(i: Int, s: String) -> String {
    var result = ""
    result.reserveCapacity(i * s.unicodeScalars.count)
    (0..<i).forEach { _ in result += s }
    return result
}

private enum LineType {
    case LeftSubtree
    case Root
    case RightSubtree
}

extension RedBlackTree {

    func dump() {
        dump(root)
    }

    func dump(top: Handle?) {
        /// - Returns: (tab level, lines), where each line is (matchkind, graphic, columns)
        func dump(handle: Handle?, prefix: Summary) -> (Int, [(LineType, String, [String])]) {
            guard let handle = handle else { return (0, []) }

            let node = self[handle]
            let (leftTabs, leftLines) = dump(node.left, prefix: prefix)
            
            let p = prefix + self[node.left]?.summary
            let (rightTabs, rightLines) = dump(node.right, prefix: p + node.head)

            let tabs = max(leftTabs, rightTabs)

            let dot = (node.color == .Black ? "●" : "○")

            let root = [
                "\(handle):",
                "    \(InsertionKey(summary: p, head: node.head))",
                "⟼ \(node.payload)",
                "\t☺:\(node.head)",
                "\t∑:\(node.summary)"]

            if leftLines.isEmpty && rightLines.isEmpty {
                return (tabs, [(.Root, "\(dot)\t", root)])
            }

            var lines: [(LineType, String, [String])] = []

            let rightIndent = (tabs - rightTabs) * "\t"
            if rightLines.isEmpty {
                lines.append((.RightSubtree, "┏━\t" + "\t" + rightIndent, ["nil"]))
            }
            else {
                for (m, graphic, text) in rightLines {
                    switch m {
                    case .RightSubtree:
                        lines.append((.RightSubtree, "\t" + graphic + rightIndent, text))
                    case .Root:
                        lines.append((.RightSubtree, "┏━\t" + graphic + rightIndent, text))
                    case .LeftSubtree:
                        lines.append((.RightSubtree, "┃\t" + graphic + rightIndent, text))
                    }
                }
            }

            lines.append((.Root, "\(dot)\t\t" + tabs * "\t", root))

            let leftIndent = (tabs - leftTabs) * "\t"
            if leftLines.isEmpty {
                lines.append((.LeftSubtree, "┗━\t" + "\t" + leftIndent, ["nil"]))
            }
            else {
                for (m, graphic, text) in leftLines {
                    switch m {
                    case .RightSubtree:
                        lines.append((.LeftSubtree, "┃\t" + graphic + leftIndent, text))
                    case .Root:
                        lines.append((.LeftSubtree, "┗━\t" + graphic + leftIndent, text))
                    case .LeftSubtree:
                        lines.append((.LeftSubtree, "\t" + graphic + leftIndent, text))
                    }
                }
            }
            return (tabs + 1, lines)
        }

        guard let top = top else { print("nil"); return }

        let prefix = summaryBefore(self.leftmostUnder(top))
        let data = dump(top, prefix: prefix).1
        let lines = layoutColumns(data.map { $0.2 })
        let graphics = data.map { $0.1 }

        for (graphic, line) in zip(graphics, lines) {
            print(graphic + line)
        }
    }
}
