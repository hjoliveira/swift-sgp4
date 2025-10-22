//
//  SGP4Propagator.swift
//  SwiftSGP4
//
//  Created by Henrique Oliveira on 12/6/15.
//  Copyright © 2015 Henrique Oliveira. All rights reserved.
//
//  SGP4 implementation based on:
//  Vallado, D. A., Crawford, P., Hujsak, R., & Kelso, T. S. (2006).
//  "Revisiting Spacetrack Report #3" (AIAA 2006-6753)
//

import Foundation

/// SGP4/SDP4 orbit propagator
/// Implements the Simplified General Perturbations 4 algorithm
public class SGP4Propagator {
    private let tle: TLE
    private let state: SGP4State

    /// Initialize propagator with a TLE
    public init(tle: TLE) throws {
        self.tle = tle
        self.state = try SGP4State(from: tle)

        // Check for deep space - not yet implemented
        if state.isDeepSpace {
            throw PropagationError.notImplemented(
                "Deep-space (SDP4) propagation not yet implemented. Orbital period is \(SGP4Constants.twoPi / state.meanMotion) minutes (>= 225 minutes threshold)."
            )
        }
    }

    /// Propagate the satellite to a specific time
    /// - Parameter minutesSinceEpoch: Time in minutes since TLE epoch
    /// - Returns: Satellite state (position and velocity in TEME frame)
    /// - Throws: PropagationError if propagation fails
    public func propagate(minutesSinceEpoch: Double) throws -> SatelliteState {
        let tsince = minutesSinceEpoch

        // STEP 1: Update for secular gravity and atmospheric drag effects
        let (xmdf, omgadf, _, _, _, _, xnode, tempa, tempe, templ) =
            updateSecularEffects(tsince: tsince)

        // STEP 2: Long period periodic terms
        let (axn, ayn, aynl, xl) = calculateLongPeriodTerms(
            xmdf: xmdf,
            omgadf: omgadf,
            tempa: tempa,
            tempe: tempe,
            templ: templ
        )

        // STEP 3: Solve Kepler's equation
        let (u, epw) = try solveKeplerEquation(axn: axn, ayn: ayn, aynl: aynl, xl: xl)

        // STEP 4: Short period preliminary quantities
        let (ecosE, esinE, el2, pl, r) = try calculateShortPeriodPrelims(
            axn: axn,
            ayn: ayn,
            epw: epw
        )

        // STEP 5: Orientation vectors
        let (rdotk, rfdotk, rk, uk, _, xinck, xnodek) = calculateOrientationVectors(
            u: u,
            axn: axn,
            ayn: ayn,
            ecosE: ecosE,
            esinE: esinE,
            el2: el2,
            epw: epw,
            pl: pl,
            r: r,
            xnode: xnode,
            tsince: tsince
        )

        // STEP 6: Position and velocity in TEME frame
        let (position, velocity) = calculatePositionVelocity(
            rk: rk,
            uk: uk,
            xnodek: xnodek,
            xinck: xinck,
            rdotk: rdotk,
            rfdotk: rfdotk
        )

        return SatelliteState(
            position: position,
            velocity: velocity,
            minutesSinceEpoch: minutesSinceEpoch
        )
    }

    // MARK: - Private Implementation Methods

    /// Update for secular gravity and atmospheric drag effects
    private func updateSecularEffects(tsince: Double) -> (
        xmdf: Double, omgadf: Double, xnoddf: Double, omega: Double,
        xmp: Double, tsq: Double, xnode: Double, tempa: Double,
        tempe: Double, templ: Double
    ) {
        // Update for secular gravity and atmospheric drag
        let xmdf = state.meanAnomaly + state.meanMotion * tsince
        let omgadf = state.argumentOfPerigee + state.dotArgumentOfPerigee * tsince
        let xnoddf = state.rightAscension + state.dotRightAscension * tsince

        let omega = omgadf
        let xmp = xmdf
        let tsq = tsince * tsince
        let xnode = xnoddf

        // Update for drag
        let tempa = 1.0 - state.c1 * tsince
        let tempe = state.bstar * state.c4 * tsince
        let templ = state.d2 * tsq

        return (xmdf, omgadf, xnoddf, omega, xmp, tsq, xnode, tempa, tempe, templ)
    }

    /// Calculate long period periodic terms
    private func calculateLongPeriodTerms(
        xmdf: Double,
        omgadf: Double,
        tempa: Double,
        tempe: Double,
        templ: Double
    ) -> (axn: Double, ayn: Double, aynl: Double, xl: Double) {
        let a = pow(SGP4Constants.xke / state.originalMeanMotion, 2.0/3.0) * tempa * tempa
        let e = state.eccentricity - tempe
        let xl = xmdf + omgadf + state.dotRightAscension * templ

        // Lyddane modifications
        let axnl = e * cos(omgadf)
        let aynl = e * sin(omgadf) - state.aycof / (a * state.eta)

        return (axnl, aynl, aynl, xl)
    }

    /// Solve Kepler's equation for eccentric anomaly
    private func solveKeplerEquation(
        axn: Double,
        ayn: Double,
        aynl: Double,
        xl: Double
    ) throws -> (u: Double, epw: Double) {
        let u = fmod2p(xl - state.rightAscension)
        var eo1 = u
        var tem5: Double = 9999.9
        var ktr = 1

        // Newton-Raphson iteration for Kepler's equation
        while abs(tem5) >= SGP4Constants.keplerTolerance && ktr <= SGP4Constants.maxKeplerIterations {
            let sineo1 = sin(eo1)
            let coseo1 = cos(eo1)
            tem5 = 1.0 - coseo1 * axn - sineo1 * ayn

            tem5 = (u - aynl * coseo1 + axn * sineo1 - eo1) / tem5

            if abs(tem5) >= 0.95 {
                tem5 = tem5 > 0.0 ? 0.95 : -0.95
            }

            eo1 = eo1 + tem5
            ktr += 1
        }

        return (u, eo1)
    }

