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
        // TODO: Implement TEME to ECEF conversion
        // This requires computing Earth rotation angle and precession/nutation
        return (position, velocity)
    }

    /// Convert ECEF (Earth-Centered Earth-Fixed) to TEME (True Equator Mean Equinox)
    /// - Parameters:
    ///   - position: Position vector in ECEF frame (km)
    ///   - velocity: Velocity vector in ECEF frame (km/s)
    ///   - date: Date for the conversion
    /// - Returns: Tuple of (position, velocity) in TEME frame
    public static func ecefToTEME(position: Vector3D, velocity: Vector3D, date: Date) -> (Vector3D, Vector3D) {
        // TODO: Implement ECEF to TEME conversion
        return (position, velocity)
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
