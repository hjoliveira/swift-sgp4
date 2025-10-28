# Code Formatting

This project uses [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) to automatically format Swift code.

## Installation

### Option 1: Using Homebrew (macOS)

```bash
brew install swiftformat
```

### Option 2: Using Mint

```bash
mint install nicklockwood/SwiftFormat
```

### Option 3: Manual Build

SwiftFormat is already included as a package dependency, so you can build it locally:

```bash
swift build -c release --package-path .build/checkouts/SwiftFormat
```

## Usage

### Automatic Formatting on Commit

A pre-commit git hook is configured to automatically format staged Swift files before each commit. The hook will:

1. Detect all staged `.swift` files
2. Format them using the rules defined in `.swiftformat`
3. Re-stage the formatted files
4. Continue with the commit

If `swiftformat` is not installed, the hook will show a warning but allow the commit to proceed.

### Manual Formatting

Format all Swift files in the project:

```bash
swiftformat .
```

Format a specific file or directory:

```bash
swiftformat Sources/
swiftformat MyFile.swift
```

Check formatting without making changes (lint mode):

```bash
swiftformat --lint .
```

### Build Plugin

SwiftFormat is also configured as a build plugin in `Package.swift`. You can run it via:

```bash
swift package plugin swiftformat
```

## Configuration

Formatting rules are defined in `.swiftformat` at the root of the project. Key settings include:

- Swift version: 6.0
- Indentation: 4 spaces
- Max line width: 120 characters
- Sorted imports enabled
- Redundant code removal enabled

To modify formatting rules, edit the `.swiftformat` file. See the [SwiftFormat documentation](https://github.com/nicklockwood/SwiftFormat#config-file) for all available options.

## CI Integration

To enforce formatting in CI, add this step to your workflow:

```bash
swiftformat --lint .
```

This will exit with a non-zero status if any files need formatting.

## Disabling for Specific Code

To disable formatting for a specific section of code, use comments:

```swift
// swiftformat:disable all
// Your unformatted code here
// swiftformat:enable all
```

Or disable specific rules:

```swift
// swiftformat:disable redundantSelf
let x = self.value
// swiftformat:enable redundantSelf
```

## Alternative: swift-format

If you prefer Apple's official formatter, you can switch to [swift-format](https://github.com/apple/swift-format):

1. Replace the SwiftFormat dependency in `Package.swift`
2. Update the pre-commit hook to use `swift-format`
3. Create a `.swift-format` configuration file

## Troubleshooting

**Hook not running**: Ensure the hook is executable:
```bash
chmod +x .git/hooks/pre-commit
```

**Different formatting results**: Ensure everyone on the team is using the same SwiftFormat version and configuration file.

**Conflicts with Xcode formatting**: Disable Xcode's automatic formatting or configure it to match SwiftFormat's rules.
