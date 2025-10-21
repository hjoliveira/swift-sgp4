//
//  TLEError.swift
//  SwiftSGP4
//
//  Created by Henrique Oliveira on 13/6/15.
//  Copyright © 2015 Henrique Oliveira. All rights reserved.
//

import Foundation

enum TLEError: ErrorType {
    case InvalidLineLength(Int)
    case InvalidElement(String)
    case FileParsing
}