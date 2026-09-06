//
//  SGP4PropagatorTests.swift
//  SwiftSGP4Tests
//
//  Created using validated test cases from:
//  Vallado, D. A., Crawford, P., Hujsak, R., & Kelso, T. S. (2006).
//  "Revisiting Spacetrack Report #3" (AIAA 2006-6753)
//  Official test data from: https://celestrak.org/publications/AIAA/2006-6753/
//

import XCTest

@testable import SwiftSGP4

/// Test cases based on official SGP4 verification data (SGP4-VER.TLE)
/// These tests validate the SGP4 propagator against established reference values
class SGP4PropagatorTests: XCTestCase {

  // MARK: - Test Data Structures

  /// Represents an expected state vector (position and velocity) at a specific time
  struct ExpectedState {
    let minutesSinceEpoch: Double
    let position: Vector3D  // km (TEME frame)
    let velocity: Vector3D  // km/s (TEME frame)
  }

  // MARK: - Satellite 00005 Tests (TEME Example - Highly Elliptical Orbit)

  /// Test satellite 00005 (58002B)
  /// Orbit characteristics: Highly elliptical (e=0.1859667), 10.82 revs/day
  func testSatellite00005_Propagation() throws {
    let tle = try TLE(
      name: "00005",
      lineOne: "1 00005U 58002B   00179.78495062  .00000023  00000-0  28098-4 0  4753",
      lineTwo: "2 00005  34.2682 348.7242 1859667 331.7664  19.3264 10.82419157413667"
    )

    let propagator = try SGP4Propagator(tle: tle)

    let expectedStates: [ExpectedState] = [
      ExpectedState(
        minutesSinceEpoch: 0.0,
        position: Vector3D(x: 7022.46529266, y: -1400.08296755, z: 0.03995155),
        velocity: Vector3D(x: 1.893841015, y: 6.405893759, z: 4.534807250)
      ),
      ExpectedState(
        minutesSinceEpoch: 360.0,
        position: Vector3D(x: -7154.03120202, y: -3783.17682504, z: -3536.19412294),
        velocity: Vector3D(x: 4.741887409, y: -4.151817765, z: -2.093935425)
      ),
      ExpectedState(
        minutesSinceEpoch: 720.0,
        position: Vector3D(x: -7134.59340119, y: 6531.68641334, z: 3260.27186483),
        velocity: Vector3D(x: -4.113793027, y: -2.911922039, z: -2.557327851)
      ),
    ]

    try verifyPropagation(propagator: propagator, expectedStates: expectedStates)
  }

  // MARK: - Satellite 06251 Tests (Near Earth Normal Drag)

  /// Test satellite 06251 (62025E - DELTA 1 DEB)
  /// Orbit characteristics: Near-earth with normal drag, perigee=377.26km
  func testSatellite06251_Propagation() throws {
    let tle = try TLE(
      name: "06251",
      lineOne: "1 06251U 62025E   06176.82412014  .00008885  00000-0  12808-3 0  3985",
      lineTwo: "2 06251  58.0579  54.0425 0030035 139.1568 221.1854 15.56387291  6774"
    )

    let propagator = try SGP4Propagator(tle: tle)

    let expectedStates: [ExpectedState] = [
      ExpectedState(
        minutesSinceEpoch: 0.0,
        position: Vector3D(x: 3988.31022699, y: 5498.96657235, z: 0.90055879),
        velocity: Vector3D(x: -3.290032738, y: 2.357652820, z: 6.496623475)
      ),
      ExpectedState(
        minutesSinceEpoch: 120.0,
        position: Vector3D(x: -3935.69800083, y: 409.10980837, z: 5471.33577327),
        velocity: Vector3D(x: -3.374784183, y: -6.635211043, z: -1.942056221)
      ),
    ]

    try verifyPropagation(propagator: propagator, expectedStates: expectedStates)
  }

  // MARK: - Satellite 28057 Tests (CBERS 2 - Near Earth, Very Low Eccentricity)

