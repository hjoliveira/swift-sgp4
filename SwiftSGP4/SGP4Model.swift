import Foundation

/// Faithful port of the reference SGP4/SDP4 algorithm from
/// Vallado, Crawford, Hujsak & Kelso, "Revisiting Spacetrack Report #3"
/// (AIAA 2006-6753), including the deep-space routines dscom, dpper,
/// dsinit and dspace.
///
/// Both `SGP4Propagator` and `SDP4Propagator` wrap this single implementation.
/// The reference is one routine with a near-Earth/deep-space branch; keeping it
/// that way here means the two paths cannot drift apart.
final class SGP4Model {

  // MARK: - WGS-72 Constants
  // SGP4 is defined against WGS-72, not WGS-84.

  static let radiusEarthKm = 6378.135
  static let xke = 0.07436691613317342  // 60 / sqrt(re^3 / mu)
  static let j2 = 0.001082616
  static let j3 = -0.00000253881
  static let j4 = -0.00000165597
  static let j3oj2 = j3 / j2
  static let x2o3 = 2.0 / 3.0
  static let twoPi = 2.0 * Double.pi

  /// Earth rotation rate in radians per minute.
  static let rptim = 4.375_269_088_011_299_66e-3

  // MARK: - Propagation Method

  enum Method {
    case nearEarth
    case deepSpace
  }

  let tle: TLE
  private(set) var method: Method = .nearEarth

  var isDeepSpace: Bool { method == .deepSpace }

  // MARK: - Epoch Elements (radians, radians/minute)

  private var eccoTLE: Double = 0  // eccentricity at epoch
  private var inclo: Double = 0  // inclination at epoch
  private var nodeo: Double = 0  // RAAN at epoch
  private var argpo: Double = 0  // argument of perigee at epoch
  private var mo: Double = 0  // mean anomaly at epoch
  private var bstar: Double = 0
  private var noUnkozai: Double = 0  // recovered mean motion

  // MARK: - Derived Constants

  private var cosio = 0.0, sinio = 0.0, cosio2 = 0.0
  private var con41 = 0.0, con42 = 0.0, x1mth2 = 0.0, x7thm1 = 0.0
  private var eccsq = 0.0, omeosq = 0.0, rteosq = 0.0
  private var ao = 0.0, gsto = 0.0

  private var cc1 = 0.0, cc4 = 0.0, cc5 = 0.0
  private var d2 = 0.0, d3 = 0.0, d4 = 0.0
  private var delmo = 0.0, eta = 0.0, sinmao = 0.0
  private var argpdot = 0.0, mdot = 0.0, nodedot = 0.0, nodecf = 0.0
  private var omgcof = 0.0, xmcof = 0.0
  private var t2cof = 0.0, t3cof = 0.0, t4cof = 0.0, t5cof = 0.0
  private var xlcof = 0.0, aycof = 0.0
  private var isimp = false

  // MARK: - Deep Space: dscom Outputs

  private var e3 = 0.0, ee2 = 0.0
  private var peo = 0.0, pgho = 0.0, pho = 0.0, pinco = 0.0, plo = 0.0
  private var se2 = 0.0, se3 = 0.0
  private var sgh2 = 0.0, sgh3 = 0.0, sgh4 = 0.0
  private var sh2 = 0.0, sh3 = 0.0
  private var si2 = 0.0, si3 = 0.0
  private var sl2 = 0.0, sl3 = 0.0, sl4 = 0.0
  private var xgh2 = 0.0, xgh3 = 0.0, xgh4 = 0.0
  private var xh2 = 0.0, xh3 = 0.0
  private var xi2 = 0.0, xi3 = 0.0
  private var xl2 = 0.0, xl3 = 0.0, xl4 = 0.0
  private var zmol = 0.0, zmos = 0.0

  // MARK: - Deep Space: dsinit Outputs

  private var irez = 0  // 0 none, 1 synchronous, 2 half-day
  private var d2201 = 0.0, d2211 = 0.0
  private var d3210 = 0.0, d3222 = 0.0
  private var d4410 = 0.0, d4422 = 0.0
  private var d5220 = 0.0, d5232 = 0.0, d5421 = 0.0, d5433 = 0.0
  private var dedt = 0.0, didt = 0.0, dmdt = 0.0, dnodt = 0.0, domdt = 0.0
  private var del1 = 0.0, del2 = 0.0, del3 = 0.0
  private var xfact = 0.0, xlamo = 0.0
  var xli = 0.0, xni = 0.0
  var atime = 0.0

  /// Intermediate dscom values retained for dsinit.
  var dscom = DscomResult()

  // MARK: - Initialization

  init(tle: TLE) throws {
    self.tle = tle

    let no = tle.meanMotion * Self.twoPi / 1440.0  // rad/min
    eccoTLE = tle.eccentricity
    inclo = tle.inclination * .pi / 180.0
    nodeo = tle.rightAscendingNode * .pi / 180.0
    argpo = tle.argumentPerigee * .pi / 180.0
    mo = tle.meanAnomaly * .pi / 180.0
    bstar = tle.bstar

    guard eccoTLE >= 0.0, eccoTLE < 1.0 else {
      throw PropagationError.invalidEccentricity
    }
    guard no > 0.0 else {
      throw PropagationError.orbitDecayed
    }

    try initialize(no: no)
  }

  /// Days since 1949 December 31 00:00 UT, the epoch the deep-space
  /// routines are expressed in.
  private var epochDays1950: Double {
    return SiderealTime.julianDate(from: tle.epoch) - 2_433_281.5
  }

