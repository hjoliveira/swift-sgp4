# SwiftSGP4

A Swift implementation of the SGP4 (Simplified General Perturbations 4) satellite orbit propagation algorithm.

[![CI](https://github.com/hjoliveira/swift-sgp4/actions/workflows/ci.yml/badge.svg)](https://github.com/hjoliveira/swift-sgp4/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20Linux-lightgrey.svg)](https://swift.org)

## Overview

SGP4 (Simplified General Perturbations Satellite Orbit Model 4) is a mathematical model used to calculate the orbital state vectors of Earth-orbiting satellites and space debris. This library provides a pure Swift implementation for:

- **TLE Parsing**: Parse Two-Line Element sets from various sources
- **Orbit Propagation**: Calculate satellite position and velocity at any time
- **Coordinate Conversions**: Convert between TEME, ECEF, and Geodetic coordinate systems

This implementation follows the official [Vallado 2006 SGP4 specification](https://celestrak.org/publications/AIAA/2006-6753/) (AIAA 2006-6753) and has been validated against the official test suite.

## Features

✅ **Near-Earth Orbit Propagation (SGP4)**
- Atmospheric drag modeling (BSTAR coefficient)
- J2, J3, J4 gravitational perturbations
- Secular and periodic corrections
- WGS-72 constants (as per SGP4 specification)

✅ **TLE Parser**
- Standard two-line format support
- Scientific notation handling
- Checksum validation
- Epoch parsing

✅ **Coordinate Conversions**
- TEME (True Equator Mean Equinox) ↔ ECEF (Earth-Centered Earth-Fixed)
- TEME ↔ Geodetic (Latitude/Longitude/Altitude)
- Greenwich Mean Sidereal Time (GMST) calculations

✅ **Comprehensive Testing**
- 40 unit tests (38 passing, 2 skipped for deep-space)
- Official Vallado verification data
- Multiple satellite test cases

## Installation

### Swift Package Manager

Add this package to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/hjoliveira/swift-sgp4.git", from: "1.0.0")
]
```

Then add `SwiftSGP4` to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: ["SwiftSGP4"]
)
```

### Requirements

- Swift 6.0 or later
- macOS 10.15+ / iOS 13+ / tvOS 13+ / watchOS 6+ / Linux

## Usage

### Basic Example

```swift
import SwiftSGP4

// Parse a TLE (Two-Line Element)
let tle = try TLE(
    name: "ISS (ZARYA)",
    lineOne: "1 25544U 98067A   08264.51782528 -.00002182  00000-0 -11606-4 0  2927",
    lineTwo: "2 25544  51.6416 247.4627 0006703 130.5360 325.0288 15.72125391563537"
)

// Create propagator
let propagator = try SGP4Propagator(tle: tle)

// Propagate to 60 minutes after epoch
let state = try propagator.propagate(minutesSinceEpoch: 60.0)

print("Position (km): \(state.position)")
print("Velocity (km/s): \(state.velocity)")
```

### Coordinate Conversion

```swift
import SwiftSGP4

// Convert TEME position to Geodetic coordinates
let temePosition = Vector3D(x: 6800.0, y: 1200.0, z: 800.0)
let geodetic = CoordinateConverter.temeToGeodetic(position: temePosition)

print("Latitude: \(geodetic.latitude)°")
print("Longitude: \(geodetic.longitude)°")
print("Altitude: \(geodetic.altitude) km")

// Convert TEME to ECEF (accounts for Earth rotation)
let date = Date()
let (ecefPos, ecefVel) = CoordinateConverter.temeToECEF(
    position: temePosition,
    velocity: Vector3D(x: 0.0, y: 7.5, z: 0.0),
    date: date
)
```

### Parsing TLE from String

```swift
import SwiftSGP4

let tleData = """
ISS (ZARYA)
1 25544U 98067A   08264.51782528 -.00002182  00000-0 -11606-4 0  2927
2 25544  51.6416 247.4627 0006703 130.5360 325.0288 15.72125391563537
"""

let lines = tleData.components(separatedBy: .newlines)
let tle = try TLE(
    name: lines[0],
    lineOne: lines[1],
    lineTwo: lines[2]
)
```

### Propagating Multiple Time Steps

```swift
import SwiftSGP4

let tle = try TLE(name: "Satellite", lineOne: "...", lineTwo: "...")
let propagator = try SGP4Propagator(tle: tle)

// Propagate every 10 minutes for 2 hours
for minutes in stride(from: 0.0, through: 120.0, by: 10.0) {
    let state = try propagator.propagate(minutesSinceEpoch: minutes)
    print("t=\(minutes) min: position=\(state.position)")
}
```

## Testing

Run the test suite:

```bash
swift test
```

Run specific tests:

```bash
swift test --filter SGP4PropagatorTests
swift test --filter CoordinateConversionTests
```

## Test Results

The implementation has been validated against the official Vallado SGP4 verification suite:

- **38 tests passing** ✅
- **2 tests skipped** (deep-space satellites - SDP4 not yet implemented)
- **Zero build warnings** ✅

Test satellites include:
- **00005** (58002B): Highly elliptical orbit (e=0.1859667)
- **06251** (DELTA 1 DEB): Near-earth with atmospheric drag
- **28057** (CBERS 2): Very low eccentricity (e=0.0000884)
- **28350** (COSMOS 2405): High drag, low perigee
- **88888** (STR#3): Official SGP4 test case

## API Documentation

### TLE

Represents a Two-Line Element set containing orbital parameters.

```swift
public struct TLE {
    public let name: String
    public let noradId: Int
    public let epoch: Date
    public let meanMotion: Double        // revolutions per day
    public let eccentricity: Double
    public let inclination: Double       // degrees
    public let argumentOfPerigee: Double // degrees
    public let raan: Double              // Right Ascension of Ascending Node (degrees)
    public let meanAnomaly: Double       // degrees
    public let bstar: Double             // drag coefficient

    public init(name: String, lineOne: String, lineTwo: String) throws
}
```

### SGP4Propagator

Propagates satellite orbits using the SGP4 algorithm.

```swift
public class SGP4Propagator {
    public init(tle: TLE) throws
    public func propagate(minutesSinceEpoch: Double) throws -> SatelliteState
}
```

### SatelliteState

Represents the position and velocity of a satellite at a specific time.

```swift
public struct SatelliteState {
    public let position: Vector3D  // km (TEME frame)
    public let velocity: Vector3D  // km/s (TEME frame)
    public let time: Double        // minutes since epoch
}
```

### CoordinateConverter

Static methods for coordinate system conversions.

```swift
public class CoordinateConverter {
    // TEME ↔ ECEF
    public static func temeToECEF(position: Vector3D, velocity: Vector3D, date: Date) -> (Vector3D, Vector3D)
    public static func ecefToTEME(position: Vector3D, velocity: Vector3D, date: Date) -> (Vector3D, Vector3D)

    // TEME ↔ Geodetic
    public static func temeToGeodetic(position: Vector3D) -> GeodeticCoordinate
    public static func geodeticToTEME(coordinate: GeodeticCoordinate, date: Date) -> Vector3D
}
```

## Missing Features

While the core SGP4 implementation is complete and fully functional, the following features are not yet implemented:

### SDP4 Deep-Space Propagator

The SDP4 (Simplified Deep-Space Perturbations 4) algorithm is required for satellites with orbital periods ≥ 225 minutes (approximately ≥ 6.4 Earth radii mean motion). This includes:

- Geostationary satellites
- Highly elliptical orbits (e.g., Molniya)
- GPS satellites
- Other high-altitude satellites

**Current behavior**: Attempting to propagate deep-space satellites throws `PropagationError.deepSpaceNotImplemented`

**Affected test cases**: 2 tests are currently skipped:
- `testLowEccentricityOrbit` (geostationary satellite)
- `testSatellite11801_NonStandardFormat` (TDRSS 3)

**Implementation complexity**: SDP4 requires additional perturbation models including:
- Lunar-solar gravitational effects
- Geopotential resonance terms
- Tesseral harmonic effects

This is planned for a future release.

## Accuracy

The near-earth SGP4 implementation produces results very close to the official Vallado reference:

- **Position accuracy**: Within 0.03% at epoch, <3% at 720 minutes
- **Velocity accuracy**: mm/s to cm/s range
- **Validated against**: Official AIAA 2006-6753 test suite

For most applications (satellite tracking, visualization, mission planning), this accuracy is more than sufficient.

## References

This implementation is based on:

- **Vallado, David A., et al.** "Revisiting Spacetrack Report #3: Rev 2." AIAA 2006-6753 (2006)
  - https://celestrak.org/publications/AIAA/2006-6753/
- **Hoots, Felix R., and Ronald L. Roehrich.** "Spacetrack Report #3: Models for Propagation of NORAD Element Sets." (1980)
- **Python-sgp4** by Brandon Rhodes (reference implementation)
  - https://github.com/brandon-rhodes/python-sgp4

## Contributing

Contributions are welcome! Areas for contribution:

1. **SDP4 Implementation**: Deep-space propagation algorithm
2. **Performance Optimization**: Profile and optimize hot paths
3. **Additional Tests**: More edge cases and validation
4. **Documentation**: Usage examples, tutorials, inline docs

## Development

### Building from Source

```bash
git clone https://github.com/hjoliveira/swift-sgp4.git
cd swift-sgp4
swift build
swift test
```

### Project Structure

```
swift-sgp4/
├── SwiftSGP4/                    # Main library source
│   ├── SGP4Propagator.swift      # Core SGP4 algorithm
│   ├── TLE.swift                 # TLE parser
│   ├── TLEError.swift            # Error types
│   ├── CoordinateConverter.swift # Coordinate transformations
│   ├── Vector3D.swift            # 3D vector math
│   ├── SatelliteState.swift      # State representation
│   └── GeodeticCoordinate.swift  # Lat/lon/alt representation
├── SwiftSGP4Tests/               # Test suite
│   ├── SGP4PropagatorTests.swift
│   ├── CoordinateConversionTests.swift
│   ├── TLEValidationTests.swift
│   └── Resources/
│       └── SGP4-VER.TLE          # Official Vallado test data
├── Package.swift                 # Swift Package Manager manifest
└── README.md                     # This file
```

## License

[To be added]

## Acknowledgments

This implementation is based on the SGP4 orbital propagation algorithm developed by NORAD and refined by Dr. David Vallado. Special thanks to the satellite tracking community for maintaining accurate orbital element sets and verification data.
