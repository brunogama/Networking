# ModernNetworking Package And Dependency Guide

## Table of contents

- Workspace shape
- Affected-package detection
- Package responsibilities
- External dependency boundaries
- Dependency-change rules

## Workspace shape

The repository root is a workspace shell:

- [Package.swift](../../../Package.swift) wires local packages together
- it does not define build targets
- it does not define test targets

The real packages are:

- `Packages/Networking`
- `Packages/NetworkingMacros`

Shared tooling and workflow files live at the root:

- `.swift-format`
- `.swiftlint.yml`
- `.pre-commit-config.yaml`
- `scripts/test-affected-packages.sh`
- `AGENTS.md`
- `RULES.md`

## Affected-package detection

Use this decision table:

- Files under `Packages/Networking/`:
  - affected package: `Networking`
- Files under `Packages/NetworkingMacros/`:
  - affected package: `NetworkingMacros`
- Files under `scripts/`:
  - affected packages: both, unless the script is obviously package-local
- Root `Package.swift`, `Package.resolved`, `.swift-format`, `.swiftlint.yml`, `.pre-commit-config.yaml`, `AGENTS.md`, or `RULES.md`:
  - affected packages: both

The pre-commit helper [scripts/test-affected-packages.sh](../../../scripts/test-affected-packages.sh) assumes dependency-aware testing in this order:

1. `MacroTemplateKit`
2. `NetworkingMacros`
3. `Networking`

Keep that expectation intact when changing package relationships or validation scripts.

## Package responsibilities

### Networking

- Primary HTTP client, middleware, observability, testing helpers, and BDD support
- Local manifests:
  - `Packages/Networking/Package.swift`
  - `Packages/Networking/Package.resolved`

### NetworkingMacros

- Swift macros and compiler plugin support for generated HTTP client APIs
- Local manifests:
  - `Packages/NetworkingMacros/Package.swift`
  - `Packages/NetworkingMacros/Package.resolved`

## External dependency boundaries

Current external dependencies are package-specific:

### `Packages/Networking`

- OpenTelemetry Swift
- SwiftCheck
- Quick
- Nimble

### `Packages/NetworkingMacros`

- MacroTemplateKit
- swift-syntax
- swift-macro-testing

The root workspace manifest should only reference local path packages unless the workspace structure itself changes.

## Dependency-change rules

- Add dependencies only in the package that actually needs them.
- Update the matching `Package.resolved` file for the affected package.
- Do not update both resolved files unless both dependency graphs changed.
- Do not add products or targets to the root workspace manifest to work around package-local issues.
- Explain why an existing dependency cannot solve the problem before introducing a new one.
