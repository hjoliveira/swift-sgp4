//
//  TLE.swift
//  SwiftSGP4
//
//  Created by Henrique Oliveira on 12/6/15.
//  Copyright © 2015 Henrique Oliveira. All rights reserved.
//

import Foundation

// Format described at http://www.celestrak.com/NORAD/documentation/tle-fmt.asp
public struct TLE {
    let TLE_LEN_LINE_NAME = 22
    
    let TLE1_COL_NORADNUM = 2
    let TLE1_LEN_NORADNUM = 5
    let TLE1_COL_INTLDESC_A = 9
    let TLE1_LEN_INTLDESC_A = 2
    let TLE1_COL_INTLDESC_B = 11
    let TLE1_LEN_INTLDESC_B = 3
    let TLE1_COL_INTLDESC_C = 14
    let TLE1_LEN_INTLDESC_C = 3
    let TLE1_COL_EPOCH_A = 18
    let TLE1_LEN_EPOCH_A = 2
    let TLE1_COL_EPOCH_B = 20
    let TLE1_LEN_EPOCH_B = 12
    let TLE1_COL_MEANMOTIONDT2 = 33
    let TLE1_LEN_MEANMOTIONDT2 = 10
    let TLE1_COL_MEANMOTIONDDT6 = 44
    let TLE1_LEN_MEANMOTIONDDT6 = 8
    let TLE1_COL_BSTAR = 53
    let TLE1_LEN_BSTAR = 8
    let TLE1_COL_EPHEMTYPE = 62
    let TLE1_LEN_EPHEMTYPE = 1
    let TLE1_COL_ELNUM = 64
    let TLE1_LEN_ELNUM = 4
    
    let TLE2_COL_NORADNUM = 2
    let TLE2_LEN_NORADNUM = 5
    let TLE2_COL_INCLINATION = 8
    let TLE2_LEN_INCLINATION = 8
    let TLE2_COL_RAASCENDNODE = 17
    let TLE2_LEN_RAASCENDNODE = 8
    let TLE2_COL_ECCENTRICITY = 26
    let TLE2_LEN_ECCENTRICITY = 7
    let TLE2_COL_ARGPERIGEE = 34
    let TLE2_LEN_ARGPERIGEE = 8
    let TLE2_COL_MEANANOMALY = 43
    let TLE2_LEN_MEANANOMALY = 8
    let TLE2_COL_MEANMOTION = 52
    let TLE2_LEN_MEANMOTION = 11
    let TLE2_COL_REVATEPOCH = 64
    let TLE2_LEN_REVATEPOCH = 5
    
    var name: String
//    var lineOne: String
//    var lineTwo: String
    
    var noradNumber: Int
    var intDesignator: String
    var epoch: NSDate
    var meanMotionDt2: Double
    var meanMotionDdt6: Double
    var bstar: Double
    var inclination: Double
    var rightAscendingNode: Double
    var eccentricity: Double
    var argumentPerigee: Double
    var meanAnomaly: Double
    var meanMotion: Double
    var orbitNumber: Int
    
