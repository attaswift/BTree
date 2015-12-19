//
//  RedBlackTree descriptions.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-19.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

extension RedBlackHandle: CustomStringConvertible {
    var description: String {
        return "#\(index)"
    }
}

extension RedBlackTree: CustomStringConvertible {
    var description: String {
        return "RedBlackTree with \(count) elements"
    }
}