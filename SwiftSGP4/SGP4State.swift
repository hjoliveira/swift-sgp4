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

    /// con41 = 3*cos²(i) - 1
    let con41: Double

    /// con42 = 1 - 5*cos²(i)
    let con42: Double

    /// x1mth2 = 1 - cos²(i)
    let x1mth2: Double

    /// x7thm1 = 7*cos²(i) - 1
    let x7thm1: Double

    // MARK: - Additional Coefficients for Non-Simple Mode

    /// omgcof: coefficient for argument of perigee secular correction
    let omgcof: Double

    /// xmcof: coefficient for mean anomaly secular correction
    let xmcof: Double

    /// nodecf: coefficient for node secular correction
    let nodecf: Double

    /// t2cof: coefficient for t² terms
    let t2cof: Double

    /// t3cof: coefficient for t³ terms
    let t3cof: Double

    /// t4cof: coefficient for t⁴ terms
    let t4cof: Double

    /// t5cof: coefficient for t⁵ terms
    let t5cof: Double

    /// delmo: (1 + η*cos(M₀))³ for simple mode check
    let delmo: Double

    /// sinmao: sin(M₀) for simple mode check
    let sinmao: Double

    /// Simple propagation mode flag (true if perigee < 220 km)
    let isSimpleMode: Bool

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
        // Following Vallado's initl() function exactly
        let ak = pow(SGP4Constants.xke / meanMotionRadPerMin, 2.0/3.0)
        let d1 = 0.75 * SGP4Constants.j2 * (3.0 * cosInclination * cosInclination - 1.0) / (beta * beta * beta)
        var del = d1 / (ak * ak)
        let adel = ak * (1.0 - del * del - del * (1.0 / 3.0 + 134.0 * del * del / 81.0))
        del = d1 / (adel * adel)
        let n0dp = meanMotionRadPerMin / (1.0 + del)

        // Calculate semi-major axis in earth radii
        let ao = pow(SGP4Constants.xke / n0dp, 2.0/3.0)
        self.semiMajorAxis = ao
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

        // Calculate drag coefficients (C1-C5)
        let cosInclSq = cosInclination * cosInclination

        // Pre-compute helper values based on inclination
        self.con42 = 1.0 - 5.0 * cosInclSq
        self.con41 = 3.0 * cosInclSq - 1.0
        self.x1mth2 = 1.0 - cosInclSq
        self.x7thm1 = 7.0 * cosInclSq - 1.0

        let s = semiMajorAxis * (1.0 - eccentricity) - 1.0 + SGP4Constants.s0 / SGP4Constants.earthRadius

        let qoms24 = SGP4Constants.qoms2t
        let tsi = 1.0 / (semiMajorAxis - s)
        let eta2 = eta * eta
        let eeta = eccentricity * eta

        let psisq = abs(1.0 - eta2)
        let coef = qoms24 * pow(tsi, 4.0)
        let coef1 = coef / pow(psisq, 3.5)

        self.c2 = coef1 * originalMeanMotion * (semiMajorAxis * (1.0 + 1.5 * eta2 + eeta * (4.0 + eta2)) +
                  0.375 * SGP4Constants.j2 * tsi / psisq * con41 * (8.0 + 3.0 * eta2 * (8.0 + eta2)))

        self.c1 = bstar * c2

        self.c3 = (eccentricity > 1.0e-4) ? coef * tsi * SGP4Constants.j3 * originalMeanMotion * sinInclination / eccentricity : 0.0

        self.c4 = 2.0 * originalMeanMotion * coef1 * semiMajorAxis * beta * beta *
                  (eta * (2.0 + 0.5 * eta2) + eccentricity * (0.5 + 2.0 * eta2) -
                   SGP4Constants.j2 * tsi / (semiMajorAxis * psisq) *
                   (-3.0 * con41 * (1.0 - 2.0 * eeta + eta2 * (1.5 - 0.5 * eeta)) +
                    0.75 * x1mth2 * (2.0 * eta2 - eeta * (1.0 + eta2)) * cos(2.0 * argumentOfPerigee)))

        self.c5 = 2.0 * coef1 * semiMajorAxis * beta * beta * (1.0 + 2.75 * (eta2 + eeta) + eeta * eta2)

        // D2, D3, D4 coefficients
        let rp = semiMajorAxis * (1.0 - eccentricity)  // Perigee in earth radii
        self.isSimpleMode = rp < (220.0 / SGP4Constants.earthRadius + 1.0)

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

        // Additional coefficients for secular corrections
        let cc3 = (eccentricity > 1.0e-4) ? -2.0 * coef * tsi * SGP4Constants.j3oj2 * originalMeanMotion * sinInclination / eccentricity : 0.0
        self.omgcof = bstar * cc3 * cos(argumentOfPerigee)
        self.xmcof = (eccentricity > 1.0e-4) ? -(2.0/3.0) * coef * bstar / eeta : 0.0

        // Node coefficient
        let pinvsq = 1.0 / (semiMajorAxis * semiMajorAxis * (1.0 - eccentricity * eccentricity))
        let temp1Init = 1.5 * SGP4Constants.j2 * pinvsq * originalMeanMotion
        let xhdot1 = -temp1Init * cosInclination
        self.nodecf = 3.5 * (1.0 - eccentricity * eccentricity) * xhdot1 * c1

        // t coefficients
        self.t2cof = 1.5 * c1

        if !isSimpleMode {
            let cc1sq = c1 * c1
            self.t3cof = d2 + 2.0 * cc1sq
            self.t4cof = 0.25 * (3.0 * d3 + c1 * (12.0 * d2 + 10.0 * cc1sq))
            self.t5cof = 0.2 * (3.0 * d4 + 12.0 * c1 * d3 + 6.0 * d2 * d2 + 15.0 * cc1sq * (2.0 * d2 + cc1sq))
        } else {
            self.t3cof = 0.0
            self.t4cof = 0.0
            self.t5cof = 0.0
        }

        // Secular delmo and sinmao
        let delmotemp = 1.0 + eta * cos(self.meanAnomaly)
        self.delmo = delmotemp * delmotemp * delmotemp
        self.sinmao = sin(self.meanAnomaly)

        // Secular rates using temp1Init
        let cosio4 = cosInclSq * cosInclSq
        let rteosq = sqrt(1.0 - eccentricity * eccentricity)
        let temp2Init = 0.5 * temp1Init * SGP4Constants.j2 * pinvsq
        let temp3Init = -0.46875 * SGP4Constants.j4 * pinvsq * pinvsq * originalMeanMotion

        self.dotMeanMotion = originalMeanMotion + 0.5 * temp1Init * rteosq * con41 +
                             0.0625 * temp2Init * rteosq * (13.0 - 78.0 * cosInclSq + 137.0 * cosio4)

        self.dotArgumentOfPerigee = -0.5 * temp1Init * con42 +
                                    0.0625 * temp2Init * (7.0 - 114.0 * cosInclSq + 395.0 * cosio4) +
                                    temp3Init * (3.0 - 36.0 * cosInclSq + 49.0 * cosio4)

        self.dotRightAscension = xhdot1 + (0.5 * temp2Init * (4.0 - 19.0 * cosInclSq) +
                                           2.0 * temp3Init * (3.0 - 7.0 * cosInclSq)) * cosInclination

        // Additional J2 coefficients
        // Check for divide by zero with inclination = 180 deg
        if abs(cosInclination + 1.0) > 1.5e-12 {
            self.xlcof = -0.25 * SGP4Constants.j3oj2 * sinInclination * (3.0 + 5.0 * cosInclination) / (1.0 + cosInclination)
        } else {
            self.xlcof = -0.25 * SGP4Constants.j3oj2 * sinInclination * (3.0 + 5.0 * cosInclination) / 1.5e-12
        }

        self.aycof = -0.5 * SGP4Constants.j3oj2 * sinInclination

        // Resonance flags (for deep space)
        self.isSynchronous = false  // Will be set for 12-hour orbits in SDP4
        self.isResonance = false    // Will be set for 24-hour orbits in SDP4
    }
}
