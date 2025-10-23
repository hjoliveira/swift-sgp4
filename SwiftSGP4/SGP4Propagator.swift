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
        let (_, omgadf, _, _, xmp, _, xnode, tempa, tempe, templ) =
            updateSecularEffects(tsince: tsince)

        // STEP 2: Long period periodic terms
        let (am, axnl, aynl, xl, nm, _) = calculateLongPeriodTerms(
            xmp: xmp,
            omgadf: omgadf,
            xnode: xnode,
            tempa: tempa,
            tempe: tempe,
            templ: templ
        )

        // STEP 3: Solve Kepler's equation
        let (u, epw) = try solveKeplerEquation(axnl: axnl, aynl: aynl, xl: xl, xnode: xnode)

        // STEP 4: Short period preliminary quantities
        let (ecosE, esinE, el2, pl, r) = try calculateShortPeriodPrelims(
            am: am,
            axnl: axnl,
            aynl: aynl,
            epw: epw
        )

        // STEP 5: Orientation vectors
        let (rdotk, rfdotk, rk, uk, xinck, xnodek) = calculateOrientationVectors(
            u: u,
            am: am,
            axnl: axnl,
            aynl: aynl,
            ecosE: ecosE,
            esinE: esinE,
            el2: el2,
            epw: epw,
            pl: pl,
            r: r,
            xnode: xnode,
            nm: nm
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
        let xmdf = state.meanAnomaly + state.dotMeanMotion * tsince
        let omgadf = state.argumentOfPerigee + state.dotArgumentOfPerigee * tsince
        let xnoddf = state.rightAscension + state.dotRightAscension * tsince

        var omega = omgadf
        var xmp = xmdf
        let tsq = tsince * tsince
        let xnode = xnoddf + state.nodecf * tsq

        // Update for drag
        var tempa = 1.0 - state.c1 * tsince
        var tempe = state.bstar * state.c4 * tsince
        var templ = state.t2cof * tsq

        // Non-simple mode: additional secular corrections
        if !state.isSimpleMode {
            let delomg = state.omgcof * tsince
            let delmtemp = 1.0 + state.eta * cos(xmdf)
            let delm = state.xmcof * (delmtemp * delmtemp * delmtemp - state.delmo)
            let temp = delomg + delm
            xmp = xmdf + temp
            omega = omgadf - temp
            let t3 = tsq * tsince
            let t4 = t3 * tsince
            tempa = tempa - state.d2 * tsq - state.d3 * t3 - state.d4 * t4
            tempe = tempe + state.bstar * state.c5 * (sin(xmp) - state.sinmao)
            templ = templ + state.t3cof * t3 + t4 * (state.t4cof + tsince * state.t5cof)
        }

        return (xmdf, omega, xnoddf, omega, xmp, tsq, xnode, tempa, tempe, templ)
    }

    /// Calculate long period periodic terms
    private func calculateLongPeriodTerms(
        xmp: Double,
        omgadf: Double,
        xnode: Double,
        tempa: Double,
        tempe: Double,
        templ: Double
    ) -> (am: Double, axnl: Double, aynl: Double, xl: Double, nm: Double, em: Double) {
        // Update mean motion and semi-major axis for drag
        var nm = state.originalMeanMotion
        let am = pow(SGP4Constants.xke / nm, 2.0/3.0) * tempa * tempa
        nm = SGP4Constants.xke / pow(am, 1.5)

        // Update eccentricity
        var em = state.eccentricity - tempe

        // Clamp eccentricity to valid range
        if em < 1.0e-6 {
            em = 1.0e-6
        }

        // Update mean anomaly with templ correction
        let mm = xmp + state.originalMeanMotion * templ
        _ = mm + omgadf + xnode  // xlm calculated but not used

        // Lyddane modifications for long-period perturbations
        let axnl = em * cos(omgadf)
        let temp = 1.0 / (am * (1.0 - em * em))
        let aynl = em * sin(omgadf) + temp * state.aycof
        let xl = mm + omgadf + xnode + temp * state.xlcof * axnl

        return (am, axnl, aynl, xl, nm, em)
    }

    /// Solve Kepler's equation for eccentric anomaly
    private func solveKeplerEquation(
        axnl: Double,
        aynl: Double,
        xl: Double,
        xnode: Double
    ) throws -> (u: Double, epw: Double) {
        let u = fmod2p(xl - xnode)
        var eo1 = u
        var tem5: Double = 9999.9
        var ktr = 1

        // Newton-Raphson iteration for Kepler's equation
        // Kepler equation (Vallado form): u = eo1 + aynl * cos(eo1) - axnl * sin(eo1)
        while abs(tem5) >= 1.0e-12 && ktr <= 10 {
            let sineo1 = sin(eo1)
            let coseo1 = cos(eo1)

            // This is the denominator for Newton-Raphson
            tem5 = 1.0 - coseo1 * axnl - sineo1 * aynl

            // This is the update step
            tem5 = (u - aynl * coseo1 + axnl * sineo1 - eo1) / tem5

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
        am: Double,
        axnl: Double,
        aynl: Double,
        epw: Double
    ) throws -> (ecosE: Double, esinE: Double, el2: Double, pl: Double, r: Double) {
        let ecosE = axnl * cos(epw) + aynl * sin(epw)
        let esinE = axnl * sin(epw) - aynl * cos(epw)
        let el2 = axnl * axnl + aynl * aynl
        let pl = am * (1.0 - el2)

        // Check for negative pl
        guard pl >= 0 else {
            throw PropagationError.invalidEccentricity("Semi-latus rectum is negative")
        }

        let r = am * (1.0 - ecosE)

        return (ecosE, esinE, el2, pl, r)
    }

    /// Calculate orientation vectors
    private func calculateOrientationVectors(
        u: Double,
        am: Double,
        axnl: Double,
        aynl: Double,
        ecosE: Double,
        esinE: Double,
        el2: Double,
        epw: Double,
        pl: Double,
        r: Double,
        xnode: Double,
        nm: Double
    ) -> (rdotk: Double, rfdotk: Double, rk: Double, uk: Double,
          xinck: Double, xnodek: Double) {
        // Calculate rdot and rfdot
        let rdotl = sqrt(am) * esinE / r
        let rvdotl = sqrt(pl) / r
        let betal = sqrt(1.0 - el2)
        let temp = esinE / (1.0 + betal)

        // Calculate true anomaly components
        let sineo1 = sin(epw)
        let coseo1 = cos(epw)


        // Use the ORIGINAL Vallado formula exactly as in the C++ reference
        // Even though there's numerical cancellation, this is the correct formula
        let sinu = am / r * (sineo1 - aynl - axnl * temp)
        let cosu = am / r * (coseo1 - axnl + aynl * temp)
        let su = atan2(sinu, cosu)

        let sin2u = (cosu + cosu) * sinu
        let cos2u = 1.0 - 2.0 * sinu * sinu

        // Calculate temp1 and temp2 based on current pl (not pre-computed values!)
        let tempVar = 1.0 / pl
        let temp1 = 0.5 * SGP4Constants.j2 * tempVar
        let temp2 = temp1 * tempVar

        // Short period perturbations
        let rk = r * (1.0 - 1.5 * temp2 * betal * state.con41) +
                 0.5 * temp1 * state.x1mth2 * cos2u

        let uk = su - 0.25 * temp2 * state.x7thm1 * sin2u

        let xnodek = xnode + 1.5 * temp2 * state.cosInclination * sin2u

        let xinck = state.inclination + 1.5 * temp2 * state.cosInclination * state.sinInclination * cos2u

        // Update velocities
        let mvt = rdotl - nm * temp1 * state.x1mth2 * sin2u / SGP4Constants.xke
        let rvdot = rvdotl + nm * temp1 * (state.x1mth2 * cos2u + 1.5 * state.con41) / SGP4Constants.xke

        return (mvt, rvdot, rk, uk, xinck, xnodek)
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

        let vkmpersec = SGP4Constants.earthRadius * SGP4Constants.xke / 60.0
        let xdot = (rdotk * ux + rfdotk * vx) * vkmpersec
        let ydot = (rdotk * uy + rfdotk * vy) * vkmpersec
        let zdot = (rdotk * uz + rfdotk * vz) * vkmpersec

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
