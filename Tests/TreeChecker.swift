//
//  TreeChecker.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-20.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import TreeCollections

struct RedBlackInfo<Config: RedBlackConfig, Payload> {
    typealias Tree = RedBlackTree<Config, Payload>
    typealias Handle = Tree.Handle
    typealias Summary = Tree.Summary
    typealias Key = Tree.Key

    var nodeCount: Int = 0

    var minDepth: Int = 0
    var maxDepth: Int = 0

    var minRank: Int = 0
    var maxRank: Int = 0

    var color: Color = .Black
    var summary: Summary = Summary()
    var minKey: Key? = nil
    var maxKey: Key? = nil

    var defects: [(Handle, String, String, UInt)] = []

    mutating func addDefect(handle: Handle, _ description: String, file: String = __FILE__, line: UInt = __LINE__) {
        defects.append((handle, description, file, line))
    }
}

extension RedBlackTree {
    private func collectInfo(blacklist: Set<Handle>, handle: Handle?, parent: Handle?, prefix: Summary) -> Info {

        guard let handle = handle else { return Info() }

        var info = Info()
        let node = self[handle]

        if blacklist.contains(handle) {
            info.addDefect(handle, "node is linked more than once")
            return info
        }
        var blacklist = blacklist
        blacklist.insert(handle)

        let li = collectInfo(blacklist, handle: node.left, parent: handle, prefix: prefix)
        let ri = collectInfo(blacklist, handle: node.right, parent: handle, prefix: prefix + li.summary + node.head)
        info.summary = li.summary + node.head + ri.summary

        info.nodeCount = li.nodeCount + 1 + ri.nodeCount

        info.minDepth = min(li.minDepth, ri.minDepth) + 1
        info.maxDepth = max(li.maxDepth, ri.maxDepth) + 1
        info.minRank = min(li.minRank, ri.minRank) + (node.color == .Black ? 1 : 0)
        info.maxRank = max(li.maxRank, ri.maxRank) + (node.color == .Black ? 1 : 0)

        info.defects = li.defects + ri.defects
        info.color = node.color

        if node.parent != parent {
            info.addDefect(handle, "parent is \(node.parent), expected \(parent)")
        }
        if node.color == .Red {
            if li.color != .Black {
                info.addDefect(handle, "color is red but left child(\(node.left) is also red")
            }
            if ri.color != .Black {
                info.addDefect(handle, "color is red but right child(\(node.left) is also red")
            }
        }
        if li.minRank != ri.minRank {
            info.addDefect(handle, "mismatching child subtree ranks: \(li.minRank) vs \(ri.minRank)")
        }
        if info.summary != node.summary {
            info.addDefect(handle, "summary is \(node.summary), expected \(info.summary)")
        }
        let key = Config.key(node.head, prefix: prefix + li.summary)
        info.maxKey = ri.maxKey
        info.minKey = li.minKey
        if let lk = li.maxKey where Config.compare(lk, to: node.head, prefix: prefix + li.summary) == .After {
            info.addDefect(handle, "node's key is ordered before its maximum left descendant: \(key) < \(lk)")
        }
        if let rk = ri.minKey where Config.compare(rk, to: node.head, prefix: prefix + li.summary) == .Before {
            info.addDefect(handle, "node's key is ordered after its minimum right descendant: \(key) > \(rk)")
        }
        return info
    }

    var debugInfo: Info {
        var info = collectInfo([], handle: root, parent: nil, prefix: Summary())
        if info.color == .Red {
            info.addDefect(root!, "root is red")
        }
        if info.nodeCount != count {
            info.addDefect(root!, "count of reachable nodes is \(count), expected \(info.nodeCount)")
        }
        return info
    }

    func assertTreeIsValid() {
        let info = debugInfo
        for (handle, explanation, file, line) in info.defects {
            XCTFail("\(handle): \(explanation)", file: file, line: line)
        }
    }
}
