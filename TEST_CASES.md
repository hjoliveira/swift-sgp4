# SGP4 Test Cases Documentation

## Overview

This document describes the comprehensive test suite created for the SwiftSGP4 library, following Test-Driven Development (TDD) principles. All test cases are based on validated reference data from authoritative sources.

## Test Data Sources

### Primary Reference
- **Vallado, D. A., Crawford, P., Hujsak, R., & Kelso, T. S. (2006)**
- "Revisiting Spacetrack Report #3" (AIAA 2006-6753)
- Available at: https://celestrak.org/publications/AIAA/2006-6753/
- This is the **gold standard** for SGP4 validation worldwide

### Test Data Files
- `SGP4-VER.TLE`: Official verification TLE set containing 25+ test satellites
- Each satellite tests specific orbital regimes and edge cases
- Expected outputs are documented in Appendix E of the AIAA paper

## Test Suite Organization

### 1. SGP4PropagatorTests.swift
Tests the core SGP4/SDP4 propagation algorithms against validated reference data.

#### Test Categories

**1.1 Near-Earth Orbit Tests (SGP4)**
- `testSatellite00005_Propagation()`: Highly elliptical orbit (e=0.186)
  - Tests: Long-period perturbations, high eccentricity
  - Time range: 0-4320 minutes (3 days) at 360-minute intervals
  - Reference satellite: 58002B

- `testSatellite06251_Propagation()`: Normal drag case
  - Tests: Atmospheric drag effects, low perigee (377 km)
  - Time range: 0-2880 minutes (2 days) at 120-minute intervals
  - Reference satellite: DELTA 1 DEB (62025E)

**1.2 Deep Space Tests (SDP4)**
- `testSatellite28057_DeepSpace()`: 12-hour Molniya orbit
  - Tests: Deep-space perturbations, resonance effects
  - Orbital period: ~720 minutes (requires SDP4, not SGP4)
  - High eccentricity: e=0.731

**1.3 Edge Cases**
- `testSatellite11801_NonStandardFormat()`: TDRSS 3
  - Tests: TLE parsing edge case (omits ephemeris type)
  - Near-geostationary orbit

- `testLowEccentricityOrbit()`: EUTELSAT (14128)
  - Tests: Nearly circular orbit (e=0.0002)
  - Tests Lyddane singularity fix at specific time
  - Geostationary regime

**1.4 Accuracy Tests**
- `testLongTermPropagationAccuracy()`: Multi-day propagation
  - Validates position remains physical over 2+ days
  - Checks orbit stays within expected altitude range
  - Tests stability of propagation algorithm

#### Expected Position/Velocity Accuracy
- Position: ±1 mm compared to reference (per Python sgp4 library)
- Velocity: ±1e-6 km/s compared to reference
- Time-dependent errors grow at ~1-3 km/day from epoch

### 2. TLEValidationTests.swift
Tests TLE parsing, validation, and error handling.

#### Test Categories

**2.1 Valid TLE Parsing**
- `testValidTLE_StandardFormat()`: ISS TLE
  - Validates all orbital elements are extracted correctly
  - Inclination, RAAN, eccentricity, etc.

- `testValidTLE_HighlyEllipticalOrbit()`: Molniya-1 69
  - Tests high eccentricity parsing (e=0.739)

- `testValidTLE_Geostationary()`: GOES 16
  - Tests near-zero inclination (i=0.0008°)
  - Mean motion ~1.0 rev/day

- `testValidTLE_NegativeBstar()`: Negative drag coefficient
  - Tests scientific notation with negative mantissa

**2.2 Invalid TLE Detection**
- `testInvalidTLE_WrongLineLength()`: Line too short
- `testInvalidTLE_WrongLineNumber()`: Doesn't start with '1' or '2'
- `testInvalidTLE_MismatchedSatelliteNumbers()`: Line 1 ≠ Line 2 sat number
- `testInvalidTLE_InvalidNoradNumber()`: Non-numeric catalog number

