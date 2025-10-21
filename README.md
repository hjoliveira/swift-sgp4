# swift-sgp4

A Swift implementation of the SGP4 satellite orbit propagation algorithm.

## Overview

SGP4 (Simplified General Perturbations Satellite Orbit Model 4) is a mathematical model used to calculate the orbital state vectors of satellites and space debris relative to the Earth-centered inertial coordinate system. This library provides a Swift implementation for parsing Two-Line Element (TLE) sets and propagating satellite positions.

## Current Status

**Note:** This project was originally written for Swift 2/3 and requires migration to work with modern Swift versions.

### Known Issues

The codebase currently does not compile with Swift 6.0.3 due to the following compatibility issues:

1. **Error Handling**: `ErrorType` has been renamed to `Error` in Swift 3+
2. **String API Changes**: Methods like `componentsSeparatedByString()` have been replaced with `components(separatedBy:)`
3. **Foundation API Updates**: Various Foundation APIs have been modernized (e.g., `NSCalendar.currentCalendar()` → `Calendar.current`)
4. **Syntax Updates**: C-style for loops have been removed
5. **Character API**: `String.characters` has been deprecated

### Migration Required

The code needs to be updated to Swift 6.0.3 standards. Main areas requiring attention:

- `SwiftSGP4/TLEError.swift`: Error protocol conformance
- `SwiftSGP4/TLE.swift`: String and Foundation API updates
- Loop syntax modernization throughout the codebase

## Development Environment Setup

### Swift Installation (Ubuntu 24.04)

This project has been tested with Swift 6.0.3 on Ubuntu 24.04 LTS (x86_64).

#### Installing Swift

1. **Download Swift 6.0.3 for Ubuntu 24.04:**
   ```bash
   cd /tmp
   wget https://download.swift.org/swift-6.0.3-release/ubuntu2404/swift-6.0.3-RELEASE/swift-6.0.3-RELEASE-ubuntu24.04.tar.gz
   ```

2. **Extract and install:**
   ```bash
   tar xzf swift-6.0.3-RELEASE-ubuntu24.04.tar.gz
   sudo mv swift-6.0.3-RELEASE-ubuntu24.04 /usr/local/swift
   ```

3. **Add Swift to PATH:**
   ```bash
   echo 'export PATH=/usr/local/swift/usr/bin:$PATH' >> ~/.bashrc
   echo 'export PATH=/usr/local/swift/usr/bin:$PATH' >> ~/.profile
   source ~/.bashrc
   ```

4. **Verify installation:**
   ```bash
   swift --version
   # Should output: Swift version 6.0.3 (swift-6.0.3-RELEASE)

   swift package --version
   # Should output: Swift Package Manager - Swift 6.0.3
   ```

### Building the Project

**Note:** The build currently fails due to Swift version compatibility issues mentioned above.

To attempt a build:

```bash
swift build
```

To run tests (once the code is migrated):

```bash
swift test
```

## Project Structure

```
swift-sgp4/
├── SwiftSGP4/              # Main library source
│   ├── SGP4Propagator.swift
│   ├── TLE.swift           # Two-Line Element parser
│   └── TLEError.swift      # Error definitions
├── SwiftSGP4Tests/         # Test suite
├── Package.swift           # Swift Package Manager manifest
├── .gitignore              # Git ignore rules
└── README.md               # This file
```

## Swift Package Manager Integration

This project uses Swift Package Manager (SPM) as its build system. The `Package.swift` file defines:

- Package name: `SwiftSGP4`
- Platforms: iOS 8.0+
- Products: SwiftSGP4 library
- Targets: Main library and test suite

## Usage (After Migration)

Once the code is migrated to Swift 6, typical usage will be:

```swift
import SwiftSGP4

// Parse a TLE from file
let tle = try TLE(name: "ISS (ZARYA)", tleFilename: "path/to/tle.txt")

// Create propagator
let propagator = SGP4Propagator(tle: tle)

// Propagate to a specific time
let position = propagator.propagate(to: date)
```

## Contributing

Contributions are welcome! Priority areas:

1. **Swift 6 Migration**: Update the codebase to be compatible with Swift 6.0.3
2. **Testing**: Add comprehensive test coverage
3. **Documentation**: Add inline documentation and usage examples
4. **CI/CD**: Set up continuous integration

## Resources

- [SGP4 Algorithm Reference](https://celestrak.org/NORAD/documentation/)
- [Swift.org](https://swift.org/)
- [Swift Package Manager Documentation](https://swift.org/package-manager/)

## Development History

### 2025-10-21: Swift Development Environment Setup

- Installed Swift 6.0.3 on Ubuntu 24.04 LTS
- Configured Swift Package Manager
- Updated `.gitignore` to exclude `.build/` directory
- Identified Swift compatibility issues requiring migration

## License

[Add license information here]

## Acknowledgments

This implementation is based on the SGP4 orbital propagation algorithm developed by NORAD.
