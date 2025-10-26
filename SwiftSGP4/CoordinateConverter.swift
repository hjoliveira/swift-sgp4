//
//  CoordinateConverter.swift
//  SwiftSGP4
//
//  Copyright © 2024 SwiftSGP4. All rights reserved.
//

import Foundation

/// Coordinate system conversion utilities
/// Supports conversions between TEME, ECEF, and Geodetic coordinate systems
public class CoordinateConverter {

    // MARK: - TEME <-> ECEF Conversions

    /// Convert TEME (True Equator Mean Equinox) to ECEF (Earth-Centered Earth-Fixed)
    /// - Parameters:
    ///   - position: Position vector in TEME frame (km)
    ///   - velocity: Velocity vector in TEME frame (km/s)
    ///   - date: Date for the conversion
    /// - Returns: Tuple of (position, velocity) in ECEF frame
    public static func temeToECEF(position: Vector3D, velocity: Vector3D, date: Date) -> (Vector3D, Vector3D) {
        // Calculate Greenwich Mean Sidereal Time (GMST)
        let gmst = calculateGMST(date: date)

        // Rotate position and velocity by -GMST around Z-axis
        // ECEF rotates with Earth, TEME is inertial
        let cosGMST = cos(gmst)
        let sinGMST = sin(gmst)

        // Rotation matrix R_z(-GMST)
        // [  cos(gmst)  sin(gmst)  0 ]
        // [ -sin(gmst)  cos(gmst)  0 ]
        // [     0          0       1 ]

        let ecefPosition = Vector3D(
            x: cosGMST * position.x + sinGMST * position.y,
            y: -sinGMST * position.x + cosGMST * position.y,
            z: position.z
        )

        // Velocity transformation includes Earth's rotation rate
        // ω_Earth = 7.2921159e-5 rad/s
        let omegaEarth = 7.2921159e-5  // rad/s

        // v_ECEF = R_z(-GMST) * (v_TEME - ω × r_TEME)
        // ω × r = [0, 0, ω_Earth] × [x, y, z] = [-ω*y, ω*x, 0]
        let omega_cross_r = Vector3D(
            x: -omegaEarth * position.y,
            y: omegaEarth * position.x,
            z: 0.0
        )

        let vel_relative = Vector3D(
            x: velocity.x - omega_cross_r.x,
            y: velocity.y - omega_cross_r.y,
            z: velocity.z - omega_cross_r.z
        )

        let ecefVelocity = Vector3D(
            x: cosGMST * vel_relative.x + sinGMST * vel_relative.y,
            y: -sinGMST * vel_relative.x + cosGMST * vel_relative.y,
            z: vel_relative.z
        )

        return (ecefPosition, ecefVelocity)
    }

    /// Convert ECEF (Earth-Centered Earth-Fixed) to TEME (True Equator Mean Equinox)
    /// - Parameters:
    ///   - position: Position vector in ECEF frame (km)
    ///   - velocity: Velocity vector in ECEF frame (km/s)
    ///   - date: Date for the conversion
    /// - Returns: Tuple of (position, velocity) in TEME frame
    public static func ecefToTEME(position: Vector3D, velocity: Vector3D, date: Date) -> (Vector3D, Vector3D) {
        // Calculate Greenwich Mean Sidereal Time (GMST)
        let gmst = calculateGMST(date: date)

        // Rotate position and velocity by +GMST around Z-axis (inverse of TEME to ECEF)
        let cosGMST = cos(gmst)
        let sinGMST = sin(gmst)

        // Rotation matrix R_z(+GMST)
        // [ cos(gmst)  -sin(gmst)  0 ]
        // [ sin(gmst)   cos(gmst)  0 ]
        // [    0           0       1 ]

        let temePosition = Vector3D(
            x: cosGMST * position.x - sinGMST * position.y,
            y: sinGMST * position.x + cosGMST * position.y,
            z: position.z
        )

        // Velocity transformation (inverse operation)
        let omegaEarth = 7.2921159e-5  // rad/s

        let vel_rotated = Vector3D(
            x: cosGMST * velocity.x - sinGMST * velocity.y,
            y: sinGMST * velocity.x + cosGMST * velocity.y,
            z: velocity.z
        )

        // Add back Earth's rotation: v_TEME = v_rotated + ω × r_TEME
        let omega_cross_r = Vector3D(
            x: -omegaEarth * temePosition.y,
            y: omegaEarth * temePosition.x,
            z: 0.0
        )

        let temeVelocity = Vector3D(
            x: vel_rotated.x + omega_cross_r.x,
            y: vel_rotated.y + omega_cross_r.y,
            z: vel_rotated.z + omega_cross_r.z
        )

        return (temePosition, temeVelocity)
    }

    // MARK: - Time Utilities

