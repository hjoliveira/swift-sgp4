import Foundation

/// SGP4 orbit propagator (near-Earth satellites)
/// Implements the Simplified General Perturbations 4 algorithm
/// Reference: Vallado et al. "Revisiting Spacetrack Report #3" (AIAA 2006-6753)
public class SGP4Propagator: Propagator {
    public let tle: TLE

    // MARK: - WGS-72 Constants (NOT WGS-84!)
    // SGP4 uses WGS-72 Earth model for compatibility with historical data
    private let earthRadius: Double = 6378.135  // km (WGS-72)
    private let j2: Double = 0.001082616        // J2 harmonic (WGS-72)
    private let j3: Double = -0.00000253881     // J3 harmonic
    private let j4: Double = -0.00000165597     // J4 harmonic
    private let ke: Double = 0.0743669161       // sqrt(GM) in Earth radii^(3/2) / minute
    private let xke: Double = 0.0743669161      // Reciprocal of time unit
    private let tumin: Double = 13.44683950578  // Time units per minute

    // MARK: - Initialization Variables (computed from TLE)
    private var n0: Double = 0       // Mean motion (rad/min)
    private var e0: Double = 0       // Eccentricity
    private var i0: Double = 0       // Inclination (rad)
    private var omega0: Double = 0   // Argument of perigee (rad)
    private var raan0: Double = 0    // Right ascension of ascending node (rad)
    private var m0: Double = 0       // Mean anomaly (rad)
    private var bstar: Double = 0    // Drag coefficient

    // Derived constants (computed during initialization)
    private var a0: Double = 0       // Semi-major axis
    private var delta1: Double = 0   // Secular drag coefficient
    private var aodp: Double = 0     // Recovered semi-major axis
    private var cosio: Double = 0    // cos(inclination)
    private var sinio: Double = 0    // sin(inclination)
    private var theta2: Double = 0   // cos²(inclination)
    private var theta4: Double = 0   // cos⁴(inclination)
    private var betao2: Double = 0   // (1 - e²)
    private var betao: Double = 0    // sqrt(1 - e²)
    private var xi: Double = 0       // 1 / (aodp - s)
    private var eta: Double = 0      // aodp * e * xi
    private var s4: Double = 0       // Secular terms
    private var c1: Double = 0       // Drag coefficient
    private var c2: Double = 0       // Secular gravity term
    private var c3: Double = 0       // Atmospheric density term
    private var c4: Double = 0       // Long period periodic term
    private var c5: Double = 0       // Short period periodic term
    private var xnodcf: Double = 0   // Node precession factor
    private var t2cof: Double = 0    // Time-squared coefficient
    private var xlcof: Double = 0    // L coefficient
    private var aycof: Double = 0    // Y coefficient
    private var xmdot: Double = 0    // Mean anomaly rate
    private var omgdot: Double = 0   // Argument of perigee rate
    private var xnodot: Double = 0   // Node rate
    private var delmo: Double = 0    // Mean anomaly delta
    private var sinmo: Double = 0    // sin(mean anomaly)
    private var x1mth2: Double = 0   // 1 - theta2
    private var x3thm1: Double = 0   // 3*theta2 - 1
    private var x7thm1: Double = 0   // 7*theta2 - 1
    private var omgcof: Double = 0   // Omega coefficient
    private var xmcof: Double = 0    // Mean anomaly coefficient
    private var n0pp: Double = 0     // Recovered mean motion (after Kozai)
    private var d2: Double = 0       // Drag coefficient 2
    private var d3: Double = 0       // Drag coefficient 3
    private var d4: Double = 0       // Drag coefficient 4
    private var t3cof: Double = 0    // Time^3 coefficient
    private var t4cof: Double = 0    // Time^4 coefficient
    private var t5cof: Double = 0    // Time^5 coefficient

    private var _isDeepSpace: Bool = false
    private var isimp: Int = 0       // Simplified propagation flag

    /// SGP4 is for near-Earth satellites only
    public var isDeepSpace: Bool {
        return false
    }