  private func initialize(no: Double) throws {
    // --- initl ---
    eccsq = eccoTLE * eccoTLE
    omeosq = 1.0 - eccsq
    rteosq = sqrt(omeosq)
    cosio = cos(inclo)
    cosio2 = cosio * cosio
    sinio = sin(inclo)

    con41 = 3.0 * cosio2 - 1.0
    con42 = 1.0 - 5.0 * cosio2
    x1mth2 = 1.0 - cosio2
    x7thm1 = 7.0 * cosio2 - 1.0

    // Un-Kozai the mean motion.
    let ak = pow(Self.xke / no, Self.x2o3)
    let d1 = 0.75 * Self.j2 * con41 / (rteosq * omeosq)
    var del = d1 / (ak * ak)
    let adel = ak * (1.0 - del * del - del * (1.0 / 3.0 + 134.0 * del * del / 81.0))
    del = d1 / (adel * adel)
    noUnkozai = no / (1.0 + del)

    ao = pow(Self.xke / noUnkozai, Self.x2o3)
    let po = ao * omeosq
    let posq = po * po
    let rp = ao * (1.0 - eccoTLE)

    gsto = SiderealTime.greenwichMeanSiderealTime(
      julianDate: epochDays1950 + 2_433_281.5)

    // --- sgp4init ---
    let period = Self.twoPi / noUnkozai
    method = period >= 225.0 ? .deepSpace : .nearEarth

    // Atmospheric drag boundary.
    // The reference clamps sfour for a very low perigee rather than rejecting
    // the orbit, and recomputes qzms24 to match the lowered boundary.
    var sfour = 78.0 / Self.radiusEarthKm + 1.0
    var qzms24 = pow((120.0 - 78.0) / Self.radiusEarthKm, 4.0)
    let perige = (rp - 1.0) * Self.radiusEarthKm
    if perige < 156.0 {
      var s = perige - 78.0
      if perige < 98.0 {
        s = 20.0
      }
      qzms24 = pow((120.0 - s) / Self.radiusEarthKm, 4.0)
      sfour = s / Self.radiusEarthKm + 1.0
    }
    let pinvsq = 1.0 / posq

    let tsi = 1.0 / (ao - sfour)
    eta = ao * eccoTLE * tsi
    let etasq = eta * eta
    let eeta = eccoTLE * eta
    let psisq = abs(1.0 - etasq)
    let coef = qzms24 * pow(tsi, 4.0)
    let coef1 = coef / pow(psisq, 3.5)

    let cc2 =
      coef1 * noUnkozai
      * (ao * (1.0 + 1.5 * etasq + eeta * (4.0 + etasq))
        + 0.375 * Self.j2 * tsi / psisq * con41 * (8.0 + 3.0 * etasq * (8.0 + etasq)))
    cc1 = bstar * cc2

    var cc3 = 0.0
    if eccoTLE > 1.0e-4 {
      cc3 = -2.0 * coef * tsi * Self.j3oj2 * noUnkozai * sinio / eccoTLE
    }

    cc4 =
      2.0 * noUnkozai * coef1 * ao * omeosq
      * (eta * (2.0 + 0.5 * etasq) + eccoTLE * (0.5 + 2.0 * etasq)
        - Self.j2 * tsi / (ao * psisq)
        * (-3.0 * con41 * (1.0 - 2.0 * eeta + etasq * (1.5 - 0.5 * eeta))
          + 0.75 * x1mth2 * (2.0 * etasq - eeta * (1.0 + etasq)) * cos(2.0 * argpo)))
    cc5 = 2.0 * coef1 * ao * omeosq * (1.0 + 2.75 * (etasq + eeta) + eeta * etasq)

    let cosio4 = cosio2 * cosio2
    let temp1 = 1.5 * Self.j2 * pinvsq * noUnkozai
    let temp2 = 0.5 * temp1 * Self.j2 * pinvsq
    let temp3 = -0.46875 * Self.j4 * pinvsq * pinvsq * noUnkozai

    mdot =
      noUnkozai + 0.5 * temp1 * rteosq * con41
      + 0.0625 * temp2 * rteosq * (13.0 - 78.0 * cosio2 + 137.0 * cosio4)
    argpdot =
      -0.5 * temp1 * con42 + 0.0625 * temp2 * (7.0 - 114.0 * cosio2 + 395.0 * cosio4)
      + temp3 * (3.0 - 36.0 * cosio2 + 49.0 * cosio4)
    let xhdot1 = -temp1 * cosio
    nodedot =
      xhdot1
      + (0.5 * temp2 * (4.0 - 19.0 * cosio2) + 2.0 * temp3 * (3.0 - 7.0 * cosio2)) * cosio

    let xpidot = argpdot + nodedot
    omgcof = bstar * cc3 * cos(argpo)
    xmcof = 0.0
    if eccoTLE > 1.0e-4 {
      xmcof = -Self.x2o3 * coef * bstar / eeta
    }
    nodecf = 3.5 * omeosq * xhdot1 * cc1
    t2cof = 1.5 * cc1

    // Guard the singularity at cosio == -1.
    if abs(cosio + 1.0) > 1.5e-12 {
      xlcof = -0.25 * Self.j3oj2 * sinio * (3.0 + 5.0 * cosio) / (1.0 + cosio)
    } else {
      xlcof = -0.25 * Self.j3oj2 * sinio * (3.0 + 5.0 * cosio) / 1.5e-12
    }
    aycof = -0.5 * Self.j3oj2 * sinio

    delmo = pow(1.0 + eta * cos(mo), 3.0)
    sinmao = sin(mo)
    isimp = rp < (220.0 / Self.radiusEarthKm + 1.0)

    if method == .deepSpace {
      // Deep space always uses the simplified drag path.
      isimp = true

      var ep = eccoTLE
      var inclp = inclo
      var nodep = nodeo
      var argpp = argpo
      var mp = mo

      runDscom(tc: 0.0, ep: ep, argpp: argpp, inclp: inclp, nodep: nodep, np: noUnkozai)
      runDpper(
        t: 0.0, initializing: true, ep: &ep, inclp: &inclp, nodep: &nodep, argpp: &argpp,
        mp: &mp)

      runDsinit(tc: 0.0, xpidot: xpidot)
    } else if !isimp {
      let cc1sq = cc1 * cc1
      d2 = 4.0 * ao * tsi * cc1sq
      let temp = d2 * tsi * cc1 / 3.0
      d3 = (17.0 * ao + sfour) * temp
      d4 = 0.5 * temp * ao * tsi * (221.0 * ao + 31.0 * sfour) * cc1
      t3cof = d2 + 2.0 * cc1sq
      t4cof = 0.25 * (3.0 * d3 + cc1 * (12.0 * d2 + 10.0 * cc1sq))
      t5cof = 0.2 * (3.0 * d4 + 12.0 * cc1 * d3 + 6.0 * d2 * d2 + 15.0 * cc1sq * (2.0 * d2 + cc1sq))
    }
  }
}

