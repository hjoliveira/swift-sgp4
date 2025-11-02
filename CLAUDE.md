# Always keep in mind

- Install Swift 6.x from swift.org if the swift command cannot be found. No need to use a docker container.

- ALWAYS run the build after making changes and pushing them.

- ALWAYS run the tests after making changes and pushing them.

- Try to keep 0 warnings when building.

# Useful commands

- swift build: build the project

- swift test: run the tests

# Code formatting

The project uses swift-format for code formatting. The configuration is stored in `.swift-format`.

## Installing swift-format

1. Install Swift 6.x if not already installed
2. Clone and build swift-format:
   ```bash
   git clone --depth 1 --branch 600.0.0 https://github.com/swiftlang/swift-format.git
   cd swift-format
   swift build -c release
   ```
3. The binary will be at `.build/release/swift-format`

## Using swift-format

- Format all Swift files: `swift-format format -i -r SwiftSGP4 SwiftSGP4Tests Package.swift`
- Check formatting: `swift-format lint -r SwiftSGP4 SwiftSGP4Tests Package.swift`
- Format a single file: `swift-format format -i <file.swift>`