    /// Initialize propagator with a TLE
    public init(tle: TLE) throws {
        self.tle = tle

        // Convert TLE elements from degrees to radians and revs/day to rad/min
        self.n0 = tle.meanMotion * 2.0 * .pi / 1440.0  // Convert revs/day to rad/min
        self.e0 = tle.eccentricity
        self.i0 = tle.inclination * .pi / 180.0
        self.omega0 = tle.argumentPerigee * .pi / 180.0
        self.raan0 = tle.rightAscendingNode * .pi / 180.0
        self.m0 = tle.meanAnomaly * .pi / 180.0
        self.bstar = tle.bstar

        // Precompute trigonometric values
        cosio = cos(i0)
        sinio = sin(i0)
        theta2 = cosio * cosio
        theta4 = theta2 * theta2
        x1mth2 = 1.0 - theta2
        x3thm1 = 3.0 * theta2 - 1.0
        x7thm1 = 7.0 * theta2 - 1.0

        // Check for deep space (orbital period >= 225 minutes, ~6.4 revs/day)
        let period = 2.0 * .pi / n0  // minutes
        _isDeepSpace = period >= 225.0

        if _isDeepSpace {
            // This propagator only handles near-Earth orbits
            // Use PropagatorFactory.create() to automatically select the correct propagator
            throw PropagationError.deepSpaceNotImplemented
        }

        // Initialize SGP4 near-earth model
        try initializeNearEarth()
    }

    /// Initialize near-earth SGP4 constants
    private func initializeNearEarth() throws {
        // Calculate intermediate values first (needed for initialization)
        betao2 = 1.0 - e0 * e0
        betao = sqrt(betao2)

        // Recover original mean motion (n0pp) and semi-major axis (a0pp)
        let a1 = pow(ke / n0, 2.0 / 3.0)
        let temp = 1.5 * j2 * x3thm1 / (a1 * a1 * betao2)
        let delta1 = temp / (a1 * a1)
        self.delta1 = delta1

        let a0 = a1 * (1.0 - delta1 / 3.0 - delta1 * delta1 - 134.0 * delta1 * delta1 * delta1 / 81.0)
        self.a0 = a0

        let delta0 = temp / (a0 * a0)
        let n0pp = n0 / (1.0 + delta0)
        let a0pp = a0 / (1.0 - delta0)
        self.aodp = a0pp
        self.n0pp = n0pp

        // Check for orbit decay
        let perigee = (a0pp * (1.0 - e0) - 1.0) * earthRadius
        if perigee < 98.0 || a0pp < 0.95 {
            // Orbit has decayed or is invalid
            throw PropagationError.orbitDecayed
        }

        // For perigee less than 220 km, use simple drag model
        let s = earthRadius + 78.0  // 78 km atmospheric boundary
        let qoms24 = pow((120.0 - 78.0) / earthRadius, 4.0)
        let perige = (aodp * (1.0 - e0) - 1.0) * earthRadius

        let pinvsq: Double
        if perige < 156.0 {
            if perige < 98.0 {
                throw PropagationError.orbitDecayed
            }
            let s4temp = perige - 78.0
            s4 = s4temp / earthRadius + 1.0
            pinvsq = 1.0 / (aodp * aodp * betao2 * betao2)
        } else {
            s4 = s / earthRadius
            pinvsq = 1.0 / (aodp * aodp * betao2 * betao2)
        }

        let tsi = 1.0 / (aodp - s4)
        xi = tsi
        eta = aodp * e0 * tsi
        let etasq = eta * eta
        let eeta = e0 * eta

        let psisq = abs(1.0 - etasq)
        let coef = qoms24 * pow(tsi, 4.0)
        let coef1 = coef / pow(psisq, 3.5)

        let c2 = coef1 * n0pp * (aodp * (1.0 + 1.5 * etasq + eeta * (4.0 + etasq)) +
                                  0.75 * j2 * tsi / psisq * x3thm1 * (8.0 + 3.0 * etasq * (8.0 + etasq)))
        self.c2 = c2
        self.c1 = bstar * c2
        self.c3 = e0 > 1e-4 ? coef * tsi * j2 * n0pp * sinio / e0 : 0.0
        self.c4 = 2.0 * n0pp * coef1 * aodp * betao2 *
            (eta * (2.0 + 0.5 * etasq) + e0 * (0.5 + 2.0 * etasq) -
             j2 * tsi / (aodp * psisq) * (-3.0 * x3thm1 * (1.0 - 2.0 * eeta + etasq *
                                                            (1.5 - 0.5 * eeta)) +
                                          0.75 * x1mth2 * (2.0 * etasq - eeta * (1.0 + etasq)) * cos(2.0 * omega0)))
        self.c5 = 2.0 * coef1 * aodp * betao2 * (1.0 + 2.75 * (etasq + eeta) + eeta * etasq)

        // Compute rates (secular effects of atmospheric drag and gravitation)
        let temp1 = 3.0 * j2 * pinvsq * n0pp
        let temp2 = temp1 * j2 * pinvsq
        let temp3 = 1.25 * j4 * pinvsq * pinvsq * n0pp

        xmdot = n0pp + 0.5 * temp1 * betao * x3thm1 + 0.0625 * temp2 * betao *
            (13.0 - 78.0 * theta2 + 137.0 * theta4)

        let x1m5th = 1.0 - 5.0 * theta2
        omgdot = -0.5 * temp1 * x1m5th + 0.0625 * temp2 * (7.0 - 114.0 * theta2 + 395.0 * theta4) +
            temp3 * (3.0 - 36.0 * theta2 + 49.0 * theta4)

        let xhdot1 = -temp1 * cosio
        xnodot = xhdot1 + (0.5 * temp2 * (4.0 - 19.0 * theta2) +
                           2.0 * temp3 * (3.0 - 7.0 * theta2)) * cosio

        xnodcf = 3.5 * betao2 * xhdot1 * c1
        t2cof = 1.5 * c1
        xlcof = 0.125 * j3 * sinio * (3.0 + 5.0 * cosio) / (1.0 + cosio)
        aycof = 0.25 * j3 * sinio

        delmo = pow(1.0 + eta * cos(m0), 3.0)
        sinmo = sin(m0)
        omgcof = bstar * c3 * cos(omega0)
        xmcof = 0.0
        if e0 > 1e-4 {
            xmcof = -2.0 / 3.0 * coef * bstar / eeta
        }

        // Check if simplified propagation (low perigee < 220 km)
        if perige < 220.0 {
            isimp = 1
        } else {
            isimp = 0
            // Calculate higher-order drag terms for non-simplified propagation
            let cc1sq = c1 * c1
            d2 = 4.0 * aodp * tsi * cc1sq

            let temp = d2 * tsi * c1 / 3.0
            d3 = (17.0 * aodp + s4) * temp
            d4 = 0.5 * temp * aodp * tsi * (221.0 * aodp + 31.0 * s4) * c1

            t3cof = d2 + 2.0 * cc1sq
            t4cof = 0.25 * (3.0 * d3 + c1 * (12.0 * d2 + 10.0 * cc1sq))
            t5cof = 0.2 * (3.0 * d4 + 12.0 * c1 * d3 + 6.0 * d2 * d2 +
                           15.0 * cc1sq * (2.0 * d2 + cc1sq))
        }
    }