// MARK: - Deep Space Routines

extension SGP4Model {

  /// Deep space common quantities (dscom).
  /// Computes the solar and lunar terms shared by dpper and dsinit.
  fileprivate func computeDscom(
    tc: Double, ep: Double, argpp: Double, inclp: Double, nodep: Double, np: Double
  ) -> DscomResult {
    var r = DscomResult()

    let zes = 0.01675
    let zel = 0.05490
    let c1ss = 2.9864797e-6
    let c1l = 4.7968065e-7
    let zsinis = 0.39785416
    let zcosis = 0.91744867
    let zcosgs = 0.1945905
    let zsings = -0.98088458

    let nm = np
    let em = ep
    let snodm = sin(nodep)
    let cnodm = cos(nodep)
    let sinomm = sin(argpp)
    let cosomm = cos(argpp)
    let sinim = sin(inclp)
    let cosim = cos(inclp)
    let emsq = em * em
    let betasq = 1.0 - emsq
    let rtemsq = sqrt(betasq)

    r.sinim = sinim
    r.cosim = cosim
    r.emsq = emsq
    r.rtemsq = rtemsq

    let day = epochDays1950 + 18261.5 + tc / 1440.0
    let xnodce = (4.5236020 - 9.2422029e-4 * day).truncatingRemainder(dividingBy: SGP4Model.twoPi)
    let stem = sin(xnodce)
    let ctem = cos(xnodce)
    let zcosil = 0.91375164 - 0.03568096 * ctem
    let zsinil = sqrt(1.0 - zcosil * zcosil)
    let zsinhl = 0.089683511 * stem / zsinil
    let zcoshl = sqrt(1.0 - zsinhl * zsinhl)
    let gam = 5.8351514 + 0.0019443680 * day
    var zx = 0.39785416 * stem / zsinil
    let zy = zcoshl * ctem + 0.91744867 * zsinhl * stem
    zx = atan2(zx, zy)
    zx = gam + zx - xnodce
    let zcosgl = cos(zx)
    let zsingl = sin(zx)

    var zcosg = zcosgs
    var zsing = zsings
    var zcosi = zcosis
    var zsini = zsinis
    var zcosh = cnodm
    var zsinh = snodm
    var cc = c1ss
    let xnoi = 1.0 / nm

    var s1 = 0.0
    var s2 = 0.0
    var s3 = 0.0
    var s4 = 0.0
    var s5 = 0.0
    var s6 = 0.0
    var s7 = 0.0
    var z1 = 0.0
    var z2 = 0.0
    var z3 = 0.0
    var z11 = 0.0
    var z12 = 0.0
    var z13 = 0.0
    var z21 = 0.0
    var z22 = 0.0
    var z23 = 0.0
    var z31 = 0.0
    var z32 = 0.0
    var z33 = 0.0
    var ss1 = 0.0
    var ss2 = 0.0
    var ss3 = 0.0
    var ss4 = 0.0
    var ss5 = 0.0
    var ss6 = 0.0
    var ss7 = 0.0
    var sz1 = 0.0
    var sz2 = 0.0
    var sz3 = 0.0
    var sz11 = 0.0
    var sz12 = 0.0
    var sz13 = 0.0
    var sz21 = 0.0
    var sz22 = 0.0
    var sz23 = 0.0
    var sz31 = 0.0
    var sz32 = 0.0
    var sz33 = 0.0

    // Pass 1 solar, pass 2 lunar.
    for lsflg in 1...2 {
      let a1 = zcosg * zcosh + zsing * zcosi * zsinh
      let a3 = -zsing * zcosh + zcosg * zcosi * zsinh
      let a7 = -zcosg * zsinh + zsing * zcosi * zcosh
      let a8 = zsing * zsini
      let a9 = zsing * zsinh + zcosg * zcosi * zcosh
      let a10 = zcosg * zsini
      let a2 = cosim * a7 + sinim * a8
      let a4 = cosim * a9 + sinim * a10
      let a5 = -sinim * a7 + cosim * a8
      let a6 = -sinim * a9 + cosim * a10

      let x1 = a1 * cosomm + a2 * sinomm
      let x2 = a3 * cosomm + a4 * sinomm
      let x3 = -a1 * sinomm + a2 * cosomm
      let x4 = -a3 * sinomm + a4 * cosomm
      let x5 = a5 * sinomm
      let x6 = a6 * sinomm
      let x7 = a5 * cosomm
      let x8 = a6 * cosomm

      z31 = 12.0 * x1 * x1 - 3.0 * x3 * x3
      z32 = 24.0 * x1 * x2 - 6.0 * x3 * x4
      z33 = 12.0 * x2 * x2 - 3.0 * x4 * x4
      z1 = 3.0 * (a1 * a1 + a2 * a2) + z31 * emsq
      z2 = 6.0 * (a1 * a3 + a2 * a4) + z32 * emsq
      z3 = 3.0 * (a3 * a3 + a4 * a4) + z33 * emsq
      z11 = -6.0 * a1 * a5 + emsq * (-24.0 * x1 * x7 - 6.0 * x3 * x5)
      z12 =
        -6.0 * (a1 * a6 + a3 * a5)
        + emsq * (-24.0 * (x2 * x7 + x1 * x8) - 6.0 * (x3 * x6 + x4 * x5))
      z13 = -6.0 * a3 * a6 + emsq * (-24.0 * x2 * x8 - 6.0 * x4 * x6)
      z21 = 6.0 * a2 * a5 + emsq * (24.0 * x1 * x5 - 6.0 * x3 * x7)
      z22 =
        6.0 * (a4 * a5 + a2 * a6)
        + emsq * (24.0 * (x2 * x5 + x1 * x6) - 6.0 * (x4 * x7 + x3 * x8))
      z23 = 6.0 * a4 * a6 + emsq * (24.0 * x2 * x6 - 6.0 * x4 * x8)
      z1 = z1 + z1 + betasq * z31
      z2 = z2 + z2 + betasq * z32
      z3 = z3 + z3 + betasq * z33
      s3 = cc * xnoi
      s2 = -0.5 * s3 / rtemsq
      s4 = s3 * rtemsq
      s1 = -15.0 * em * s4
      s5 = x1 * x3 + x2 * x4
      s6 = x2 * x3 + x1 * x4
      s7 = x2 * x4 - x1 * x3

      if lsflg == 1 {
        ss1 = s1
        ss2 = s2
        ss3 = s3
        ss4 = s4
        ss5 = s5
        ss6 = s6
        ss7 = s7
        sz1 = z1
        sz2 = z2
        sz3 = z3
        sz11 = z11
        sz12 = z12
        sz13 = z13
        sz21 = z21
        sz22 = z22
        sz23 = z23
        sz31 = z31
        sz32 = z32
        sz33 = z33
        zcosg = zcosgl
        zsing = zsingl
        zcosi = zcosil
        zsini = zsinil
        zcosh = zcoshl * cnodm + zsinhl * snodm
        zsinh = snodm * zcoshl - cnodm * zsinhl
        cc = c1l
      }
    }

    r.zmol = (4.7199672 + 0.22997150 * day - gam).truncatingRemainder(
      dividingBy: SGP4Model.twoPi)
    r.zmos = (6.2565837 + 0.017201977 * day).truncatingRemainder(dividingBy: SGP4Model.twoPi)

    // Solar periodic coefficients.
    r.se2 = 2.0 * ss1 * ss6
    r.se3 = 2.0 * ss1 * ss7
    r.si2 = 2.0 * ss2 * sz12
    r.si3 = 2.0 * ss2 * (sz13 - sz11)
    r.sl2 = -2.0 * ss3 * sz2
    r.sl3 = -2.0 * ss3 * (sz3 - sz1)
    r.sl4 = -2.0 * ss3 * (-21.0 - 9.0 * emsq) * zes
    r.sgh2 = 2.0 * ss4 * sz32
    r.sgh3 = 2.0 * ss4 * (sz33 - sz31)
    r.sgh4 = -18.0 * ss4 * zes
    r.sh2 = -2.0 * ss2 * sz22
    r.sh3 = -2.0 * ss2 * (sz23 - sz21)

    // Lunar periodic coefficients.
    r.ee2 = 2.0 * s1 * s6
    r.e3 = 2.0 * s1 * s7
    r.xi2 = 2.0 * s2 * z12
    r.xi3 = 2.0 * s2 * (z13 - z11)
    r.xl2 = -2.0 * s3 * z2
    r.xl3 = -2.0 * s3 * (z3 - z1)
    r.xl4 = -2.0 * s3 * (-21.0 - 9.0 * emsq) * zel
    r.xgh2 = 2.0 * s4 * z32
    r.xgh3 = 2.0 * s4 * (z33 - z31)
    r.xgh4 = -18.0 * s4 * zel
    r.xh2 = -2.0 * s2 * z22
    r.xh3 = -2.0 * s2 * (z23 - z21)

    r.s1 = s1
    r.s2 = s2
    r.s3 = s3
    r.s4 = s4
    r.s5 = s5
    r.ss1 = ss1
    r.ss2 = ss2
    r.ss3 = ss3
    r.ss4 = ss4
    r.ss5 = ss5
    r.sz1 = sz1
    r.sz3 = sz3
    r.sz11 = sz11
    r.sz13 = sz13
    r.sz21 = sz21
    r.sz23 = sz23
    r.sz31 = sz31
    r.sz33 = sz33
    r.z1 = z1
    r.z3 = z3
    r.z11 = z11
    r.z13 = z13
    r.z21 = z21
    r.z23 = z23
    r.z31 = z31
    r.z33 = z33

    return r
  }
}