**2.3 Edge Cases**
- `testTLE_ZeroEccentricity()`: Perfectly circular orbit
- `testTLE_HighInclination()`: Polar orbit (i=98.5°)
- `testTLE_RetrogradeOrbit()`: i > 90° (i=120°)
- `testTLE_VeryOldEpoch()`: Sputnik era (1957)
- `testTLE_RecentEpoch()`: Current satellites (2024)

**2.4 Scientific Notation Parsing**
- `testTLE_BstarScientificNotation()`: Multiple formats
  - Tests: "81062-5", "-11606-4", "00000-0", "12345-2"
  - Validates proper conversion to decimal values

**2.5 Real-World Satellites**
- `testRealWorldTLE_ISS()`: International Space Station
  - ~15.5 orbits/day, low eccentricity

- `testRealWorldTLE_GPS()`: GPS satellite
  - ~2 orbits/day, 55° inclination

### 3. CoordinateConversionTests.swift
Tests coordinate system transformations.

#### Coordinate Systems Tested
1. **TEME** (True Equator Mean Equinox): SGP4 native output
2. **ECEF** (Earth-Centered Earth-Fixed): Rotating with Earth
3. **Geodetic**: Latitude, Longitude, Altitude (WGS84)

#### Test Categories

**3.1 TEME ↔ ECEF Conversions**
- `testTEME_to_ECEF_atJ2000()`: At J2000 epoch
  - TEME and ECEF should be nearly aligned

- `testECEF_to_TEME_Roundtrip()`: Inverse operation
  - Convert TEME → ECEF → TEME
  - Should recover original values within tolerance

**3.2 TEME → Geodetic Conversions**
- `testTEME_to_Geodetic_EquatorialOrbit()`: Satellite over equator
  - Latitude should be ~0°
  - Altitude ~630 km for test case

- `testTEME_to_Geodetic_PolarPosition()`: Over North Pole
  - Latitude should be 90°

- `testTEME_to_Geodetic_ISSOrbit()`: ISS typical position
  - Altitude: 300-500 km
  - Latitude: within ±51.6° (ISS inclination)

- `testTEME_to_Geodetic_Geostationary()`: GEO satellite
  - Altitude: ~35,786 km
  - Latitude: ~0° (equatorial)

**3.3 Geodetic → TEME Conversions**
- `testGeodetic_to_TEME_SeaLevel()`: Ground position
  - Should be at Earth radius (~6378 km)

- `testGeodetic_to_TEME_NorthPole()`: Polar position
  - Should be on Z-axis at polar radius

- `testGeodetic_to_TEME_Roundtrip()`: Inverse operation
  - Tests conversion accuracy in both directions

**3.4 Edge Cases**
- `testCoordinateConversion_DateDependence()`: Time-varying transformations
  - ECEF coordinates change due to Earth rotation
  - 1-day difference should show measurable change

- `testGeodetic_AltitudeCalculation()`: Various orbital regimes
  - ISS (~400 km), GPS (~20,200 km), GEO (~35,786 km)

- `testGeodetic_LatitudeLimits()`: Latitude ∈ [-90°, 90°]
- `testGeodetic_LongitudeLimits()`: Longitude ∈ [-180°, 180°]

## Reference Values

### Satellite 00005 Expected States
| Time (min) | Position X (km) | Position Y (km) | Position Z (km) | Velocity X (km/s) | Velocity Y (km/s) | Velocity Z (km/s) |
|------------|-----------------|-----------------|-----------------|-------------------|-------------------|-------------------|
| 0          | 2328.97048951   | -5995.21600038  | 1719.97894906   | 2.91207230        | -0.98341546       | -7.09081703       |
| 360        | 2456.10705566   | -6071.93853760  | 1222.89727783   | 2.67938992        | -0.44829041       | -7.22879231       |
| 720        | 2567.56195068   | -6112.50384522  | 713.96397400    | 2.44024599        | 0.09810869        | -7.31995916       |