    /// Propagate the satellite to a specific time
    /// - Parameter minutesSinceEpoch: Time in minutes since TLE epoch
    /// - Returns: Satellite state (position and velocity in TEME frame)
    /// - Throws: PropagationError if propagation fails
    public func propagate(minutesSinceEpoch: Double) throws -> SatelliteState {
        let tsince = minutesSinceEpoch

        // Update for secular gravity and atmospheric drag
        let xmdf = m0 + xmdot * tsince
        let omgadf = omega0 + omgdot * tsince
        let xnoddf = raan0 + xnodot * tsince
        var omega = omgadf
        var xmp = xmdf
        let tsq = tsince * tsince
        let xnode = xnoddf + xnodcf * tsq
        var tempa = 1.0 - c1 * tsince
        var tempe = bstar * c4 * tsince
        var templ = t2cof * tsq

        // Update for drag
        let delomg = omgcof * tsince
        let delm = xmcof * (pow(1.0 + eta * cos(xmdf), 3.0) - delmo)
        let temp = delomg + delm
        xmp = xmdf + temp
        omega = omgadf - temp
        let tcube = tsq * tsince
        let tfour = tsince * tcube

        // Apply drag and perturbation corrections
        if isimp != 1 {
            tempa = tempa - d2 * tsq - d3 * tcube - d4 * tfour
            tempe = tempe + bstar * c5 * (sin(xmp) - sinmo)
            templ = templ + t3cof * tcube + tfour * (t4cof + tsince * t5cof)
        } else {
            tempe = tempe + bstar * c5 * (sin(xmp) - sinmo)
            // templ already has t2cof * tsq, no additional terms for simplified
        }

        let a = aodp * tempa * tempa
        let e = e0 - tempe
        let xl = xmp + omega + xnode + n0pp * templ

        // Check for orbit decay
        if a < 0.95 || e < 0.0 || e > 0.999 {
            throw PropagationError.orbitDecayed
        }

        // Long period periodic terms
        let axn = e * cos(omega)
        let temp2 = 1.0 / (a * (1.0 - e * e))
        let xll = temp2 * xlcof * axn
        let aynl = temp2 * aycof
        let xlt = xl + xll
        let ayn = e * sin(omega) + aynl

        // Solve Kepler's equation (iterative Newton-Raphson)
        let capu = fmod(xlt - xnode, 2.0 * .pi)
        let (sinepw, cosepw) = try solveKepler(capu: capu, axn: axn, ayn: ayn)

        // Short period preliminary quantities
        let ecose = axn * cosepw + ayn * sinepw
        let esine = axn * sinepw - ayn * cosepw
        let el2 = axn * axn + ayn * ayn
        let pl = a * (1.0 - el2)

        if pl < 0.0 {
            throw PropagationError.orbitDecayed
        }

        let r = a * (1.0 - ecose)
        var rdot = sqrt(a) * esine / r * ke
        var rfdot = sqrt(pl) / r * ke
        let temp3 = a / r

        // Update for short periodics
        let sinu = temp3 * (sinepw - ayn - axn * esine / (1.0 + sqrt(1.0 - el2)))
        let cosu = temp3 * (cosepw - axn + ayn * esine / (1.0 + sqrt(1.0 - el2)))
        let u = atan2(sinu, cosu)

        let sin2u = (cosu + cosu) * sinu
        let cos2u = 1.0 - 2.0 * sinu * sinu

        let temp4 = 1.0 / pl
        let temp5 = j2 * temp4
        let temp6 = temp5 * temp4

        // Update for short period periodics
        let rk = r * (1.0 - 1.5 * temp6 * betao * x3thm1) + 0.5 * temp5 * x1mth2 * cos2u
        let uk = u - 0.25 * temp6 * x7thm1 * sin2u
        let xnodek = xnode + 1.5 * temp6 * cosio * sin2u
        let xinck = i0 + 1.5 * temp6 * cosio * sinio * cos2u
        rdot = rdot - n0pp * temp5 * x1mth2 * sin2u
        rfdot = rfdot + n0pp * temp5 * (x1mth2 * cos2u + 1.5 * x3thm1)

        // Orientation vectors
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

        // Position and velocity in TEME frame (km and km/s)
        let x = rk * ux * earthRadius
        let y = rk * uy * earthRadius
        let z = rk * uz * earthRadius

        let xdot = (rdot * ux + rfdot * vx) * earthRadius / 60.0
        let ydot = (rdot * uy + rfdot * vy) * earthRadius / 60.0
        let zdot = (rdot * uz + rfdot * vz) * earthRadius / 60.0

        let position = Vector3D(x: x, y: y, z: z)
        let velocity = Vector3D(x: xdot, y: ydot, z: zdot)

        return SatelliteState(
            position: position,
            velocity: velocity,
            minutesSinceEpoch: minutesSinceEpoch
        )
    }

