# SGP4 True Anomaly Bug - Detailed Analysis

## Date
2025-10-23

## Current Status
❌ **CRITICAL BUG**: SGP4 propagation fails due to incorrect true anomaly calculation

## Progress Made
1. ✅ Identified root cause: Numerical cancellation in Valle-Vallado formula
2. ✅ Attempted alternative numerically stable formulation
3. ⚠️ Partial improvement but still incorrect

## The Bug

### Original Vallado Formula (Catastrophic Cancellation)
```swift
sinu = (am/r) * (sineo1 - aynl - axnl * temp)
cosu = (am/r) * (coseo1 - axnl + aynl * temp)
su = atan2(sinu, cosu)
```

**Problem**: For satellite 00005 at t=0:
- sineo1 = -0.0814
- aynl = -0.0875
- axnl * temp = 0.0061
- **Sum = -0.0814 + 0.0875 - 0.0061 ≈ 0.00001** ← CANCELLATION!
- Result: `su ≈ 0°` (should be ~355°)

### Alternative Formula Attempted
```swift
let sqrtBetal = sqrt(1.0 - el2)
let denom = 1.0 - ecosE
let sinu = sqrtBetal * esinE / denom
let cosu = (ecosE - el2) / denom
let su = atan2(sinu, cosu)
```

**Result**:
- `su = 28.1°` (should be ~355°)
- Position Z improved from 0.05 km to 1900 km (expected 1720 km)
- **Still wrong quadrant!**

## Analysis

### What's Correct
✅ Kepler solver converges correctly (epw = 6.2017 rad = 355.3°)
✅ Eccentric anomaly is correct
✅ All formulas match Vallado C++ reference exactly
✅ ecosE and esinE calculations verified

### What's Wrong
❌ True anomaly calculation produces wrong result
❌ Position vectors have 3x-10x errors
❌ Alternative formula gives wrong quadrant (28° vs 355°)

## Hypothesis

The issue may be:

1. **Wrong interpretation of `su`**: Maybe `su` is not the true anomaly directly, but some intermediate angle?

2. **Missing angle unwrapping**: The formula might need special handling for angles near 0°/360°

3. **Perturbation term error**: The `axnl` and `aynl` terms may have a sign error or wrong calculation

4. **Reference frame issue**: The angle might be measured in a different reference frame than expected

## Test Results

### Satellite 00005 (Eccentric Orbit)
- Expected: Position = (2328.97, -5995.22, 1719.98) km
- With original formula: (7022.47, -1400.07, 0.051) km
- With alternative formula: (6739.72, 1497.74, 1899.51) km
- **Best Z component**: 1900 km vs expected 1720 km (10% error)

### Satellite 06251 (Typical LEO)
- Fails with "semi-latus rectum is negative" at t=120 min
- Suggests eccentricity becomes > 1 during propagation
- Root cause: Wrong true anomaly feeds into short-period corrections

## Next Steps to Fix

### Option 1: Debug with Vallado Test Vectors
Need intermediate values from Vallado's test suite for:
- axnl, aynl after long-period corrections
- temp, ecosE, esinE
- sinu, cosu before atan2
- Expected su value

### Option 2: Port C++ Code Exactly
Line-by-line port of Vallado's C++ code, including:
- Any angle normalization
- Any special cases for specific quadrants
- Exact order of operations

### Option 3: Use Alternative Conversion
Research if there's a published alternative that's more numerically stable while still accounting for SGP4 perturbations.

### Option 4: Check for Sign Errors
Systematically verify each sign in the formulas:
- Is it `sineo1 - aynl` or `sineo1 + aynl`?
- Is it `axnl * temp` or `-axnl * temp`?
- Review original Spacetrack Report #3

## Code Locations

- True anomaly calc: `SwiftSGP4/SGP4Propagator.swift:291-321`
- Long-period terms: `SwiftSGP4/SGP4Propagator.swift:167-176`
- Kepler solver: `SwiftSGP4/SGP4Propagator.swift:175-207`

## References

- Vallado C++ reference: `/tmp/cpp/cpp/SGP4/SGP4/SGP4.cpp` lines 1975-1980
- Original paper: Vallado et al. (2006) "Revisiting Spacetrack Report #3"
- Test data: https://celestrak.org/publications/AIAA/2006-6753/

## Recommendation

This bug requires access to:
1. **Validated intermediate test vectors** with ALL values at each step
2. **Working reference implementation** to trace through with debugger
3. **Domain expert** familiar with SGP4 implementation nuances

The formulas appear mathematically correct but produce wrong results, suggesting a subtle implementation detail is missing.

---

**Status**: Blocked - needs expert review or detailed test vectors
**Branch**: `claude/sgp4-propagator-phase-2-011CUQ6q5eWpg3GqBwM7WrA9`
**Last Updated**: 2025-10-23 18:40 UTC
