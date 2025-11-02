# Proposal: API Client Macro System

## Why

ModernNetworking currently requires developers to write repetitive networking code for each API endpoint, manually constructing HTTP requests, handling parameters, and decoding responses. This leads to boilerplate code duplication across API client implementations and increases the likelihood of errors in request construction.

A Retrofit-style macro system would enable developers to define complete REST API clients declaratively using protocol annotations, with the compiler generating type-safe NetworkClient-based implementations at build time. This eliminates networking boilerplate while maintaining compile-time validation of endpoints, parameters, and types.

## What Changes

- Add Swift macro system for declarative API client generation from annotated protocols
- Implement 9 public macros: `@API`, `@GET`, `@POST`, `@PUT`, `@PATCH`, `@DELETE`, `@DefaultHeaders`, `@Timeout`, and parameter handling
- Generate `Sendable`-conforming implementation structs that integrate with existing NetworkClient infrastructure
- Provide compile-time validation for path parameters, query parameters, request bodies, and return types
- Support full HTTP CRUD operations with automatic JSON encoding/decoding
- Integrate seamlessly with existing middleware (authentication, retry, caching, logging) and security features

Example usage:
```swift
@API(baseURL: "https://api.github.com")
protocol GitHubAPI {
    @GET("/users/{username}")
    func getUser(username: String) async throws -> User

    @POST("/repos/{owner}/{repo}/issues", body: "issue")
    func createIssue(owner: String, repo: String, issue: NewIssue) async throws -> Issue
}

// Compiler generates GitHubAPIImplementation with full NetworkClient integration
let api = GitHubAPIImplementation()
let user = try await api.getUser(username: "brunogama")
```

**BREAKING**: None. This is additive functionality built on top of existing NetworkClient.

## Impact

### Affected Specs
- **networking-macros** (NEW): Complete macro system specification

### Affected Code
- `Package.swift` - Already configured with NetworkingMacros macro target
- `Sources/Networking/Macros/` - Public macro declarations (9 files)
- `Sources/NetworkingMacros/` - SwiftSyntax-based macro implementations (15+ files)
- `Tests/NetworkingTests/Macros/` - Macro expansion tests (comprehensive test suite)

### Dependencies
- SwiftSyntax 600.0.0+ (already dependency)
- swift-macro-testing 0.5.2+ (already dependency)
- No new external dependencies required

### Migration Path
- Fully backward compatible - no breaking changes to existing NetworkClient API
- Developers can opt-in to macro-based API clients incrementally
- Generated code uses existing NetworkClient, inheriting all middleware and security features

### Performance Implications
- Compile-time code generation adds <5s to build time for 20 endpoints
- Runtime performance identical to hand-written NetworkClient code (zero overhead)
- Generated code follows same execution path as manual implementation

### Testing Requirements
- 80% unit test coverage for macro expansion logic
- 15% integration tests validating generated code with NetworkClient
- 5% E2E tests with real network requests
- Property-based testing for path template validation
- All tests must pass with Swift 6 strict concurrency enabled