    /// Solve Kepler's equation using Newton-Raphson iteration
    /// - Parameters:
    ///   - capu: Mean anomaly (radians)
    ///   - axn: e * cos(omega)
    ///   - ayn: e * sin(omega)
    /// - Returns: (sin(E), cos(E)) where E is eccentric anomaly
    private func solveKepler(capu: Double, axn: Double, ayn: Double) throws -> (Double, Double) {
        var epw = capu
        let maxIterations = 10
        let tolerance = 1e-12

        // Newton-Raphson iteration
        for _ in 0..<maxIterations {
            let sinepw = sin(epw)
            let cosepw = cos(epw)
            let ecosE = axn * cosepw + ayn * sinepw
            let esinE = axn * sinepw - ayn * cosepw
            let f = capu - epw + esinE

            if abs(f) < tolerance {
                return (sinepw, cosepw)
            }

            let df = 1.0 - ecosE
            let delta = f / df
            epw += delta
        }

        // If we didn't converge, use the last computed values
        return (sin(epw), cos(epw))
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
            return "Deep space (SDP4) propagation not yet implemented"
        case .invalidEccentricity:
            return "Eccentricity out of valid range (0 <= e < 1)"
        case .keplerConvergenceFailed:
            return "Kepler equation failed to converge"
        }
    }
}
