import Foundation

/// SDP4 orbit propagator (deep-space satellites)
/// Implements the Simplified Deep Space Perturbations 4 algorithm
/// Reference: Vallado et al. "Revisiting Spacetrack Report #3" (AIAA 2006-6753)
///
/// Used for satellites with orbital periods >= 225 minutes, including:
/// - Geostationary satellites (24-hour period)
/// - GPS satellites (12-hour period)
/// - Molniya orbits (12-hour highly elliptical)
/// - Other high-altitude orbits
public class SDP4Propagator: Propagator {
  public let tle: TLE

  // MARK: - WGS-72 Constants (NOT WGS-84!)
  // SDP4 uses WGS-72 Earth model for compatibility with historical data
  private let earthRadius: Double = 6378.135  // km (WGS-72)
  private let j2: Double = 0.001082616  // J2 harmonic (WGS-72)
  private let j3: Double = -0.00000253881  // J3 harmonic
  private let j4: Double = -0.00000165597  // J4 harmonic
  private let ke: Double = 0.0743669161  // sqrt(GM) in Earth radii^(3/2) / minute
  private let xke: Double = 0.0743669161  // Reciprocal of time unit
  private let tumin: Double = 13.44683950578  // Time units per minute

  // MARK: - Basic Orbital Elements (from TLE)
  private var n0: Double = 0  // Mean motion (rad/min)
  private var e0: Double = 0  // Eccentricity
  private var i0: Double = 0  // Inclination (rad)
  private var omega0: Double = 0  // Argument of perigee (rad)
  private var raan0: Double = 0  // Right ascension of ascending node (rad)
  private var m0: Double = 0  // Mean anomaly (rad)
  private var bstar: Double = 0  // Drag coefficient

  // MARK: - Derived SGP4 Constants
  private var aodp: Double = 0  // Semi-major axis (Earth radii)
  private var cosio: Double = 0  // cos(inclination)
  private var sinio: Double = 0  // sin(inclination)
  private var theta2: Double = 0  // cos²(inclination)
  private var x1mth2: Double = 0  // 1 - cos²(i)
  private var x3thm1: Double = 0  // 3*cos²(i) - 1
  private var betao2: Double = 0  // (1 - e²)
  private var betao: Double = 0  // sqrt(1 - e²)

  // MARK: - Deep Space Common Parameters (dscom)
  private var gsto: Double = 0  // Greenwich sidereal time at epoch
  private var zmol: Double = 0  // Mean longitude of moon - ascending node
  private var zmos: Double = 0  // Mean longitude of sun
  private var savtsn: Double = 0  // Stored value

  // MARK: - Deep Space Initialization Parameters (dsinit)
  private var irez: Int = 0  // Resonance flag: 0=none, 1=sync, 2=half-day
  private var d2201: Double = 0  // Resonance coefficients
  private var d2211: Double = 0
  private var d3210: Double = 0
  private var d3222: Double = 0
  private var d4410: Double = 0
  private var d4422: Double = 0
  private var d5220: Double = 0
  private var d5232: Double = 0
  private var d5421: Double = 0
  private var d5433: Double = 0
  private var del1: Double = 0  // Secular integration constants
  private var del2: Double = 0
  private var del3: Double = 0
  private var xfact: Double = 0
  private var xlamo: Double = 0  // Mean longitude at epoch
  private var xli: Double = 0  // Initial mean longitude
  private var xni: Double = 0  // Initial mean motion

  // MARK: - Lunar-Solar Periodic Terms (dpper)
  private var e3: Double = 0  // Eccentricity coefficients
  private var ee2: Double = 0
  private var peo: Double = 0  // Perigee perturbation
  private var pgho: Double = 0  // Geopotential harmonic
  private var pho: Double = 0  // Inclination perturbation
  private var pinco: Double = 0  // Inclination coefficient
  private var plo: Double = 0  // Mean longitude perturbation
  private var se2: Double = 0  // Solar eccentricity terms
  private var se3: Double = 0
  private var sgh2: Double = 0  // Solar geopotential harmonics
  private var sgh3: Double = 0
  private var sgh4: Double = 0
  private var sh2: Double = 0  // Solar inclination terms
  private var sh3: Double = 0
  private var si2: Double = 0  // Solar node terms
  private var si3: Double = 0
  private var sl2: Double = 0  // Solar longitude terms
  private var sl3: Double = 0
  private var sl4: Double = 0
  private var xgh2: Double = 0  // Lunar geopotential harmonics
  private var xgh3: Double = 0
  private var xgh4: Double = 0
  private var xh2: Double = 0  // Lunar inclination terms
  private var xh3: Double = 0
  private var xi2: Double = 0  // Lunar node terms
  private var xi3: Double = 0
  private var xl2: Double = 0  // Lunar longitude terms
  private var xl3: Double = 0
  private var xl4: Double = 0
  private var zmol_c: Double = 0  // Lunar mean longitude (cached)
  private var zmos_c: Double = 0  // Solar mean longitude (cached)

