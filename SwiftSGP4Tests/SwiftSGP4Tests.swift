import XCTest

@testable import SwiftSGP4

class SwiftSGP4Tests: XCTestCase {

  /// Writes a TLE file into a temporary directory and returns its path.
  private func writeTemporaryTLE(_ contents: String, name: String = "tle") throws -> String {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true)
    let path = directory.appendingPathComponent("\(name).txt").path
    try contents.write(toFile: path, atomically: true, encoding: .utf8)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: directory)
    }
    return path
  }

  private static let sentinelTLE = """
    SENTINEL-1A
    1 39634U 14016A   15164.10430418 -.00000008  00000-0  81062-5 0  9996
    2 39634  98.1805 171.2383 0001291  78.4154 281.7186 14.59198020 63499
    """

  func testParseTLEFromFile() throws {
    let path = try writeTemporaryTLE(Self.sentinelTLE)

    let tle = try TLE(name: "SENTINEL-1A", tleFilename: path)
    checkTLE(tle)
  }

  /// The satellite of interest may sit between other entries in the file.
  func testParseTLEFromFile_FindsNameAmongOtherSatellites() throws {
    let contents = """
      ISS (ZARYA)
      1 25544U 98067A   08264.51782528 -.00002182  00000-0 -11606-4 0  2927
      2 25544  51.6416 247.4627 0006703 130.5360 325.0288 15.72125391563537
      \(Self.sentinelTLE)
      NOAA 19
      1 33591U 09005A   06176.02341244  .00000060  00000-0  35940-4 0  1836
      2 33591  98.4283 247.6961 0000884  88.1964 271.9322 14.35478080140550
      """
    let path = try writeTemporaryTLE(contents)

    let tle = try TLE(name: "SENTINEL-1A", tleFilename: path)
    checkTLE(tle)
  }

  /// A name that is not in the file must throw, not trap on a force unwrap.
  func testParseTLEFromFile_MissingNameThrows() throws {
    let path = try writeTemporaryTLE(Self.sentinelTLE)

    XCTAssertThrowsError(try TLE(name: "NOT PRESENT", tleFilename: path)) { error in
      guard case TLEError.fileParsing = error else {
        XCTFail("Expected fileParsing error, got \(error)")
        return
      }
    }
  }

  /// A name on the final line has no element lines after it; must throw, not trap.
  func testParseTLEFromFile_TruncatedFileThrows() throws {
    let path = try writeTemporaryTLE("SENTINEL-1A")

    XCTAssertThrowsError(try TLE(name: "SENTINEL-1A", tleFilename: path)) { error in
      guard case TLEError.fileParsing = error else {
        XCTFail("Expected fileParsing error, got \(error)")
        return
      }
    }
  }

  /// A name followed by only one element line must throw, not trap.
  func testParseTLEFromFile_MissingSecondLineThrows() throws {
    let contents = """
      SENTINEL-1A
      1 39634U 14016A   15164.10430418 -.00000008  00000-0  81062-5 0  9996
      """
    let path = try writeTemporaryTLE(contents)

    XCTAssertThrowsError(try TLE(name: "SENTINEL-1A", tleFilename: path)) { error in
      guard case TLEError.fileParsing = error else {
        XCTFail("Expected fileParsing error, got \(error)")
        return
      }
    }
  }

  func testParseTLEFromLines() throws {
    let tle = try TLE(
      name: "SENTINEL-1A",
      lineOne: "1 39634U 14016A   15164.10430418 -.00000008  00000-0  81062-5 0  9996",
      lineTwo: "2 39634  98.1805 171.2383 0001291  78.4154 281.7186 14.59198020 63499")

    checkTLE(tle)
  }

  func checkTLE(_ tle: TLE) {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
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
    // BSTAR: 81062-5 = 0.81062E-5 = 0.0000081062
    XCTAssertEqual(tle.bstar, 0.0000081062, accuracy: 0.00000000001)
    XCTAssertEqual(tle.inclination, 98.1805)
    XCTAssertEqual(tle.rightAscendingNode, 171.2383)
    XCTAssertEqual(tle.eccentricity, 0.0001291, accuracy: 0.0000001)
    XCTAssertEqual(tle.argumentPerigee, 78.4154)
    XCTAssertEqual(tle.meanAnomaly, 281.7186)
    XCTAssertEqual(tle.meanMotion, 14.59198020)
    XCTAssertEqual(tle.orbitNumber, 63499)
  }
}
