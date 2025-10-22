//
//  SGP4State.swift
//  SwiftSGP4
//
//  Internal state for SGP4 propagation calculations
//  Stores initialized parameters and pre-computed coefficients
//

import Foundation

/// Internal state variables for SGP4 propagation
/// Contains initialized orbital elements and pre-computed coefficients
struct SGP4State {
    // MARK: - Original TLE Elements (converted to internal units)

    /// Epoch time (Julian date)
    let epoch: Date

    /// Inclination (radians)
    let inclination: Double

    /// Right ascension of ascending node (radians)
    let rightAscension: Double

    /// Eccentricity (dimensionless, 0 <= e < 1)
    let eccentricity: Double

    /// Argument of perigee (radians)
    let argumentOfPerigee: Double

    /// Mean anomaly (radians)
    let meanAnomaly: Double

    /// Mean motion (radians/minute) - converted from revolutions/day
    let meanMotion: Double

    /// BSTAR drag term (1/earth radii)
    let bstar: Double

    // MARK: - Derived Orbital Parameters

    /// Semi-major axis (earth radii)
    let semiMajorAxis: Double

    /// Original mean motion before corrections (radians/minute)
    let originalMeanMotion: Double

    /// Perigee altitude (km)
    let perigeeAltitude: Double

    /// Deep space flag (true if orbital period > 225 minutes)
    let isDeepSpace: Bool

    // MARK: - Pre-computed Trigonometric Values

    /// sin(inclination)
    let sinInclination: Double

    /// cos(inclination)
    let cosInclination: Double

    /// sin(argument of perigee)
    let sinArgumentOfPerigee: Double

    /// cos(argument of perigee)
    let cosArgumentOfPerigee: Double

    // MARK: - Common Subexpressions

    /// e² (eccentricity squared)
    let eccentricitySquared: Double

    /// √(1 - e²) (beta₀ in Vallado)
    let beta: Double

    /// 1 / beta
    let betaInverse: Double

    /// eta = √(1 - e²)
    let eta: Double

    // MARK: - SGP4 Drag Coefficients (C1-C5)

    /// C1: Main drag coefficient
    let c1: Double

    /// C2: Drag and J2 interaction
    let c2: Double

    /// C3: Atmospheric density variation with altitude
    let c3: Double

    /// C4: Long-period perturbations due to drag
    let c4: Double

    /// C5: Short-period perturbations
    let c5: Double

    // MARK: - Additional Drag Parameters

    /// D2: Second-order drag coefficient
    let d2: Double

    /// D3: Third-order drag coefficient
    let d3: Double

    /// D4: Fourth-order drag coefficient
    let d4: Double

    // MARK: - Secular Rates

    /// Rate of change of mean motion due to drag (radians/minute²)
    let dotMeanMotion: Double

    /// Rate of change of argument of perigee (radians/minute)
    let dotArgumentOfPerigee: Double

    /// Rate of change of right ascension (radians/minute)
    let dotRightAscension: Double

    // MARK: - J2 Perturbation Coefficients

    /// Common J2 term
    let aycof: Double

    /// Lumped J2 coefficients for long-period
    let xlcof: Double

    // MARK: - Resonance Terms (for deep space only)

    /// Synchronous flag (12-hour resonance)
    let isSynchronous: Bool

    /// Resonance flag (24-hour resonance)
    let isResonance: Bool

    // MARK: - Helper Values

    /// 1.5 * J2 * (earth radius / semi-major axis)²
    let temp1: Double

    /// temp1 * temp1
    let temp2: Double

    /// temp1 * temp2
    let temp3: Double