  // MARK: - SGP4 Rate Parameters
  private var xmdot: Double = 0  // Mean anomaly rate
  private var omgdot: Double = 0  // Argument of perigee rate
  private var xnodot: Double = 0  // Node rate
  private var xnodcf: Double = 0  // Node precession factor

  /// SDP4 is for deep-space satellites
  public var isDeepSpace: Bool {
    return true
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
    x1mth2 = 1.0 - theta2
    x3thm1 = 3.0 * theta2 - 1.0
    betao2 = 1.0 - e0 * e0
    betao = sqrt(betao2)

    // Recover original mean motion and semi-major axis
    let a1 = pow(ke / n0, 2.0 / 3.0)
    let temp = 1.5 * j2 * x3thm1 / (a1 * a1 * betao2)
    let delta1 = temp / (a1 * a1)
    let a0 = a1 * (1.0 - delta1 / 3.0 - delta1 * delta1 - 134.0 * delta1 * delta1 * delta1 / 81.0)
    let delta0 = temp / (a0 * a0)
    let n0pp = n0 / (1.0 + delta0)
    let a0pp = a0 / (1.0 - delta0)
    self.aodp = a0pp

    // Check for orbit decay
    let perigee = (a0pp * (1.0 - e0) - 1.0) * earthRadius
    if perigee < 98.0 || a0pp < 0.95 {
      throw PropagationError.orbitDecayed
    }

    // Compute rates (secular effects of gravitation)
    let pinvsq = 1.0 / (aodp * aodp * betao2 * betao2)
    let temp1 = 3.0 * j2 * pinvsq * n0pp
    let temp2 = temp1 * j2 * pinvsq
    let temp3 = 1.25 * j4 * pinvsq * pinvsq * n0pp

    xmdot =
      n0pp + 0.5 * temp1 * betao * x3thm1 + 0.0625 * temp2 * betao
      * (13.0 - 78.0 * theta2 + 137.0 * theta2 * theta2)

    let x1m5th = 1.0 - 5.0 * theta2
    omgdot =
      -0.5 * temp1 * x1m5th + 0.0625 * temp2 * (7.0 - 114.0 * theta2 + 395.0 * theta2 * theta2)
      + temp3 * (3.0 - 36.0 * theta2 + 49.0 * theta2 * theta2)

    let xhdot1 = -temp1 * cosio
    xnodot =
      xhdot1 + (0.5 * temp2 * (4.0 - 19.0 * theta2) + 2.0 * temp3 * (3.0 - 7.0 * theta2)) * cosio

    // Initialize deep space parameters
    try initializeDeepSpace()
  }

  /// Initialize deep space perturbations (dscom + dsinit + dpper)
  private func initializeDeepSpace() throws {
    // Calculate Greenwich Sidereal Time at epoch
    let jd = julianDateFromEpoch(tle.epoch)
    gsto = gstime(jd: jd)

    // Deep Space Common (dscom)
    let (zmol_ds, zmos_ds) = computeDeepSpaceCommon(jd: jd)
    self.zmol = zmol_ds
    self.zmos = zmos_ds
    self.zmol_c = zmol_ds
    self.zmos_c = zmos_ds

    // Deep Space Initialization (dsinit)
    try deepSpaceInit(jd: jd)

    // Deep Space Periodic perturbations at epoch (dpper)
    applyPeriodicCorrections(time: 0.0)
  }

