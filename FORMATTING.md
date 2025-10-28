# Code Formatting and Linting

This project uses two complementary tools to maintain code quality:
- **[SwiftFormat](https://github.com/nicklockwood/SwiftFormat)** - Automatic code formatting (whitespace, indentation, etc.)
- **[SwiftLint](https://github.com/realm/SwiftLint)** - Code style and best practices linting

## Installation

### Option 1: Using Homebrew (macOS) - Recommended

```bash
brew install swiftformat swiftlint
```

### Option 2: Using Mint

```bash
mint install nicklockwood/SwiftFormat
mint install realm/SwiftLint
```

### Option 3: Manual Build

Both tools are included as package dependencies, so you can build them locally:

```bash
swift build -c release --package-path .build/checkouts/SwiftFormat
swift build -c release --package-path .build/checkouts/SwiftLint
```

## Usage

### Automatic Formatting and Linting on Commit

A pre-commit git hook is configured to automatically format and lint staged Swift files before each commit. The hook will:

1. Detect all staged `.swift` files
2. **Format** them using SwiftFormat with the rules defined in `.swiftformat`
3. Re-stage the formatted files
4. **Lint** them using SwiftLint with the rules defined in `.swiftlint.yml`
5. Show any linting issues (but still allow the commit)

If the tools are not installed, the hook will show warnings but allow the commit to proceed.

### Manual Formatting

Format all Swift files in the project:

```bash
swiftformat .
```

Format a specific file or directory:

```bash
swiftformat SwiftSGP4/
swiftformat MyFile.swift
```

Check formatting without making changes:

```bash
swiftformat --lint .
```

### Manual Linting

Lint all Swift files in the project:

```bash
swiftlint lint
```

Lint specific files:

```bash
swiftlint lint --path SwiftSGP4/
```

Auto-fix some linting issues:

```bash
swiftlint --fix
```

Count violations by rule:

```bash
swiftlint analyze
```

### Build Plugins

Both SwiftFormat and SwiftLint are configured as build plugins in `Package.swift`:

```bash
# Run SwiftFormat via plugin
swift package plugin swiftformat

# SwiftLint runs automatically during build
swift build
```

## Configuration

### SwiftFormat Configuration

Formatting rules are defined in `.swiftformat` at the root of the project. Key settings include:

- Swift version: 6.0
- Indentation: 4 spaces
- Max line width: 120 characters
- Sorted imports enabled
- Redundant code removal enabled

To modify formatting rules, edit the `.swiftformat` file. See the [SwiftFormat documentation](https://github.com/nicklockwood/SwiftFormat#config-file) for all available options.

### SwiftLint Configuration

Linting rules are defined in `.swiftlint.yml` at the root of the project. Key settings include:

- Line length: 120 characters (warning), 200 (error)
- File length: 500 lines (warning), 1000 (error)
- Function body length: 50 lines (warning), 100 (error)
- Cyclomatic complexity: 15 (warning), 25 (error)
- Many opt-in rules enabled for better code quality
- Custom rules for operator whitespace and force unwrapping

To modify linting rules, edit the `.swiftlint.yml` file. See the [SwiftLint documentation](https://realm.github.io/SwiftLint/) for all available rules.

## CI Integration

To enforce formatting and linting in CI, add these steps to your workflow:

```bash
# Check formatting (will fail if files need formatting)
swiftformat --lint .

# Run linter (will fail if there are violations)
swiftlint lint --strict
```

Both commands will exit with a non-zero status if there are issues, which will fail the CI build.

## Disabling for Specific Code

### SwiftFormat

To disable formatting for a specific section of code:

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

### SwiftLint

To disable linting for a specific section of code:

```swift
// swiftlint:disable all
// Your code here
// swiftlint:enable all
```

Or disable specific rules:

```swift
// swiftlint:disable line_length force_cast
let foo = someLongVariableNameThatExceedsTheLineLimit as! String
// swiftlint:enable line_length force_cast
```

Disable for just the next line:

```swift
// swiftlint:disable:next force_cast
let foo = bar as! String
```

Disable for the current line:

```swift
let foo = bar as! String // swiftlint:disable:this force_cast
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

**Different formatting/linting results**: Ensure everyone on the team is using compatible versions:
```bash
swiftformat --version
swiftlint version
```

**Too many linting warnings**: You can temporarily disable specific rules in `.swiftlint.yml` by adding them to the `disabled_rules` section.

**Conflicts with Xcode formatting**: Disable Xcode's automatic formatting or configure it to match SwiftFormat's rules. You can also use Xcode's "Editor > SwiftFormat > Format File" if you install the SwiftFormat Xcode extension.

**SwiftLint build plugin warnings**: The build plugin runs during compilation and shows violations. To suppress these during development, you can temporarily remove the plugin from `Package.swift` or fix the violations.
