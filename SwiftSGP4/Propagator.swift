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
    // The model classifies the orbit during initialization, using the
    // recovered (un-Kozai'd) mean motion exactly as the reference does.
    // A period of 225 minutes or more requires deep-space handling.
    let model = try SGP4Model(tle: tle)

    if model.isDeepSpace {
      return SDP4Propagator(model: model)
    } else {
      return SGP4Propagator(model: model)
    }
  }
}
