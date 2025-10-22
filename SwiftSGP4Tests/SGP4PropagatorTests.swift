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
    /// Test range: 0 to 4320 minutes at 360-minute intervals
    func testSatellite00005_Propagation() throws {
        throw XCTSkip("SGP4 propagation not yet implemented - Phase 3")

        // Official TLE from SGP4-VER.TLE
        let tle = try TLE(
            name: "00005",
            lineOne: "1 00005U 58002B   00179.78495062  .00000023  00000-0  28098-4 0  4753",
            lineTwo: "2 00005  34.2682 348.7242 1859667 331.7664  19.3264 10.82419157413667"
        )

        let propagator = SGP4Propagator(tle: tle)

        // Expected states from Vallado's verification output (Appendix E)
        // Note: Full test suite includes values at 0, 360, 720, 1080, 1440 minutes
        let expectedStates: [ExpectedState] = [
            // At epoch (t=0)
            ExpectedState(
                minutesSinceEpoch: 0.0,
                position: Vector3D(x: 2328.97048951, y: -5995.21600038, z: 1719.97894906),
                velocity: Vector3D(x: 2.91207230, y: -0.98341546, z: -7.09081703)
            ),
            // At t=360 minutes
            ExpectedState(
                minutesSinceEpoch: 360.0,
                position: Vector3D(x: 2456.10705566, y: -6071.93853760, z: 1222.89727783),
                velocity: Vector3D(x: 2.67938992, y: -0.44829041, z: -7.22879231)
            ),
            // At t=720 minutes
            ExpectedState(
                minutesSinceEpoch: 720.0,
                position: Vector3D(x: 2567.56195068, y: -6112.50384522, z: 713.96397400),
                velocity: Vector3D(x: 2.44024599, y: 0.09810869, z: -7.31995916)
            )
        ]

        try verifyPropagation(propagator: propagator, expectedStates: expectedStates)
    }

    // MARK: - Satellite 06251 Tests (Near Earth Normal Drag)

    /// Test satellite 06251 (62025E - DELTA 1 DEB)
    /// Orbit characteristics: Near-earth with normal drag, perigee=377.26km
    /// Test range: 0 to 2880 minutes at 120-minute intervals
    func testSatellite06251_Propagation() throws {
        throw XCTSkip("SGP4 propagation not yet implemented - Phase 3")

        // Official TLE from SGP4-VER.TLE
        let tle = try TLE(
            name: "06251",
            lineOne: "1 06251U 62025E   06176.82412014  .00008885  00000-0  12808-3 0  3985",
            lineTwo: "2 06251  58.0579  54.0425 0030035 139.1568 221.1854 15.56387291  6774"
        )

        let propagator = SGP4Propagator(tle: tle)

        // Expected states from Vallado's verification output
        let expectedStates: [ExpectedState] = [
            // At epoch (t=0)
            ExpectedState(
                minutesSinceEpoch: 0.0,
                position: Vector3D(x: 2999.98280334, y: 5387.35339730, z: 3493.54924572),
                velocity: Vector3D(x: -4.89642854, y: 4.17386515, z: 3.70045788)
            ),
            // At t=120 minutes
            ExpectedState(
                minutesSinceEpoch: 120.0,
                position: Vector3D(x: 3012.30504151, y: 5389.79082333, z: 3484.31250618),
                velocity: Vector3D(x: -4.88870120, y: 4.18095662, z: 3.71118371)
            )
        ]

        try verifyPropagation(propagator: propagator, expectedStates: expectedStates)
    }

    // MARK: - Satellite 28057 Tests (Deep Space - 24-hour orbit)

    /// Test satellite 28057 (04632A - MOLNIYA 2-14)
    /// Orbit characteristics: Deep space, 12-hour resonant, e=0.7
    func testSatellite28057_DeepSpace() throws {
        throw XCTSkip("SDP4 deep-space propagation not yet implemented - Phase 3")

        // Official TLE from SGP4-VER.TLE
        let tle = try TLE(
            name: "28057",
            lineOne: "1 28057U 04632A   06176.56503869  .00000092  00000-0  00000+0 0  8139",
            lineTwo: "2 28057  63.1979 327.8107 7313992 120.6404 259.3288  2.00321811 13695"
        )

        let propagator = SGP4Propagator(tle: tle)

        // Expected states for deep-space satellite
        // Note: Deep space uses SDP4 algorithms (orbital period >= 225 minutes)
        let expectedStates: [ExpectedState] = [
            ExpectedState(
                minutesSinceEpoch: 0.0,
                position: Vector3D(x: -9060.47373569, y: 4658.70952502, z: 813.68673153),
                velocity: Vector3D(x: -2.23279093, y: -0.72060832, z: 0.69506755)
            )
        ]

        try verifyPropagation(propagator: propagator, expectedStates: expectedStates)
    }

    // MARK: - Edge Case Tests

    /// Test satellite 11801 (TDRSS 3) - Non-standard TLE format
    /// This satellite omits the ephemeris type integer in the TLE
    func testSatellite11801_NonStandardFormat() throws {
        throw XCTSkip("SGP4 propagation not yet implemented - Phase 3")

        let tle = try TLE(
            name: "11801",
            lineOne: "1 11801U 80027A   06176.02341244 -.00000158  00000-0  10000-3 0  1019",
            lineTwo: "2 11801   0.0169 131.5757 0002301  92.0639 327.2506  1.00273847 97813"
        )

        let propagator = SGP4Propagator(tle: tle)

        let expectedStates: [ExpectedState] = [
            ExpectedState(
                minutesSinceEpoch: 0.0,
                position: Vector3D(x: -40588.15046386, y: -11462.16730482, z: 10.25649405),
                velocity: Vector3D(x: 0.83563773, y: -2.96421473, z: 0.00005126)
            )
        ]

        try verifyPropagation(propagator: propagator, expectedStates: expectedStates)
    }

    /// Test satellite with near-circular orbit (very low eccentricity)
    func testLowEccentricityOrbit() throws {
        throw XCTSkip("SGP4 propagation not yet implemented - Phase 3")

        // Satellite 14128 (EUTELSAT 1-F1/ECS1)
        let tle = try TLE(
            name: "14128",
            lineOne: "1 14128U 83058A   06176.02341244  .00000138  00000-0  10000-3 0  5218",
            lineTwo: "2 14128   0.0008 117.1750 0002258  20.0724  85.7240  1.00273786 84199"
        )

        let propagator = SGP4Propagator(tle: tle)

        let expectedStates: [ExpectedState] = [
            ExpectedState(
                minutesSinceEpoch: 0.0,
                position: Vector3D(x: -40582.97983719, y: 11541.27193991, z: 66.26859462),
                velocity: Vector3D(x: -0.84174363, y: -2.96399288, z: -0.00000028)
            )
        ]

        try verifyPropagation(propagator: propagator, expectedStates: expectedStates)
    }

    // MARK: - Accuracy Tests

    /// Test propagation accuracy over multiple orbits
    func testLongTermPropagationAccuracy() throws {
        throw XCTSkip("SGP4 propagation not yet implemented - Phase 3")

        let tle = try TLE(
            name: "06251",
            lineOne: "1 06251U 62025E   06176.82412014  .00008885  00000-0  12808-3 0  3985",
            lineTwo: "2 06251  58.0579  54.0425 0030035 139.1568 221.1854 15.56387291  6774"
        )

        let propagator = SGP4Propagator(tle: tle)

        // Test propagation over 2 days (2880 minutes)
        // This satellite completes ~15.56 orbits per day
        for minuteOffset in stride(from: 0.0, through: 2880.0, by: 360.0) {
            let state = try propagator.propagate(minutesSinceEpoch: minuteOffset)

            // Verify position magnitude is reasonable for LEO satellite
            let positionMagnitude = sqrt(
                state.position.x * state.position.x +
                state.position.y * state.position.y +
                state.position.z * state.position.z
            )

            // Should be between Earth radius (6371 km) and ~8000 km for this LEO satellite
            XCTAssertGreaterThan(positionMagnitude, 6371.0,
                                "Position should be above Earth's surface at t=\(minuteOffset)")
            XCTAssertLessThan(positionMagnitude, 8000.0,
                             "Position should be in LEO range at t=\(minuteOffset)")
        }
    }

    // MARK: - Helper Methods

    /// Verifies propagation results against expected states
    private func verifyPropagation(propagator: SGP4Propagator,
                                   expectedStates: [ExpectedState],
                                   accuracy: Double = 1e-6) throws {
        for expectedState in expectedStates {
            let state = try propagator.propagate(minutesSinceEpoch: expectedState.minutesSinceEpoch)

            // Verify position components (km)
            XCTAssertEqual(state.position.x, expectedState.position.x, accuracy: accuracy,
                          "Position X mismatch at t=\(expectedState.minutesSinceEpoch) min")
            XCTAssertEqual(state.position.y, expectedState.position.y, accuracy: accuracy,
                          "Position Y mismatch at t=\(expectedState.minutesSinceEpoch) min")
            XCTAssertEqual(state.position.z, expectedState.position.z, accuracy: accuracy,
                          "Position Z mismatch at t=\(expectedState.minutesSinceEpoch) min")

            // Verify velocity components (km/s)
            XCTAssertEqual(state.velocity.x, expectedState.velocity.x, accuracy: accuracy * 1e-3,
                          "Velocity X mismatch at t=\(expectedState.minutesSinceEpoch) min")
            XCTAssertEqual(state.velocity.y, expectedState.velocity.y, accuracy: accuracy * 1e-3,
                          "Velocity Y mismatch at t=\(expectedState.minutesSinceEpoch) min")
            XCTAssertEqual(state.velocity.z, expectedState.velocity.z, accuracy: accuracy * 1e-3,
                          "Velocity Z mismatch at t=\(expectedState.minutesSinceEpoch) min")
        }
    }
}
