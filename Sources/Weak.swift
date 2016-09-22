//
//  Weak.swift
//  BTree
//
//  Created by Károly Lőrentey on 2016-02-11.
//  Copyright © 2015–2016 Károly Lőrentey.
//

internal struct Weak<T: AnyObject> {
    weak var value: T?

    init(_ value: T) {
        self.value = value
    }
}
