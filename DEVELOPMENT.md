# Development Guide

This document provides detailed technical information for developers working on the swift-sgp4 project.

## Environment Setup

### Swift Installation Details

The project requires Swift 6.0.3 or later. The installation process documented here is for Ubuntu 24.04 LTS.

**Installation Location:** `/usr/local/swift`

**PATH Configuration:**
```bash
export PATH=/usr/local/swift/usr/bin:$PATH
```

This has been added to both `~/.bashrc` and `~/.profile` for persistence across sessions.

### Verification

After installation, verify your environment:

```bash
# Check Swift version
swift --version
# Expected: Swift version 6.0.3 (swift-6.0.3-RELEASE)

# Check target platform
swift --version | grep Target
# Expected: Target: x86_64-unknown-linux-gnu

# Verify SPM
swift package --version
# Expected: Swift Package Manager - Swift 6.0.3
```

## Migration from Swift 2/3 to Swift 6

### Current Build Errors

The project currently has compilation errors that need to be addressed:

#### 1. Error Protocol (TLEError.swift)

**Issue:**
```swift
enum TLEError: ErrorType {  // ErrorType doesn't exist in Swift 3+
    case InvalidLineLength(Int)
    case InvalidElement(String)
    case FileParsing
}
```

**Fix Required:**
```swift
enum TLEError: Error {  // Changed to Error protocol
    case invalidLineLength(Int)      // Swift naming conventions
    case invalidElement(String)
    case fileParsing
}
```

#### 2. String API Changes (TLE.swift)

**Issues:**

a. **NSUTF8StringEncoding:**
```swift
// Old (Swift 2)
let tleText = try String(contentsOfFile: tleFilename, encoding: NSUTF8StringEncoding)

// New (Swift 6)
let tleText = try String(contentsOfFile: tleFilename, encoding: .utf8)
```

b. **componentsSeparatedByString:**
```swift
// Old
let lines = tleText.componentsSeparatedByString("\n")

// New
let lines = tleText.components(separatedBy: "\n")
```

c. **String.characters:**
```swift
// Old
let lineLength = line.characters.count

// New
let lineLength = line.count  // String is a collection in Swift 4+
```

d. **substringWithRange:**
```swift
// Old
let substring = (str as NSString).substringWithRange(NSRange(location: location, length: length))

// New
let start = str.index(str.startIndex, offsetBy: location)
let end = str.index(start, offsetBy: length)
let substring = String(str[start..<end])
```

e. **stringByTrimmingCharactersInSet:**
```swift
// Old
substring.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())

// New
substring.trimmingCharacters(in: .whitespacesAndNewlines)
```

#### 3. C-style For Loops

**Issue:**
```swift
for var i = 0; i < lines.count; ++i {
    // ...
}
```

**Fix Required:**
```swift
for i in 0..<lines.count {
    // ...
}
```

#### 4. Foundation API Updates

**NSCalendar:**
```swift
// Old
NSCalendar.currentCalendar().dateFromComponents(comps)

// New
Calendar.current.date(from: comps)
```

**NSDateComponents:**
```swift
// Old
let comps = NSDateComponents()

// New
var comps = DateComponents()
```

### Migration Checklist

- [ ] Update `TLEError.swift`
  - [ ] Change `ErrorType` to `Error`
  - [ ] Update case naming to follow Swift conventions

- [ ] Update `TLE.swift`
  - [ ] Replace `NSUTF8StringEncoding` with `.utf8`
  - [ ] Replace `componentsSeparatedByString()` with `components(separatedBy:)`
  - [ ] Remove `.characters` references
  - [ ] Update substring methods
  - [ ] Update `trimmingCharacters` calls
  - [ ] Convert C-style for loops
  - [ ] Update Calendar API calls
  - [ ] Update DateComponents API calls

- [ ] Update `SGP4Propagator.swift` (if needed)
  - [ ] Review for any legacy API usage

