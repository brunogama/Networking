# Agent Rules (@RULES.md)

This file serves as the definitive source of truth for AI agents working on the ModernNetworking project. If `CLAUDE.md` or `.cursorrules` contradict this file, **this file takes precedence**.

## 1. Core Philosophy

- **Production-Grade Quality**: All code must be ready for production. No "temporary" or "hacky" solutions unless explicitly requested for prototyping.
- **Safety First**: strict adherence to security and safety protocols.
- **Minimalism**: Write code that is simple, readable, and does exactly what is needed—no more, no less.

## 2. Mandatory Constraints (MUST)

### Code Quality
- **Verify Before Committing**: ALWAYS run `swift build -Xswiftc -warnings-as-errors && swift test` before finishing a task.
- **Strict Concurrency**: All Swift code must be fully strictly concurrent (Swift 6 mode). Use `await`, `MainActor`, and `Sendable` correctly.
- **No Force Unwrapping**: Never use `!` on optionals in production code.
- **No Fatal Errors**: Do not use `fatalError()` in production code.

### Security
- **No Secrets**: Never commit API keys, tokens, or passwords.
- **Input Validation**: Validate all external inputs (network, user, file system).

## 3. Workflow

- **Plan First**: Always analyze the task and create a plan before writing code.
- **Step-by-Step**: Execute complex changes in small, verifiable steps.
- **Self-Correction**: If a step fails, stop, analyze, and fix the plan. Do not blindly retry.

## 4. Communication

- **Be Concise**: Keep status updates and explanations short and to the point.
- **Ask for Clarification**: If a requirement is ambiguous, ask the user.
