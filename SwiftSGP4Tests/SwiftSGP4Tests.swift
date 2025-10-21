//
//  SwiftSGP4Tests.swift
//  SwiftSGP4Tests
//
//  Created by Henrique Oliveira on 13/6/15.
//  Copyright © 2015 Henrique Oliveira. All rights reserved.
//

import XCTest
@testable import SwiftSGP4

class SwiftSGP4Tests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testParseTLEFromFile() {
        if let path = Bundle(for: type(of: self)).path(forResource: "tle", ofType: "txt") {

            do {
                let tle = try TLE(name: "SENTINEL-1A", tleFilename: path)
                checkTLE(tle)
            } catch {
                print(error)
                XCTFail()
            }
        }
    }
    
    func testParseTLEFromLines() {
        do {
            let tle = try TLE(name: "SENTINEL-1A",
                lineOne: "1 39634U 14016A   15164.10430418 -.00000008  00000-0  81062-5 0  9996",
                lineTwo: "2 39634  98.1805 171.2383 0001291  78.4154 281.7186 14.59198020 63499")
            
            checkTLE(tle)
        
        } catch {
            print(error)
            XCTFail()
        }
        
    }
    
    func checkTLE(_ tle: TLE) {
        let cal = Calendar.current
        let year = cal.component(.year, from: tle.epoch)
        guard let day = cal.ordinality(of: .day, in: .year, for: tle.epoch) else {
            XCTFail("Could not determine day ordinality from epoch date")
            return
        }

        XCTAssertEqual(tle.name, "SENTINEL-1A")
        XCTAssertEqual(tle.noradNumber, 39634)
        XCTAssertEqual(tle.intDesignator, "14016A")
        XCTAssertEqual(year, 2015)
        XCTAssertEqual(day, 164)
        XCTAssertEqual(tle.meanMotionDt2, -0.00000008)
        XCTAssertEqual(tle.meanMotionDdt6, 00000E-0)
        XCTAssertEqual(tle.bstar, 0.81062, accuracy: 0.00001)
        XCTAssertEqual(tle.inclination, 98.1805)
        XCTAssertEqual(tle.rightAscendingNode, 171.2383)
        XCTAssertEqual(tle.eccentricity, 0001291)
        XCTAssertEqual(tle.argumentPerigee, 78.4154)
        XCTAssertEqual(tle.meanAnomaly, 281.7186)
        XCTAssertEqual(tle.meanMotion, 14.59198020)
        XCTAssertEqual(tle.orbitNumber, 63499)
    }
    
}
