import Foundation

/// Protocol for satellite orbit propagators
/// Defines the interface for both SGP4 (near-Earth) and SDP4 (deep-space) propagators
public protocol Propagator {
  /// Propagates the satellite state to a specific time
  /// - Parameter minutesSinceEpoch: Time in minutes since the TLE epoch
  /// - Returns: The satellite state at the specified time
  /// - Throws: PropagationError if propagation fails
  func propagate(minutesSinceEpoch: Double) throws -> SatelliteState

  /// The Two-Line Element set used for initialization
  var tle: TLE { get }

  /// Whether this is a deep-space propagator (orbital period >= 225 minutes)
  var isDeepSpace: Bool { get }
}

/// Factory for creating the appropriate propagator based on orbital characteristics
public enum PropagatorFactory {
  /// Creates the appropriate propagator (SGP4 or SDP4) based on the satellite's orbital period
  /// - Parameter tle: The Two-Line Element set
  /// - Returns: A propagator instance (SGP4Propagator for near-Earth, SDP4Propagator for deep-space)
  /// - Throws: PropagationError if initialization fails
  public static func create(tle: TLE) throws -> Propagator {
    // Convert mean motion from revolutions/day to radians/minute
    let n0 = tle.meanMotion * (2.0 * .pi / 1440.0)  // rad/min

    // Calculate orbital period in minutes
    let period = (2.0 * .pi) / n0

    // Select propagator based on orbital period
    // Period >= 225 minutes indicates deep-space orbit requiring SDP4
    if period >= 225.0 {
      return try SDP4Propagator(tle: tle)
    } else {
      return try SGP4Propagator(tle: tle)
    }
  }
}