    /// Calculate Greenwich Mean Sidereal Time (GMST) from a Date
    /// - Parameter date: The date/time for which to calculate GMST
    /// - Returns: GMST in radians
    private static func calculateGMST(date: Date) -> Double {
        // Convert Date to Julian Date
        let jd = dateToJulianDate(date: date)

        // Calculate Julian centuries from J2000.0 (JD 2451545.0)
        let tUT1 = (jd - 2451545.0) / 36525.0

        // GMST at 0h UT (IAU 1982 formula)
        // Result in seconds
        var gmst = 67310.54841 + (876600.0 * 3600.0 + 8640184.812866) * tUT1
        gmst += 0.093104 * tUT1 * tUT1
        gmst -= 6.2e-6 * tUT1 * tUT1 * tUT1

        // Add fraction of day
        let secondsInDay = 86400.0
        let fraction = (jd - floor(jd + 0.5) + 0.5) * secondsInDay
        gmst += fraction * 1.00273790935

        // Convert to radians and normalize to [0, 2π]
        let gmstRadians = (gmst / 240.0) * .pi / 180.0  // Convert from seconds to radians
        return gmstRadians.truncatingRemainder(dividingBy: 2.0 * .pi)
    }

    /// Convert a Date to Julian Date
    /// - Parameter date: The date to convert
    /// - Returns: Julian Date
    private static func dateToJulianDate(date: Date) -> Double {
        // Unix epoch (1970-01-01 00:00:00 UTC) = JD 2440587.5
        let unixEpochJD = 2440587.5
        let secondsPerDay = 86400.0

        let timeIntervalSince1970 = date.timeIntervalSince1970
        let jd = unixEpochJD + (timeIntervalSince1970 / secondsPerDay)

        return jd
    }

    // MARK: - TEME <-> Geodetic Conversions

    /// Convert TEME position to Geodetic coordinates (lat/lon/alt)
    /// - Parameter position: Position vector in TEME frame (km)
    /// - Returns: Geodetic coordinate (latitude, longitude, altitude)
    public static func temeToGeodetic(position: Vector3D) -> GeodeticCoordinate {
        // TEME and ECEF share the same geodetic conversion (difference is time-based rotation)
        // We can treat TEME positions as ECEF for geodetic purposes

        let x = position.x
        let y = position.y
        let z = position.z

        // Calculate longitude (degrees)
        let longitude = atan2(y, x) * 180.0 / .pi

        // Calculate distance from Z-axis
        let p = sqrt(x * x + y * y)

        // Special handling for poles (when p is very small)
        if p < 1e-10 {
            // At the poles
            let latitude = z > 0 ? 90.0 : -90.0
            let altitude = abs(z) - earthRadiusPolar
            return GeodeticCoordinate(latitude: latitude, longitude: longitude, altitude: altitude)
        }

        // Iteratively calculate geodetic latitude
        // Starting approximation
        var lat = atan2(z, p * (1.0 - earthEccentricitySquared))
        var previousLat: Double
        var iterations = 0
        let maxIterations = 10

        repeat {
            previousLat = lat
            let sinLat = sin(lat)

            // Radius of curvature in the prime vertical
            let N = earthRadiusEquatorial / sqrt(1.0 - earthEccentricitySquared * sinLat * sinLat)

            // Calculate altitude
            let altitude = p / cos(lat) - N

            // Update latitude estimate
            lat = atan2(z, p * (1.0 - earthEccentricitySquared * N / (N + altitude)))

            iterations += 1
        } while abs(lat - previousLat) > 1e-12 && iterations < maxIterations

        let latitude = lat * 180.0 / .pi

        // Final altitude calculation
        let sinLat = sin(lat)
        let N = earthRadiusEquatorial / sqrt(1.0 - earthEccentricitySquared * sinLat * sinLat)
        let altitude = p / cos(lat) - N

        return GeodeticCoordinate(latitude: latitude, longitude: longitude, altitude: altitude)
    }

    /// Convert Geodetic coordinates to TEME position
    /// - Parameters:
    ///   - coordinate: Geodetic coordinate (latitude, longitude, altitude)
    ///   - date: Date for the conversion
    /// - Returns: Position vector in TEME frame (km)
    public static func geodeticToTEME(coordinate: GeodeticCoordinate, date: Date) -> Vector3D {
        // Convert lat/lon from degrees to radians
        let latRad = coordinate.latitude * .pi / 180.0
        let lonRad = coordinate.longitude * .pi / 180.0

        let sinLat = sin(latRad)
        let cosLat = cos(latRad)
        let sinLon = sin(lonRad)
        let cosLon = cos(lonRad)

        // Radius of curvature in the prime vertical (N)
        let N = earthRadiusEquatorial / sqrt(1.0 - earthEccentricitySquared * sinLat * sinLat)

        // Calculate ECEF/TEME coordinates
        let x = (N + coordinate.altitude) * cosLat * cosLon
        let y = (N + coordinate.altitude) * cosLat * sinLon
        let z = (N * (1.0 - earthEccentricitySquared) + coordinate.altitude) * sinLat

        return Vector3D(x: x, y: y, z: z)
    }

    // MARK: - Earth Constants (WGS84)

    /// WGS84 Earth equatorial radius (km)
    public static let earthRadiusEquatorial = 6378.137

    /// WGS84 Earth polar radius (km)
    public static let earthRadiusPolar = 6356.752

    /// WGS84 Earth flattening
    public static let earthFlattening = 1.0 / 298.257223563

    /// WGS84 Earth eccentricity squared
    public static let earthEccentricitySquared = 2.0 * earthFlattening - earthFlattening * earthFlattening
}