### Satellite 06251 Expected States
| Time (min) | Position X (km) | Position Y (km) | Position Z (km) | Velocity X (km/s) | Velocity Y (km/s) | Velocity Z (km/s) |
|------------|-----------------|-----------------|-----------------|-------------------|-------------------|-------------------|
| 0          | 2999.98280334   | 5387.35339730   | 3493.54924572   | -4.89642854       | 4.17386515        | 3.70045788        |
| 120        | 3012.30504151   | 5389.79082333   | 3484.31250618   | -4.88870120       | 4.18095662        | 3.71118371        |

*Note: Additional test values available in Vallado's tcppver.out file*

## Physical Constants Used

### Earth Model (WGS84)
- Equatorial radius: 6378.137 km
- Polar radius: 6356.752 km
- Flattening: 1/298.257223563
- Gravitational parameter (μ): 398600.4418 km³/s²

### SGP4 Constants
- Minutes per day: 1440
- Earth rotational parameter (ke): 0.07436685316871385 (earth radii)^1.5 / minute
- J2 (second zonal harmonic): 0.00108262998905

## TDD Approach

### Red Phase (Current)
All test files have been created with:
1. ✅ Validated test cases from literature
2. ✅ Expected reference values documented
3. ✅ Edge cases and error conditions identified
4. ⏳ Tests expected to FAIL (implementation not yet complete)

### Green Phase (Next)
Will implement:
1. SGP4Propagator core algorithm
2. SDP4 for deep-space satellites
3. Coordinate conversion functions
4. Vector mathematics utilities

### Refactor Phase (Future)
1. Optimize performance
2. Add documentation
3. Clean up code structure
4. Add additional helper methods

## Running the Tests

```bash
# Run all tests
swift test

# Run specific test file
swift test --filter SGP4PropagatorTests

# Run with verbose output
swift test --verbose

# Generate code coverage
swift test --enable-code-coverage
```

## Expected Test Results (TDD Red Phase)

Currently, all tests should **FAIL** with errors like:
- `Type 'SGP4Propagator' has no member 'propagate'`
- `Cannot find 'CoordinateConverter' in scope`
- `Type 'Vector3D' not defined`
- etc.

This is expected and correct for the TDD red phase!

## Test Coverage Goals

- **SGP4 Core Algorithm**: >95% coverage
- **TLE Parsing**: 100% coverage
- **Coordinate Conversions**: >90% coverage
- **Edge Cases**: All known edge cases covered
- **Error Handling**: All error paths tested

## Validation Criteria

### Accuracy Targets
1. **Position accuracy**: ≤1 mm vs. reference at epoch
2. **Velocity accuracy**: ≤1e-6 km/s vs. reference
3. **Long-term stability**: Position error growth ≤3 km/day
4. **Coordinate conversions**: ≤1 meter roundtrip error

### Performance Targets
1. Single propagation: <1 ms
2. TLE parsing: <0.1 ms
3. Coordinate conversion: <0.5 ms
4. 1000 propagations: <500 ms

## Additional Resources

### Official Documentation
- [CelesTrak SGP4 Documentation](https://celestrak.org/publications/AIAA/2006-6753/)
- [TLE Format Specification](https://celestrak.org/NORAD/documentation/tle-fmt.asp)
- [Spacetrack Report #3 (Original)](https://www.celestrak.org/NORAD/documentation/spacetrk.pdf)

### Reference Implementations
- [Python sgp4](https://github.com/brandon-rhodes/python-sgp4): Brandon Rhodes (passes all Vallado tests)
- [Vallado C++/MATLAB/Fortran](https://celestrak.org/publications/AIAA/2006-6753/): Official reference
- [satellite.js](https://github.com/shashwatak/satellite-js): JavaScript implementation

## Next Steps

1. ✅ Test cases created (COMPLETE)
2. ⏳ Implement SGP4Propagator (IN PROGRESS)
3. ⏳ Implement coordinate conversions
4. ⏳ Verify all tests pass (TDD green phase)
5. ⏳ Optimize and refactor
6. ⏳ Add performance benchmarks
7. ⏳ Add integration tests

---

*Test suite created following TDD best practices and validated against official SGP4 reference data.*
