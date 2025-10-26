#!/usr/bin/env python3
"""
Generate expected values for new SGP4 test satellites
Using official python-sgp4 reference implementation
"""

from sgp4.api import Satrec
import math

satellites = {
    '28057': {
        'name': 'CBERS 2',
        'line1': '1 28057U 03049A   06177.78615833  .00000060  00000-0  35940-4 0  1836',
        'line2': '2 28057  98.4283 247.6961 0000884  88.1964 271.9322 14.35478080140550',
        'times': [0.0, 360.0, 720.0],
        'description': 'Near-earth, very low eccentricity (e=0.0000884)'
    },
    '28350': {
        'name': 'COSMOS 2405',
        'line1': '1 28350U 04020A   06167.21788666  .16154492  76267-5  18678-3 0  8894',
        'line2': '2 28350  64.9977 345.6130 0024870 260.7578  99.9590 16.47856722116490',
        'times': [0.0, 120.0, 240.0],
        'description': 'Near-earth, perigee=127.20km, high drag'
    },
    '88888': {
        'name': 'STR#3 SGP4 test',
        'line1': '1 88888U          80275.98708465  .00073094  13844-3  66816-4 0    87',
        'line2': '2 88888  72.8435 115.9689 0086731  52.6988 110.5714 16.05824518  1058',
        'times': [0.0, 360.0, 720.0],
        'description': 'Official SGP4 test case'
    }
}

for sat_id, data in satellites.items():
    print("="*70)
    print(f"Satellite {sat_id} - {data['name']}")
    print(f"Description: {data['description']}")
    print("="*70)

    sat = Satrec.twoline2rv(data['line1'], data['line2'])

    print(f"\nTLE Parameters:")
    print(f"  Eccentricity: {sat.ecco:.10f}")
    print(f"  Inclination: {math.degrees(sat.inclo):.6f}°")
    print(f"  Mean motion: {sat.no_kozai * 1440 / (2 * math.pi):.8f} revs/day")
    print(f"  BSTAR: {sat.bstar:.10e}")
    print(f"  Method: {sat.method} (n=near-earth, d=deep-space)")

    print(f"\nExpected State Vectors:")
    print(f"// Test times: {', '.join(str(t) for t in data['times'])} minutes")

    for t in data['times']:
        e, r, v = sat.sgp4_tsince(t)

        if e == 0:
            print(f"\n    // At t={t:.1f} minutes")
            print(f"    ExpectedState(")
            print(f"        minutesSinceEpoch: {t},")
            print(f"        position: Vector3D(x: {r[0]:.8f}, y: {r[1]:.8f}, z: {r[2]:.8f}),")
            print(f"        velocity: Vector3D(x: {v[0]:.8f}, y: {v[1]:.8f}, z: {v[2]:.8f})")
            print(f"    ),")
        else:
            print(f"\n✗ Error at t={t}: code {e}")

    print()

print("="*70)
print("Generation complete!")
print("="*70)
