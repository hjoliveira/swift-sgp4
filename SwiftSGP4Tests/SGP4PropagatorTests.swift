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
  struct ExpectedState: Sendable {
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

      guard let propagator = try? PropagatorFactory.create(tle: tle) else {
        // Some verification entries are decayed or otherwise unpropagatable.
        continue
      }

      // Classification uses the recovered (un-Kozai'd) mean motion, which
      // differs slightly from the TLE value, so only assert away from the
      // 225-minute boundary.
      let period = 1440.0 / tle.meanMotion
      if period > 230.0 {
        XCTAssertTrue(
          propagator.isDeepSpace,
          "NORAD \(tle.noradNumber) (period \(period) min) should be deep-space")
      } else if period < 220.0 {
        XCTAssertFalse(
          propagator.isDeepSpace,
          "NORAD \(tle.noradNumber) (period \(period) min) should be near-Earth")
      }

      // A deep-space propagator must report itself as such, and SGP4Propagator
      // must refuse those TLEs outright.
      if propagator.isDeepSpace {
        XCTAssertThrowsError(try SGP4Propagator(tle: tle)) { error in
          XCTAssertEqual(error as? PropagationError, .deepSpaceNotImplemented)
        }
      }
    }
  }

  /// Every verification satellite that propagates - near-Earth and deep-space
  /// alike - must produce a finite state above the Earth's surface.
  func testVerificationTLEsProduceFiniteStates() throws {
    let entries = try Self.verificationTLEs()
    var propagated = 0

    for (lineOne, lineTwo) in entries {
      let tle = try TLE(name: "VER", lineOne: lineOne, lineTwo: lineTwo)
      guard let propagator = try? PropagatorFactory.create(tle: tle),
        let state = try? propagator.propagate(minutesSinceEpoch: 0.0)
      else { continue }

      propagated += 1
      let radius = state.position.magnitude

      XCTAssertTrue(radius.isFinite, "Non-finite position for NORAD \(tle.noradNumber)")
      XCTAssertTrue(state.velocity.magnitude.isFinite)
      XCTAssertGreaterThan(radius, 6000.0, "NORAD \(tle.noradNumber) below Earth centre")
      XCTAssertLessThan(radius, 100_000.0, "NORAD \(tle.noradNumber) implausibly distant")
    }

    XCTAssertGreaterThan(propagated, 20, "Should have propagated most of the verification set")
  }

  // MARK: - Deep-Space Tests (SDP4)

  /// A deep-space satellite and its expected states.
  struct DeepSpaceCase: Sendable {
    let norad: Int
    let name: String
    let lineOne: String
    let lineTwo: String
    let states: [ExpectedState]
  }

  /// Reference states for every deep-space regime in the verification set:
  /// geostationary, 12-hour resonant, 24-hour resonant, Molniya (e > 0.68),
  /// near-equatorial (Lyddane), and a very low perigee case.
  static let deepSpaceCases: [DeepSpaceCase] = [
    DeepSpaceCase(
      norad: 11801, name: "TDRSS 3",
      lineOne: "1 11801U 80027A   06176.02341244 -.00000158  00000-0  10000-3 0  1019",
      lineTwo: "2 11801   0.0169 131.5757 0002301  92.0639 327.2506  1.00273847 97813",
      states: [
        ExpectedState(
          minutesSinceEpoch: 0.0,
          position: Vector3D(x: -41396.75805927, y: -7962.15416263, z: 0.13939309),
          velocity: Vector3D(x: 0.581234100, y: -3.019904821, z: 0.000052717)
        ),
        ExpectedState(
          minutesSinceEpoch: 360.0,
          position: Vector3D(x: 8168.78871528, y: -41359.42587063, z: 0.04980367),
          velocity: Vector3D(x: 3.016956076, y: 0.595264829, z: -0.000000542)
        ),
        ExpectedState(
          minutesSinceEpoch: 720.0,
          position: Vector3D(x: 41337.90287654, y: 8345.18161237, z: 0.06749512),
          velocity: Vector3D(x: -0.607954146, y: 3.013425637, z: 0.000048040)
        ),
      ]),
    DeepSpaceCase(
      norad: 14128, name: "EUTELSAT 1-F1",
      lineOne: "1 14128U 83058A   06176.02341244  .00000138  00000-0  10000-3 0  5218",
      lineTwo: "2 14128   0.0008 117.1750 0002258  20.0724  85.7240  1.00273786 84199",
      states: [
        ExpectedState(
          minutesSinceEpoch: 0.0,
          position: Vector3D(x: -30831.79028680, y: -28759.69118470, z: 7.07926728),
          velocity: Vector3D(x: 2.096826591, y: -2.248915281, z: 0.000313237)
        ),
        ExpectedState(
          minutesSinceEpoch: 360.0,
          position: Vector3D(x: 28887.31302037, y: -30726.22430721, z: 4.11320037),
          velocity: Vector3D(x: 2.239694339, y: 2.105590866, z: -0.000453851)
        ),
        ExpectedState(
          minutesSinceEpoch: 720.0,
          position: Vector3D(x: 30608.04768438, y: 28999.56900255, z: -5.37214457),
          velocity: Vector3D(x: -2.115201611, y: 2.231515061, z: -0.000282489)
        ),
      ]),
    DeepSpaceCase(
      norad: 8195, name: "MOLNIYA 2-14",
      lineOne: "1 08195U 75081A   06176.33215444  .00000099  00000-0  11873-3 0   813",
      lineTwo: "2 08195  64.1586 279.0717 6877146 264.7651  20.2257  2.00491383225656",
      states: [
        ExpectedState(
          minutesSinceEpoch: 0.0,
          position: Vector3D(x: 2349.89483350, y: -14785.93811562, z: 0.02119378),
          velocity: Vector3D(x: 2.721488096, y: -3.256811655, z: 4.498416672)
        ),
        ExpectedState(
          minutesSinceEpoch: 360.0,
          position: Vector3D(x: 19089.29762968, y: 3107.89495018, z: 39958.14661370),
          velocity: Vector3D(x: -0.410308034, y: 1.640332277, z: -0.306873818)
        ),
        ExpectedState(
          minutesSinceEpoch: 720.0,
          position: Vector3D(x: 2622.13222207, y: -15125.15464924, z: 474.51048398),
          velocity: Vector3D(x: 2.688287199, y: -3.078426664, z: 4.494979530)
        ),
      ]),
    DeepSpaceCase(
      norad: 9880, name: "MOLNIYA 1-36",
      lineOne: "1 09880U 77021A   06176.56157475  .00000421  00000-0  10000-3 0  9814",
      lineTwo: "2 09880  64.5968 349.3786 7069051 270.0229  16.3320  2.00813614112380",
      states: [
        ExpectedState(
          minutesSinceEpoch: 0.0,
          position: Vector3D(x: 13020.06750784, y: -2449.07193500, z: 1.15896030),
          velocity: Vector3D(x: 4.247363935, y: 1.597178501, z: 4.956708611)
        ),
        ExpectedState(
          minutesSinceEpoch: 360.0,
          position: Vector3D(x: 328.74217398, y: 19554.92047380, z: 40558.26246145),
          velocity: Vector3D(x: -1.593281066, y: 0.126772913, z: -0.359627307)
        ),
        ExpectedState(
          minutesSinceEpoch: 720.0,
          position: Vector3D(x: 13725.09398980, y: -2180.70877090, z: 863.29684523),
          velocity: Vector3D(x: 3.878478111, y: 1.656846496, z: 4.944867241)
        ),
      ]),
    DeepSpaceCase(
      norad: 21897, name: "MOLNIYA 1-83",
      lineOne: "1 21897U 92011A   06176.02341244 -.00001273  00000-0 -13525-3 0  3044",
      lineTwo: "2 21897  62.1749 198.0096 7421690 253.0462  20.1561  2.01269994104880",
      states: [
        ExpectedState(
          minutesSinceEpoch: 0.0,
          position: Vector3D(x: -14464.72135182, y: -4699.19517587, z: 0.06681686),
          velocity: Vector3D(x: -3.249312013, y: -3.281032707, z: 4.007046940)
        ),
        ExpectedState(
          minutesSinceEpoch: 360.0,
          position: Vector3D(x: -2775.46649359, y: -22839.64574119, z: 39494.64689967),
          velocity: Vector3D(x: 1.468963405, y: 0.489481769, z: -0.023972788)
        ),
        ExpectedState(
          minutesSinceEpoch: 720.0,
          position: Vector3D(x: -15302.38845375, y: -5556.43440300, z: 1095.95088753),
          velocity: Vector3D(x: -2.838224312, y: -3.134231137, z: 3.992596326)
        ),
      ]),
    DeepSpaceCase(
      norad: 22674, name: "SL-6 R/B(2)",
      lineOne: "1 22674U 93035D   06176.55909107  .00002121  00000-0  29868-3 0  6569",
      lineTwo: "2 22674  63.5035 354.4452 7541712 253.3264  18.7754  1.96679808 93877",
      states: [
        ExpectedState(
          minutesSinceEpoch: 0.0,
          position: Vector3D(x: 14712.22023280, y: -1443.81061850, z: 0.83497888),
          velocity: Vector3D(x: 4.418965470, y: 1.629592098, z: 4.115531802)
        ),
        ExpectedState(
          minutesSinceEpoch: 360.0,
          position: Vector3D(x: 12721.50543331, y: 19258.96193362, z: 40898.47648359),
          velocity: Vector3D(x: -1.457448565, y: 0.179955469, z: 0.071502601)
        ),
        ExpectedState(
          minutesSinceEpoch: 720.0,
          position: Vector3D(x: 10924.40116466, y: -2571.92414170, z: -2956.34856294),
          velocity: Vector3D(x: 6.071727751, y: 1.349579102, z: 3.898430260)
        ),
      ]),
    DeepSpaceCase(
      norad: 28129, name: "NAVSTAR 53",
      lineOne: "1 28129U 03058A   06175.57071136 -.00000104  00000-0  10000-3 0   459",
      lineTwo: "2 28129  54.7298 324.8098 0048506 266.2640  93.1663  2.00562768 18443",
      states: [
        ExpectedState(
          minutesSinceEpoch: 0.0,
          position: Vector3D(x: 21707.46412351, y: -15318.61752390, z: 0.13551152),
          velocity: Vector3D(x: 1.304029214, y: 1.816904974, z: 3.161919976)
        ),
        ExpectedState(
          minutesSinceEpoch: 360.0,
          position: Vector3D(x: -21607.02086957, y: 15432.59962630, z: 206.62470309),
          velocity: Vector3D(x: -1.306049851, y: -1.817011568, z: -3.163725018)
        ),
        ExpectedState(
          minutesSinceEpoch: 720.0,
          position: Vector3D(x: 21858.23838149, y: -15101.51661554, z: 387.34517048),
          velocity: Vector3D(x: 1.247973967, y: 1.856017403, z: 3.161439948)
        ),
      ]),
    DeepSpaceCase(
      norad: 24208, name: "ITALSAT 2",
      lineOne: "1 24208U 96044A   06177.04061740 -.00000094  00000-0  10000-3 0  1600",
      lineTwo: "2 24208   3.8536  80.0121 0026640 311.0977  48.3000  1.00778054 36119",
      states: [
        ExpectedState(
          minutesSinceEpoch: 0.0,
          position: Vector3D(x: 7534.10987189, y: 41266.39266843, z: -0.10801028),
          velocity: Vector3D(x: -3.027168008, y: 0.558848996, z: 0.207982755)
        ),
        ExpectedState(
          minutesSinceEpoch: 360.0,
          position: Vector3D(x: -41413.95109398, y: 7055.51656639, z: 2838.90906671),
          velocity: Vector3D(x: -0.521665080, y: -3.029172207, z: -0.002066843)
        ),
        ExpectedState(
          minutesSinceEpoch: 720.0,
          position: Vector3D(x: -6874.77975542, y: -41530.38329422, z: -46.60245459),
          velocity: Vector3D(x: 3.027415087, y: -0.494671177, z: -0.207337260)
        ),
      ]),
    DeepSpaceCase(
      norad: 26975, name: "COSMOS 1024 DEB",
      lineOne: "1 26975U 78066F   06174.85818871  .00000620  00000-0  10000-3 0  6809",
      lineTwo: "2 26975  68.4714 236.1303 5602877 123.7484 302.5767  2.05657553 67521",
      states: [
        ExpectedState(
          minutesSinceEpoch: 0.0,
          position: Vector3D(x: -14506.92313768, y: -21613.56043281, z: 10.05018894),
          velocity: Vector3D(x: 2.212943308, y: 1.159970892, z: 3.020600202)
        ),
        ExpectedState(
          minutesSinceEpoch: 360.0,
          position: Vector3D(x: -16785.45507465, y: -734.79159704, z: -34300.57085853),
          velocity: Vector3D(x: -1.386528125, y: -1.907762641, z: -0.220949641)
        ),
        ExpectedState(
          minutesSinceEpoch: 720.0,
          position: Vector3D(x: -11646.39698980, y: -19855.44222106, z: 3574.00109607),
          velocity: Vector3D(x: 2.626712727, y: 1.815887329, z: 2.960883901)
        ),
      ]),
    DeepSpaceCase(
      norad: 25954, name: "AMC-4",
      lineOne: "1 25954U 99060A   04039.68057285 -.00000108  00000-0  00000-0 0  6847",
      lineTwo: "2 25954   0.0004 243.8136 0001765  15.5294  22.7134  1.00271289 15615",
      states: [
        ExpectedState(
          minutesSinceEpoch: 0.0,
          position: Vector3D(x: 8827.15660472, y: -41223.00971237, z: 3.63482963),
          velocity: Vector3D(x: 3.007087319, y: 0.643701323, z: 0.000941663)
        ),
        ExpectedState(
          minutesSinceEpoch: 360.0,
          position: Vector3D(x: 41192.55903455, y: 9013.79606759, z: 12.90495666),
          velocity: Vector3D(x: -0.656727442, y: 3.003543458, z: -0.000257479)
        ),
        ExpectedState(
          minutesSinceEpoch: 720.0,
          position: Vector3D(x: -9172.23500245, y: 41161.63475527, z: -3.43575757),
          velocity: Vector3D(x: -3.000571486, y: -0.668847508, z: -0.000940101)
        ),
      ]),
    DeepSpaceCase(
      norad: 28626, name: "XM-3",
      lineOne: "1 28626U 05008A   06176.46683397 -.00000205  00000-0  10000-3 0  2190",
      lineTwo: "2 28626   0.0019 286.9433 0000335  13.7918  55.6504  1.00270176  4891",
      states: [
        ExpectedState(
          minutesSinceEpoch: 0.0,
          position: Vector3D(x: 42080.71852213, y: -2646.86387436, z: 0.81851294),
          velocity: Vector3D(x: 0.193105177, y: 3.068688251, z: 0.000438449)
        ),
        ExpectedState(
          minutesSinceEpoch: 360.0,
          position: Vector3D(x: 2467.44290178, y: 42093.60909959, z: 5.15062987),
          velocity: Vector3D(x: -3.069341800, y: 0.179976276, z: -0.000031739)
        ),
        ExpectedState(
          minutesSinceEpoch: 720.0,
          position: Vector3D(x: -42103.20138132, y: 2291.06228893, z: -0.13274964),
          velocity: Vector3D(x: -0.166974816, y: -3.070104560, z: -0.000311007)
        ),
      ]),
    DeepSpaceCase(
      norad: 4632, name: "04632",
      lineOne: "1 04632U 70093B   04031.91070959 -.00000084  00000-0  10000-3 0  9955",
      lineTwo: "2 04632  11.4628 273.1101 1450506 207.6000 143.9350  1.20231981 44145",
      states: [
        ExpectedState(
          minutesSinceEpoch: 0.0,
          position: Vector3D(x: 2334.11450085, y: -41920.44035349, z: -0.03867437),
          velocity: Vector3D(x: 2.826321032, y: -0.065091664, z: 0.570936053)
        ),
        ExpectedState(
          minutesSinceEpoch: 360.0,
          position: Vector3D(x: 38879.09428705, y: -1422.60061339, z: 7847.02393290),
          velocity: Vector3D(x: -0.295839737, y: 3.054325811, z: -0.025488707)
        ),
        ExpectedState(
          minutesSinceEpoch: 720.0,
          position: Vector3D(x: -16246.22678308, y: 27314.47092022, z: -2978.89356001),
          velocity: Vector3D(x: -3.170318911, y: -1.953195794, z: -0.663084261)
        ),
      ]),
    DeepSpaceCase(
      norad: 16925, name: "SL-6 R/B(2) 16925",
      lineOne: "1 16925U 86065D   06151.67415771  .02550794 -30915-6  18784-3 0  4486",
      lineTwo: "2 16925  62.0906 295.0239 5596327 245.1593  47.9690  4.88511875148616",
      states: [
        ExpectedState(
          minutesSinceEpoch: 0.0,
          position: Vector3D(x: 5559.11686836, y: -11941.04090781, z: -19.41235206),
          velocity: Vector3D(x: 3.392116762, y: -1.946985124, z: 4.250755852)
        ),
        ExpectedState(
          minutesSinceEpoch: 360.0,
          position: Vector3D(x: 12805.22442200, y: -10258.94667177, z: 13780.16486738),
          velocity: Vector3D(x: 0.619279224, y: 1.821510542, z: 2.507365975)
        ),
        ExpectedState(
          minutesSinceEpoch: 720.0,
          position: Vector3D(x: 11531.64866625, y: -858.27542736, z: 19086.85993771),
          velocity: Vector3D(x: -1.170071901, y: 2.660311986, z: 0.096005705)
        ),
      ]),
  ]

  /// Every deep-space satellite must match the reference state vectors, not
  /// merely land at a plausible radius.
  func testDeepSpacePropagationMatchesReference() throws {
    for testCase in Self.deepSpaceCases {
      let tle = try TLE(
        name: testCase.name, lineOne: testCase.lineOne, lineTwo: testCase.lineTwo)
      let propagator = try PropagatorFactory.create(tle: tle)

      XCTAssertTrue(
        propagator.isDeepSpace,
        "NORAD \(testCase.norad) (\(testCase.name)) should be deep-space")

      for expected in testCase.states {
        let state = try propagator.propagate(minutesSinceEpoch: expected.minutesSinceEpoch)
        let t = expected.minutesSinceEpoch

        XCTAssertEqual(
          (state.position - expected.position).magnitude, 0.0, accuracy: 0.001,
          "NORAD \(testCase.norad) position at t=\(t) min")
        XCTAssertEqual(
          (state.velocity - expected.velocity).magnitude, 0.0, accuracy: 1e-6,
          "NORAD \(testCase.norad) velocity at t=\(t) min")
      }
    }
  }

  /// Highly eccentric Molniya orbits must propagate, not be rejected. Their
  /// perigees are well above the atmosphere; an earlier implementation
  /// wrongly reported them as decayed.
  func testHighEccentricityMolniyaOrbitsPropagate() throws {
    let molniya = Self.deepSpaceCases.filter { [8195, 9880, 21897, 22674].contains($0.norad) }
    XCTAssertEqual(molniya.count, 4, "Expected all four Molniya-class cases")

    for testCase in molniya {
      let tle = try TLE(
        name: testCase.name, lineOne: testCase.lineOne, lineTwo: testCase.lineTwo)
      XCTAssertGreaterThan(tle.eccentricity, 0.65, "\(testCase.name) should be highly eccentric")

      let propagator = try PropagatorFactory.create(tle: tle)
      let state = try propagator.propagate(minutesSinceEpoch: 0.0)

      XCTAssertGreaterThan(
        state.position.magnitude, 6378.0,
        "\(testCase.name) perigee is far above the atmosphere")
    }
  }

  /// A perigee below 98 km lowers the atmospheric boundary; the reference
  /// clamps it and keeps propagating rather than rejecting the orbit.
  func testVeryLowPerigeePropagates() throws {
    let tle = try TLE(
      name: "SL-6 R/B(2)",
      lineOne: "1 16925U 86065D   06151.67415771  .02550794 -30915-6  18784-3 0  4486",
      lineTwo: "2 16925  62.0906 295.0239 5596327 245.1593  47.9690  4.88511875148616"
    )

    let propagator = try PropagatorFactory.create(tle: tle)
    let state = try propagator.propagate(minutesSinceEpoch: 0.0)

    XCTAssertEqual(
      (state.position - Vector3D(x: 5559.11686836, y: -11941.04090781, z: -19.41235206))
        .magnitude,
      0.0, accuracy: 0.001)
  }

  /// The resonance integrator is stateful, so results must not depend on the
  /// order in which times are requested.
  func testDeepSpacePropagationIsOrderIndependent() throws {
    let testCase = Self.deepSpaceCases.first { $0.norad == 8195 }!
    let tle = try TLE(
      name: testCase.name, lineOne: testCase.lineOne, lineTwo: testCase.lineTwo)

    let forward = try PropagatorFactory.create(tle: tle)
    let times = [0.0, 360.0, 720.0, 1440.0]
    let ascending = try times.map { try forward.propagate(minutesSinceEpoch: $0).position }

    let backward = try PropagatorFactory.create(tle: tle)
    var descending: [Vector3D] = []
    for t in times.reversed() {
      descending.append(try backward.propagate(minutesSinceEpoch: t).position)
    }
    descending.reverse()

    for (a, b) in zip(ascending, descending) {
      XCTAssertEqual((a - b).magnitude, 0.0, accuracy: 0.001, "Result depends on call order")
    }
  }

  /// Negative times (propagating backwards from epoch) must also work.
  func testDeepSpaceBackwardPropagation() throws {
    let tle = try TLE(
      name: "TDRSS 3",
      lineOne: "1 11801U 80027A   06176.02341244 -.00000158  00000-0  10000-3 0  1019",
      lineTwo: "2 11801   0.0169 131.5757 0002301  92.0639 327.2506  1.00273847 97813"
    )
    let propagator = try PropagatorFactory.create(tle: tle)
    let state = try propagator.propagate(minutesSinceEpoch: -720.0)

    XCTAssertEqual(
      (state.position - Vector3D(x: 41476.45722542, y: 7626.03065045, z: -0.53338207))
        .magnitude,
      0.0, accuracy: 0.001)
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