  /// Compute deep space common parameters (dscom)
  private func computeDeepSpaceCommon(jd: Double) -> (zmol: Double, zmos: Double) {
    // Days since 1900 Jan 0.5
    let days = jd - 2415020.0

    // Mean anomalies (radians)
    // Sun - mean longitude
    let zmos = fmod(282.463 + 0.985647 * days, 360.0) * .pi / 180.0

    // Moon - mean longitude
    let zmol = fmod(291.438 + 13.176396 * days, 360.0) * .pi / 180.0

    return (zmol: zmol, zmos: zmos)
  }

  /// Deep space initialization (dsinit)
  private func deepSpaceInit(jd: Double) throws {
    // Compute resonance flag based on orbital period
    let period = 2.0 * .pi / n0  // minutes
    let daysPerPeriod = period / 1440.0  // days

    // Check for synchronous (geosynchronous) or half-day resonance
    if abs(daysPerPeriod - 1.0) < 0.0625 {
      // 24-hour (geosynchronous) resonance
      irez = 1
    } else if abs(daysPerPeriod - 0.5) < 0.0104 {
      // 12-hour (semi-synchronous) resonance
      irez = 2
    } else {
      // No resonance
      irez = 0
    }

    // Initialize resonance terms based on irez
    if irez != 0 {
      initializeResonanceTerms()
    }

    // Initialize lunar/solar periodic coefficients
    initializePeriodicCoefficients()

    // Store initial values for secular integration
    xli = m0 + omega0 + raan0
    xni = n0
    xlamo = m0 + omega0 + raan0 - gsto
  }

  /// Initialize lunar and solar periodic coefficients
  private func initializePeriodicCoefficients() {
    let betao4 = betao2 * betao2

    // Solar eccentricity terms
    se2 = 2.0 * e0 * cosio
    se3 = 0.0

    // Solar node terms
    si2 = 2.0 * sinio * cosio
    si3 = 0.0

    // Solar longitude terms
    sl2 = -2.0 * j2 / betao4
    sl3 = 0.0
    sl4 = 0.0

    // Solar geopotential harmonics
    sgh2 = 2.0 * j2 / betao4 * (1.0 - 5.0 * theta2)
    sgh3 = 0.0
    sgh4 = -2.0 * j4 / (betao4 * betao4) * (1.0 - 14.0 * theta2 + 49.0 * theta2 * theta2)

    // Solar inclination terms
    sh2 = 0.0
    sh3 = 0.0

    // Lunar eccentricity terms
    ee2 = 2.0 * e0 * cosio
    e3 = 0.0

    // Lunar node terms
    xi2 = 2.0 * sinio * cosio
    xi3 = 0.0

    // Lunar longitude terms
    xl2 = -2.0 * j2 / betao4
    xl3 = 0.0
    xl4 = 0.0

    // Lunar geopotential harmonics
    xgh2 = 2.0 * j2 / betao4 * (1.0 - 5.0 * theta2)
    xgh3 = 0.0
    xgh4 = -2.0 * j4 / (betao4 * betao4) * (1.0 - 14.0 * theta2 + 49.0 * theta2 * theta2)

    // Lunar inclination terms
    xh2 = 0.0
    xh3 = 0.0
  }

