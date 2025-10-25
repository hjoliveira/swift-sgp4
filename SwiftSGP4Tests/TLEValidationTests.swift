import XCTest
@testable import SwiftSGP4

class TLEValidationTests: XCTestCase {

    // MARK: - Valid TLE Parsing Tests

    func testValidTLE_StandardFormat() throws {
        let tle = try TLE(
            name: "ISS (ZARYA)",
            lineOne: "1 25544U 98067A   08264.51782528 -.00002182  00000-0 -11606-4 0  2927",
            lineTwo: "2 25544  51.6416 247.4627 0006703 130.5360 325.0288 15.72125391563537"
        )

        XCTAssertEqual(tle.name, "ISS (ZARYA)")
        XCTAssertEqual(tle.noradNumber, 25544)
        XCTAssertEqual(tle.intDesignator, "98067A")
        XCTAssertEqual(tle.inclination, 51.6416, accuracy: 0.0001)
        XCTAssertEqual(tle.rightAscendingNode, 247.4627, accuracy: 0.0001)
        XCTAssertEqual(tle.eccentricity, 0.0006703, accuracy: 0.0000001)
        XCTAssertEqual(tle.argumentPerigee, 130.5360, accuracy: 0.0001)
        XCTAssertEqual(tle.meanAnomaly, 325.0288, accuracy: 0.0001)
        XCTAssertEqual(tle.meanMotion, 15.72125391, accuracy: 0.00000001)
        XCTAssertEqual(tle.orbitNumber, 63537)
    }

    func testValidTLE_HighlyEllipticalOrbit() throws {
        // Molniya orbit with high eccentricity
        let tle = try TLE(
            name: "MOLNIYA 1-69",
            lineOne: "1 08195U 75081A   06176.33215444  .00000099  00000-0  11873-3 0   813",
            lineTwo: "2 08195  62.9072 225.4191 7388600 280.7164  14.2345  2.00491383225656"
        )

        XCTAssertEqual(tle.noradNumber, 8195)
        XCTAssertEqual(tle.eccentricity, 0.7388600, accuracy: 0.0000001)
        XCTAssertEqual(tle.meanMotion, 2.00491383, accuracy: 0.00000001)
    }

    func testValidTLE_Geostationary() throws {
        // Near-geostationary satellite (mean motion ~ 1.0 rev/day)
        let tle = try TLE(
            name: "GOES 16",
            lineOne: "1 41866U 16071A   06176.02341244  .00000138  00000-0  10000-3 0  5218",
            lineTwo: "2 41866   0.0008 117.1750 0002258  20.0724  85.7240  1.00273786 84199"
        )

        XCTAssertEqual(tle.noradNumber, 41866)
        XCTAssertEqual(tle.inclination, 0.0008, accuracy: 0.0001)
        XCTAssertEqual(tle.eccentricity, 0.0002258, accuracy: 0.0000001)
        XCTAssertEqual(tle.meanMotion, 1.00273786, accuracy: 0.00000001)
    }

    func testValidTLE_NegativeBstar() throws {
        let tle = try TLE(
            name: "TEST SAT",
            lineOne: "1 25544U 98067A   08264.51782528 -.00002182  00000-0 -11606-4 0  2927",
            lineTwo: "2 25544  51.6416 247.4627 0006703 130.5360 325.0288 15.72125391563537"
        )

        XCTAssertEqual(tle.meanMotionDt2, -0.00002182, accuracy: 0.00000001)
        // Bstar should be negative: -11606-4 = -0.11606E-4 = -0.000011606
        XCTAssertLessThan(tle.bstar, 0.0)
    }

    // MARK: - Invalid TLE Detection Tests

    func testInvalidTLE_WrongLineLength() {
        XCTAssertThrowsError(try TLE(
            name: "INVALID",
            lineOne: "1 25544U 98067A   08264.51782528", // Too short
            lineTwo: "2 25544  51.6416 247.4627 0006703 130.5360 325.0288 15.72125391563537"
        )) { error in
            guard case TLEError.invalidLineLength(let line) = error else {
                XCTFail("Expected invalidLineLength error")
                return
            }
            XCTAssertEqual(line, 1)
        }
    }

