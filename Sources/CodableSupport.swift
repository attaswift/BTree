//
//  CodableSupport.swift
//  BTree
//
//  Created by Benoit Pereira da silva on 20/01/2018.
//  Copyright © 2018 Károly Lőrentey. All rights reserved.
//

import Foundation

#if !DISABLE_CODABLE_SUPPORT

typealias Value = Codable

extension BTreeNode:Codable{

    enum BTreeNodeCodingKeys: String,CodingKey{
        case elements
        case children
        case count
    }

    convenience init(from decoder: Decoder) throws{
        self.init()
        let values = try decoder.container(keyedBy: BTreeNodeCodingKeys.self)
        //self.elements = try values.decodeIfPresent(Array<Element>.self,forKey: .elements) ?? Array<Element>()
        self.children = try values.decodeIfPresent(Array<BTreeNode>.self, forKey: .children) ?? Array<BTreeNode>()
        self.count = try  values.decodeIfPresent(Int.self, forKey: .count)  ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: BTreeNodeCodingKeys.self)
        //try container.encodeIfPresent(self.elements,forKey: .elements)
        try container.encodeIfPresent(self.children,forKey: .children)
        try container.encodeIfPresent(self.count,forKey: .count)
    }
}


extension BTree: Codable{

    enum BTreeCodingKeys: String,CodingKey{
        case root
    }

    public init(from decoder: Decoder) throws{
        self.init()
        let values = try decoder.container(keyedBy: BTreeCodingKeys.self)
        self.root = try values.decode(Node.self,forKey: .root)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: BTreeCodingKeys.self)
        try container.encode(self.root,forKey: .root)
    }
}


extension List:Codable{

    enum ListCodingKeys: String,CodingKey{
        case tree
    }

    public init(from decoder: Decoder) throws{
        self.init()
        let values = try decoder.container(keyedBy: ListCodingKeys.self)
        self.tree = try values.decode(Tree.self,forKey: .tree)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ListCodingKeys.self)
        try container.encode(self.tree,forKey: .tree)
    }

}

#endif