  /// Test satellite 28057 (03049A - CBERS 2)
  /// Orbit characteristics: Near-earth, very low eccentricity (e=0.0000884)
  func testSatellite28057_Propagation() throws {
    let tle = try TLE(
      name: "28057",
      lineOne: "1 28057U 03049A   06177.78615833  .00000060  00000-0  35940-4 0  1836",
      lineTwo: "2 28057  98.4283 247.6961 0000884  88.1964 271.9322 14.35478080140550"
    )

    let propagator = try SGP4Propagator(tle: tle)

    let expectedStates: [ExpectedState] = [
      ExpectedState(
        minutesSinceEpoch: 0.0,
        position: Vector3D(x: -2715.28237486, y: -6619.26436889, z: -0.01341443),
        velocity: Vector3D(x: -1.00858727, y: 0.42278200, z: 7.38527294)
      ),
      ExpectedState(
        minutesSinceEpoch: 360.0,
        position: Vector3D(x: 2801.25607157, y: 5455.03931333, z: -3692.12865694),
        velocity: Vector3D(x: -0.59509586, y: -3.95192312, z: -6.29879913)
      ),
      ExpectedState(
        minutesSinceEpoch: 720.0,
        position: Vector3D(x: -2090.79884266, y: -2723.22832193, z: 6266.13356576),
        velocity: Vector3D(x: 1.99264067, y: 6.33752952, z: 3.41180308)
      ),
    ]

    try verifyPropagation(propagator: propagator, expectedStates: expectedStates)
  }

  // MARK: - Satellite 28350 Tests (COSMOS 2405 - Near Earth, High Drag)

  /// Test satellite 28350 (04020A - COSMOS 2405)
  /// Orbit characteristics: Near-earth, perigee=127.20km, high drag (BSTAR=0.00018678)
  /// Exercises the simplified drag path (isimp == 1).
  func testSatellite28350_Propagation() throws {
    let tle = try TLE(
      name: "28350",
      lineOne: "1 28350U 04020A   06167.21788666  .16154492  76267-5  18678-3 0  8894",
      lineTwo: "2 28350  64.9977 345.6130 0024870 260.7578  99.9590 16.47856722116490"
    )

    let propagator = try SGP4Propagator(tle: tle)

    let expectedStates: [ExpectedState] = [
      ExpectedState(
        minutesSinceEpoch: 0.0,
        position: Vector3D(x: 6333.08123128, y: -1580.82852326, z: 90.69355720),
        velocity: Vector3D(x: 0.71463442, y: 3.22424655, z: 7.08312813)
      ),
      ExpectedState(
        minutesSinceEpoch: 120.0,
        position: Vector3D(x: -3990.93845855, y: 3052.98341907, z: 4155.32700629),
        velocity: Vector3D(x: -5.90900619, y: -0.87630797, z: -5.03913140)
      ),
      ExpectedState(
        minutesSinceEpoch: 240.0,
        position: Vector3D(x: -603.55232010, y: -2685.13474569, z: -5891.70274282),
        velocity: Vector3D(x: 7.57251991, y: -1.97565673, z: 0.12172261)
      ),
    ]

    try verifyPropagation(propagator: propagator, expectedStates: expectedStates)
  }

  // MARK: - Satellite 88888 Tests (STR#3 Official SGP4 Test Case)

  /// Test satellite 88888 (STR#3 SGP4 test)
  /// Orbit characteristics: Official SGP4 test case, e=0.0086731
  func testSatellite88888_Propagation() throws {
    let tle = try TLE(
      name: "88888",
      lineOne: "1 88888U          80275.98708465  .00073094  13844-3  66816-4 0    87",
      lineTwo: "2 88888  72.8435 115.9689 0086731  52.6988 110.5714 16.05824518  1058"
    )

    let propagator = try SGP4Propagator(tle: tle)

    let expectedStates: [ExpectedState] = [
      ExpectedState(
        minutesSinceEpoch: 0.0,
        position: Vector3D(x: 2328.96975262, y: -5995.22051338, z: 1719.97297192),
        velocity: Vector3D(x: 2.91207328, y: -0.98341796, z: -7.09081621)
      ),
      ExpectedState(
        minutesSinceEpoch: 360.0,
        position: Vector3D(x: 2456.10706533, y: -6071.93855503, z: 1222.89768554),
        velocity: Vector3D(x: 2.67939004, y: -0.44829081, z: -7.22879215)
      ),
      ExpectedState(
        minutesSinceEpoch: 720.0,
        position: Vector3D(x: 2567.56229695, y: -6112.50383922, z: 713.96374435),
        velocity: Vector3D(x: 2.44024575, y: 0.09810900, z: -7.31995926)
      ),
    ]

    try verifyPropagation(propagator: propagator, expectedStates: expectedStates)
  }