- [ ] Update test files
  - [ ] Ensure test syntax is Swift 6 compatible

- [ ] Update `Package.swift`
  - [ ] Consider updating minimum platform versions
  - [ ] Add Swift tools version if needed

## Build System

### Swift Package Manager

The project uses SPM exclusively. Key commands:

```bash
# Clean build artifacts
swift package clean

# Update dependencies (when added)
swift package update

# Generate Xcode project (for macOS development)
swift package generate-xcodeproj

# Build in debug mode
swift build

# Build in release mode
swift build -c release

# Run tests
swift test

# Run specific test
swift test --filter TestName
```

### Build Artifacts

Build artifacts are stored in `.build/` directory:

```
.build/
├── debug/              # Debug builds
├── release/            # Release builds
└── repositories/       # Dependency checkouts
```

This directory is excluded from version control via `.gitignore`.

## Code Quality

### Swift Naming Conventions

Follow Swift API Design Guidelines:
- Use `lowerCamelCase` for variables, functions, and enum cases
- Use `UpperCamelCase` for types
- Prefer clarity over brevity
- Follow established Foundation patterns

Example:
```swift
// Good
case invalidLineLength(Int)

// Bad
case InvalidLineLength(Int)
```

### Error Handling

Always use Swift's error handling mechanism:

```swift
enum TLEError: Error {
    case invalidLineLength(Int)
    case invalidElement(String)
    case fileParsing
}

// Usage
throw TLEError.invalidElement("Invalid orbitNumber")
```

## Testing

### Running Tests

```bash
# Run all tests
swift test

# Run with verbose output
swift test --verbose

# Run specific test suite
swift test --filter SwiftSGP4Tests
```

### Test Structure

Tests are located in `SwiftSGP4Tests/` directory. Follow XCTest conventions:

```swift
import XCTest
@testable import SwiftSGP4

final class TLETests: XCTestCase {
    func testTLEParsing() throws {
        // Test implementation
    }
}
```

## Git Workflow

### Branch Naming

- Feature branches: `feature/description`
- Bug fixes: `fix/description`
- Claude-generated: `claude/description-sessionid`

### Commit Messages

Follow conventional commit format:

```
<type>: <short summary>

<detailed description>

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

### Pre-commit Checks

Before committing:

1. Ensure code compiles: `swift build`
2. Run tests: `swift test`
3. Check for untracked files: `git status`

## Troubleshooting

### Swift Not Found

If `swift` command is not found after installation:

```bash
# Add to PATH
export PATH=/usr/local/swift/usr/bin:$PATH

# Verify
which swift
```

### Build Failures

1. Clean build artifacts:
   ```bash
   swift package clean
   ```

2. Reset package cache:
   ```bash
   rm -rf .build
   swift package reset
   ```

3. Check Swift version:
   ```bash
   swift --version
   ```

### Permission Issues

If you encounter permission issues with `/usr/local/swift`:

```bash
sudo chown -R $USER:$USER /usr/local/swift
```

## Resources

### Swift Language

- [Swift Language Guide](https://docs.swift.org/swift-book/)
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [Swift Evolution](https://apple.github.io/swift-evolution/)

### Swift Package Manager

- [SPM Documentation](https://swift.org/package-manager/)
- [Package Manifest Format](https://github.com/apple/swift-package-manager/blob/main/Documentation/PackageDescription.md)

### SGP4 Algorithm

- [Celestrak SGP4 Documentation](https://celestrak.org/NORAD/documentation/)
- [Revisiting Spacetrack Report #3](https://celestrak.org/publications/AIAA/2006-6753/)

## Next Steps

1. **Complete Swift 6 Migration**: Address all compilation errors
2. **Add Test Coverage**: Implement comprehensive test suite
3. **Performance Testing**: Benchmark propagation performance
4. **Documentation**: Add inline code documentation
5. **CI/CD**: Set up GitHub Actions for automated testing
6. **Example Projects**: Create sample applications demonstrating usage
