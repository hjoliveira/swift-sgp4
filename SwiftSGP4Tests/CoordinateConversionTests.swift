import XCTest
@testable import SwiftSGP4

class CoordinateConversionTests: XCTestCase {

    let accuracy = 1e-6 // km for position, degrees for angles

    // MARK: - TEME to ECEF Conversion Tests

    /// Test conversion at J2000 epoch (no rotation)
    func testTEME_to_ECEF_atJ2000() throws {
        let temePosition = Vector3D(x: 6000.0, y: 0.0, z: 0.0)
        let temeVelocity = Vector3D(x: 0.0, y: 7.5, z: 0.0)

        // At J2000 epoch (2000-01-01 12:00:00 TT), TEME and ECEF should be nearly aligned
        let j2000 = Date(timeIntervalSinceReferenceDate: 0) // Approximation

        let (ecefPosition, ecefVelocity) = CoordinateConverter.temeToECEF(
            position: temePosition,
            velocity: temeVelocity,
            date: j2000
        )

        // At J2000, expect minimal difference between TEME and ECEF
        XCTAssertEqual(ecefPosition.x, temePosition.x, accuracy: 100.0)
        XCTAssertEqual(ecefPosition.y, temePosition.y, accuracy: 100.0)
        XCTAssertEqual(ecefPosition.z, temePosition.z, accuracy: 100.0)
    }

    /// Test ECEF to TEME conversion (inverse operation)
    func testECEF_to_TEME_Roundtrip() throws {
        let originalTEME = Vector3D(x: 5000.0, y: 3000.0, z: 2000.0)
        let originalVelocity = Vector3D(x: 1.0, y: 5.0, z: 3.0)
        let testDate = Date()

        // Convert TEME -> ECEF -> TEME
        let (ecefPos, ecefVel) = CoordinateConverter.temeToECEF(
            position: originalTEME,
            velocity: originalVelocity,
            date: testDate
        )

        let (reconvertedTEME, reconvertedVel) = CoordinateConverter.ecefToTEME(
            position: ecefPos,
            velocity: ecefVel,
            date: testDate
        )

        // Should recover original values
        XCTAssertEqual(reconvertedTEME.x, originalTEME.x, accuracy: accuracy)
        XCTAssertEqual(reconvertedTEME.y, originalTEME.y, accuracy: accuracy)
        XCTAssertEqual(reconvertedTEME.z, originalTEME.z, accuracy: accuracy)

        XCTAssertEqual(reconvertedVel.x, originalVelocity.x, accuracy: accuracy * 1e-3)
        XCTAssertEqual(reconvertedVel.y, originalVelocity.y, accuracy: accuracy * 1e-3)
        XCTAssertEqual(reconvertedVel.z, originalVelocity.z, accuracy: accuracy * 1e-3)
    }

    // MARK: - TEME to Geodetic Conversion Tests

    /// Test conversion of satellite position to lat/lon/alt
    func testTEME_to_Geodetic_EquatorialOrbit() throws {
        // Satellite directly over equator at altitude ~630 km
        let temePosition = Vector3D(x: 7000.0, y: 0.0, z: 0.0)

        let geodetic = CoordinateConverter.temeToGeodetic(position: temePosition)

        XCTAssertEqual(geodetic.latitude, 0.0, accuracy: 0.1, "Should be on equator")
        XCTAssertEqual(geodetic.altitude, 630.0, accuracy: 10.0, "Altitude should be ~630 km")
    }

    /// Test conversion for polar position
    func testTEME_to_Geodetic_PolarPosition() throws {
        // Satellite over North Pole at altitude ~630 km
        let temePosition = Vector3D(x: 0.0, y: 0.0, z: 7000.0)

        let geodetic = CoordinateConverter.temeToGeodetic(position: temePosition)

        XCTAssertEqual(geodetic.latitude, 90.0, accuracy: 0.1, "Should be at North Pole")
        XCTAssertEqual(geodetic.altitude, 630.0, accuracy: 10.0)
    }