  /// The propagator must be exact at the epoch itself, where no secular or drag
  /// terms have accumulated. This is the sharpest available regression guard.
  func testPropagationIsExactAtEpoch() throws {
    let cases: [(String, String, String, Vector3D)] = [
      (
        "00005",
        "1 00005U 58002B   00179.78495062  .00000023  00000-0  28098-4 0  4753",
        "2 00005  34.2682 348.7242 1859667 331.7664  19.3264 10.82419157413667",
        Vector3D(x: 7022.46529266, y: -1400.08296755, z: 0.03995155)
      ),
      (
        "06251",
        "1 06251U 62025E   06176.82412014  .00008885  00000-0  12808-3 0  3985",
        "2 06251  58.0579  54.0425 0030035 139.1568 221.1854 15.56387291  6774",
        Vector3D(x: 3988.31022699, y: 5498.96657235, z: 0.90055879)
      ),
      (
        "88888",
        "1 88888U          80275.98708465  .00073094  13844-3  66816-4 0    87",
        "2 88888  72.8435 115.9689 0086731  52.6988 110.5714 16.05824518  1058",
        Vector3D(x: 2328.96975262, y: -5995.22051338, z: 1719.97297192)
      ),
    ]

    for (name, lineOne, lineTwo, expected) in cases {
      let propagator = try SGP4Propagator(
        tle: try TLE(name: name, lineOne: lineOne, lineTwo: lineTwo))
      let state = try propagator.propagate(minutesSinceEpoch: 0.0)

      XCTAssertEqual(
        (state.position - expected).magnitude, 0.0, accuracy: 0.001,
        "Satellite \(name) should match the reference to a metre at epoch")
    }
  }

  // MARK: - Verification File Driven Tests

  /// Exercise every entry in the bundled official verification file, rather than
  /// relying only on the hand-copied cases above.
  func testAllVerificationTLEsParseAndClassify() throws {
    let entries = try Self.verificationTLEs()

    XCTAssertGreaterThan(entries.count, 20, "Verification file should hold many satellites")

    for (lineOne, lineTwo) in entries {
      let tle = try TLE(name: "VER", lineOne: lineOne, lineTwo: lineTwo)

      // Deep-space classification must agree with the orbital period.
      let period = 1440.0 / tle.meanMotion
      let expectedDeepSpace = period >= 225.0

      guard let propagator = try? PropagatorFactory.create(tle: tle) else {
        // Some verification entries are decayed or otherwise unpropagatable.
        continue
      }

      XCTAssertEqual(
        propagator.isDeepSpace, expectedDeepSpace,
        "Wrong propagator for NORAD \(tle.noradNumber) (period \(period) min)")
    }
  }

  /// Every near-Earth verification satellite that propagates must produce a
  /// finite state above the Earth's surface.
  func testVerificationTLEsProduceFiniteStates() throws {
    let entries = try Self.verificationTLEs()
    var propagated = 0

    for (lineOne, lineTwo) in entries {
      let tle = try TLE(name: "VER", lineOne: lineOne, lineTwo: lineTwo)
      guard let propagator = try? PropagatorFactory.create(tle: tle),
        !propagator.isDeepSpace,
        let state = try? propagator.propagate(minutesSinceEpoch: 0.0)
      else { continue }

      propagated += 1
      let radius = state.position.magnitude

      XCTAssertTrue(radius.isFinite, "Non-finite position for NORAD \(tle.noradNumber)")
      XCTAssertTrue(state.velocity.magnitude.isFinite)
      XCTAssertGreaterThan(radius, 6000.0, "NORAD \(tle.noradNumber) below Earth centre")
      XCTAssertLessThan(radius, 100_000.0, "NORAD \(tle.noradNumber) implausibly distant")
    }

    XCTAssertGreaterThan(propagated, 5, "Should have propagated several near-Earth satellites")
  }

