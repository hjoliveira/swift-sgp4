//
//  TLEError.swift
//  SwiftSGP4
//
//  Created by Henrique Oliveira on 13/6/15.
//  Copyright © 2015 Henrique Oliveira. All rights reserved.
//

import Foundation

public enum TLEError: Error {
    case invalidLineLength(Int)
    case invalidElement(String)
    case fileParsing
}