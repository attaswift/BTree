//
//  Map2.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-17.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

public struct Map<Key: Comparable, Value> {
    private typealias Config = SimpleTreeConfig<Key>
    private typealias Tree = RedBlackTree<Config, Value>
    private typealias Node = Tree.Node
    private typealias Handle = Tree.Index

    private var tree: Tree
    
}