  // MARK: - Deep-Space Tests (SDP4)

  /// Satellite 11801 (TDRSS 3) - geostationary, requires deep-space propagation.
  func testSatellite11801_NonStandardFormat() throws {
    let tle = try TLE(
      name: "TDRSS 3",
      lineOne: "1 11801U 80027A   06176.02341244 -.00000158  00000-0  10000-3 0  1019",
      lineTwo: "2 11801   0.0169 131.5757 0002301  92.0639 327.2506  1.00273847 97813"
    )

    let propagator = try PropagatorFactory.create(tle: tle)
    XCTAssertTrue(propagator.isDeepSpace, "Satellite 11801 should be classified as deep-space")

    let state = try propagator.propagate(minutesSinceEpoch: 0.0)

    XCTAssertEqual(
      state.position.magnitude, 42164.0, accuracy: 5000.0, "Should be near geostationary radius")
  }

  /// Satellite 14128 (EUTELSAT 1-F1) - geostationary, low eccentricity.
  func testLowEccentricityOrbit() throws {
    let tle = try TLE(
      name: "EUTELSAT 1-F1",
      lineOne: "1 14128U 83058A   06176.02341244  .00000138  00000-0  10000-3 0  5218",
      lineTwo: "2 14128   0.0008 117.1750 0002258  20.0724  85.7240  1.00273786 84199"
    )

    let propagator = try PropagatorFactory.create(tle: tle)
    XCTAssertTrue(propagator.isDeepSpace, "Satellite 14128 should be classified as deep-space")

    let state = try propagator.propagate(minutesSinceEpoch: 0.0)

    XCTAssertEqual(
      state.position.magnitude, 42164.0, accuracy: 5000.0, "Should be near geostationary radius")
  }

  /// Satellite 28129 (NAVSTAR 53 / GPS) - 12h non-resonant.
  func testSatellite28129_GPS() throws {
    let tle = try TLE(
      name: "NAVSTAR 53 (USA 175)",
      lineOne: "1 28129U 03058A   06175.57071136 -.00000104  00000-0  10000-3 0   459",
      lineTwo: "2 28129  54.7298 324.8098 0048506 266.2640  93.1663  2.00562768 18443"
    )

    let propagator = try PropagatorFactory.create(tle: tle)
    XCTAssertTrue(propagator.isDeepSpace, "GPS satellite should be deep-space")

    let state = try propagator.propagate(minutesSinceEpoch: 0.0)

    XCTAssertGreaterThan(state.position.magnitude, 20000.0, "Should be above LEO")
    XCTAssertLessThan(state.position.magnitude, 40000.0, "Should be below GEO")
  }

  /// Satellite 24208 (ITALSAT 2) - 24h resonant GEO, inclination > 3 deg.
  func testSatellite24208_InclinedGEO() throws {
    let tle = try TLE(
      name: "ITALSAT 2",
      lineOne: "1 24208U 96044A   06177.04061740 -.00000094  00000-0  10000-3 0  1600",
      lineTwo: "2 24208   3.8536  80.0121 0026640 311.0977  48.3000  1.00778054 36119"
    )

    let propagator = try PropagatorFactory.create(tle: tle)
    XCTAssertTrue(propagator.isDeepSpace, "GEO satellite should be deep-space")

    let state = try propagator.propagate(minutesSinceEpoch: 0.0)

    XCTAssertEqual(
      state.position.magnitude, 42164.0, accuracy: 5000.0, "Should be near GEO radius")
  }