    /// Initialization from TLE
    init(from tle: TLE) throws {
        self.epoch = tle.epoch

        // Convert degrees to radians
        self.inclination = tle.inclination * SGP4Constants.deg2rad
        self.rightAscension = tle.rightAscendingNode * SGP4Constants.deg2rad
        self.eccentricity = tle.eccentricity
        self.argumentOfPerigee = tle.argumentPerigee * SGP4Constants.deg2rad
        self.meanAnomaly = tle.meanAnomaly * SGP4Constants.deg2rad

        // Convert mean motion from revolutions/day to radians/minute
        // n = (revs/day) * (2π rad/rev) / (1440 min/day)
        let meanMotionRadPerMin = tle.meanMotion * SGP4Constants.twoPi / SGP4Constants.minutesPerDay

        // Validate eccentricity
        guard eccentricity >= SGP4Constants.minEccentricity && eccentricity < SGP4Constants.maxEccentricity else {
            throw PropagationError.invalidEccentricity(
                "Eccentricity \(eccentricity) out of range [0, 1)"
            )
        }

        // Pre-compute trigonometric values
        self.sinInclination = sin(inclination)
        self.cosInclination = cos(inclination)
        self.sinArgumentOfPerigee = sin(argumentOfPerigee)
        self.cosArgumentOfPerigee = cos(argumentOfPerigee)

        // Compute common subexpressions
        self.eccentricitySquared = eccentricity * eccentricity
        self.beta = sqrt(1.0 - eccentricitySquared)
        self.betaInverse = 1.0 / beta
        self.eta = beta

        // Recover original mean motion (before drag effects in TLE)
        // This uses WGS-84 Earth radius and gravitational parameter
        let a1 = pow(SGP4Constants.xke / meanMotionRadPerMin, 2.0/3.0)
        let delta1 = (1.5 * SGP4Constants.j2 * (3.0 * cosInclination * cosInclination - 1.0)) /
                     (a1 * a1 * beta * beta * beta)
        let a0 = a1 * (1.0 - delta1 / 3.0 - delta1 * delta1 - 134.0 * delta1 * delta1 * delta1 / 81.0)
        let delta0 = (1.5 * SGP4Constants.j2 * (3.0 * cosInclination * cosInclination - 1.0)) /
                     (a0 * a0 * beta * beta * beta)

        // Calculate semi-major axis in earth radii
        let n0dp = meanMotionRadPerMin / (1.0 + delta0)
        self.semiMajorAxis = pow(SGP4Constants.xke / n0dp, 2.0/3.0)
        self.originalMeanMotion = n0dp
        self.meanMotion = n0dp

        // Calculate perigee altitude (km)
        let perigeeER = (semiMajorAxis * (1.0 - eccentricity) - 1.0) * SGP4Constants.earthRadius
        self.perigeeAltitude = perigeeER

        // Validate perigee altitude
        guard perigeeAltitude >= SGP4Constants.minPerigeeAltitude else {
            throw PropagationError.decayed(
                "Satellite has decayed: perigee altitude \(perigeeAltitude) km < \(SGP4Constants.minPerigeeAltitude) km"
            )
        }

        // Calculate orbital period to determine deep space vs near earth
        let period = SGP4Constants.twoPi / meanMotion
        self.isDeepSpace = period >= SGP4Constants.deepSpaceThreshold

        // Initialize bstar
        self.bstar = tle.bstar

        // Pre-compute J2 perturbation terms
        self.temp1 = 1.5 * SGP4Constants.j2 / (semiMajorAxis * semiMajorAxis)
        self.temp2 = temp1 * temp1
        self.temp3 = temp1 * temp2

        // Calculate drag coefficients (C1-C5)
        let cosInclSq = cosInclination * cosInclination
        let theta2 = cosInclSq

        let s = semiMajorAxis * (1.0 - eccentricity) - 1.0 + SGP4Constants.s0 / SGP4Constants.earthRadius

        let qoms24 = SGP4Constants.qoms2t
        let tsi = 1.0 / (semiMajorAxis - s)
        let eta2 = eta * eta
        let eeta = eccentricity * eta

        let psisq = abs(1.0 - eta2)
        let coef = qoms24 * pow(tsi, 4.0)
        let coef1 = coef / pow(psisq, 3.5)

        self.c2 = coef1 * originalMeanMotion * (semiMajorAxis * (1.0 + 1.5 * eta2 + eeta * (4.0 + eta2)) +
                  0.375 * SGP4Constants.j2 * tsi / psisq * (8.0 + 3.0 * eta2 * (8.0 + eta2)))

        self.c1 = bstar * c2

        self.c3 = (eccentricity > 1.0e-4) ? coef * tsi * SGP4Constants.j3 * originalMeanMotion * sinInclination / eccentricity : 0.0

        self.c4 = 2.0 * originalMeanMotion * coef1 * semiMajorAxis * beta * beta *
                  (eta * (2.0 + 0.5 * eta2) + eccentricity * (0.5 + 2.0 * eta2) -
                   SGP4Constants.j2 * tsi / (semiMajorAxis * psisq) *
                   (-3.0 * (1.0 - 3.0 * theta2) * (1.0 + 1.5 * eta2 - 2.0 * eeta - 0.5 * eta * eta2) +
                    0.75 * (1.0 - theta2) * (2.0 * eta2 - eeta - eta * eta2) * cos(2.0 * argumentOfPerigee)))

        self.c5 = 2.0 * coef1 * semiMajorAxis * beta * beta * (1.0 + 2.75 * (eta2 + eeta) + eeta * eta2)

        // D2, D3, D4 coefficients
        if semiMajorAxis < 1.0 {
            // Low perigee case - not typical
            self.d2 = 0.0
            self.d3 = 0.0
            self.d4 = 0.0
        } else {
            self.d2 = 4.0 * semiMajorAxis * tsi * c1 * c1
            let temp = d2 * tsi * c1
            self.d3 = (17.0 * semiMajorAxis + s) * temp / 3.0
            self.d4 = 0.5 * temp * semiMajorAxis * tsi * (221.0 * semiMajorAxis + 31.0 * s) * c1
        }

        // Secular rates
        self.dotMeanMotion = 0.0  // Will be updated during propagation

        // Secular rate of argument of perigee
        self.dotArgumentOfPerigee = -0.5 * temp1 * (5.0 * cosInclSq - 1.0) * originalMeanMotion / beta / beta

        // Secular rate of right ascension
        self.dotRightAscension = -temp1 * cosInclination * originalMeanMotion / beta / beta

        // Additional J2 coefficients
        self.xlcof = (eccentricity > 1.0e-4) ? 0.125 * SGP4Constants.j3 * sinInclination * (3.0 + 5.0 * cosInclination) / (1.0 + cosInclination) : 0.0

        self.aycof = -0.5 * SGP4Constants.j3 * sinInclination

        // Resonance flags (for deep space)
        self.isSynchronous = false  // Will be set for 12-hour orbits in SDP4
        self.isResonance = false    // Will be set for 24-hour orbits in SDP4
    }
}