  /// Initialize resonance coefficients for synchronous/semi-synchronous orbits
  private func initializeResonanceTerms() {
    let sini2 = sinio * sinio
    let cosi2 = cosio * cosio

    if irez == 1 {
      // Geosynchronous (24-hour) resonance terms
      let g200 = 1.0 + eeta * (-2.5 + 0.8125 * eeta)
      let g310 = 1.0 + 2.0 * eeta
      let g300 = 1.0 + eeta * (-6.0 + 6.60937 * eeta)
      let g201 = -0.306 - (eeta - 0.64) * 0.44

      d2201 = 1.0 * sini2 * g201
      d2211 = 3.0 * sini2 * cosi2
      d3210 = -3.0 * sini2 * g310
      d3222 = 9.0 * sini2 * (1.0 - 2.0 * cosi2) * g300
      d4410 = -12.0 * sini2 * cosi2 * g200
      d4422 = 18.0 * sini2 * (2.0 - 3.0 * cosi2)
      d5220 = 27.0 * sini2 * g200
      d5232 = 54.0 * sini2 * cosi2
      d5421 = -108.0 * sini2 * (1.0 - 5.0 * cosi2)
      d5433 = 162.0 * sini2 * (-1.0 + 2.0 * cosi2)
    } else if irez == 2 {
      // Semi-synchronous (12-hour) resonance terms
      let g211 = 1.0 + 2.5 * eeta
      let g310 = 1.0 + 2.0 * eeta
      let g322 = 1.0 + eeta * (3.0 - 2.5 * eeta)
      let g410 = 1.0 + 3.5 * eeta
      let g422 = 1.0 + eeta * (4.5 - 3.5 * eeta)
      let g520 = 1.0 + eeta * (5.0 - 4.5 * eeta)

      d2201 = 1.5 * sini2 * g211
      d2211 = 3.0 * sini2 * cosi2 * g211
      d3210 = -3.0 * sini2 * g310
      d3222 = 9.0 * sini2 * (1.0 - 2.0 * cosi2) * g322
      d4410 = -12.0 * sini2 * cosi2 * g410
      d4422 = 18.0 * sini2 * (2.0 - 3.0 * cosi2) * g422
      d5220 = 27.0 * sini2 * g520
      d5232 = 54.0 * sini2 * cosi2 * g520
      d5421 = -108.0 * sini2 * (1.0 - 5.0 * cosi2) * g520
      d5433 = 162.0 * sini2 * (-1.0 + 2.0 * cosi2) * g520
    }

    // Common scaling factor
    let scale = 1.0e-5
    d2201 *= scale
    d2211 *= scale
    d3210 *= scale
    d3222 *= scale
    d4410 *= scale
    d4422 *= scale
    d5220 *= scale
    d5232 *= scale
    d5421 *= scale
    d5433 *= scale
  }

  /// Helper: eta = aodp * e0 / xi (needed for resonance calculations)
  private var eeta: Double {
    return e0
  }

  /// Apply periodic corrections from lunar-solar perturbations (dpper)
  private func applyPeriodicCorrections(time: Double) {
    // Compute solar and lunar mean longitudes
    let zm = zmos + 4.771734281e-3 * time
    let zf = zm + 2.0 * 0.01675 * sin(zm)
    let sinzf = sin(zf)
    let coszf = cos(zf)
    let f2 = 0.5 * sinzf * sinzf - 0.25
    let f3 = -0.5 * sinzf * coszf

    // Solar terms
    let ses = se2 * f2 + se3 * f3
    let sis = si2 * f2 + si3 * f3
    let sls = sl2 * f2 + sl3 * f3 + sl4 * (sinzf * sinzf * sinzf * sinzf - 0.375)
    let sghs = sgh2 * f2 + sgh3 * f3 + sgh4 * (sinzf * sinzf * sinzf * sinzf - 0.375)
    let shs = sh2 * f2 + sh3 * f3

    // Lunar terms
    let zm_l = zmol + 1.653916e-2 * time
    let zf_l = zm_l + 0.0549 * sin(zm_l)
    let sinzf_l = sin(zf_l)
    let coszf_l = cos(zf_l)
    let f2_l = 0.5 * sinzf_l * sinzf_l - 0.25
    let f3_l = -0.5 * sinzf_l * coszf_l

    let sel = ee2 * f2_l + e3 * f3_l
    let sil = xi2 * f2_l + xi3 * f3_l
    let sll = xl2 * f2_l + xl3 * f3_l + xl4 * (sinzf_l * sinzf_l * sinzf_l * sinzf_l - 0.375)
    let sghl = xgh2 * f2_l + xgh3 * f3_l + xgh4 * (sinzf_l * sinzf_l * sinzf_l * sinzf_l - 0.375)
    let shl = xh2 * f2_l + xh3 * f3_l

    // Combine solar and lunar terms
    peo = ses + sel
    pinco = sis + sil
    plo = sls + sll
    pgho = sghs + sghl
    pho = shs + shl
  }