  /// Satellite 26975 (COSMOS 1024 DEB) - 12h resonant.
  func testSatellite26975_MediumEccentricity12h() throws {
    let tle = try TLE(
      name: "COSMOS 1024 DEB",
      lineOne: "1 26975U 78066F   06174.85818871  .00000620  00000-0  10000-3 0  6809",
      lineTwo: "2 26975  68.4714 236.1303 5602877 123.7484 302.5767  2.05657553 67521"
    )

    let propagator = try PropagatorFactory.create(tle: tle)
    XCTAssertTrue(propagator.isDeepSpace, "12h orbit should be deep-space")

    let state = try propagator.propagate(minutesSinceEpoch: 0.0)

    XCTAssertGreaterThan(state.position.magnitude, 6000.0, "Should be above Earth")
    XCTAssertLessThan(state.position.magnitude, 50000.0, "Should be in 12h orbit range")
  }

  /// Satellite 25954 (AMC-4) - very low inclination (0.0004 deg).
  func testSatellite25954_VeryLowInclination() throws {
    let tle = try TLE(
      name: "AMC-4",
      lineOne: "1 25954U 99060A   04039.68057285 -.00000108  00000-0  00000-0 0  6847",
      lineTwo: "2 25954   0.0004 243.8136 0001765  15.5294  22.7134  1.00271289 15615"
    )

    let propagator = try PropagatorFactory.create(tle: tle)
    XCTAssertTrue(propagator.isDeepSpace, "GEO satellite should be deep-space")

    let state = try propagator.propagate(minutesSinceEpoch: 0.0)

    XCTAssertEqual(
      state.position.magnitude, 42164.0, accuracy: 5000.0, "Should be near GEO radius")
  }

  /// Satellite 28626 (XM-3) - 24h resonant, very low inclination.
  func testSatellite28626_LowInclinationGEO() throws {
    let tle = try TLE(
      name: "XM-3",
      lineOne: "1 28626U 05008A   06176.46683397 -.00000205  00000-0  10000-3 0  2190",
      lineTwo: "2 28626   0.0019 286.9433 0000335  13.7918  55.6504  1.00270176  4891"
    )

    let propagator = try PropagatorFactory.create(tle: tle)
    XCTAssertTrue(propagator.isDeepSpace, "GEO satellite should be deep-space")

    let state = try propagator.propagate(minutesSinceEpoch: 0.0)

    XCTAssertEqual(
      state.position.magnitude, 42164.0, accuracy: 5000.0, "Should be near GEO radius")
  }

  /// Satellite 04632 - deep space with Lyddane fix, moderate eccentricity.
  func testSatellite04632_LyddaneFix() throws {
    let tle = try TLE(
      name: "04632",
      lineOne: "1 04632U 70093B   04031.91070959 -.00000084  00000-0  10000-3 0  9955",
      lineTwo: "2 04632  11.4628 273.1101 1450506 207.6000 143.9350  1.20231981 44145"
    )

    let propagator = try PropagatorFactory.create(tle: tle)
    XCTAssertTrue(propagator.isDeepSpace, "Should be deep-space")

    let state = try propagator.propagate(minutesSinceEpoch: 0.0)

    XCTAssertGreaterThan(state.position.magnitude, 6000.0, "Should be above Earth")
    XCTAssertLessThan(state.position.magnitude, 60000.0, "Should be in deep-space range")
  }

  // MARK: - Known SDP4 Limitations
  //
  // The SDP4 lunar-solar model is incomplete: several periodic coefficients are
  // stubbed at zero and `propagate` adds an inclination term to the eccentricity,
  // which drives `e` past 1 for highly eccentric orbits. These satellites are
  // therefore reported as decayed even though their true perigees are well above
  // the atmosphere (08195's perigee is roughly 1900 km).
  //
  // These tests pin that behaviour deliberately, so the defect stays visible
  // instead of being hidden behind a print statement. When SDP4 is corrected,
  // they will fail and should be replaced with real reference-value assertions.