/// Intermediate values produced by dscom and consumed by dsinit.
struct DscomResult {
  var sinim = 0.0, cosim = 0.0, emsq = 0.0, rtemsq = 0.0
  var zmol = 0.0, zmos = 0.0
  var se2 = 0.0, se3 = 0.0, si2 = 0.0, si3 = 0.0
  var sl2 = 0.0, sl3 = 0.0, sl4 = 0.0
  var sgh2 = 0.0, sgh3 = 0.0, sgh4 = 0.0, sh2 = 0.0, sh3 = 0.0
  var ee2 = 0.0, e3 = 0.0, xi2 = 0.0, xi3 = 0.0
  var xl2 = 0.0, xl3 = 0.0, xl4 = 0.0
  var xgh2 = 0.0, xgh3 = 0.0, xgh4 = 0.0, xh2 = 0.0, xh3 = 0.0
  var s1 = 0.0, s2 = 0.0, s3 = 0.0, s4 = 0.0, s5 = 0.0
  var ss1 = 0.0, ss2 = 0.0, ss3 = 0.0, ss4 = 0.0, ss5 = 0.0
  var sz1 = 0.0, sz3 = 0.0, sz11 = 0.0, sz13 = 0.0
  var sz21 = 0.0, sz23 = 0.0, sz31 = 0.0, sz33 = 0.0
  var z1 = 0.0, z3 = 0.0, z11 = 0.0, z13 = 0.0
  var z21 = 0.0, z23 = 0.0, z31 = 0.0, z33 = 0.0
}

extension SGP4Model {

  /// Stores the dscom outputs this model needs later.
  func runDscom(tc: Double, ep: Double, argpp: Double, inclp: Double, nodep: Double, np: Double) {
    let r = computeDscom(tc: tc, ep: ep, argpp: argpp, inclp: inclp, nodep: nodep, np: np)
    dscom = r

    e3 = r.e3
    ee2 = r.ee2
    se2 = r.se2
    se3 = r.se3
    sgh2 = r.sgh2
    sgh3 = r.sgh3
    sgh4 = r.sgh4
    sh2 = r.sh2
    sh3 = r.sh3
    si2 = r.si2
    si3 = r.si3
    sl2 = r.sl2
    sl3 = r.sl3
    sl4 = r.sl4
    xgh2 = r.xgh2
    xgh3 = r.xgh3
    xgh4 = r.xgh4
    xh2 = r.xh2
    xh3 = r.xh3
    xi2 = r.xi2
    xi3 = r.xi3
    xl2 = r.xl2
    xl3 = r.xl3
    xl4 = r.xl4
    zmol = r.zmol
    zmos = r.zmos
  }