    /// Test conversion for ISS typical position
    func testTEME_to_Geodetic_ISSOrbit() throws {
        // Typical ISS position: altitude ~400 km, inclination 51.6 degrees
        let temePosition = Vector3D(x: 5000.0, y: 3000.0, z: 4000.0)

        let geodetic = CoordinateConverter.temeToGeodetic(position: temePosition)

        // ISS orbits at ~400 km altitude
        XCTAssertGreaterThan(geodetic.altitude, 300.0)
        XCTAssertLessThan(geodetic.altitude, 500.0)

        // Latitude should be within ISS inclination limits
        XCTAssertGreaterThanOrEqual(geodetic.latitude, -51.6)
        XCTAssertLessThanOrEqual(geodetic.latitude, 51.6)

        // Longitude should be valid
        XCTAssertGreaterThanOrEqual(geodetic.longitude, -180.0)
        XCTAssertLessThanOrEqual(geodetic.longitude, 180.0)
    }

    /// Test geostationary satellite position
    func testTEME_to_Geodetic_Geostationary() throws {
        // GEO satellite at ~35,786 km altitude
        let geoRadius = 42164.0 // km (Earth radius + GEO altitude)
        let temePosition = Vector3D(x: geoRadius, y: 0.0, z: 0.0)

        let geodetic = CoordinateConverter.temeToGeodetic(position: temePosition)

        XCTAssertEqual(geodetic.latitude, 0.0, accuracy: 0.1, "GEO satellites are equatorial")
        XCTAssertEqual(geodetic.altitude, 35786.0, accuracy: 100.0, "Should be at GEO altitude")
    }

    // MARK: - Geodetic to TEME Conversion Tests

    func testGeodetic_to_TEME_SeaLevel() throws {
        let geodetic = GeodeticCoordinate(latitude: 0.0, longitude: 0.0, altitude: 0.0)

        let temePosition = CoordinateConverter.geodeticToTEME(coordinate: geodetic, date: Date())

        // At sea level on equator, should be at Earth equatorial radius
        let magnitude = sqrt(
            temePosition.x * temePosition.x +
            temePosition.y * temePosition.y +
            temePosition.z * temePosition.z
        )

        XCTAssertEqual(magnitude, 6378.137, accuracy: 1.0, "Should be at Earth equatorial radius")
        XCTAssertEqual(temePosition.z, 0.0, accuracy: 1.0, "Should be at equator (z=0)")
    }

    func testGeodetic_to_TEME_NorthPole() throws {
        let geodetic = GeodeticCoordinate(latitude: 90.0, longitude: 0.0, altitude: 0.0)

        let temePosition = CoordinateConverter.geodeticToTEME(coordinate: geodetic, date: Date())

        // At North Pole, should be on Z-axis
        XCTAssertEqual(temePosition.x, 0.0, accuracy: 1.0)
        XCTAssertEqual(temePosition.y, 0.0, accuracy: 1.0)
        XCTAssertEqual(temePosition.z, 6356.752, accuracy: 1.0, "Should be at Earth polar radius")
    }

    func testGeodetic_to_TEME_Roundtrip() throws {
        let original = GeodeticCoordinate(latitude: 45.0, longitude: -75.0, altitude: 400.0)

        let temePosition = CoordinateConverter.geodeticToTEME(coordinate: original, date: Date())
        let reconverted = CoordinateConverter.temeToGeodetic(position: temePosition)

        XCTAssertEqual(reconverted.latitude, original.latitude, accuracy: 0.01)
        XCTAssertEqual(reconverted.longitude, original.longitude, accuracy: 0.01)
        XCTAssertEqual(reconverted.altitude, original.altitude, accuracy: 1.0)
    }

    // MARK: - Special Cases and Edge Tests

    func testCoordinateConversion_DateDependence() throws {
        let temePosition = Vector3D(x: 7000.0, y: 0.0, z: 0.0)
        let temeVelocity = Vector3D(x: 0.0, y: 7.5, z: 0.0)

        // Test at two different dates (1 day apart)
        let date1 = Date()
        let date2 = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 86400)

        let (ecef1, _) = CoordinateConverter.temeToECEF(
            position: temePosition,
            velocity: temeVelocity,
            date: date1
        )

