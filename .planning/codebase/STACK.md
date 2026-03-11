# Technology Stack

**Analysis Date:** 2026-02-14

## Languages

**Primary:**
- Swift 6.0+ - Entire codebase (async/await, structured concurrency, macros)

**Secondary:**
- None - Pure Swift project with no polyglot dependencies

## Runtime

**Environment:**
- Swift 6.0 (minimum), as declared in `Package.swift` line 1

**Package Manager:**
- Swift Package Manager (SPM)
- Lockfile: `Package.resolved` present

## Frameworks

**Core:**
- Foundation - HTTP primitives (URLSession, URLRequest, URLResponse)
- FoundationNetworking - Linux/cross-platform support (imported conditionally with `#if canImport(FoundationNetworking)`)

**Networking:**
- URLSession - HTTP client engine (native to Foundation)

**Testing:**
- XCTest - Unit testing framework (standard Swift testing)
- SwiftCheck 0.12.0+ - Property-based testing (imported via Package.swift line 24)
- Quick 7.4.0+ - BDD testing framework (imported via Package.swift line 25)
- Nimble 13.0.0+ - BDD assertion library (imported via Package.swift line 26)
- MacroTesting 0.5.2+ - Macro expansion testing (imported via Package.swift line 23)

**Build/Dev:**
- Swift Compiler Plugin Support - Macro plugin infrastructure (`SwiftCompilerPlugin` from `swift-syntax`)
- SwiftSyntax 600.0.0+ - AST manipulation for macros (imported via Package.swift line 22)
- SwiftSyntaxBuilder - AST node construction for macros
- SwiftSyntaxMacros - Macro protocol definitions

**Code Quality:**
- SwiftLint - Linting (configured in `.swiftlint.yml`)
- swift-format - Code formatting (configured in `.swift-format`)

## Key Dependencies

**Critical (direct usage):**
- swift-syntax 600.0.0+ - Required for macro plugin system
  - Packages: SwiftSyntax, SwiftSyntaxBuilder, SwiftSyntaxMacros, SwiftCompilerPlugin
  - Why it matters: Enables compile-time code generation for @API, @GET, @POST, etc. macros

**Testing Infrastructure:**
- SwiftCheck 0.12.0+ - Property-based testing framework
  - Location: `Tests/NetworkingTests/PropertyTests/`
  - Used for algorithmic testing (retry backoff, circuit breaker FSM, interceptor chains)

- Quick 7.4.0+ - BDD testing DSL
  - Location: `Sources/Networking/BDD/` (excluded from main library, available for integration)
  - Used for behavior-driven test descriptions

- Nimble 13.0.0+ - Matcher-based assertions
  - Location: Integration with Quick BDD tests
  - Provides `expect(...).to(...)` syntax

- swift-macro-testing 0.5.2+ - Macro assertion helpers
  - Location: `Tests/NetworkingTests/Macros/`
  - Used for testing macro expansion correctness

## Configuration

**Environment:**
- No environment variables required for library usage
- Runtime configuration via NetworkClient builder DSL (`Sources/Networking/NetworkClient.swift`)
- Security configuration via SecurityConfiguration type

**Build:**
- `Package.swift` - SPM manifest (lines 1-66)
- `.swiftlint.yml` - Linting rules (280+ lines, Google Swift style guide)
- `.swift-format` - Formatting rules (JSON format, 100 char line length)
- SwiftSettings in Package.swift:
  - `-warn-concurrency` flag enabled for actor safety
  - `-enable-actor-data-race-checks` flag enabled for concurrency validation

**Swift Compiler Flags:**
- `-warnings-as-errors` - Enforced in pre-commit validation
- `-warn-concurrency` - Detects unsafe concurrent code
- `-enable-actor-data-race-checks` - Validates actor isolation at compile time

## Platform Requirements

**Development:**
- Swift 6.0 or later
- Xcode 16+ recommended (for Swift 6 support)
- macOS, Linux (any platform with Swift 6 toolchain)

**Production (Target Platforms):**
- iOS 16+ (`platforms` in Package.swift line 10)
- macOS 13+ (`platforms` in Package.swift line 11)
- tvOS 16+ (`platforms` in Package.swift line 12)
- watchOS 9+ (`platforms` in Package.swift line 13)

**Security/Cryptography (Platform-specific):**
- Security framework (iOS, macOS) - Keychain access for token storage (`Sources/Networking/KeychainService.swift`)
- CommonCrypto (optional) - File transfer checksums (`Sources/Networking/FileTransferOperations.swift`)

## Macro System

**Compiler Plugin:**
- Target: `NetworkingMacros` (macro implementation target in Package.swift lines 43-50)
- Compiler Plugin API from SwiftCompilerPlugin
- Entry point: `Sources/NetworkingMacros/Plugin.swift` (defines `NetworkingPlugin`)

**Available Macros:**
```
@API - Protocol macro (generates API client types)
@GET, @POST, @PUT, @PATCH, @DELETE - HTTP method macros
@Body - Parameter macro (binds request body)
@Headers - Parameter macro (binds headers)
@Path - Parameter macro (binds path parameters)
@Query - Parameter macro (binds query parameters)
@DefaultHeaders - Request macro (sets default headers)
@Timeout - Request macro (configures timeout)
@Interceptors - Request macro (registers interceptors)
```

## Concurrency Model

**Async/Await:**
- All public APIs use Swift 6 `async throws` (no callbacks)
- URLSession integration via `.data(from:)` and `.data(for:)` async methods

**Actor Isolation:**
- `-enable-actor-data-race-checks` enabled in Package.swift
- Sendable protocol enforced on all shared types
- Examples: `HTTPRequest`, `HTTPResponse`, `HTTPError`, `KeychainService` all marked `Sendable`

**Thread Safety:**
- URLSession is thread-safe natively
- Middleware chain is serial (preserves request order)
- Actor-protected cache in caching middleware

## Build Outputs

**Library Target:** `Networking`
- Binary: `libNetworking.dylib` or `.a` (platform-dependent)
- Exported symbols from `Sources/Networking/Networking.swift`

**Macro Plugin Target:** `NetworkingMacros`
- Plugin binary loaded at compile-time
- Injected into Swift compiler process

**Test Target:** `NetworkingTests`
- Executable test bundle
- 62 test files covering all public APIs

## Package Distribution

**SPM Distribution:**
- GitHub repository: https://github.com/brunogama/Networking
- Package URL: `https://github.com/brunogama/Networking.git`
- Distributed as single library target `Networking`

**Documentation:**
- Swift-DocC catalog in `Documentation.docc/`
- Built-in documentation comments using `///` (triple-slash)
- AllPublicDeclarationsHaveDocumentation rule enforced

---

*Stack analysis: 2026-02-14*