  /// Deep space long period periodic contributions (dpper).
  ///
  /// When `initializing` is true the perturbations are evaluated at the epoch
  /// and stored as the reference offsets (peo, pinco, plo, pgho, pho); on
  /// subsequent calls those offsets are removed and the result applied to the
  /// osculating elements.
  func runDpper(
    t: Double, initializing: Bool,
    ep: inout Double, inclp: inout Double, nodep: inout Double,
    argpp: inout Double, mp: inout Double
  ) {
    let zns = 1.19459e-5
    let zes = 0.01675
    let znl = 1.5835218e-4
    let zel = 0.05490

    // Solar terms.
    var zm = initializing ? zmos : zmos + zns * t
    var zf = zm + 2.0 * zes * sin(zm)
    var sinzf = sin(zf)
    var f2 = 0.5 * sinzf * sinzf - 0.25
    var f3 = -0.5 * sinzf * cos(zf)
    let ses = se2 * f2 + se3 * f3
    let sis = si2 * f2 + si3 * f3
    let sls = sl2 * f2 + sl3 * f3 + sl4 * sinzf
    let sghs = sgh2 * f2 + sgh3 * f3 + sgh4 * sinzf
    let shs = sh2 * f2 + sh3 * f3

    // Lunar terms.
    zm = initializing ? zmol : zmol + znl * t
    zf = zm + 2.0 * zel * sin(zm)
    sinzf = sin(zf)
    f2 = 0.5 * sinzf * sinzf - 0.25
    f3 = -0.5 * sinzf * cos(zf)
    let sel = ee2 * f2 + e3 * f3
    let sil = xi2 * f2 + xi3 * f3
    let sll = xl2 * f2 + xl3 * f3 + xl4 * sinzf
    let sghl = xgh2 * f2 + xgh3 * f3 + xgh4 * sinzf
    let shll = xh2 * f2 + xh3 * f3

    var pe = ses + sel
    var pinc = sis + sil
    var pl = sls + sll
    var pgh = sghs + sghl
    var ph = shs + shll

    if initializing {
      // The reference zeroes peo/pinco/plo/pgho/pho in dscom and skips the
      // application block entirely while initializing, so the epoch call
      // contributes nothing and the offsets stay at zero.
      return
    }

    pe -= peo
    pinc -= pinco
    pl -= plo
    pgh -= pgho
    ph -= pho

    inclp += pinc
    ep += pe
    let sinip = sin(inclp)
    let cosip = cos(inclp)

    if inclp >= 0.2 {
      // Apply periodics directly.
      ph /= sinip
      pgh -= cosip * ph
      argpp += pgh
      nodep += ph
      mp += pl
    } else {
      // Apply periodics with the Lyddane modification for low inclination.
      let sinop = sin(nodep)
      let cosop = cos(nodep)
      var alfdp = sinip * sinop
      var betdp = sinip * cosop
      let dalf = ph * cosop + pinc * cosip * sinop
      let dbet = -ph * sinop + pinc * cosip * cosop
      alfdp += dalf
      betdp += dbet
      nodep = nodep.truncatingRemainder(dividingBy: SGP4Model.twoPi)
      if nodep < 0.0 {
        nodep += SGP4Model.twoPi
      }
      var xls = mp + argpp + cosip * nodep
      let dls = pl + pgh - pinc * nodep * sinip
      xls += dls
      let xnoh = nodep
      nodep = atan2(alfdp, betdp)
      if nodep < 0.0 {
        nodep += SGP4Model.twoPi
      }
      if abs(xnoh - nodep) > Double.pi {
        if nodep < xnoh {
          nodep += SGP4Model.twoPi
        } else {
          nodep -= SGP4Model.twoPi
        }
      }
      mp += pl
      argpp = xls - mp - cosip * nodep
    }
  }

