import Foundation

/// SGP4 orbit propagator (near-Earth satellites).
///
/// Implements the Simplified General Perturbations 4 algorithm.
/// Reference: Vallado et al. "Revisiting Spacetrack Report #3" (AIAA 2006-6753)
///
/// The algorithm itself lives in `SGP4Model`, which is shared with
/// `SDP4Propagator`; this type is the near-Earth entry point and rejects
/// orbits that require deep-space handling.
public class SGP4Propagator: Propagator {
  private let model: SGP4Model

  public var tle: TLE { model.tle }

  /// SGP4 is for near-Earth satellites only.
  public var isDeepSpace: Bool { false }

  /// Initialize the propagator with a TLE.
  /// - Throws: `PropagationError.deepSpaceNotImplemented` when the orbital
  ///   period is 225 minutes or more; use `PropagatorFactory.create(tle:)` to
  ///   select the correct propagator automatically.
  public init(tle: TLE) throws {
    let model = try SGP4Model(tle: tle)
    guard !model.isDeepSpace else {
      throw PropagationError.deepSpaceNotImplemented
    }
    self.model = model
  }

  init(model: SGP4Model) {
    self.model = model
  }

  /// Propagate the satellite to a specific time.
  /// - Parameter minutesSinceEpoch: Time in minutes since the TLE epoch.
  /// - Returns: Satellite state (position and velocity in the TEME frame).
  /// - Throws: `PropagationError` if propagation fails.
  public func propagate(minutesSinceEpoch: Double) throws -> SatelliteState {
    return try model.propagate(minutesSinceEpoch: minutesSinceEpoch)
  }
}

/// Errors that can occur during propagation
public enum PropagationError: Error {
  case orbitDecayed
  case deepSpaceNotImplemented
  case invalidEccentricity
  case keplerConvergenceFailed

  public var localizedDescription: String {
    switch self {
    case .orbitDecayed:
      return "Satellite orbit has decayed"
    case .deepSpaceNotImplemented:
      return
        "This satellite requires deep-space propagation (SDP4). Use PropagatorFactory.create() to automatically select the appropriate propagator."
    case .invalidEccentricity:
      return "Eccentricity out of valid range (0 <= e < 1)"
    case .keplerConvergenceFailed:
      return "Kepler equation failed to converge"
    }
  }
}
