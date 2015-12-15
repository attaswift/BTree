//
//  SegmentedArray.swift
//  TreeCollections
//
//  Created by Károly Lőrentey on 2015-12-14.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

internal struct SegmentedArray<Element> {
    private let segmentScale: Int
    private var contents: [[Element]] = []

    internal init(segmentScale: Int) {
        self.segmentScale = max(segmentScale, 5)
    }

    internal var count: Int {
        let c = contents.count
        guard c > 0 else { return 0 }
        return (c << segmentScale) + contents.last!.count
    }

    internal subscript(index: Int) -> Element {
        get {
            let segment = index >> segmentScale
            let offset = index & (1 << segmentScale - 1)
            return contents[segment][offset]
        }
        set {
            let segment = index >> segmentScale
            let offset = index & (1 << segmentScale - 1)
            contents[segment][offset] = newValue
        }
    }

    internal mutating func append(element: Element) {
        guard let last = contents.last else { contents = [[element]]; return }
        if last.count == (1 << segmentScale - 1) {
            contents.append([element])
        }
        else {
            contents[contents.count - 1].append(element)
        }
    }

    internal mutating func removeLast() -> Element {
        let element = contents[contents.count - 1].removeLast()
        if contents.last!.isEmpty {
            contents.removeLast()
        }
        return element
    }
}