  /// Deep space initialization for resonance effects (dsinit).
  func runDsinit(tc: Double, xpidot: Double) {
    let r = dscom
    let q22 = 1.7891679e-6
    let q31 = 2.1460748e-6
    let q33 = 2.2123015e-7
    let root22 = 1.7891679e-6
    let root44 = 7.3636953e-9
    let root54 = 2.1765803e-9
    let root32 = 3.7393792e-7
    let root52 = 1.1428639e-7
    let znl = 1.5835218e-4
    let zns = 1.19459e-5

    let nm = noUnkozai
    let em = eccoTLE
    let emsq = r.emsq
    let inclm = inclo
    let sinim = r.sinim
    let cosim = r.cosim

    irez = 0
    if nm < 0.0052359877 && nm > 0.0034906585 {
      irez = 1
    }
    if nm >= 8.26e-3 && nm <= 9.24e-3 && em >= 0.5 {
      irez = 2
    }

    // Solar contributions.
    let ses = r.ss1 * zns * r.ss5
    let sis = r.ss2 * zns * (r.sz11 + r.sz13)
    let sls = -zns * r.ss3 * (r.sz1 + r.sz3 - 14.0 - 6.0 * emsq)
    let sghs = r.ss4 * zns * (r.sz31 + r.sz33 - 6.0)
    var shs = -zns * r.ss2 * (r.sz21 + r.sz23)
    if inclm < 5.2359877e-2 || inclm > Double.pi - 5.2359877e-2 {
      shs = 0.0
    }
    if sinim != 0.0 {
      shs /= sinim
    }
    let sgs = sghs - cosim * shs

    // Lunar contributions.
    dedt = ses + r.s1 * znl * r.s5
    didt = sis + r.s2 * znl * (r.z11 + r.z13)
    dmdt = sls - znl * r.s3 * (r.z1 + r.z3 - 14.0 - 6.0 * emsq)
    let sghl = r.s4 * znl * (r.z31 + r.z33 - 6.0)
    var shll = -znl * r.s2 * (r.z21 + r.z23)
    if inclm < 5.2359877e-2 || inclm > Double.pi - 5.2359877e-2 {
      shll = 0.0
    }
    domdt = sgs + sghl
    dnodt = shs
    if sinim != 0.0 {
      domdt -= cosim / sinim * shll
      dnodt += shll / sinim
    }

    guard irez != 0 else { return }

    let theta = (gsto + tc * SGP4Model.rptim).truncatingRemainder(dividingBy: SGP4Model.twoPi)
    let aonv = pow(nm / SGP4Model.xke, SGP4Model.x2o3)

    if irez == 2 {
      // Half-day (12 h) resonance terms.
      let cosisq = cosim * cosim
      let emo = em
      let em2 = eccoTLE
      let emsqo = emsq
      let emsq2 = eccsq
      let eoc = em2 * emsq2

      let g201 = -0.306 - (em2 - 0.64) * 0.440
      var g211 = 0.0
      var g310 = 0.0
      var g322 = 0.0
      var g410 = 0.0
      var g422 = 0.0
      var g520 = 0.0
      if em2 <= 0.65 {
        g211 = 3.616 - 13.2470 * em2 + 16.2900 * emsq2
        g310 = -19.302 + 117.3900 * em2 - 228.4190 * emsq2 + 156.5910 * eoc
        g322 = -18.9068 + 109.7927 * em2 - 214.6334 * emsq2 + 146.5816 * eoc
        g410 = -41.122 + 242.6940 * em2 - 471.0940 * emsq2 + 313.9530 * eoc
        g422 = -146.407 + 841.8800 * em2 - 1629.014 * emsq2 + 1083.4350 * eoc
        g520 = -532.114 + 3017.977 * em2 - 5740.032 * emsq2 + 3708.276 * eoc
      } else {
        g211 = -72.099 + 331.819 * em2 - 508.738 * emsq2 + 266.724 * eoc
        g310 = -346.844 + 1582.851 * em2 - 2415.925 * emsq2 + 1246.113 * eoc
        g322 = -342.585 + 1554.908 * em2 - 2366.899 * emsq2 + 1215.972 * eoc
        g410 = -1052.797 + 4758.686 * em2 - 7193.992 * emsq2 + 3651.957 * eoc
        g422 = -3581.690 + 16178.110 * em2 - 24462.770 * emsq2 + 12422.520 * eoc
        if em2 > 0.715 {
          g520 = -5149.66 + 29936.92 * em2 - 54087.36 * emsq2 + 31324.56 * eoc
        } else {
          g520 = 1464.74 - 4664.75 * em2 + 3763.64 * emsq2
        }
      }

      var g533 = 0.0
      var g521 = 0.0
      var g532 = 0.0
      if em2 < 0.7 {
        g533 = -919.22770 + 4988.6100 * em2 - 9064.7700 * emsq2 + 5542.21 * eoc
        g521 = -822.71072 + 4568.6173 * em2 - 8491.4146 * emsq2 + 5337.524 * eoc
        g532 = -853.66600 + 4690.2500 * em2 - 8624.7700 * emsq2 + 5341.4 * eoc
      } else {
        g533 = -37995.780 + 161616.52 * em2 - 229838.20 * emsq2 + 109377.94 * eoc
        g521 = -51752.104 + 218913.95 * em2 - 309468.16 * emsq2 + 146349.42 * eoc
        g532 = -40023.880 + 170470.89 * em2 - 242699.48 * emsq2 + 115605.82 * eoc
      }

      let sini2 = sinim * sinim
      let f220 = 0.75 * (1.0 + 2.0 * cosim + cosisq)
      let f221 = 1.5 * sini2
      let f321 = 1.875 * sinim * (1.0 - 2.0 * cosim - 3.0 * cosisq)
      let f322 = -1.875 * sinim * (1.0 + 2.0 * cosim - 3.0 * cosisq)
      let f441 = 35.0 * sini2 * f220
      let f442 = 39.3750 * sini2 * sini2
      let f522 =
        9.84375 * sinim
        * (sini2 * (1.0 - 2.0 * cosim - 5.0 * cosisq)
          + 0.33333333 * (-2.0 + 4.0 * cosim + 6.0 * cosisq))
      let f523 =
        sinim
        * (4.92187512 * sini2 * (-2.0 - 4.0 * cosim + 10.0 * cosisq)
          + 6.56250012 * (1.0 + 2.0 * cosim - 3.0 * cosisq))
      let f542 =
        29.53125 * sinim
        * (2.0 - 8.0 * cosim + cosisq * (-12.0 + 8.0 * cosim + 10.0 * cosisq))
      let f543 =
        29.53125 * sinim
        * (-2.0 - 8.0 * cosim + cosisq * (12.0 + 8.0 * cosim - 10.0 * cosisq))

      let xno2 = nm * nm
      let ainv2 = aonv * aonv
      var temp1 = 3.0 * xno2 * ainv2
      var temp = temp1 * root22
      d2201 = temp * f220 * g201
      d2211 = temp * f221 * g211
      temp1 *= aonv
      temp = temp1 * root32
      d3210 = temp * f321 * g310
      d3222 = temp * f322 * g322
      temp1 *= aonv
      temp = 2.0 * temp1 * root44
      d4410 = temp * f441 * g410
      d4422 = temp * f442 * g422
      temp1 *= aonv
      temp = temp1 * root52
      d5220 = temp * f522 * g520
      d5232 = temp * f523 * g532
      temp = 2.0 * temp1 * root54
      d5421 = temp * f542 * g521
      d5433 = temp * f543 * g533

      xlamo = (mo + nodeo + nodeo - theta - theta).truncatingRemainder(
        dividingBy: SGP4Model.twoPi)
      xfact = mdot + dmdt + 2.0 * (nodedot + dnodt - SGP4Model.rptim) - noUnkozai
      _ = emo
      _ = emsqo
    }

    if irez == 1 {
      // Synchronous (24 h) resonance terms.
      let g200 = 1.0 + emsq * (-2.5 + 0.8125 * emsq)
      let g310 = 1.0 + 2.0 * emsq
      let g300 = 1.0 + emsq * (-6.0 + 6.60937 * emsq)
      let f220 = 0.75 * (1.0 + cosim) * (1.0 + cosim)
      let f311 = 0.9375 * sinim * sinim * (1.0 + 3.0 * cosim) - 0.75 * (1.0 + cosim)
      var f330 = 1.0 + cosim
      f330 = 1.875 * f330 * f330 * f330

      del1 = 3.0 * nm * nm * aonv * aonv
      del2 = 2.0 * del1 * f220 * g200 * q22
      del3 = 3.0 * del1 * f330 * g300 * q33 * aonv
      del1 = del1 * f311 * g310 * q31 * aonv

      xlamo = (mo + nodeo + argpo - theta).truncatingRemainder(dividingBy: SGP4Model.twoPi)
      xfact = mdot + xpidot - SGP4Model.rptim + dmdt + domdt + dnodt - noUnkozai
    }

    xli = xlamo
    xni = noUnkozai
    atime = 0.0
  }

