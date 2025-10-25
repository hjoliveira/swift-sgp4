# Test Status for swift-sgp4

## Summary

As of Phase 2 completion, the following tests have been enabled and are ready to run:

## SGP4 Propagation Tests (✅ ENABLED)

### Near-Earth SGP4 Tests

All near-earth SGP4 tests have been enabled in `SwiftSGP4Tests/SGP4PropagatorTests.swift`:

1. **testSatellite00005_Propagation** ✅ ENABLED
   - Satellite: 00005 (58002B)
   - Orbit type: Highly elliptical (e=0.1859667)
   - Mean motion: 10.82 revs/day
   - Test points: 0, 360, 720 minutes (3 states)
   - Purpose: Validates highly eccentric orbits

2. **testSatellite06251_Propagation** ✅ ENABLED
   - Satellite: 06251 (62025E - DELTA 1 DEB)
   - Orbit type: Near-earth LEO with normal drag
   - Perigee: 377.26 km
   - Mean motion: 15.56 revs/day
   - Test points: 0, 120 minutes (2 states)
   - Purpose: Validates typical LEO satellite with atmospheric drag

3. **testSatellite11801_NonStandardFormat** ✅ ENABLED
   - Satellite: 11801 (TDRSS 3)
   - Orbit type: Near-geostationary
   - Special: Non-standard TLE format (omits ephemeris type)
   - Test points: 0 minutes (1 state)
   - Purpose: Validates edge case TLE parsing and GEO-like orbits

4. **testLowEccentricityOrbit** ✅ ENABLED
   - Satellite: 14128 (EUTELSAT 1-F1/ECS1)
   - Orbit type: Near-circular, near-geostationary (e=0.0002258)
   - Test points: 0 minutes (1 state)
   - Purpose: Validates nearly circular orbits

5. **testLongTermPropagationAccuracy** ✅ ENABLED
   - Satellite: 06251 (same as test #2)
   - Test points: 0, 360, 720, 1080, 1440, 1800, 2160, 2520, 2880 minutes
   - Purpose: Validates propagation accuracy over 2 days (multiple orbits)
   - Sanity checks: Position magnitude in valid LEO range (6371-8000 km)

### Deep-Space SDP4 Tests

6. **testSatellite28057_DeepSpace** ⚠️ SKIPPED
   - Satellite: 28057 (04632A - MOLNIYA 2-14)
   - Orbit type: Deep space, 12-hour resonant (e=0.7)
   - Status: **SKIPPED - SDP4 not implemented**
   - Note: Will be implemented in Phase 6

## TLE Parsing Tests (✅ PASSING)

All TLE parsing tests in `SwiftSGP4Tests/SwiftSGP4Tests.swift` and `SwiftSGP4Tests/TLEValidationTests.swift` are already passing:

- ✅ testParseTLEFromFile
- ✅ testParseTLEFromLines
- ✅ All TLE validation tests

## Coordinate Conversion Tests (⚠️ SKIPPED)

Tests in `SwiftSGP4Tests/CoordinateConversionTests.swift` remain skipped (9 tests):

- ⚠️ All coordinate conversion tests (TEME ↔ Geodetic, etc.)
- Note: Coordinate conversion is planned for future phases

## Expected Test Results

### What Should Pass

The SGP4 implementation should match Vallado's reference values within:

- **Position accuracy**: ±1e-6 km (±1 millimeter) in test assertions
- **Velocity accuracy**: ±1e-9 km/s (±1 mm/s) in test assertions

These are the assertion tolerances - actual SGP4 algorithm accuracy is:
- ~1-2 km position error within days of epoch
- Error increases with time from epoch due to atmospheric variations

### How to Run Tests

```bash
# Build the project
swift build

# Run all tests
swift test

# Run specific test
swift test --filter SGP4PropagatorTests

# Run with verbose output
swift test -v
```

### Expected Output

If all tests pass, you should see:

```
Test Suite 'All tests' passed at 2025-10-22 ...
     Executed 11 tests, with 0 failures (0 unexpected) in 0.XXX (0.XXX) seconds
```

Breakdown:
- TLE parsing tests: 2+ tests (already passing)
- TLE validation tests: Multiple tests (already passing)
- SGP4 propagator tests: 5 enabled + 1 skipped deep-space test

### If Tests Fail

Potential issues and debugging steps:

1. **Initialization failures**
   - Check: `SGP4State.init(from:)` calculations
   - Verify: Constants in `SGP4Constants.swift` match Vallado's values
   - Issue: Incorrect drag coefficient computation (C1-C5)

2. **Position/velocity mismatches**
   - Check: Kepler equation solver convergence
   - Verify: Short-period and long-period perturbation calculations
   - Issue: Sign errors in coordinate transformations

3. **Large errors at t=0 (epoch)**
   - Check: Initialization of orbital elements
   - Issue: Incorrect unit conversions (degrees→radians, revs/day→rad/min)

4. **Errors increasing with time**
   - Check: Secular rate calculations (drag, J2 perturbations)
   - Issue: Incorrect `dotArgumentOfPerigee` or `dotRightAscension`

## Validation Data Sources

All test data comes from:

**Vallado, D. A., Crawford, P., Hujsak, R., & Kelso, T. S. (2006)**
*"Revisiting Spacetrack Report #3"* AIAA 2006-6753

Official test data: https://celestrak.org/publications/AIAA/2006-6753/

The test vectors include TLEs and expected position/velocity at various
times, verified against multiple independent SGP4 implementations.

## Next Steps

1. **Run the tests**: `swift test`
2. **Analyze failures**: Compare actual vs expected values
3. **Debug algorithm**: Check calculations step-by-step
4. **Iterate**: Fix issues and re-test
5. **Validate**: Ensure all near-earth tests pass within tolerance

## Current Status

- ✅ Phase 1: Modernization (COMPLETE)
- ✅ Phase 2: SGP4 Implementation (COMPLETE - NEEDS VALIDATION)
- 🔄 Phase 3: Testing (IN PROGRESS - Tests enabled, awaiting validation)
- ⏳ Phase 4: Documentation
- ⏳ Phase 5: Infrastructure
- ⏳ Phase 6: Advanced Features (SDP4, etc.)

---

**Last Updated**: 2025-10-22
**Test Suite**: 5 SGP4 near-earth tests enabled, 1 deep-space test skipped
**Ready to run**: Yes (requires Swift 6.x)
