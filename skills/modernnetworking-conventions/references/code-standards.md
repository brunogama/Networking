# ModernNetworking Code Standards

## Table of contents

- Precedence
- Core standards
- Testing standards
- Tooling standards
- Verification commands
- Review checklist

## Precedence

Apply standards in this order:

1. `RULES.md`
2. `AGENTS.md`
3. Package-specific `CLAUDE.md`
4. Tooling configuration files such as `.swift-format`, `.swiftlint.yml`, and `.pre-commit-config.yaml`

## Core standards

- Keep changes production-ready unless the user explicitly asks for a prototype.
- Prefer the smallest correct diff. Avoid opportunistic refactors, file renames, or unrelated formatting.
- Preserve Swift 6 strict concurrency:
  - keep `Sendable` annotations intact
  - maintain actor isolation and `@MainActor` boundaries
  - use `await` correctly across async boundaries
- Do not add force unwraps, `fatalError()`, `precondition()`, or `assert()` in production code.
- Prefer value types and explicit data flow over shared mutable state.
- Keep code readable and unsurprising. Use early exits instead of deep nesting where practical.

## Testing standards

- Match the dominant test style in the touched area:
  - Swift Testing for newer suites
  - Quick/Nimble only in established BDD areas unless migration is the goal
  - XCTest where that file or subsystem already uses it
- Add or update tests when behavior changes.
- Keep tests deterministic. Avoid hidden shared state unless the suite is intentionally serialized.
- Use project mocks and helpers before inventing new test infrastructure:
  - `MockNetworkClient`
  - `MockURLProtocol`
  - `MockDSL`
- Respect the relaxed nested SwiftLint configuration in package test directories when editing tests.

## Tooling standards

- Format changed Swift files from the repo root:

```bash
swift-format -i --configuration .swift-format <changed-swift-files>
```

- Lint changed Swift files from the repo root with explicit filenames:

```bash
swiftlint lint --fix --config .swiftlint.yml -- <changed-swift-files>
swiftlint lint --strict --config .swiftlint.yml -- <changed-swift-files>
```

- Do not rely on repo-root `swift test`. The root manifest has no targets or tests.
- Use package-path-aware commands for build and test validation.
- Respect pre-commit expectations in `.pre-commit-config.yaml`, especially:
  - formatter
  - SwiftLint fix
  - warnings-as-errors build
  - affected-package tests
  - branch protection and changelog checks

## Verification commands

### Networking

```bash
swift build --package-path Packages/Networking -Xswiftc -warnings-as-errors
swift test --package-path Packages/Networking
```

### NetworkingMacros

```bash
swift build --package-path Packages/NetworkingMacros -Xswiftc -warnings-as-errors
swift test --package-path Packages/NetworkingMacros
```

### Shared root changes

Run both package validation sets when the change touches shared root tooling, package wiring, or shared scripts.

## Review checklist

- Is the affected package set correct?
- Are concurrency and `Sendable` constraints preserved?
- Does the change avoid new force unwraps or runtime traps in production code?
- Are the formatter and linter commands applicable to the changed files?
- Did the required package build and test commands run?
- Were dependency changes kept minimal and justified?
