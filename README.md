# swift-sgp4

A Swift implementation of the SGP4 satellite orbit propagation algorithm.

## Installation

### Swift Package Manager

Add SwiftSGP4 to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/hjoliveira/swift-sgp4.git", from: "1.0.0")
]
```

Or in Xcode:
1. File > Add Package Dependencies...
2. Enter the repository URL: `https://github.com/hjoliveira/swift-sgp4.git`
3. Select version requirements

## Requirements

- Swift 5.9+
- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+

## Status

🚧 **Under Active Development** - See [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for roadmap.

- ✅ TLE parsing
- ⚠️ SGP4 propagator (in progress)
