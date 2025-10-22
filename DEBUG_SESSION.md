# SGP4 Propagator Debugging Session

## Session Date
2025-10-22

## Objective
Fix SGP4 propagation algorithm by comparing line-by-line with Vallado's reference C++ implementation.

## Changes Made

### 1. Added Missing Initialization Coefficients (SGP4State.swift)
- **con41, con42**: Inclination-based coefficients (`3*cos²i - 1`, `1 - 5*cos²i`)
- **x1mth2, x7thm1**: Pre-computed values (`1 - cos²i`, `7*cos²i - 1`)
- **omgcof, xmcof, nodecf**: Secular correction coefficients
- **t2cof, t3cof, t4cof, t5cof**: Time-power coefficients for non-simple mode
- **delmo, sinmao**: Drag-related values
- **isSimpleMode**: Flag for perigee < 220 km check
- **j3oj2**: J3/J2 ratio constant in SGP4Constants.swift

### 2. Fixed C2 and C4 Drag Coefficients
**Before:**
```swift
self.c2 = ... * (8.0 + 3.0 * eta2 * (8.0 + eta2)))
self.c4 = ... * (-3.0 * (1.0 - 3.0 * theta2) * ...)
```

**After:**
```swift
self.c2 = ... * con41 * (8.0 + 3.0 * eta2 * (8.0 + eta2)))
self.c4 = ... * (-3.0 * con41 * (1.0 - 2.0 * eeta + eta2 * (1.5 - 0.5 * eeta)) + ...)
```

### 3. Fixed Secular Rates Calculation
- Changed from simplified formulas to full Vallado formulas
- Now includes J4 terms and higher-order corrections
- Properly calculates `dotMeanMotion`, `dotArgumentOfPerigee`, `dotRightAscension`

### 4. Added Non-Simple Mode Logic (SGP4Propagator.swift)
**updateSecularEffects()** now includes:
- delomg and delm corrections when `!isSimpleMode`
- Additional terms for `tempa`, `tempe`, `templ`
- Proper `xmp` and `omega` updates

### 5. Fixed Long-Period Terms Calculation
- Now updates `nm` (mean motion) from drag: `am = (xke/nm)^(2/3) * tempa²`, then `nm = xke / am^1.5`
- Corrected `axnl` and `aynl` formulas per Vallado
- Fixed `xl` calculation to include `xlcof` term

### 6. Fixed Short-Period Perturbations
- **temp1/temp2**: Now recalculated from `pl` during propagation (not pre-computed!)
```swift
let tempVar = 1.0 / pl
let temp1 = 0.5 * j2 * tempVar
let temp2 = temp1 * tempVar
```
- Use `con41` instead of ad-hoc `(3*cos²i - 1)` calculations
- Use `x1mth2` and `x7thm1` instead of recalculating

### 7. Fixed Velocity Conversion
**Before:**
```swift
let xdot = (rdotk * ux + rfdotk * vx) * earthRadius / 60.0
```

**After:**
```swift
let vkmpersec = earthRadius * xke / 60.0
let xdot = (rdotk * ux + rfdotk * vx) * vkmpersec
```

## Build Status
✅ **Build succeeds with 0 warnings**

## Test Status
❌ **All 5 SGP4 tests still failing**

### Example Failure (Satellite 00005 at t=0.0):
| Component | Expected (km or km/s) | Got (km or km/s) | Error |
|-----------|----------------------|------------------|-------|
| Position X | 2328.97 | 7022.47 | **3x too large** |
| Position Y | -5995.22 | -1400.07 | **Wrong magnitude** |
| Position Z | 1719.98 | 0.051 | **~34000x too small!** |
| Velocity X | 2.91 | 1.89 | Wrong |
| Velocity Y | -0.98 | 6.41 | Wrong sign & magnitude |
| Velocity Z | -7.09 | 4.53 | Wrong sign |

### Exponential Divergence
At t=360 min: Positions reach ~10²⁶ km (astronomical!)
At t=720 min: Positions reach ~10²⁸ km
This indicates **numerical instability** or **fundamental calculation error**

## Root Cause Analysis

### Symptoms
1. **Z component nearly zero at t=0** (0.051 vs 1720 km expected)
   - Suggests `sinuk ≈ 0` or `sinik ≈ 0`
   - Since inclination = 34.27° → `sinik = 0.563` (correct)
   - Therefore `uk ≈ 0` (true anomaly calculation error?)

2. **X and Y components wrong by factors of 2-4**
   - Magnitude in wrong quadrant

3. **Exponential growth** at later times
   - Suggests feedback loop amplifying initial errors

### Likely Culprits (Not Yet Investigated)
1. **Kepler's Equation Solver** (`solveKeplerEquation`)
   - May not be converging correctly
   - Initial guess `u = fmod2p(xl - xnode)` may be wrong

2. **Eccentric Anomaly Transformation** (`calculateShortPeriodPrelims`)
   - Conversion from eccentric to true anomaly may have sign errors
   - `sinu` and `cosu` formulas need verification

3. **Long-Period Terms** (`calculateLongPeriodTerms`)
   - `xl` formula may still be incorrect
   - Missing some intermediate calculation?

4. **Coordinate Frame Transformation** (`calculatePositionVelocity`)
   - The final TEME transformation matrices may have errors
   - `ux`, `uy`, `uz`, `vx`, `vy`, `vz` calculations need verification

## Next Steps

### Immediate Actions
1. **Add Debug Logging**
   - Print intermediate values at each step
   - Compare with Vallado's debug output for same TLE

2. **Test with Simple Case**
   - Try circular orbit (e=0) at equator (i=0)
   - Verify coordinate transformation works for trivial case

3. **Verify Kepler Solver**
   - Add iteration count check
   - Print initial `u`, final `eo1`, and convergence

4. **Unit Test Each Function**
   - Test `solveKeplerEquation` with known inputs
   - Test `calculateShortPeriodPrelims` independently
   - Test coordinate transformations

### Long-Term Fix
1. Download Vallado's test data with intermediate values
2. Compare each calculation step-by-step
3. Identify exact point where divergence occurs
4. Fix the root cause formula

## References
- **Vallado's C++ Code**: `/tmp/cpp/SGP4/SGP4/SGP4TJK.cpp`
- **sgp4()** function: Lines 1754-2038
- **sgp4init()** function: Lines 1360-1657
- **initl()** function: Lines 1202-1271

## Files Modified
- `SwiftSGP4/SGP4Constants.swift` - Added j3oj2
- `SwiftSGP4/SGP4State.swift` - Added 15 new coefficients, fixed C2/C4
- `SwiftSGP4/SGP4Propagator.swift` - Complete rewrite of propagation logic

## Commit Hash
`95c02c7` - "Fix SGP4 propagation algorithm - major rewrite (work in progress)"
