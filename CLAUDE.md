# Swift SGP4 - Project Guide for AI Assistants

This document contains important instructions and guidelines for working on the Swift SGP4 project.

## Project Overview

Swift SGP4 is a Swift implementation of the Simplified General Perturbations 4 (SGP4) satellite orbit propagation algorithm.

## Development Environment

### Swift Installation

- **Required Version**: Swift 6.x
- **Installation**: Download from [swift.org](https://swift.org) if the swift command cannot be found
- **Note**: No need to use a docker container

## Development Workflow

### Essential Rules

1. **ALWAYS run the build** after making changes and pushing them
2. **ALWAYS run the tests** after making changes and pushing them
3. **Try to keep 0 warnings** when building

### Useful Commands

- **Build the project**: `swift build`
- **Run tests**: `swift test`

## Code Formatting

The project uses `swift-format` for code formatting.

### Configuration

- Configuration file: `.swift-format` (in repository root)
- Integration: Swift Package Manager plugin (no manual installation required)

### Formatting Commands

- **Format all Swift files**:
  ```bash
  swift package format-source-code --allow-writing-to-package-directory
  ```

- **Check formatting (lint)**:
  ```bash
  swift package lint-source-code
  ```

### CI Format Check

- The CI workflow automatically checks code formatting on all pull requests and pushes to main/master
- **Important**: If your code is not properly formatted, the CI check will fail
- **Best Practice**: Run the format command before pushing your changes

## Git Workflow

1. Make your changes on the designated feature branch
2. Format your code using swift-format
3. Build the project and fix any errors/warnings
4. Run tests and ensure they pass
5. Commit with clear, descriptive messages
6. Push to the feature branch

## Additional Notes

- Keep code clean and well-documented
- Follow Swift best practices and conventions
- Ensure all tests pass before pushing
- Monitor CI checks after pushing