    /// Calculate short period preliminary quantities
    private func calculateShortPeriodPrelims(
        axn: Double,
        ayn: Double,
        epw: Double
    ) throws -> (ecosE: Double, esinE: Double, el2: Double, pl: Double, r: Double) {
        let ecosE = axn * cos(epw) + ayn * sin(epw)
        let esinE = axn * sin(epw) - ayn * cos(epw)
        let el2 = axn * axn + ayn * ayn
        let pl = state.semiMajorAxis * (1.0 - el2)

        // Check for negative pl
        guard pl >= 0 else {
            throw PropagationError.invalidEccentricity("Semi-latus rectum is negative")
        }

        let r = state.semiMajorAxis * (1.0 - ecosE)

        return (ecosE, esinE, el2, pl, r)
    }

    /// Calculate orientation vectors
    private func calculateOrientationVectors(
        u: Double,
        axn: Double,
        ayn: Double,
        ecosE: Double,
        esinE: Double,
        el2: Double,
        epw: Double,
        pl: Double,
        r: Double,
        xnode: Double,
        tsince: Double
    ) -> (rdotk: Double, rfdotk: Double, rk: Double, uk: Double,
          xn: Double, xinck: Double, xnodek: Double) {
        var rdot = SGP4Constants.xke * sqrt(state.semiMajorAxis) * esinE / r
        var rfdot = SGP4Constants.xke * sqrt(pl) / r

        let temp = ecosE / (1.0 + sqrt(1.0 - el2))

        let cosu = state.semiMajorAxis / r * (cos(epw) - axn + ayn * esinE * temp)
        let sinu = state.semiMajorAxis / r * (sin(epw) - ayn - axn * esinE * temp)
        let u_new = atan2(sinu, cosu)

        let sin2u = (cosu + cosu) * sinu
        let cos2u = 1.0 - 2.0 * sinu * sinu

        // Short period perturbations
        let rk = r * (1.0 - 1.5 * state.temp2 * state.beta * state.c3 * cos(2.0 * state.argumentOfPerigee)) +
                 0.5 * state.temp1 * (1.0 - state.cosInclination * state.cosInclination) * cos2u

        let uk = u_new - 0.25 * state.temp2 * (7.0 * state.cosInclination * state.cosInclination - 1.0) * sin2u

        let xnodek = xnode + 1.5 * state.temp2 * state.cosInclination * sin2u

        let xinck = state.inclination + 1.5 * state.temp2 * state.cosInclination * state.sinInclination * cos2u

        rdot = rdot - state.originalMeanMotion * state.temp1 * (1.0 - state.cosInclination * state.cosInclination) * sin2u

        rfdot = rfdot + state.originalMeanMotion * state.temp1 *
                ((1.0 - state.cosInclination * state.cosInclination) * cos2u +
                 1.5 * state.cosInclination * state.cosInclination)

        let xn = SGP4Constants.xke / pow(state.semiMajorAxis, 1.5)

        return (rdot, rfdot, rk, uk, xn, xinck, xnodek)
    }

    /// Calculate position and velocity in TEME coordinate frame
    private func calculatePositionVelocity(
        rk: Double,
        uk: Double,
        xnodek: Double,
        xinck: Double,
        rdotk: Double,
        rfdotk: Double
    ) -> (position: Vector3D, velocity: Vector3D) {
        // Unit orientation vectors
        let sinuk = sin(uk)
        let cosuk = cos(uk)
        let sinik = sin(xinck)
        let cosik = cos(xinck)
        let sinnok = sin(xnodek)
        let cosnok = cos(xnodek)
        let xmx = -sinnok * cosik
        let xmy = cosnok * cosik
        let ux = xmx * sinuk + cosnok * cosuk
        let uy = xmy * sinuk + sinnok * cosuk
        let uz = sinik * sinuk
        let vx = xmx * cosuk - cosnok * sinuk
        let vy = xmy * cosuk - sinnok * sinuk
        let vz = sinik * cosuk

        // Position and velocity in km and km/s
        let x = rk * ux * SGP4Constants.earthRadius
        let y = rk * uy * SGP4Constants.earthRadius
        let z = rk * uz * SGP4Constants.earthRadius

        let xdot = (rdotk * ux + rfdotk * vx) * SGP4Constants.earthRadius / 60.0
        let ydot = (rdotk * uy + rfdotk * vy) * SGP4Constants.earthRadius / 60.0
        let zdot = (rdotk * uz + rfdotk * vz) * SGP4Constants.earthRadius / 60.0

        let position = Vector3D(x: x, y: y, z: z)
        let velocity = Vector3D(x: xdot, y: ydot, z: zdot)

        return (position, velocity)
    }

    // MARK: - Helper Methods

    /// Normalize angle to range [0, 2π]
    private func fmod2p(_ x: Double) -> Double {
        var result = x.truncatingRemainder(dividingBy: SGP4Constants.twoPi)
        if result < 0.0 {
            result += SGP4Constants.twoPi
        }
        return result
    }
}

/// Errors that can occur during propagation
public enum PropagationError: Error {
    case notImplemented(String)
    case decayed(String)
    case invalidEccentricity(String)
    case invalidMeanMotion(String)
}
