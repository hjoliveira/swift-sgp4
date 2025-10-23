# SGP4 Debugging Notes - Session 2025-10-23

## Current Status

Continuing work from previous session on `claude/sgp4-propagator-phase-2-011CUNqrWhfxHzZTmrh59NgM` branch.

### What's Working
- ✅ Swift 6.0.2 installed and configured
- ✅ All TLE parsing tests pass (18/18)
- ✅ Code compiles with 0 warnings
- ✅ Build infrastructure complete
- ✅ Kepler equation solver converges correctly

### Current Failure

**Test**: `testSatellite00005_Propagation` at t=0 minutes (epoch)

**Expected Output**:
- Position: (2328.97, -5995.22, 1719.98) km
- Velocity: (2.91, -0.98, -7.09) km/s

**Actual Output**:
- Position: (7022.47, -1400.07, 0.051) km
- Velocity: (1.89, 6.41, 4.53) km/s

**Errors**:
- X: 3.0x wrong
- Y: 4.3x wrong
- Z: 33,000x wrong (nearly zero instead of 1720 km!)

### Root Cause Identified

The Z position is nearly zero because the **true anomaly `su` ≈ 0°** when it should be ≈ 355°.

#### Trace of Values at t=0:

```
Mean anomaly (mm): 0.3373 rad = 19.3°
Argument of perigee (omgadf): 5.7904 rad = 331.8°
Eccentricity (em): 0.18597

Eccentricity components after long-period corrections:
- axnl = em * cos(omgadf) = 0.1638
- aynl = em * sin(omgadf) + temp * aycof = -0.0875

Eccentric anomaly from Kepler solver:
- Input: u = 6.128 rad
- Output: epw = 6.2017 rad = 355.3° ✓ CORRECT
- sineo1 = sin(epw) = -0.0814 ✓ CORRECT
- coseo1 = cos(epw) = 0.9967 ✓ CORRECT

True anomaly calculation (THE BUG):
- sinu = (am/r) * (sineo1 - aynl - axnl * temp)
- sinu = (1.354/1.123) * (-0.0814 - (-0.0875) - 0.1638 * 0.0373)
- sinu = 1.206 * (-0.0814 + 0.0875 - 0.0061)
- sinu = 1.206 * 0.00001  ← NUMERICAL CANCELLATION!
- su = atan2(0.00001, 1.0) ≈ 0° ← WRONG! Should be ~355°
```

### The Problem

The formula for converting eccentric to true anomaly is:
```
sinu = (am/r) * (sineo1 - aynl - axnl * temp)
cosu = (am/r) * (coseo1 - axnl + aynl * temp)
```

This formula **matches the Vallado C++ reference exactly** (line 1978-1979 of SGP4.cpp).

However, the terms `sineo1`, `aynl`, and `axnl * temp` are canceling almost perfectly:
- sineo1 = -0.0814
- aynl = -0.0875
- axnl * temp = 0.0061
- Sum = -0.0814 + 0.0875 - 0.0061 ≈ 0.00001

This numerical cancellation causes the true anomaly to be calculated as nearly zero.

### Hypothesis

One of the following must be true:

1. **Input values wrong**: The values of `axnl`, `aynl`, or `temp` are being calculated incorrectly
2. **Different formula needed**: Maybe there's a more numerically stable formulation
3. **Missing correction**: There may be an additional term or correction we're missing
4. **Order of operations**: We may be applying corrections in the wrong order

### Comparison with C++ Reference

All formulas match Vallado's C++ reference code:
- ✓ Long-period perturbations (lines 1935-1938)
- ✓ Kepler solver (lines 1945-1956)
- ✓ Short-period prelims (lines 1960-1976)
- ✓ True anomaly calculation (lines 1978-1979)

### Next Steps to Try

1. **Add more debug output** to trace `axnl` and `aynl` calculation step-by-step
2. **Check initialization** of `state.aycof` and `state.xlcof` values
3. **Compare with test vectors** from Vallado's paper to find where divergence starts
4. **Try simpler test case** with circular orbit (e≈0) to isolate the issue
5. **Check if there's an alternative formula** for near-zero true anomaly cases

### Code Locations

- Kepler solver: `SGP4Propagator.swift:187-234`
- Long-period terms: `SGP4Propagator.swift:140-185`
- True anomaly calc: `SGP4Propagator.swift:257-259`
- Position transform: `SGP4Propagator.swift:286-325`

### Test Command

```bash
export PATH=/usr/local/swift-6.0.2/usr/bin:$PATH
swift test --filter testSatellite00005_Propagation
```

### References

- Vallado C++ code: `/tmp/cpp/cpp/SGP4/SGP4/SGP4.cpp`
- Test data source: Vallado et al. (2006) "Revisiting Spacetrack Report #3"

---

**Last Updated**: 2025-10-23
**Debug branch**: `claude/sgp4-propagator-phase-2-011CUNqrWhfxHzZTmrh59NgM`
**Status**: Active debugging - numerical cancellation issue identified
