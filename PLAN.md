# SGP4 Implementation Plan

## Current Status (2025-10-25)

### ✅ Completed
- **TLE Parser**: Fully functional (16/16 tests passing)
- **Coordinate Conversions**: 13/14 tests passing
  - TEME ↔ Geodetic conversions implemented
  - Only missing: TEME ↔ ECEF with GMST (Earth rotation)
- **Data Structures**: Vector3D, SatelliteState, GeodeticCoordinate all complete
- **Test Infrastructure**: Official Vallado test data ready in `SGP4-VER.TLE`

### ❌ Not Implemented
- **SGP4 Propagator**: Currently just `fatalError()` stub
- All 7 SGP4PropagatorTests crash waiting for implementation

## Next Steps: Implement SGP4 Propagation Algorithm

### Branch
Working on: `claude/implement-sgp4-propagator`

### Implementation Strategy: Option A (Agreed)

**Use python-sgp4 as reference** ⭐ (Recommended approach)
- Reference: https://github.com/brandon-rhodes/python-sgp4
- Most widely used, well-tested implementation
- Translate to Swift idiomatically (not line-by-line port)
- Validate against test cases incrementally

### Algorithm Phases

#### Phase 1: Constants & Initialization
```swift
// Physical constants (WGS-72, NOT WGS-84!)
// - Earth radius: 6378.135 km (WGS-72)
// - Gravitational parameter: ke = 0.0743669161
// - J2, J3, J4 gravity harmonics
// Convert TLE orbital elements to internal working variables
```

#### Phase 2: Near-Earth Detection
```swift
// If mean motion < 225 min period (~6.4 revs/day): use SGP4
// Otherwise: use SDP4 (deep-space)
// START WITH NEAR-EARTH ONLY, add deep-space later
```

#### Phase 3: Core SGP4 Algorithm Steps

**Step 1: Secular Effects** (time-dependent drift)
- Atmospheric drag (using BSTAR from TLE)
- Update mean motion, eccentricity, argument of perigee

**Step 2: Long-Period Periodic Terms**
- Gravitational perturbations from Earth's oblateness (J2, J3, J4)
- Updates to semi-major axis, eccentricity, inclination

**Step 3: Solve Kepler's Equation**
- Convert mean anomaly → eccentric anomaly (iterative Newton-Raphson)
- Then eccentric anomaly → true anomaly

**Step 4: Short-Period Periodic Terms**
- Final corrections for position/velocity

**Step 5: Position & Velocity Calculation**
- Convert orbital elements to Cartesian TEME coordinates
- Return SatelliteState(position, velocity, time)

### Incremental Milestones

**Milestone 1**: Basic structure ✓
- Implement constants and TLE conversion
- Create stub for propagation flow
- **Test**: Verify initialization doesn't crash

**Milestone 2**: Simplified propagation
- Implement Kepler equation solver
- Basic orbital mechanics (no perturbations)
- **Test**: Should be within ~100 km of expected (very rough)

**Milestone 3**: Add secular effects
- Drag and secular perturbations
- **Test**: Should be within ~10 km

**Milestone 4**: Add periodic perturbations
- J2, J3, J4 gravity harmonics
- **Test**: Should match Vallado reference data within 1 mm

**Milestone 5**: Edge cases
- Handle near-circular orbits
- Handle equatorial orbits
- Numerical stability improvements

### Validation Requirements

**Critical**: Must match official Vallado test data
- Reference data: `SwiftSGP4Tests/Resources/SGP4-VER.TLE`
- Tests already written: `SGP4PropagatorTests.swift`
- Expected values from Vallado 2006 paper (AIAA 2006-6753)
- **Accuracy requirement**: Within **1e-6 km** (1 mm)

### Test Satellites in Test Suite

1. **Satellite 00005** (58002B)
   - Highly elliptical orbit (e=0.1859667)
   - 10.82 revs/day
   - Test range: 0-4320 minutes

2. **Satellite 06251** (DELTA 1 DEB)
   - Near-earth with normal drag
   - Perigee: 377.26 km
   - Test range: 0-2880 minutes

3. **Satellite 28057** (MOLNIYA 2-14)
   - Deep space, 12-hour resonant
   - e=0.7 (SDP4 algorithm - Phase 6)

4. **Satellite 11801** (TDRSS 3)
   - Near-geostationary
   - Non-standard TLE format test

5. **Satellite 14128** (EUTELSAT 1-F1)
   - Near-geostationary, very low eccentricity
   - Tests Lyddane choice at 2080 minutes

### Key Implementation Challenges

1. **Numerical precision**: SGP4 is sensitive to floating-point errors
2. **Edge cases**: Near-circular/equatorial orbits need special handling
3. **Coordinate frames**: Must return TEME, not ECEF
4. **Constants**: SGP4 uses **WGS-72**, not WGS-84 (different Earth radius!)
5. **Units**: Internally uses Earth radii and radians, must convert properly

### Estimated Effort

- **Lines of code**: ~300-500 for core SGP4
- **Time estimate**:
  - Basic working version: 2-4 hours
  - Fully tested & validated: 6-10 hours
  - With deep-space SDP4: +4 hours

## Reference Resources

### Primary References
- **Vallado 2006 Paper**: "Revisiting Spacetrack Report #3" (AIAA 2006-6753)
  - https://celestrak.org/publications/AIAA/2006-6753/
- **Python-SGP4**: https://github.com/brandon-rhodes/python-sgp4
  - Most trusted reference implementation
  - Passes all official Vallado tests
  - Well-documented and maintained

### Additional Resources
- **CelesTrak**: Official SGP4 documentation and test data
- **Vallado MATLAB Code**: https://github.com/Spacecraft-Code/Vallado
- **SGP4 npm package**: JavaScript implementation (alternative reference)

## File Structure

```
swift-sgp4/
├── SwiftSGP4/
│   ├── SGP4Propagator.swift       ❌ TO IMPLEMENT
│   ├── TLE.swift                  ✅ Complete
│   ├── CoordinateConverter.swift  ✅ 93% complete
│   └── ...
├── SwiftSGP4Tests/
│   ├── SGP4PropagatorTests.swift     ✅ Tests ready with expected values
│   ├── Resources/SGP4-VER.TLE        ✅ Official Vallado test data
│   └── ...
└── PLAN.md                        📝 This file
```

## Next Session Action Items

1. ✅ Branch created: `claude/implement-sgp4-propagator`
2. ⏭️ Fetch python-sgp4 reference (if github access available)
3. ⏭️ Implement SGP4 algorithm in `SGP4Propagator.swift`
4. ⏭️ Run tests: `swift test --filter SGP4PropagatorTests`
5. ⏭️ Iterate until all near-earth tests pass
6. ⏭️ Create PR when tests pass

## Success Criteria

- [ ] All near-earth SGP4PropagatorTests passing (5-6 tests)
- [ ] Position accuracy within 1e-6 km of Vallado reference
- [ ] Velocity accuracy within 1e-9 km/s
- [ ] No crashes or numerical instabilities
- [ ] Clean code with comments explaining key steps
- [ ] Deep-space (SDP4) can be future work

---

**Last Updated**: 2025-10-25
**Status**: Ready to implement SGP4 core algorithm
**Current Branch**: `claude/implement-sgp4-propagator`