        let (ecef2, _) = CoordinateConverter.temeToECEF(
            position: temePosition,
            velocity: temeVelocity,
            date: date2
        )

        // ECEF coordinates should differ due to Earth rotation and precession
        let difference = sqrt(
            pow(ecef1.x - ecef2.x, 2) +
            pow(ecef1.y - ecef2.y, 2) +
            pow(ecef1.z - ecef2.z, 2)
        )

        XCTAssertGreaterThan(difference, 0.1, "ECEF should change with date due to Earth rotation")
    }

    func testGeodetic_AltitudeCalculation() throws {
        // Test altitude calculation for various orbital regimes
        let testCases: [(Double, String)] = [
            (6778.137, "ISS altitude (~400 km)"),
            (7378.137, "1000 km altitude"),
            (20200.0 + 6378.137, "GPS altitude (~20,200 km)"),
            (35786.0 + 6378.137, "GEO altitude (~35,786 km)")
        ]

        for (radius, description) in testCases {
            let temePosition = Vector3D(x: radius, y: 0.0, z: 0.0)
            let geodetic = CoordinateConverter.temeToGeodetic(position: temePosition)

            XCTAssertEqual(geodetic.altitude, radius - 6378.137, accuracy: 10.0,
                          "Altitude calculation failed for \(description)")
        }
    }

    func testGeodetic_LatitudeLimits() throws {
        // Test that latitude is always in valid range [-90, 90]
        let randomPositions = [
            Vector3D(x: 7000.0, y: 0.0, z: 7000.0),
            Vector3D(x: -5000.0, y: 3000.0, z: -2000.0),
            Vector3D(x: 0.0, y: 8000.0, z: 1000.0),
            Vector3D(x: 4000.0, y: -4000.0, z: 4000.0)
        ]

        for position in randomPositions {
            let geodetic = CoordinateConverter.temeToGeodetic(position: position)

            XCTAssertGreaterThanOrEqual(geodetic.latitude, -90.0,
                                       "Latitude should be >= -90 degrees")
            XCTAssertLessThanOrEqual(geodetic.latitude, 90.0,
                                    "Latitude should be <= 90 degrees")
        }
    }

    func testGeodetic_LongitudeLimits() throws {
        // Test that longitude is always in valid range [-180, 180]
        let randomPositions = [
            Vector3D(x: 7000.0, y: 7000.0, z: 0.0),
            Vector3D(x: -5000.0, y: 5000.0, z: 0.0),
            Vector3D(x: 0.0, y: 8000.0, z: 0.0),
            Vector3D(x: 4000.0, y: -4000.0, z: 0.0)
        ]

        for position in randomPositions {
            let geodetic = CoordinateConverter.temeToGeodetic(position: position)

            XCTAssertGreaterThanOrEqual(geodetic.longitude, -180.0,
                                       "Longitude should be >= -180 degrees")
            XCTAssertLessThanOrEqual(geodetic.longitude, 180.0,
                                    "Longitude should be <= 180 degrees")
        }
    }

    // MARK: - Accuracy Reference Tests

    /// Test against known reference values from Vallado's examples
    func testCoordinateConversion_ValladoExample() throws {
        // Example from "Fundamentals of Astrodynamics and Applications" by Vallado
        // TEME position at a specific date/time

        // This is a placeholder for when we have exact reference values
        // let temePosition = Vector3D(x: ..., y: ..., z: ...)
        // let referenceDate = Date(...)
        // let expectedECEF = Vector3D(x: ..., y: ..., z: ...)

        // let (ecefPosition, _) = CoordinateConverter.temeToECEF(
        //     position: temePosition,
        //     velocity: Vector3D(x: 0, y: 0, z: 0),
        //     date: referenceDate
        // )

        // XCTAssertEqual(ecefPosition.x, expectedECEF.x, accuracy: accuracy)
        // XCTAssertEqual(ecefPosition.y, expectedECEF.y, accuracy: accuracy)
        // XCTAssertEqual(ecefPosition.z, expectedECEF.z, accuracy: accuracy)
    }
}