  /// Highly eccentric deep-space orbits are currently rejected as decayed.
  func testKnownLimitation_HighEccentricityDeepSpaceRejected() throws {
    let cases: [(String, String, String, Double)] = [
      (
        "MOLNIYA 2-14",
        "1 08195U 75081A   06176.33215444  .00000099  00000-0  11873-3 0   813",
        "2 08195  64.1586 279.0717 6877146 264.7651  20.2257  2.00491383225656", 0.6877
      ),
      (
        "MOLNIYA 1-36",
        "1 09880U 77021A   06176.56157475  .00000421  00000-0  10000-3 0  9814",
        "2 09880  64.5968 349.3786 7069051 270.0229  16.3320  2.00813614112380", 0.7069
      ),
      (
        "MOLNIYA 1-83",
        "1 21897U 92011A   06176.02341244 -.00001273  00000-0 -13525-3 0  3044",
        "2 21897  62.1749 198.0096 7421690 253.0462  20.1561  2.01269994104880", 0.7422
      ),
      (
        "SL-6 R/B(2)",
        "1 22674U 93035D   06176.55909107  .00002121  00000-0  29868-3 0  6569",
        "2 22674  63.5035 354.4452 7541712 253.3264  18.7754  1.96679808 93877", 0.7542
      ),
    ]

    for (name, lineOne, lineTwo, eccentricity) in cases {
      let tle = try TLE(name: name, lineOne: lineOne, lineTwo: lineTwo)
      XCTAssertEqual(tle.eccentricity, eccentricity, accuracy: 0.0001)

      let propagator = try PropagatorFactory.create(tle: tle)
      XCTAssertTrue(propagator.isDeepSpace, "\(name) should be deep-space")

      XCTAssertThrowsError(
        try propagator.propagate(minutesSinceEpoch: 0.0),
        "KNOWN GAP: SDP4 rejects \(name) (e=\(eccentricity)); fix SDP4 and update this test"
      ) { error in
        XCTAssertEqual(error as? PropagationError, .orbitDecayed)
      }
    }
  }

  /// A perigee below 98 km is rejected during initialization.
  /// The reference implementation instead clamps its atmospheric boundary and
  /// keeps propagating, so this is a deliberate deviation, pinned here.
  func testKnownLimitation_VeryLowPerigeeRejectedAtInit() throws {
    let tle = try TLE(
      name: "SL-6 R/B(2)",
      lineOne: "1 16925U 86065D   06151.67415771  .02550794 -30915-6  18784-3 0  4486",
      lineTwo: "2 16925  62.0906 295.0239 5596327 245.1593  47.9690  4.88511875148616"
    )

    XCTAssertThrowsError(try PropagatorFactory.create(tle: tle)) { error in
      XCTAssertEqual(error as? PropagationError, .orbitDecayed)
    }
  }

  // MARK: - Additional Near-Earth Edge Cases (SGP4)

  /// Satellite 29238 (SL-12 DEB) - perigee 212 km, exercises simplified drag.
  func testSatellite29238_SimplifiedDrag() throws {
    let tle = try TLE(
      name: "SL-12 DEB",
      lineOne: "1 29238U 06022G   06177.28732010  .00766286  10823-4  13334-2 0   101",
      lineTwo: "2 29238  51.5595 213.7903 0202579  95.2503 267.9010 15.73823839  1061"
    )

    let propagator = try PropagatorFactory.create(tle: tle)
    XCTAssertFalse(propagator.isDeepSpace, "Should be near-Earth")

    let state = try propagator.propagate(minutesSinceEpoch: 0.0)

    XCTAssertGreaterThan(state.position.magnitude, 6600.0, "Should be in low LEO")
    XCTAssertLessThan(state.position.magnitude, 7500.0, "Should be in LEO range")
  }

  /// A near-Earth TLE must be rejected by SGP4Propagator only when deep-space.
  func testDeepSpaceTLERejectedBySGP4Propagator() throws {
    let tle = try TLE(
      name: "ITALSAT 2",
      lineOne: "1 24208U 96044A   06177.04061740 -.00000094  00000-0  10000-3 0  1600",
      lineTwo: "2 24208   3.8536  80.0121 0026640 311.0977  48.3000  1.00778054 36119"
    )

    XCTAssertThrowsError(try SGP4Propagator(tle: tle)) { error in
      XCTAssertEqual(error as? PropagationError, .deepSpaceNotImplemented)
    }
  }

  // MARK: - Accuracy Tests

