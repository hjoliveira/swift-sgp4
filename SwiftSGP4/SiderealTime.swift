import Foundation

/// Greenwich Mean Sidereal Time and Julian Date utilities.
///
/// A single implementation shared by the coordinate converter and the
/// deep-space propagator, so the two can never drift apart.
enum SiderealTime {

  /// Julian Date of the Unix epoch (1970-01-01 00:00:00 UTC)
  static let unixEpochJulianDate = 2_440_587.5

  /// Julian Date of J2000.0 (2000-01-01 12:00:00 TT)
  static let j2000JulianDate = 2_451_545.0

  static let secondsPerDay = 86_400.0

  /// Convert a `Date` to a Julian Date.
  /// - Parameter date: The instant to convert.
  /// - Returns: Julian Date.
  static func julianDate(from date: Date) -> Double {
    return unixEpochJulianDate + date.timeIntervalSince1970 / secondsPerDay
  }

  /// Greenwich Mean Sidereal Time for a Julian Date (IAU 1982).
  ///
  /// The polynomial is evaluated at the full Julian Date, so it already
  /// accounts for the time of day. Adding the day fraction separately would
  /// double-count it and rotate the result by up to 180 degrees.
  ///
  /// - Parameter julianDate: Julian Date of the instant.
  /// - Returns: GMST in radians, normalized to [0, 2π).
  static func greenwichMeanSiderealTime(julianDate: Double) -> Double {
    let tUT1 = (julianDate - j2000JulianDate) / 36525.0

    // Result in seconds of time.
    var gmst =
      67310.54841 + (876600.0 * 3600.0 + 8640184.812866) * tUT1
      + 0.093104 * tUT1 * tUT1
      - 6.2e-6 * tUT1 * tUT1 * tUT1

    // 240 seconds of time per degree.
    gmst = (gmst / 240.0) * .pi / 180.0

    gmst = gmst.truncatingRemainder(dividingBy: 2.0 * .pi)
    if gmst < 0.0 {
      gmst += 2.0 * .pi
    }
    return gmst
  }

  /// Greenwich Mean Sidereal Time for a `Date`.
  /// - Parameter date: The instant to evaluate.
  /// - Returns: GMST in radians, normalized to [0, 2π).
  static func greenwichMeanSiderealTime(date: Date) -> Double {
    return greenwichMeanSiderealTime(julianDate: julianDate(from: date))
  }
}
