import Foundation

public enum TLEError: Error {
    case invalidLineLength(Int)
    case invalidElement(String)
    case fileParsing
}