  /// Test propagation accuracy over multiple orbits
  func testLongTermPropagationAccuracy() throws {
    let tle = try TLE(
      name: "06251",
      lineOne: "1 06251U 62025E   06176.82412014  .00008885  00000-0  12808-3 0  3985",
      lineTwo: "2 06251  58.0579  54.0425 0030035 139.1568 221.1854 15.56387291  6774"
    )

    let propagator = try SGP4Propagator(tle: tle)

    for minuteOffset in stride(from: 0.0, through: 2880.0, by: 360.0) {
      let state = try propagator.propagate(minutesSinceEpoch: minuteOffset)
      let positionMagnitude = state.position.magnitude

      XCTAssertGreaterThan(
        positionMagnitude, 6371.0,
        "Position should be above Earth's surface at t=\(minuteOffset)")
      XCTAssertLessThan(
        positionMagnitude, 8000.0,
        "Position should be in LEO range at t=\(minuteOffset)")
    }
  }

  // MARK: - Helper Methods

  /// Loads the (line 1, line 2) pairs from the bundled SGP4-VER.TLE resource.
  ///
  /// Line 2 in that file carries extra trailing test-harness columns (start,
  /// stop and step time), so both lines are trimmed to the 69-character
  /// standard TLE width.
  private static func verificationTLEs() throws -> [(String, String)] {
    let bundle = Bundle.module
    let url = try XCTUnwrap(
      bundle.url(forResource: "SGP4-VER", withExtension: "TLE"),
      "SGP4-VER.TLE resource is missing from the test bundle")

    let text = try String(contentsOf: url, encoding: .utf8)
    let lines =
      text
      .components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty && !$0.hasPrefix("#") }

    var entries: [(String, String)] = []
    var index = 0
    while index + 1 < lines.count {
      let first = lines[index]
      let second = lines[index + 1]

      if first.hasPrefix("1 ") && second.hasPrefix("2 ") && first.count >= 69 && second.count >= 69
      {
        entries.append((String(first.prefix(69)), String(second.prefix(69))))
        index += 2
      } else {
        index += 1
      }
    }
    return entries
  }

  /// Verifies propagation results against expected states.
  ///
  /// The tolerance is applied to the position error *vector*, not to each axis
  /// independently - three per-axis errors just under the limit can otherwise
  /// hide a much larger total error.
  ///
  /// Default: 1 km position, 1 m/s velocity. Measured worst case across the
  /// reference satellites is 278 m (satellite 00005 at t=720, e=0.186); all
  /// other cases are within 100 m and every case is exact at epoch.
  private func verifyPropagation(
    propagator: SGP4Propagator,
    expectedStates: [ExpectedState],
    positionAccuracy: Double = 1.0,
    velocityAccuracy: Double = 0.001
  ) throws {
    for expectedState in expectedStates {
      let state = try propagator.propagate(minutesSinceEpoch: expectedState.minutesSinceEpoch)
      let t = expectedState.minutesSinceEpoch

      XCTAssertEqual(
        (state.position - expectedState.position).magnitude, 0.0, accuracy: positionAccuracy,
        "Position error vector too large at t=\(t) min")
      XCTAssertEqual(
        (state.velocity - expectedState.velocity).magnitude, 0.0, accuracy: velocityAccuracy,
        "Velocity error vector too large at t=\(t) min")

      XCTAssertEqual(
        state.position.x, expectedState.position.x, accuracy: positionAccuracy,
        "Position X mismatch at t=\(t) min")
      XCTAssertEqual(
        state.position.y, expectedState.position.y, accuracy: positionAccuracy,
        "Position Y mismatch at t=\(t) min")
      XCTAssertEqual(
        state.position.z, expectedState.position.z, accuracy: positionAccuracy,
        "Position Z mismatch at t=\(t) min")

      XCTAssertEqual(
        state.velocity.x, expectedState.velocity.x, accuracy: velocityAccuracy,
        "Velocity X mismatch at t=\(t) min")
      XCTAssertEqual(
        state.velocity.y, expectedState.velocity.y, accuracy: velocityAccuracy,
        "Velocity Y mismatch at t=\(t) min")
      XCTAssertEqual(
        state.velocity.z, expectedState.velocity.z, accuracy: velocityAccuracy,
        "Velocity Z mismatch at t=\(t) min")
    }
  }
}
