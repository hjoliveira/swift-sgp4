import Foundation

/// SDP4 orbit propagator (deep-space satellites).
///
/// Implements the Simplified Deep Space Perturbations 4 algorithm, including
/// the lunar-solar periodic terms (dscom, dpper) and the 12- and 24-hour
/// resonance integration (dsinit, dspace).
/// Reference: Vallado et al. "Revisiting Spacetrack Report #3" (AIAA 2006-6753)
///
/// Used for satellites with orbital periods >= 225 minutes, including:
/// - Geostationary satellites (24-hour period)
/// - GPS satellites (12-hour period)
/// - Molniya orbits (12-hour highly elliptical)
/// - Other high-altitude orbits
///
/// The algorithm itself lives in `SGP4Model`, which is shared with
/// `SGP4Propagator`; the reference implementation is a single routine with a
/// near-Earth/deep-space branch, and keeping it that way here means the two
/// paths cannot drift apart.
public class SDP4Propagator: Propagator {
  private let model: SGP4Model

  public var tle: TLE { model.tle }

  /// Whether this satellite is handled by the deep-space branch.
  public var isDeepSpace: Bool { model.isDeepSpace }

  /// Initialize the propagator with a TLE.
  public init(tle: TLE) throws {
    self.model = try SGP4Model(tle: tle)
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