    func testInvalidTLE_WrongLineNumber() {
        XCTAssertThrowsError(try TLE(
            name: "INVALID",
            lineOne: "3 25544U 98067A   08264.51782528 -.00002182  00000-0 -11606-4 0  2927", // Should start with '1'
            lineTwo: "2 25544  51.6416 247.4627 0006703 130.5360 325.0288 15.72125391563537"
        )) { error in
            guard case TLEError.invalidElement = error else {
                XCTFail("Expected invalidElement error")
                return
            }
        }
    }

    func testInvalidTLE_MismatchedSatelliteNumbers() {
        XCTAssertThrowsError(try TLE(
            name: "INVALID",
            lineOne: "1 25544U 98067A   08264.51782528 -.00002182  00000-0 -11606-4 0  2927",
            lineTwo: "2 25545  51.6416 247.4627 0006703 130.5360 325.0288 15.72125391563537" // Different sat number
        )) { error in
            guard case TLEError.invalidElement(let message) = error else {
                XCTFail("Expected invalidElement error")
                return
            }
            XCTAssertTrue(message.contains("Satellite id not the same"))
        }
    }

    func testInvalidTLE_InvalidNoradNumber() {
        XCTAssertThrowsError(try TLE(
            name: "INVALID",
            lineOne: "1 ABCDEU 98067A   08264.51782528 -.00002182  00000-0 -11606-4 0  2927", // Non-numeric NORAD number
            lineTwo: "2 ABCDE  51.6416 247.4627 0006703 130.5360 325.0288 15.72125391563537"
        )) { error in
            guard case TLEError.invalidElement = error else {
                XCTFail("Expected invalidElement error")
                return
            }
        }
    }

    // MARK: - Edge Case Tests

    func testTLE_ZeroEccentricity() throws {
        // Perfectly circular orbit (theoretical)
        let tle = try TLE(
            name: "CIRCULAR",
            lineOne: "1 99999U 20001A   20100.50000000  .00000000  00000-0  00000-0 0  9999",
            lineTwo: "2 99999  45.0000 180.0000 0000000 000.0000 000.0000 15.00000000000001"
        )

        XCTAssertEqual(tle.eccentricity, 0.0, accuracy: 0.0000001)
    }

    func testTLE_HighInclination() throws {
        // Polar orbit
        let tle = try TLE(
            name: "POLAR",
            lineOne: "1 99999U 20001A   20100.50000000  .00000000  00000-0  00000-0 0  9999",
            lineTwo: "2 99999  98.5000 180.0000 0001000 000.0000 000.0000 14.50000000000001"
        )

        XCTAssertEqual(tle.inclination, 98.5, accuracy: 0.01)
    }

    func testTLE_RetrogradeOrbit() throws {
        // Retrograde orbit (inclination > 90 degrees)
        let tle = try TLE(
            name: "RETROGRADE",
            lineOne: "1 99999U 20001A   20100.50000000  .00000000  00000-0  00000-0 0  9999",
            lineTwo: "2 99999 120.0000 180.0000 0001000 000.0000 000.0000 14.50000000000001"
        )

        XCTAssertEqual(tle.inclination, 120.0, accuracy: 0.01)
    }

    func testTLE_VeryOldEpoch() throws {
        // Satellite from 1957 (Sputnik era)
        let tle = try TLE(
            name: "OLD SATELLITE",
            lineOne: "1 00001U 57001A   57300.12345678  .00000100  00000-0  10000-3 0  9999",
            lineTwo: "2 00001  45.0000 180.0000 0100000 000.0000 000.0000 15.00000000000001"
        )

        let calendar = Calendar.current
        let year = calendar.component(.year, from: tle.epoch)
        XCTAssertEqual(year, 1957)
    }

    func testTLE_RecentEpoch() throws {
        // Satellite from 2024
        let tle = try TLE(
            name: "NEW SATELLITE",
            lineOne: "1 99999U 24001A   24100.12345678  .00000100  00000-0  10000-3 0  9999",
            lineTwo: "2 99999  45.0000 180.0000 0100000 000.0000 000.0000 15.00000000000001"
        )

        let calendar = Calendar.current
        let year = calendar.component(.year, from: tle.epoch)
        XCTAssertEqual(year, 2024)
    }

