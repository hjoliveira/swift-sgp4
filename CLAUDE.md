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

swift-format is integrated as a Swift Package Manager plugin, so no manual installation is required.

## Using swift-format

- Format all Swift files: `swift package format-source-code --allow-writing-to-package-directory`
- Check formatting (lint): `swift package lint-source-code`

The plugin will automatically use the `.swift-format` configuration file in the repository root.

## CI Format Check

The CI workflow automatically checks code formatting on all pull requests and pushes to main/master.
If your code is not properly formatted, the CI check will fail. Make sure to run the format command
before pushing your changes.
