# Agent Rules (@RULES.md)

This file is the definitive source of truth for AI agents working on the ModernNetworking project. If `AGENTS.md`, `CLAUDE.md`, or `.cursorrules` contradict this file, this file takes precedence.

## 1. Core Philosophy

- **Production-Grade Quality**: All changes must be production-ready unless the user explicitly asks for a prototype.
- **Safety First**: Treat security, concurrency safety, and input validation as mandatory.
- **Minimalism**: Write the smallest correct change. Avoid speculative abstractions and unrelated cleanup.

## 2. Workspace Awareness

- The root [Package.swift](Package.swift) is a workspace shell with no targets or tests.
- The buildable packages are:
  - `Packages/Networking`
  - `Packages/NetworkingMacros`
- Do not treat `swift test` at the repository root as meaningful validation.
- Treat both packages as affected when editing shared root files such as:
  - `Package.swift`
  - `Package.resolved`
  - `.swift-format`
  - `.swiftlint.yml`
  - `.pre-commit-config.yaml`
  - `AGENTS.md`
  - `RULES.md`
  - files under `scripts/`

## 3. Mandatory Constraints (MUST)

### Code Quality

- **Verify before finishing**:
  - If `Packages/Networking/` is affected, run:
    - `swift build --package-path Packages/Networking -Xswiftc -warnings-as-errors`
    - `swift test --package-path Packages/Networking`
  - If `Packages/NetworkingMacros/` is affected, run:
    - `swift build --package-path Packages/NetworkingMacros -Xswiftc -warnings-as-errors`
    - `swift test --package-path Packages/NetworkingMacros`
  - If shared root tooling or dependency files are affected, run both validation sets.
- **Format changed Swift files** from the repository root with:
  - `swift-format -i --configuration .swift-format <changed-swift-files>`
- **Lint changed Swift files** from the repository root with explicit filenames:
  - `swiftlint lint --fix --config .swiftlint.yml -- <changed-swift-files>`
  - `swiftlint lint --strict --config .swiftlint.yml -- <changed-swift-files>`
- **Strict Concurrency**: All Swift code must remain strictly concurrent in Swift 6 mode. Use `await`, `MainActor`, actors, and `Sendable` correctly.
- **No Force Unwrapping**: Never use `!` in production code.
- **No Fatal Runtime Traps**: Do not introduce `fatalError()`, `precondition()`, or `assert()` in production code.

### Dependency Hygiene

- The root manifest only aggregates local packages; do not add targets or products there.
- Add or update external dependencies only with clear justification.
- Update only the relevant `Package.resolved` files when the dependency graph changes.
- Keep dependency order assumptions consistent with [scripts/test-affected-packages.sh](scripts/test-affected-packages.sh).

### Security

- **No Secrets**: Never commit API keys, tokens, passwords, or other secrets.
- **Input Validation**: Validate all external inputs, including URLs, headers, request bodies, and file-system inputs.

## 4. Workflow

- **Plan First**: Analyze the task and identify the affected package or packages before writing code.
- **Read Local Guidance**: Read [AGENTS.md](AGENTS.md) and the relevant package-specific `CLAUDE.md` files for the area you are touching.
- **Step-by-Step**: Execute complex work in small, verifiable steps.
- **Self-Correction**: If validation fails, stop, analyze, and fix the issue rather than retrying blindly.
- **Scope Control**: Avoid unrelated refactors, file moves, renames, or mass formatting outside the task.

## 5. Communication

- **Be Concise**: Keep status updates and explanations short and concrete.
- **Ask for Clarification**: If a requirement is genuinely ambiguous and risky to assume, ask the user directly.