    // MARK: - Scientific Notation Parsing Tests

    func testTLE_BstarScientificNotation() throws {
        // Test various BSTAR formats
        // Note: BSTAR field is 8 characters (columns 53-60)
        let testCases: [(String, Double)] = [
            (" 81062-5", 0.81062E-5),   // Positive exponent notation (space-padded)
            ("-11606-4", -0.11606E-4),  // Negative mantissa
            (" 00000-0", 0.0),          // Zero value (space-padded)
            (" 12345-2", 0.12345E-2)    // Standard notation (space-padded)
        ]

        for (bstarString, expectedValue) in testCases {
            let tle = try TLE(
                name: "TEST",
                lineOne: "1 99999U 24001A   24100.12345678  .00000100  00000-0 \(bstarString) 0  9999",
                lineTwo: "2 99999  45.0000 180.0000 0100000 000.0000 000.0000 15.00000000000001"
            )

            XCTAssertEqual(tle.bstar, expectedValue, accuracy: 1e-10,
                          "BSTAR parsing failed for '\(bstarString)'")
        }
    }

    // MARK: - Real World TLE Tests

    func testRealWorldTLE_ISS() throws {
        // Current ISS TLE (as of test creation)
        let tle = try TLE(
            name: "ISS (ZARYA)",
            lineOne: "1 25544U 98067A   20100.12345678  .00001234  00000-0  23456-4 0  9999",
            lineTwo: "2 25544  51.6400 123.4567 0001234 123.4567 236.5433 15.54123456123456"
        )

        // Verify it parses correctly
        XCTAssertEqual(tle.noradNumber, 25544)
        XCTAssertEqual(tle.intDesignator, "98067A")

        // ISS orbit characteristics
        XCTAssertGreaterThan(tle.meanMotion, 15.0, "ISS should complete ~15 orbits per day")
        XCTAssertLessThan(tle.meanMotion, 16.0)
        XCTAssertLessThan(tle.eccentricity, 0.01, "ISS orbit should be nearly circular")
    }

    func testRealWorldTLE_GPS() throws {
        // GPS satellite (semi-synchronous orbit)
        let tle = try TLE(
            name: "GPS BIIA-10",
            lineOne: "1 22877U 93068A   20100.12345678  .00000012  00000-0  10000-3 0  9999",
            lineTwo: "2 22877  55.4567 234.5678 0123456 234.5678 125.4321  2.00612345123456"
        )

        // GPS satellites orbit at ~20,200 km altitude with period of ~12 hours
        XCTAssertGreaterThan(tle.meanMotion, 1.9, "GPS satellites complete ~2 orbits per day")
        XCTAssertLessThan(tle.meanMotion, 2.1)
        XCTAssertGreaterThan(tle.inclination, 54.0)
        XCTAssertLessThan(tle.inclination, 56.0)
    }

    // MARK: - Checksum Tests (if implemented in TLE struct)

    // Note: The current TLE implementation doesn't validate checksums
    // These tests should be enabled when checksum validation is added

    /*
    func testTLE_ValidChecksum() throws {
        // TLE with correct checksum
        let tle = try TLE(
            name: "VALID",
            lineOne: "1 25544U 98067A   08264.51782528 -.00002182  00000-0 -11606-4 0  2927",
            lineTwo: "2 25544  51.6416 247.4627 0006703 130.5360 325.0288 15.72125391563537"
        )

        XCTAssertNotNil(tle)
    }

    func testTLE_InvalidChecksum() {
        // TLE with incorrect checksum (last digit wrong)
        XCTAssertThrowsError(try TLE(
            name: "INVALID",
            lineOne: "1 25544U 98067A   08264.51782528 -.00002182  00000-0 -11606-4 0  2920", // Wrong checksum
            lineTwo: "2 25544  51.6416 247.4627 0006703 130.5360 325.0288 15.72125391563537"
        ))
    }
    */
}
