//
//  SatelliteState.swift
//  SwiftSGP4
//
//  Copyright © 2024 SwiftSGP4. All rights reserved.
//

import Foundation

/// Represents a satellite's state at a specific time
public struct SatelliteState {
  /// Position vector in TEME frame (km)
  public let position: Vector3D

  /// Velocity vector in TEME frame (km/s)
  public let velocity: Vector3D

  /// Time of the state (minutes since epoch)
  public let minutesSinceEpoch: Double

  public init(position: Vector3D, velocity: Vector3D, minutesSinceEpoch: Double) {
    self.position = position
    self.velocity = velocity
    self.minutesSinceEpoch = minutesSinceEpoch
  }
}
