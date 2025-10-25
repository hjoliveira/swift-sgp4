# SGP4 Bug Investigation - Session 2 Summary

## Date
2025-10-23 (Session 2)

## Investigation Summary

Continued from previous session's work on the true anomaly numerical cancellation bug.

### Findings

1. **Original Vallado Formula**: Confirmed catastrophic numerical cancellation
   - `sinu ≈ 1.27e-05` (should be ~-0.087)
   - `su ≈ 0°` (should be ~355°)
   - Result: Position Z = 0.05 km (should be 1720 km)

2. **Alternative Formula Attempted**: Better numerics but wrong quadrant
   - `sinu = 0.0875` (positive, but should be NEGATIVE!)
   - `su = 28°` (wrong quadrant, should be 355°)
   - Result: Position Z = 1900 km (closer to 1720 km target)

3. **Root Cause of Alternative Formula Failure**:
   - Standard eccentric-to-true anomaly conversion assumes simple two-body dynamics
   - SGP4 uses MODIFIED eccentricity components (axnl, aynl) for perturbations
   - The standard formula doesn't account for these modifications correctly

### Key Insight

For the true anomaly to be ~355° (fourth quadrant), we need:
- `sinu < 0` (negative)
- `cosu > 0` (positive)

But all our attempts produce `sinu > 0`, placing us in the first quadrant (~28°).

### Verification Against C++ Reference

✅ ALL formulas match Vallado's C++ reference EXACTLY:
- Long-period terms calculation: Matches
- Kepler equation solver: Matches
- True anomaly formula: Matches
- Short-period corrections: Matches

Yet the implementation fails. This suggests:
- **Missing context/step** we haven't identified
- **Sign convention** difference not documented
- **Angle normalization** that's implicit in C++
- **Input value** calculated incorrectly earlier in the chain

### What We Know Is Correct

✅ Kepler solver converges perfectly (epw = 6.2017 rad = 355.3°)
✅ ecosE and esinE calculations verified
✅ All constants (j2, j3, j4, aycof, xlcof) match reference values
✅ TLE parsing is correct (all 18 tests pass)
✅ Code compiles with 0 warnings

### What's Wrong

❌ True anomaly calculation produces catastrophic numerical cancellation
❌ Alternative formulas produce wrong quadrant
❌ All position components have 2x-10x errors
❌ Tests at later times diverge exponentially

## Attempted Solutions

1. **Numerically stable eccentric-to-true conversion** - Wrong quadrant
2. **Reordering terms to minimize cancellation** - Still cancels
3. **Using ecosE/esinE directly** - Wrong sign
4. **Reverted to original Vallado formula** - Extreme cancellation persists

## Blocking Issues

This bug requires ONE of:

1. **Detailed test vectors** from Vallado showing ALL intermediate values at each step
2. **Working reference implementation** (Python/JavaScript) to trace through with debugger
3. **Domain expert** familiar with SGP4 implementation nuances
4. **Original Spacetrack Report #3** with complete algorithmic details

The mathematical formulas appear correct but produce wrong results, indicating a subtle implementation detail is missing.

## Recommendation

### Short Term
- Mark Phase 2 as "blocked pending expert review"
- Document all findings comprehensively
- Reach out to SGP4 community for guidance

### Long Term Options
1. Find someone who has successfully implemented SGP4
2. Obtain Vallado's test suite with intermediate values
3. Port a known-working implementation (e.g., python-sgp4) line-by-line
4. Contact Dr. Vallado directly for clarification

## Files Modified (This Session)
- `SwiftSGP4/SGP4Propagator.swift` - Multiple debugging attempts
- `TRUE_ANOMALY_BUG_ANALYSIS.md` - Previous session's analysis
- `DEBUGGING_SESSION_2.md` - This document

## Test Status
- ✅ TLE parsing: 18/18 pass
- ❌ SGP4 propagation: 0/5 pass
- ⏭️  Deep space (SDP4): Skipped (not implemented)

---

**Status**: Investigation complete, bug not resolved
**Next Action**: Requires external expertise or detailed test vectors
**Branch**: `claude/sgp4-propagator-phase-2-011CUQ6q5eWpg3GqBwM7WrA9`
**Last Updated**: 2025-10-23 19:00 UTC
