import XCTest

@testable import SwiftSGP4

class CoordinateConversionTests: XCTestCase {

  let accuracy = 1e-6  // km for position, degrees for angles

  /// A fixed instant, so conversions are reproducible run to run.
  /// 2024-06-15 06:00:00 UTC
  static let referenceDate = Date(timeIntervalSince1970: 1_718_431_200.0)

  private func utcDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    var c = DateComponents()
    c.year = y
    c.month = m
    c.day = d
    c.hour = h
    return cal.date(from: c)!
  }

  /// Recover the Z-rotation angle (GMST) that temeToECEF applied, in degrees.
  private func rotationAngleDegrees(at date: Date) -> Double {
    let (e, _) = CoordinateConverter.temeToECEF(
      position: Vector3D(x: 1.0, y: 0.0, z: 0.0),
      velocity: Vector3D(x: 0.0, y: 0.0, z: 0.0),
      date: date
    )
    let deg = atan2(-e.y, e.x) * 180.0 / .pi
    return deg < 0 ? deg + 360.0 : deg
  }

  // MARK: - GMST Tests

  /// GMST drives every inertial/fixed frame conversion, so pin it to known values.
  /// Reference values from the IAU 1982 expression, cross-checked against Meeus
  /// (Astronomical Algorithms, ch. 12). Agreement to 1e-4 deg.
  func testGMST_KnownReferenceValues() throws {
    let cases: [(Date, Double, String)] = [
      (utcDate(2000, 1, 1, 12), 280.460618, "J2000.0 epoch"),
      (utcDate(2000, 1, 2, 0), 100.953442, "midnight UT"),
      (utcDate(2024, 6, 15, 6), 354.016505, "06h UT"),
      (utcDate(1995, 3, 10, 18), 77.938961, "18h UT, pre-2000"),
    ]

    for (date, expected, label) in cases {
      XCTAssertEqual(
        rotationAngleDegrees(at: date), expected, accuracy: 1e-4,
        "GMST wrong for \(label)")
    }
  }

  /// GMST must advance by ~360.986 degrees per solar day, not stall or double-count.
  func testGMST_AdvancesOneSiderealDayPerSolarDay() throws {
    let t0 = utcDate(2024, 6, 15, 0)
    let t1 = t0.addingTimeInterval(86400.0)

    var delta = rotationAngleDegrees(at: t1) - rotationAngleDegrees(at: t0)
    if delta < 0 { delta += 360.0 }

    XCTAssertEqual(delta, 0.98564736629, accuracy: 1e-3, "One solar day of GMST advance")
  }

  /// GMST must never be returned as a negative angle.
  func testGMST_NonNegativeForPre2000Dates() throws {
    for year in [1960, 1975, 1990, 1999] {
      let angle = rotationAngleDegrees(at: utcDate(year, 1, 1, 0))
      XCTAssertGreaterThanOrEqual(angle, 0.0, "GMST negative in \(year)")
      XCTAssertLessThan(angle, 360.0)
    }
  }

  // MARK: - TEME to ECEF Conversion Tests

  /// TEME to ECEF is a pure Z-rotation, so it preserves Z and magnitude.
  func testTEME_to_ECEF_PreservesZAndMagnitude() throws {
    let temePosition = Vector3D(x: 6000.0, y: 0.0, z: 1234.0)
    let temeVelocity = Vector3D(x: 0.0, y: 7.5, z: 0.0)

    let (ecefPosition, _) = CoordinateConverter.temeToECEF(
      position: temePosition,
      velocity: temeVelocity,
      date: Self.referenceDate
    )

    XCTAssertEqual(ecefPosition.z, temePosition.z, accuracy: 0.001)
    XCTAssertEqual(ecefPosition.magnitude, temePosition.magnitude, accuracy: 0.001)
  }

  /// The rotation must be by GMST specifically, not by some other angle.
  func testTEME_to_ECEF_RotatesByGMST() throws {
    let date = utcDate(2024, 6, 15, 6)
    let gmst = 354.016505 * .pi / 180.0
    let teme = Vector3D(x: 7000.0, y: 1500.0, z: -300.0)

    let (ecef, _) = CoordinateConverter.temeToECEF(
      position: teme, velocity: Vector3D(x: 0, y: 0, z: 0), date: date)

    let expected = Vector3D(
      x: cos(gmst) * teme.x + sin(gmst) * teme.y,
      y: -sin(gmst) * teme.x + cos(gmst) * teme.y,
      z: teme.z
    )

    XCTAssertEqual(ecef.x, expected.x, accuracy: 0.01)
    XCTAssertEqual(ecef.y, expected.y, accuracy: 0.01)
    XCTAssertEqual(ecef.z, expected.z, accuracy: 0.01)
  }

  /// Test ECEF to TEME conversion (inverse operation)
  func testECEF_to_TEME_Roundtrip() throws {
    let originalTEME = Vector3D(x: 5000.0, y: 3000.0, z: 2000.0)
    let originalVelocity = Vector3D(x: 1.0, y: 5.0, z: 3.0)
    let testDate = Self.referenceDate

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

    XCTAssertEqual(reconvertedTEME.x, originalTEME.x, accuracy: accuracy)
    XCTAssertEqual(reconvertedTEME.y, originalTEME.y, accuracy: accuracy)
    XCTAssertEqual(reconvertedTEME.z, originalTEME.z, accuracy: accuracy)

    XCTAssertEqual(reconvertedVel.x, originalVelocity.x, accuracy: accuracy)
    XCTAssertEqual(reconvertedVel.y, originalVelocity.y, accuracy: accuracy)
    XCTAssertEqual(reconvertedVel.z, originalVelocity.z, accuracy: accuracy)
  }

  /// A roundtrip cancels a wrong rotation, so also check the forward result is
  /// genuinely rotated away from the input.
  func testTEME_to_ECEF_ActuallyRotates() throws {
    let teme = Vector3D(x: 7000.0, y: 0.0, z: 0.0)
    let (ecef, _) = CoordinateConverter.temeToECEF(
      position: teme, velocity: Vector3D(x: 0, y: 0, z: 0), date: Self.referenceDate)

    XCTAssertGreaterThan(
      (ecef - teme).magnitude, 1.0,
      "ECEF should differ from TEME at a date where GMST is non-zero")
  }

  // MARK: - ECEF to Geodetic Conversion Tests

  /// These exercise the WGS84 ellipsoid math only, so they use the ECEF entry point.
  func testECEF_to_Geodetic_EquatorialPosition() throws {
    let position = Vector3D(x: 7000.0, y: 0.0, z: 0.0)

    let geodetic = CoordinateConverter.ecefToGeodetic(position: position)

    XCTAssertEqual(geodetic.latitude, 0.0, accuracy: 0.1, "Should be on equator")
    XCTAssertEqual(geodetic.longitude, 0.0, accuracy: 0.1)
    XCTAssertEqual(geodetic.altitude, 621.863, accuracy: 0.1, "7000 - 6378.137")
  }

  func testECEF_to_Geodetic_PolarPosition() throws {
    // Satellite over North Pole: polar radius 6356.752 + 630 = 6986.752 km
    let position = Vector3D(x: 0.0, y: 0.0, z: 6987.0)

    let geodetic = CoordinateConverter.ecefToGeodetic(position: position)

    XCTAssertEqual(geodetic.latitude, 90.0, accuracy: 0.1, "Should be at North Pole")
    XCTAssertEqual(geodetic.altitude, 630.0, accuracy: 10.0)
  }

  func testECEF_to_Geodetic_ISSOrbit() throws {
    let position = Vector3D(x: 4793.0, y: 2876.0, z: 3834.0)

    let geodetic = CoordinateConverter.ecefToGeodetic(position: position)

    XCTAssertGreaterThan(geodetic.altitude, 300.0)
    XCTAssertLessThan(geodetic.altitude, 500.0)

    XCTAssertGreaterThanOrEqual(geodetic.latitude, -51.6)
    XCTAssertLessThanOrEqual(geodetic.latitude, 51.6)

    XCTAssertGreaterThanOrEqual(geodetic.longitude, -180.0)
    XCTAssertLessThanOrEqual(geodetic.longitude, 180.0)
  }

  func testECEF_to_Geodetic_Geostationary() throws {
    let geoRadius = 42164.0
    let position = Vector3D(x: geoRadius, y: 0.0, z: 0.0)

    let geodetic = CoordinateConverter.ecefToGeodetic(position: position)

    XCTAssertEqual(geodetic.latitude, 0.0, accuracy: 0.1, "GEO satellites are equatorial")
    XCTAssertEqual(geodetic.altitude, 35786.0, accuracy: 100.0, "Should be at GEO altitude")
  }

  // MARK: - TEME to Geodetic Conversion Tests

  /// Geodetic longitude is tied to the rotating Earth, so the same TEME position
  /// must map to different longitudes at different times.
  func testTEME_to_Geodetic_LongitudeDependsOnDate() throws {
    let temePosition = Vector3D(x: 7000.0, y: 0.0, z: 0.0)

    let t0 = utcDate(2024, 6, 15, 0)
    let t6 = t0.addingTimeInterval(6.0 * 3600.0)

    let g0 = CoordinateConverter.temeToGeodetic(position: temePosition, date: t0)
    let g6 = CoordinateConverter.temeToGeodetic(position: temePosition, date: t6)

    // Six hours of Earth rotation is ~90.25 degrees of longitude.
    var delta = g0.longitude - g6.longitude
    if delta < 0 { delta += 360.0 }
    XCTAssertEqual(delta, 90.25, accuracy: 0.5, "6h should shift longitude ~90 deg")

    // Latitude and altitude are unaffected by a Z-rotation.
    XCTAssertEqual(g0.latitude, g6.latitude, accuracy: 1e-9)
    XCTAssertEqual(g0.altitude, g6.altitude, accuracy: 1e-9)
  }

  // MARK: - Geodetic to TEME Conversion Tests

  /// A geodetic position is fixed to the Earth, so its TEME vector must change
  /// as the Earth rotates underneath the inertial frame.
  func testGeodetic_to_TEME_DependsOnDate() throws {
    let coordinate = GeodeticCoordinate(latitude: 45.0, longitude: -75.0, altitude: 400.0)

    let t0 = utcDate(2024, 6, 15, 0)
    let t6 = t0.addingTimeInterval(6.0 * 3600.0)

    let p0 = CoordinateConverter.geodeticToTEME(coordinate: coordinate, date: t0)
    let p6 = CoordinateConverter.geodeticToTEME(coordinate: coordinate, date: t6)

    XCTAssertNotEqual(p0, p6, "TEME position must change as the Earth rotates")
    XCTAssertGreaterThan(
      (p0 - p6).magnitude, 1000.0,
      "6h of rotation should move the TEME vector substantially")

    // Rotation preserves magnitude and Z.
    XCTAssertEqual(p0.magnitude, p6.magnitude, accuracy: 1e-6)
    XCTAssertEqual(p0.z, p6.z, accuracy: 1e-6)
  }

  func testGeodetic_to_ECEF_SeaLevel() throws {
    let geodetic = GeodeticCoordinate(latitude: 0.0, longitude: 0.0, altitude: 0.0)

    let position = CoordinateConverter.geodeticToECEF(coordinate: geodetic)

    XCTAssertEqual(
      position.magnitude, 6378.137, accuracy: 1.0, "Should be at Earth equatorial radius")
    XCTAssertEqual(position.z, 0.0, accuracy: 1.0, "Should be at equator (z=0)")
  }

  func testGeodetic_to_ECEF_NorthPole() throws {
    let geodetic = GeodeticCoordinate(latitude: 90.0, longitude: 0.0, altitude: 0.0)

    let position = CoordinateConverter.geodeticToECEF(coordinate: geodetic)

    XCTAssertEqual(position.x, 0.0, accuracy: 1.0)
    XCTAssertEqual(position.y, 0.0, accuracy: 1.0)
    XCTAssertEqual(position.z, 6356.752, accuracy: 1.0, "Should be at Earth polar radius")
  }

  /// Roundtrip through the full date-aware TEME path.
  func testGeodetic_to_TEME_Roundtrip() throws {
    let original = GeodeticCoordinate(latitude: 45.0, longitude: -75.0, altitude: 400.0)
    let date = Self.referenceDate

    let temePosition = CoordinateConverter.geodeticToTEME(coordinate: original, date: date)
    let reconverted = CoordinateConverter.temeToGeodetic(position: temePosition, date: date)

    XCTAssertEqual(reconverted.latitude, original.latitude, accuracy: 0.01)
    XCTAssertEqual(reconverted.longitude, original.longitude, accuracy: 0.01)
    XCTAssertEqual(reconverted.altitude, original.altitude, accuracy: 1.0)
  }

  /// Roundtrip through the frame-free ECEF path.
  func testGeodetic_to_ECEF_Roundtrip() throws {
    let cases = [
      GeodeticCoordinate(latitude: 45.0, longitude: -75.0, altitude: 400.0),
      GeodeticCoordinate(latitude: -33.9, longitude: 151.2, altitude: 0.0),
      GeodeticCoordinate(latitude: 0.0, longitude: 0.0, altitude: 35786.0),
      GeodeticCoordinate(latitude: 78.2, longitude: 15.6, altitude: 120.0),
    ]

    for original in cases {
      let ecef = CoordinateConverter.geodeticToECEF(coordinate: original)
      let back = CoordinateConverter.ecefToGeodetic(position: ecef)

      XCTAssertEqual(back.latitude, original.latitude, accuracy: 1e-6)
      XCTAssertEqual(back.longitude, original.longitude, accuracy: 1e-6)
      XCTAssertEqual(back.altitude, original.altitude, accuracy: 1e-6)
    }
  }

  // MARK: - Special Cases and Edge Tests

  func testCoordinateConversion_DateDependence() throws {
    let temePosition = Vector3D(x: 7000.0, y: 0.0, z: 0.0)
    let temeVelocity = Vector3D(x: 0.0, y: 7.5, z: 0.0)

    let date1 = utcDate(2024, 6, 15, 0)
    let date2 = date1.addingTimeInterval(43200.0)  // 12 hours

    let (ecef1, _) = CoordinateConverter.temeToECEF(
      position: temePosition, velocity: temeVelocity, date: date1)

    let (ecef2, _) = CoordinateConverter.temeToECEF(
      position: temePosition, velocity: temeVelocity, date: date2)

    // Half a rotation puts the two roughly antipodal, so they differ by ~2r.
    XCTAssertEqual(
      (ecef1 - ecef2).magnitude, 14000.0, accuracy: 200.0,
      "12h apart should be nearly antipodal in ECEF")
  }

  func testGeodetic_AltitudeCalculation() throws {
    let testCases: [(Double, String)] = [
      (6778.137, "ISS altitude (~400 km)"),
      (7378.137, "1000 km altitude"),
      (20200.0 + 6378.137, "GPS altitude (~20,200 km)"),
      (35786.0 + 6378.137, "GEO altitude (~35,786 km)"),
    ]

    for (radius, description) in testCases {
      let position = Vector3D(x: radius, y: 0.0, z: 0.0)
      let geodetic = CoordinateConverter.ecefToGeodetic(position: position)

      XCTAssertEqual(
        geodetic.altitude, radius - 6378.137, accuracy: 1e-6,
        "Altitude calculation failed for \(description)")
    }
  }

  func testGeodetic_LatitudeLimits() throws {
    let positions = [
      Vector3D(x: 7000.0, y: 0.0, z: 7000.0),
      Vector3D(x: -5000.0, y: 3000.0, z: -2000.0),
      Vector3D(x: 0.0, y: 8000.0, z: 1000.0),
      Vector3D(x: 4000.0, y: -4000.0, z: 4000.0),
    ]

    for position in positions {
      let geodetic = CoordinateConverter.ecefToGeodetic(position: position)

      XCTAssertGreaterThanOrEqual(geodetic.latitude, -90.0, "Latitude should be >= -90 degrees")
      XCTAssertLessThanOrEqual(geodetic.latitude, 90.0, "Latitude should be <= 90 degrees")
    }
  }

  func testGeodetic_LongitudeLimits() throws {
    let positions = [
      Vector3D(x: 7000.0, y: 7000.0, z: 0.0),
      Vector3D(x: -5000.0, y: 5000.0, z: 0.0),
      Vector3D(x: 0.0, y: 8000.0, z: 0.0),
      Vector3D(x: 4000.0, y: -4000.0, z: 0.0),
    ]

    let expectedLongitudes = [45.0, 135.0, 90.0, -45.0]

    for (position, expected) in zip(positions, expectedLongitudes) {
      let geodetic = CoordinateConverter.ecefToGeodetic(position: position)

      XCTAssertGreaterThanOrEqual(geodetic.longitude, -180.0)
      XCTAssertLessThanOrEqual(geodetic.longitude, 180.0)
      XCTAssertEqual(geodetic.longitude, expected, accuracy: 1e-9)
    }
  }
}
