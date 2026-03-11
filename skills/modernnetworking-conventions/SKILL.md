---
name: modernnetworking-conventions
description: Apply the project-specific conventions for the ModernNetworking repository. Use when editing this repo, deciding which package is affected, updating Package.swift or Package.resolved files, changing root tooling like `.swift-format`, `.swiftlint.yml`, or `.pre-commit-config.yaml`, or needing the repo’s code standards, dependency boundaries, agent guidance, and verification commands.
---

# ModernNetworking Conventions

Use this skill when working anywhere in this repository. It turns the root rules, package layout, and tooling into an explicit workflow for agents.

## Workflow

1. Determine the affected area before editing:
   - `Packages/Networking/`
   - `Packages/NetworkingMacros/`
   - shared root tooling or dependency files that affect both packages
2. Read the root guidance files first:
   - `AGENTS.md`
   - `RULES.md`
3. Read the package-specific `CLAUDE.md` for the touched area:
   - `Packages/Networking/Sources/Networking/CLAUDE.md`
   - `Packages/Networking/Tests/NetworkingTests/CLAUDE.md`
   - `Packages/NetworkingMacros/CLAUDE.md`
4. Apply the repo code standards from [code-standards.md](references/code-standards.md).
5. Apply the package and dependency rules from [package-and-dependencies.md](references/package-and-dependencies.md).
6. Run the verification commands for the affected package or packages. Do not rely on `swift test` at the repo root.

## Decision Rules

- If the change only touches `Packages/Networking/`, validate only that package unless the change also affects shared root tooling or shared scripts.
- If the change only touches `Packages/NetworkingMacros/`, validate only that package unless the change also affects shared root tooling or shared scripts.
- If the change touches `Package.swift`, `Package.resolved`, `.swift-format`, `.swiftlint.yml`, `.pre-commit-config.yaml`, `AGENTS.md`, `RULES.md`, or shared scripts, treat both packages as affected.
- If the change introduces or upgrades dependencies, keep the change inside the affected package manifest and resolved file unless the root workspace shell also needs wiring.
- If the change adds tests, prefer the dominant style in the touched area. Use Swift Testing for new suites; keep Quick/Nimble only where existing BDD tests already depend on it unless migration is the task.

## References

Read [code-standards.md](references/code-standards.md) for coding, testing, and verification expectations.

Read [package-and-dependencies.md](references/package-and-dependencies.md) for workspace layout, affected-package detection, dependency boundaries, and package-specific commands.