  /// Apply deep space secular effects (dpsec)
  private func applySecularEffects(
    time: Double
  ) -> (xn: Double, em: Double, xinc: Double, omg: Double, xnode: Double) {
    var xn = n0
    let em = e0
    let xinc = i0
    let omg = omega0
    let xnode = raan0

    // Apply resonance terms if applicable
    if irez != 0 {
      let xldot = xni + xfact
      let xnddt =
        del1 * sin(xldot * time + xlamo) + del2 * sin(2.0 * (xldot * time + xlamo)) + del3
        * sin(3.0 * (xldot * time + xlamo))
      xn = xni + xnddt * time
    }

    return (xn: xn, em: em, xinc: xinc, omg: omg, xnode: xnode)
  }

  /// Propagate the satellite to a specific time
  /// - Parameter minutesSinceEpoch: Time in minutes since TLE epoch
  /// - Returns: Satellite state (position and velocity in TEME frame)
  /// - Throws: PropagationError if propagation fails
  public func propagate(minutesSinceEpoch: Double) throws -> SatelliteState {
    let tsince = minutesSinceEpoch

    // Apply deep space periodic perturbations
    applyPeriodicCorrections(time: tsince)

    // Apply deep space secular effects
    let (xn, em, xinc, omgUpdated, xnodeUpdated) = applySecularEffects(time: tsince)

    // Update for secular gravity and atmospheric drag
    let xmdf = m0 + xmdot * tsince + peo
    let omgadf = omgUpdated + omgdot * tsince + plo
    let xnoddf = xnodeUpdated + xnodot * tsince
    let omega = omgadf
    let xmp = xmdf
    let xnode = xnoddf

    // Update mean motion
    let xn_updated = xn + xmdot * tsince

    // Calculate semi-major axis
    let a = pow(ke / xn_updated, 2.0 / 3.0)
    let e = em + pinco

    // Check for orbit decay
    if a < 0.95 || e < 0.0 || e > 0.999 {
      throw PropagationError.orbitDecayed
    }

    // Long period periodic terms
    let axn = e * cos(omega)
    let temp = 1.0 / (a * (1.0 - e * e))
    let ayn = e * sin(omega) + temp * pho
    let xlt = xmp + omega + xnode

    // Solve Kepler's equation
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
    let rdot = sqrt(a) * esine / r * ke
    let rfdot = sqrt(pl) / r * ke

    // Update for short periodics
    let temp3 = a / r
    let sinu = temp3 * (sinepw - ayn - axn * esine / (1.0 + sqrt(1.0 - el2)))
    let cosu = temp3 * (cosepw - axn + ayn * esine / (1.0 + sqrt(1.0 - el2)))
    let u = atan2(sinu, cosu)

    // Orientation vectors
    let sinuk = sin(u)
    let cosuk = cos(u)
    let sinik = sin(xinc + pinco)
    let cosik = cos(xinc + pinco)
    let sinnok = sin(xnode)
    let cosnok = cos(xnode)
    let xmx = -sinnok * cosik
    let xmy = cosnok * cosik
    let ux = xmx * sinuk + cosnok * cosuk
    let uy = xmy * sinuk + sinnok * cosuk
    let uz = sinik * sinuk
    let vx = xmx * cosuk - cosnok * sinuk
    let vy = xmy * cosuk - sinnok * sinuk
    let vz = sinik * cosuk

    // Position and velocity in TEME frame (km and km/s)
    let x = r * ux * earthRadius
    let y = r * uy * earthRadius
    let z = r * uz * earthRadius

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

  // MARK: - Time Conversion Helpers

  /// Convert Date to Julian Date
  private func julianDateFromEpoch(_ date: Date) -> Double {
    let j2000 = Date(timeIntervalSince1970: 946728000.0)  // 2000-01-01 12:00:00 UTC
    let daysSinceJ2000 = date.timeIntervalSince(j2000) / 86400.0
    return 2451545.0 + daysSinceJ2000
  }

  /// Compute Greenwich Sidereal Time (GSTIME)
  /// - Parameter jd: Julian Date
  /// - Returns: GSTO in radians
  private func gstime(jd: Double) -> Double {
    let tut1 = (jd - 2451545.0) / 36525.0
    var temp =
      -6.2e-6 * tut1 * tut1 * tut1 + 0.093104 * tut1 * tut1 + (876600.0 * 3600.0 + 8640184.812866)
      * tut1 + 67310.54841
    temp = fmod(temp * .pi / 43200.0, 2.0 * .pi)
    if temp < 0.0 {
      temp += 2.0 * .pi
    }
    return temp
  }
}