    public init(name: String, tleFilename: String) throws {
        let tleText = try String(contentsOfFile: tleFilename, encoding: NSUTF8StringEncoding)
        
        let lines = tleText.componentsSeparatedByString("\n")
        
        var line1: String?
        var line2: String?
        for var i = 0; i < lines.count; ++i {
            if lines[i].stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()) == name {
                line1 = lines[i+1]
                line2 = lines[i+2]
                break
            }
        }
        try self.init(name: name, lineOne: line1!, lineTwo: line2!)
    }
    
    public init(name: String, lineOne: String, lineTwo: String) throws {
        let TLE_LEN_LINE_DATA = 69
        func isValidLineLength(line: String) -> Bool {
            let lineLength = line.characters.count
            return lineLength == TLE_LEN_LINE_DATA
        }
        
        func trimmedSubstring(str: String, location: Int, length: Int) -> String {
            let substring = (str as NSString).substringWithRange(NSRange(location: location, length: length))
            let trimmedSubstring = substring.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
            
            return trimmedSubstring
        }
        
        if !isValidLineLength(lineOne) {
            throw TLEError.InvalidLineLength(1)
        }
        
        if !isValidLineLength(lineTwo) {
            throw TLEError.InvalidLineLength(2)
        }
        
        if trimmedSubstring(lineOne, location: 0, length: 1) != "1" {
            throw TLEError.InvalidElement("Invalid first character for line 1")
        }
        
        if trimmedSubstring(lineTwo, location: 0, length: 1) != "2" {
            throw TLEError.InvalidElement("Invalid first character for line 2")
        }
        
        let satNumber1 = trimmedSubstring(lineOne, location: TLE1_COL_NORADNUM, length: TLE1_LEN_NORADNUM)
        let satNumber2 = trimmedSubstring(lineTwo, location: TLE2_COL_NORADNUM, length: TLE2_LEN_NORADNUM)
        
        if satNumber1 != satNumber2 {
            throw TLEError.InvalidElement("Satellite id not the same for both lines")
        }

        if let noradNumber = Int(satNumber1) {
            self.noradNumber = noradNumber
        } else {
            throw TLEError.InvalidElement("Invalid NORAD number")
        }
        
        self.name = name
        
        // line 1
        self.intDesignator = trimmedSubstring(lineOne, location: TLE1_COL_INTLDESC_A, length: TLE1_LEN_INTLDESC_A + TLE1_LEN_INTLDESC_B + TLE1_LEN_INTLDESC_C)
        
        guard var year = Int(trimmedSubstring(lineOne, location: TLE1_COL_EPOCH_A, length: TLE1_LEN_EPOCH_A)) else {
            throw TLEError.InvalidElement("Invalid year")
        }
        
        guard let doubleDay = Double(trimmedSubstring(lineOne, location: TLE1_COL_EPOCH_B, length: TLE1_LEN_EPOCH_B)) else {
            throw TLEError.InvalidElement("Invalid day")
        }
        
        let day = Int(doubleDay)

        if let meanMotionDt2 = Double(trimmedSubstring(lineOne, location: TLE1_COL_MEANMOTIONDT2, length: TLE1_LEN_MEANMOTIONDT2)) {
            self.meanMotionDt2 = meanMotionDt2
        } else {
            throw TLEError.InvalidElement("Invalid meanMotionDt2")
        }
        
        self.meanMotionDdt6 = (trimmedSubstring(lineOne, location: TLE1_COL_MEANMOTIONDDT6, length: TLE1_LEN_MEANMOTIONDDT6) as NSString).doubleValue * 1E-05
        
        self.bstar = (trimmedSubstring(lineOne, location: TLE1_COL_BSTAR, length: TLE1_LEN_BSTAR) as NSString).doubleValue * 1E-05
    
        // line 2
        self.inclination = (trimmedSubstring(lineTwo, location: TLE2_COL_INCLINATION, length: TLE2_LEN_INCLINATION) as NSString).doubleValue
        
        self.rightAscendingNode = (trimmedSubstring(lineTwo, location: TLE2_COL_RAASCENDNODE, length: TLE2_LEN_RAASCENDNODE) as NSString).doubleValue
        
        self.eccentricity = (trimmedSubstring(lineTwo, location: TLE2_COL_ECCENTRICITY, length: TLE2_LEN_ECCENTRICITY) as NSString).doubleValue
        
        self.argumentPerigee = (trimmedSubstring(lineTwo, location: TLE2_COL_ARGPERIGEE, length: TLE2_LEN_ARGPERIGEE) as NSString).doubleValue
        
        self.meanAnomaly = (trimmedSubstring(lineTwo, location: TLE2_COL_MEANANOMALY, length: TLE2_LEN_MEANANOMALY) as NSString).doubleValue
        
        self.meanMotion = (trimmedSubstring(lineTwo, location: TLE2_COL_MEANMOTION, length: TLE2_LEN_MEANMOTION) as NSString).doubleValue
        
        if let orbitNumber = Int(trimmedSubstring(lineTwo, location: TLE2_COL_REVATEPOCH, length: TLE2_LEN_REVATEPOCH)) {
            self.orbitNumber = orbitNumber
        } else {
            throw TLEError.InvalidElement("Invalid orbitNumber")
        }
        
        if year < 57 {
            year += 2000
        } else {
            year += 1900
        }
        
        let comps = NSDateComponents()
        comps.year = year
        comps.day = day
        
        if let epoch = NSCalendar.currentCalendar().dateFromComponents(comps) {
            self.epoch = epoch
        } else {
            throw TLEError.InvalidElement("Invalid epoch")
        }
    }
}