  /// Deep space secular effects, integrating the resonance terms (dspace).
  func runDspace(
    t: Double,
    em: inout Double, argpm: inout Double, inclm: inout Double,
    mm: inout Double, nodem: inout Double, nm: inout Double
  ) {
    let fasx2 = 0.13130908
    let fasx4 = 2.8843198
    let fasx6 = 0.37448087
    let g22 = 5.7686396
    let g32 = 0.95240898
    let g44 = 1.8014998
    let g52 = 1.0508330
    let g54 = 4.4108898
    let stepp = 720.0
    let stepn = -720.0
    let step2 = 259200.0

    var dndt = 0.0
    let theta = (gsto + t * SGP4Model.rptim).truncatingRemainder(dividingBy: SGP4Model.twoPi)

    em += dedt * t
    inclm += didt * t
    argpm += domdt * t
    nodem += dnodt * t
    mm += dmdt * t

    guard irez != 0 else { return }

    // Restart the integration if the requested time moved backwards or jumped.
    if atime == 0.0 || t * atime <= 0.0 || abs(t) < abs(atime) {
      atime = 0.0
      xni = noUnkozai
      xli = xlamo
    }
    let delt = t > 0.0 ? stepp : stepn

    var xndt = 0.0
    var xldot = 0.0
    var xnddt = 0.0
    var ft = 0.0

    while true {
      if irez != 2 {
        xndt =
          del1 * sin(xli - fasx2) + del2 * sin(2.0 * (xli - fasx4))
          + del3 * sin(3.0 * (xli - fasx6))
        xldot = xni + xfact
        xnddt =
          del1 * cos(xli - fasx2) + 2.0 * del2 * cos(2.0 * (xli - fasx4))
          + 3.0 * del3 * cos(3.0 * (xli - fasx6))
        xnddt *= xldot
      } else {
        let xomi = argpo + argpdot * atime
        let x2omi = xomi + xomi
        let x2li = xli + xli
        xndt =
          d2201 * sin(x2omi + xli - g22) + d2211 * sin(xli - g22)
          + d3210 * sin(xomi + xli - g32) + d3222 * sin(-xomi + xli - g32)
          + d4410 * sin(x2omi + x2li - g44) + d4422 * sin(x2li - g44)
          + d5220 * sin(xomi + xli - g52) + d5232 * sin(-xomi + xli - g52)
          + d5421 * sin(xomi + x2li - g54) + d5433 * sin(-xomi + x2li - g54)
        xldot = xni + xfact
        xnddt =
          d2201 * cos(x2omi + xli - g22) + d2211 * cos(xli - g22)
          + d3210 * cos(xomi + xli - g32) + d3222 * cos(-xomi + xli - g32)
          + d5220 * cos(xomi + xli - g52) + d5232 * cos(-xomi + xli - g52)
          + 2.0
          * (d4410 * cos(x2omi + x2li - g44) + d4422 * cos(x2li - g44)
            + d5421 * cos(xomi + x2li - g54) + d5433 * cos(-xomi + x2li - g54))
        xnddt *= xldot
      }

      if abs(t - atime) >= stepp {
        xli = xli + xldot * delt + xndt * step2
        xni = xni + xndt * delt + xnddt * step2
        atime += delt
      } else {
        ft = t - atime
        break
      }
    }

    nm = xni + xndt * ft + xnddt * ft * ft * 0.5
    let xl = xli + xldot * ft + xndt * ft * ft * 0.5

    if irez != 1 {
      mm = xl - 2.0 * nodem + 2.0 * theta
    } else {
      mm = xl - nodem - argpm + theta
    }
    dndt = nm - noUnkozai
    nm = noUnkozai + dndt
  }
}

// MARK: - Propagation

extension SGP4Model {

