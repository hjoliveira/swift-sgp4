//
//  SGP4Propagator.swift
//  SwiftSGP4
//
//  Created by Henrique Oliveira on 12/6/15.
//  Copyright © 2015 Henrique Oliveira. All rights reserved.
//

import Foundation

/// SGP4/SDP4 orbit propagator
/// Implements the Simplified General Perturbations 4 algorithm
public class SGP4Propagator {
    private let tle: TLE

    /// Initialize propagator with a TLE
    public init(tle: TLE) {
        self.tle = tle
    }

    /// Propagate the satellite to a specific time
    /// - Parameter minutesSinceEpoch: Time in minutes since TLE epoch
    /// - Returns: Satellite state (position and velocity in TEME frame)
    /// - Throws: PropagationError if propagation fails
    public func propagate(minutesSinceEpoch: Double) throws -> SatelliteState {
        // TODO: Implement SGP4 algorithm
        // This is a stub implementation that will be replaced
        throw PropagationError.notImplemented("SGP4 propagation not yet implemented")
    }
}

/// Errors that can occur during propagation
public enum PropagationError: Error {
    case notImplemented(String)
    case decayed(String)
    case invalidEccentricity(String)
    case invalidMeanMotion(String)
}
