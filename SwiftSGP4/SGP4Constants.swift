//
//  SGP4Constants.swift
//  SwiftSGP4
//
//  Physical and mathematical constants for SGP4/SDP4 propagation
//  Based on Vallado et al. "Revisiting Spacetrack Report #3" (AIAA 2006-6753)
//

import Foundation

/// Physical and mathematical constants used in SGP4 calculations
struct SGP4Constants {
    // MARK: - Mathematical Constants

    /// π (pi)
    static let pi = Double.pi

    /// 2π (two pi)
    static let twoPi = 2.0 * Double.pi

    /// π/2 (half pi)
    static let halfPi = Double.pi / 2.0

    /// Degrees to radians conversion factor
    static let deg2rad = Double.pi / 180.0

    /// Radians to degrees conversion factor
    static let rad2deg = 180.0 / Double.pi

    // MARK: - Earth Physical Constants (WGS-84)

    /// Earth equatorial radius (km) - WGS-84
    static let earthRadius = 6378.137

    /// Earth flattening factor (WGS-84)
    static let earthFlattening = 1.0 / 298.257223563

    /// Earth gravitational parameter μ (km³/s²) - WGS-84
    static let mu = 398600.8

    // MARK: - Gravitational Harmonic Coefficients

    /// J2 perturbation coefficient (second harmonic)
    /// Accounts for Earth's oblateness
    static let j2 = 0.00108262998905

    /// J3 perturbation coefficient (third harmonic)
    /// Accounts for pear shape of Earth
    static let j3 = -0.00000253215306

    /// J4 perturbation coefficient (fourth harmonic)
    static let j4 = -0.00000161098761

    // MARK: - Time Constants

    /// Minutes per day
    static let minutesPerDay = 1440.0

    /// Seconds per day
    static let secondsPerDay = 86400.0

    /// Days per Julian century
    static let daysPerCentury = 36525.0

    // MARK: - SGP4 Specific Constants

    /// Threshold for deep-space vs near-earth propagation (minutes)
    /// Orbital period > 225 minutes uses SDP4 (deep space)
    /// Orbital period < 225 minutes uses SGP4 (near earth)
    static let deepSpaceThreshold = 225.0

    /// Alternative deep space threshold based on mean motion
    /// 2π / 225 ≈ 0.0279... rad/min
    static let deepSpaceThresholdMeanMotion = twoPi / deepSpaceThreshold

    /// XKE: sqrt(3600.0 * mu / (earthRadius^3))
    /// Used to recover original mean motion (rad/min) from TLE mean motion (rev/day)
    /// 3600 converts from per-second to per-minute
    static let xke = 60.0 / sqrt(earthRadius * earthRadius * earthRadius / mu)

    /// QOMS2T: ((earthRadius + 120) / earthRadius)^4
    /// S parameter for atmospheric drag (120 km altitude)
    static let qoms2t = pow((earthRadius + 120.0) / earthRadius, 4.0)

    /// S parameter: earthRadius + S0
    /// S0 is the atmospheric model parameter (typically 78 km for low perigee)
    static let s0 = 78.0

    // MARK: - Convergence and Precision

    /// Maximum iterations for Kepler equation solver
    static let maxKeplerIterations = 10

    /// Convergence threshold for Kepler equation (radians)
    static let keplerTolerance = 1.0e-12

    /// Minimum allowable eccentricity
    static let minEccentricity = 0.0

    /// Maximum allowable eccentricity (must be < 1.0)
    static let maxEccentricity = 0.999

    /// Minimum perigee altitude for non-decayed orbit (km)
    /// Below ~90-100 km, atmospheric drag causes rapid decay
    static let minPerigeeAltitude = 90.0

    // MARK: - Speed of Light (for future relativistic corrections)

    /// Speed of light (km/s)
    static let speedOfLight = 299792.458

    // MARK: - Astronomical Unit (for solar perturbations in SDP4)

    /// Astronomical Unit (km)
    static let astronomicalUnit = 149597870.7
}
