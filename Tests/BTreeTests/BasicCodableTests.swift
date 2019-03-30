//
//  BasicCodableTests.swift
//  BTree
//
//  Created by Benoit Pereira da silva on 20/01/2018.
//  Copyright © 2018 Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import BTree



class BasicCodableTests: XCTestCase {

    func testEncodingDecodingList()  {
        do{
            var list = List<Int>()
            list.append(Int(666))
            let data = try JSONEncoder().encode(list)
            let list2 = try JSONDecoder().decode(List<Int>.self, from: data)
            XCTAssert(list2.count == 1,"Should contain one element, current count\(list2.count)")
            XCTAssert(list2[0] == 666)
        }catch{
            XCTFail("\(error)")
        }
    }
}
