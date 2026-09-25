# AGENTS.md

---

## Scope

This file applies to the entire repository. [RULES.md](RULES.md) is the definitive source of truth when any guidance conflicts.

---

## Workspace Layout

- The root [Package.swift](Package.swift) declares products and targets for package consumers.
- The standalone packages used for development checks are:
  - `Packages/Networking`
  - `Packages/NetworkingMacros`
- Shared root tooling lives in:
  - [.swift-format](.swift-format)
  - [.swiftlint.yml](.swiftlint.yml)
  - [.pre-commit-config.yaml](.pre-commit-config.yaml)
  - [scripts/test-affected-packages.sh](scripts/test-affected-packages.sh)

---

## Required Workflow

1. Plan first and identify the affected package or packages before editing.
2. Read [RULES.md](RULES.md) and any tracked package-specific guidance for the touched area.
3. Treat both packages as affected when touching shared root files such as `Package.swift`, `Package.resolved`, `.swift-format`, `.swiftlint.yml`, `.pre-commit-config.yaml`, `AGENTS.md`, `RULES.md`, or shared scripts.
4. Format and lint changed Swift files from the repo root using explicit filenames.
5. Run build and test commands with `--package-path`; do not rely on `swift test` at the repo root.

---

## Verification Matrix

- Changes under `Packages/Networking/`: run
  - `swift build --package-path Packages/Networking -Xswiftc -warnings-as-errors`
  - `swift test --package-path Packages/Networking`
- Changes under `Packages/NetworkingMacros/`: run
  - `swift build --package-path Packages/NetworkingMacros -Xswiftc -warnings-as-errors`
  - `swift test --package-path Packages/NetworkingMacros`
- Shared root config or dependency changes: run both package validation sets.

---

## Code Standards

- Preserve Swift 6 strict concurrency. Keep `Sendable`, actor isolation, and async boundaries correct.
- Do not introduce force unwraps, `fatalError`, `precondition`, or `assert` in production code.
- Prefer value types and the smallest viable diff. Avoid opportunistic refactors.
- Prefer the existing test style in the touched area. Use Swift Testing for new suites; extend Quick/Nimble only in existing BDD surfaces unless the task is explicitly a migration.
- Do not add or upgrade dependencies casually. Keep the root manifest and affected package manifests consistent when dependencies change.