  /// Propagate to `minutesSinceEpoch`, returning position (km) and velocity
  /// (km/s) in the TEME frame.
  func propagate(minutesSinceEpoch t: Double) throws -> SatelliteState {
    let vkmpersec = SGP4Model.radiusEarthKm * SGP4Model.xke / 60.0

    // Secular gravity and atmospheric drag.
    let xmdf = mo + mdot * t
    let argpdf = argpo + argpdot * t
    let nodedf = nodeo + nodedot * t
    var argpm = argpdf
    var mm = xmdf
    let t2 = t * t
    var nodem = nodedf + nodecf * t2
    var tempa = 1.0 - cc1 * t
    var tempe = bstar * cc4 * t
    var templ = t2cof * t2

    if !isimp {
      let delomg = omgcof * t
      let delmTemp = 1.0 + eta * cos(xmdf)
      let delm = xmcof * (delmTemp * delmTemp * delmTemp - delmo)
      let temp = delomg + delm
      mm = xmdf + temp
      argpm = argpdf - temp
      let t3 = t2 * t
      let t4 = t3 * t
      tempa = tempa - d2 * t2 - d3 * t3 - d4 * t4
      tempe += bstar * cc5 * (sin(mm) - sinmao)
      templ = templ + t3cof * t3 + t4 * (t4cof + t * t5cof)
    }

    var nm = noUnkozai
    var em = eccoTLE
    var inclm = inclo

    if method == .deepSpace {
      runDspace(
        t: t, em: &em, argpm: &argpm, inclm: &inclm, mm: &mm, nodem: &nodem, nm: &nm)
    }

    guard nm > 0.0 else {
      throw PropagationError.orbitDecayed
    }

    let am = pow(SGP4Model.xke / nm, SGP4Model.x2o3) * tempa * tempa
    nm = SGP4Model.xke / pow(am, 1.5)
    em -= tempe

    guard em < 1.0, em >= -0.001 else {
      throw PropagationError.orbitDecayed
    }
    if em < 1.0e-6 {
      em = 1.0e-6
    }

    mm += noUnkozai * templ
    var xlm = mm + argpm + nodem

    nodem = nodem.truncatingRemainder(dividingBy: SGP4Model.twoPi)
    argpm = argpm.truncatingRemainder(dividingBy: SGP4Model.twoPi)
    xlm = xlm.truncatingRemainder(dividingBy: SGP4Model.twoPi)
    mm = (xlm - argpm - nodem).truncatingRemainder(dividingBy: SGP4Model.twoPi)

    // Long period periodics.
    var ep = em
    var xincp = inclm
    var argpp = argpm
    var nodep = nodem
    var mp = mm
    var sinip = sin(xincp)
    var cosip = cos(xincp)
    var localAycof = aycof
    var localXlcof = xlcof

    if method == .deepSpace {
      runDpper(
        t: t, initializing: false, ep: &ep, inclp: &xincp, nodep: &nodep, argpp: &argpp,
        mp: &mp)

      if xincp < 0.0 {
        xincp = -xincp
        nodep += Double.pi
        argpp -= Double.pi
      }
      guard ep >= 0.0, ep <= 1.0 else {
        throw PropagationError.orbitDecayed
      }

      sinip = sin(xincp)
      cosip = cos(xincp)
      localAycof = -0.5 * SGP4Model.j3oj2 * sinip
      if abs(cosip + 1.0) > 1.5e-12 {
        localXlcof = -0.25 * SGP4Model.j3oj2 * sinip * (3.0 + 5.0 * cosip) / (1.0 + cosip)
      } else {
        localXlcof = -0.25 * SGP4Model.j3oj2 * sinip * (3.0 + 5.0 * cosip) / 1.5e-12
      }
    }

    if ep < 1.0e-6 {
      ep = 1.0e-6
    }

    let axnl = ep * cos(argpp)
    let temp = 1.0 / (am * (1.0 - ep * ep))
    let aynl = ep * sin(argpp) + temp * localAycof
    let xl = mp + argpp + nodep + temp * localXlcof * axnl

    // Kepler's equation.
    let u = (xl - nodep).truncatingRemainder(dividingBy: SGP4Model.twoPi)
    var eo1 = u
    var tem5 = 9999.9
    var ktr = 1
    var sineo1 = 0.0
    var coseo1 = 0.0
    while abs(tem5) >= 1.0e-12 && ktr <= 10 {
      sineo1 = sin(eo1)
      coseo1 = cos(eo1)
      tem5 = 1.0 - coseo1 * axnl - sineo1 * aynl
      tem5 = (u - aynl * coseo1 + axnl * sineo1 - eo1) / tem5
      if abs(tem5) >= 0.95 {
        tem5 = tem5 > 0.0 ? 0.95 : -0.95
      }
      eo1 += tem5
      ktr += 1
    }
    sineo1 = sin(eo1)
    coseo1 = cos(eo1)

    // Short period preliminary quantities.
    let ecose = axnl * coseo1 + aynl * sineo1
    let esine = axnl * sineo1 - aynl * coseo1
    let el2 = axnl * axnl + aynl * aynl
    let pl = am * (1.0 - el2)

    guard pl >= 0.0 else {
      throw PropagationError.orbitDecayed
    }

    let rl = am * (1.0 - ecose)
    let rdotl = sqrt(am) * esine / rl
    let rvdotl = sqrt(pl) / rl
    let betal = sqrt(1.0 - el2)
    let tempEsine = esine / (1.0 + betal)
    let sinu = am / rl * (sineo1 - aynl - axnl * tempEsine)
    let cosu = am / rl * (coseo1 - axnl + aynl * tempEsine)
    var su = atan2(sinu, cosu)
    let sin2u = (cosu + cosu) * sinu
    let cos2u = 1.0 - 2.0 * sinu * sinu
    let temp1 = 0.5 * SGP4Model.j2 * (1.0 / pl)
    let temp2 = temp1 * (1.0 / pl)

    // Update for short period periodics.
    let localCon41 = 3.0 * cosip * cosip - 1.0
    let localX1mth2 = 1.0 - cosip * cosip
    let localX7thm1 = 7.0 * cosip * cosip - 1.0

    let mrt = rl * (1.0 - 1.5 * temp2 * betal * localCon41) + 0.5 * temp1 * localX1mth2 * cos2u
    su = su - 0.25 * temp2 * localX7thm1 * sin2u
    let xnode = nodep + 1.5 * temp2 * cosip * sin2u
    let xinc = xincp + 1.5 * temp2 * cosip * sinip * cos2u
    let mvt = rdotl - nm * temp1 * localX1mth2 * sin2u / SGP4Model.xke
    let rvdot =
      rvdotl + nm * temp1 * (localX1mth2 * cos2u + 1.5 * localCon41) / SGP4Model.xke

    // Orientation vectors.
    let sinsu = sin(su)
    let cossu = cos(su)
    let snod = sin(xnode)
    let cnod = cos(xnode)
    let sini = sin(xinc)
    let cosi = cos(xinc)
    let xmx = -snod * cosi
    let xmy = cnod * cosi
    let ux = xmx * sinsu + cnod * cossu
    let uy = xmy * sinsu + snod * cossu
    let uz = sini * sinsu
    let vx = xmx * cossu - cnod * sinsu
    let vy = xmy * cossu - snod * sinsu
    let vz = sini * cossu

    let position = Vector3D(
      x: mrt * ux * SGP4Model.radiusEarthKm,
      y: mrt * uy * SGP4Model.radiusEarthKm,
      z: mrt * uz * SGP4Model.radiusEarthKm
    )
    let velocity = Vector3D(
      x: (mvt * ux + rvdot * vx) * vkmpersec,
      y: (mvt * uy + rvdot * vy) * vkmpersec,
      z: (mvt * uz + rvdot * vz) * vkmpersec
    )

    guard mrt >= 1.0 else {
      throw PropagationError.orbitDecayed
    }

    return SatelliteState(
      position: position, velocity: velocity, minutesSinceEpoch: t)
  }
}
