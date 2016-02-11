//
//  Weak.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2016-02-11.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

internal struct Weak<T: AnyObject> {
    weak var value: T?

    init() {
        self.value = nil
    }
    
    init(_ value: T) {
        self.value = value
    }
}

