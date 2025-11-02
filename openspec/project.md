# Project Context

## Purpose
ModernNetworking is a Swift 6 compliant networking framework for iOS, macOS, tvOS, and watchOS. The framework provides type-safe HTTP client implementations with async/await support, structured concurrency, and a powerful middleware system built on URLSession.

## Tech Stack
- Swift 6.0+ with strict concurrency
- SwiftSyntax 600.0.0+ for macro implementations
- Swift Package Manager with macro plugin support
- XCTest framework with async test support
- swift-macro-testing 0.5.2+ for macro validation

## Project Conventions

### Code Style
- Follow Google Swift Style Guide
- SwiftLint enforced with custom rules
- 100 character line limit
- Comprehensive DocC documentation required
- No force-unwrapping, no fatalError in production code

### Architecture Patterns
- Middleware-driven request/response pipeline
- Result builder DSL for request construction
- Protocol-oriented design with Swift 6 Sendable compliance
- Compile-time validation over runtime errors
- Single Responsibility Principle (SRP)

### Testing Strategy
- Test pyramid: 80% unit, 15% integration, 5% E2E
- Minimum coverage: 90% domain logic, 70% application layer, 50% infrastructure
- Property-based testing for algebraic laws
- TDD workflow: RED → GREEN → REFACTOR
- All tests must pass, warnings are errors

### Git Workflow
- Feature branches from `dev` (main branch)
- Branch naming: `epic/feature-name` or `001-feature-id`
- Commit messages: Conventional Commits format
- Pre-commit hooks enforce linting and tests
- Never use `--no-verify` to skip hooks

## Domain Context

### Networking Framework
- **NetworkClient**: Core HTTP client with middleware pipeline
- **Middleware**: Composable request/response interceptors (auth, retry, caching, logging)
- **Request Builder**: Fluent DSL using @resultBuilder
- **Type Safety**: Sendable conformance throughout, no Data races

### Macro System
- **Swift Macros**: Compile-time code generation using SwiftSyntax
- **Retrofit Pattern**: Declarative API client definitions via protocol annotations
- **Validation**: Compile-time parameter checking, path template validation
- **Integration**: Generated code uses existing NetworkClient infrastructure

## Important Constraints

### Swift 6 Compliance
- Full strict concurrency enabled
- All public types must conform to Sendable
- No @unchecked Sendable allowed
- Explicit actor isolation required

### Platform Support
- iOS 16.0+, macOS 13.0+, tvOS 16.0+, watchOS 9.0+
- Cross-platform compatibility required
- No platform-specific code in core library

### Production Quality
- This is AAA-quality production code for distribution
- No crashes allowed: no fatalError, preconditionFailure, assertions
- Enforce invariants in initializers
- Make illegal states unrepresentable

## External Dependencies
- SwiftSyntax: Macro implementation and AST manipulation
- swift-macro-testing: Macro expansion testing
- SwiftCheck: Property-based testing
- Quick/Nimble: BDD-style test framework
