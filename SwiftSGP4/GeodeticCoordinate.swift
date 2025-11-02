//
//  GeodeticCoordinate.swift
//  SwiftSGP4
//
//  Copyright © 2024 SwiftSGP4. All rights reserved.
//

import Foundation

/// Geodetic coordinate (latitude, longitude, altitude)
public struct GeodeticCoordinate {
  /// Latitude in degrees [-90, 90]
  public let latitude: Double

  /// Longitude in degrees [-180, 180]
  public let longitude: Double

  /// Altitude in kilometers above WGS84 ellipsoid
  public let altitude: Double

  public init(latitude: Double, longitude: Double, altitude: Double) {
    self.latitude = latitude
    self.longitude = longitude
    self.altitude = altitude
  }
}
