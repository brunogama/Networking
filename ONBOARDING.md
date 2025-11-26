# ModernNetworking - Comprehensive Onboarding Guide

Welcome to ModernNetworking! This guide will help you get up to speed with the codebase, architecture, and development workflows.

---

## 1. Project Overview

### Purpose and Functionality

ModernNetworking is a **Swift 6 compliant networking framework** designed for modern iOS, macOS, tvOS, and watchOS applications. The framework provides:

- **Core Networking**: Async/await URLSession integration with fluent DSL for request/response building
- **Middleware Architecture**: Comprehensive middleware system for authentication, retry logic, caching, logging, and metrics
- **Code Generation**: Macro-based API client generation inspired by Retrofit (Android)
- **Security**: OWASP Top 10 compliance with header injection prevention, certificate pinning, and secure token storage
- **File Operations**: Upload/download with progress tracking and resume support
- **Resilience**: Circuit breaker pattern for fault tolerance

### Tech Stack

**Languages & Frameworks**
- Swift 6.0+ (strict concurrency compliance)
- SwiftSyntax 600.0.0+ for macro implementations
- Foundation URLSession for HTTP transport
- Security framework for SSL pinning and certificate validation
- Keychain Services for secure credential storage

**Build System**
- Swift Package Manager (SPM) with macro plugin support
- Xcode 16.0+
- swift-format for code formatting
- SwiftLint for code quality validation

**Testing Infrastructure**
- XCTest with async/await support
- MacroTesting (swift-macro-testing 0.5.2+) for macro validation
- SwiftCheck (0.12.0+) for property-based testing
- Quick/Nimble (BDD-style testing)

**Development Tools**
- Pre-commit hooks (swift-format, SwiftLint, tests, warnings-as-errors)
- OpenSpec for spec-driven development
- DocC for documentation generation
- GitHub Actions for CI/CD

### Architecture Pattern

ModernNetworking follows a **layered middleware architecture** with three primary stages:

1. **Request Middleware Pipeline**: Processes requests before execution (authentication, headers, logging)
2. **Network Execution Layer**: URLSession-based HTTP transport with structured concurrency
3. **Response Middleware Pipeline**: Processes responses after execution (caching, validation, transformation)
4. **Error Middleware Pipeline**: Handles errors and provides recovery strategies (retry, circuit breaker)

The framework also implements:
- **Result Builder Pattern**: Fluent DSL for declarative request/response building
- **Protocol-Oriented Design**: HTTPClient protocol with NetworkClient implementation
- **Macro-Based Code Generation**: Swift macros for automatic API client creation
- **Interceptor Pattern**: Request/response interceptor chain (in development)

### Key Dependencies

**Runtime Dependencies**
- None (framework uses only Apple platform SDKs)

**Development Dependencies**
- `swiftlang/swift-syntax` (600.0.0+): SwiftSyntax for macro implementations
- `pointfreeco/swift-macro-testing` (0.5.2+): Macro expansion testing
- `typelift/SwiftCheck` (0.12.0+): Property-based testing
- `Quick/Quick` (7.4.0+): BDD test framework
- `Quick/Nimble` (13.0.0+): Matcher framework for expressive assertions

**Build Tools**
- SwiftCompilerPlugin: Compiler plugin infrastructure for macros
- swift-format: Code formatting (Google Swift Style Guide)
- SwiftLint: Linting with separation from formatting

### Platform Support

- **iOS**: 16.0+ (full feature support including background tasks)
- **macOS**: 13.0+ (complete API availability with security framework)
- **tvOS**: 16.0+ (core networking with platform-appropriate error handling)
- **watchOS**: 9.0+ (optimized for constrained resources)

---

## 2. Repository Structure

### Top-Level Directories

```
ModernNetworking/
├── Sources/                    # Framework source code
│   ├── Networking/            # Main framework target (library)
│   └── NetworkingMacros/      # Macro implementation target (compiler plugin)
├── Tests/                      # Test suite
│   └── NetworkingTests/       # Framework and macro tests
├── Samples/                    # Sample code and playground
│   └── Arena-Playground/      # Interactive examples
├── Documentation.docc/         # DocC documentation
├── openspec/                   # Spec-driven development artifacts
│   ├── specs/                 # Capability specifications
│   └── changes/               # Active and archived change proposals
├── docs/                       # Additional documentation
├── docs-build/                 # Generated DocC output
├── .claude/                    # Claude Code commands and configuration
├── .github/                    # GitHub Actions workflows
├── claude_md_files/            # Framework-specific CLAUDE.md examples
├── ai_docs/                    # AI documentation and guides
└── Package.swift               # Swift Package Manager manifest
```

### Source Code Organization

**`Sources/Networking/` - Main Framework (55 files)**

Core Networking:
- `HTTPClient.swift` - Core protocol definition
- `NetworkClient.swift` - Primary HTTPClient implementation (795 lines)
- `HTTPRequest.swift` - Request type with builder support
- `HTTPResponse.swift` - Response type with validation
- `HTTPMethod.swift` - HTTP method enumeration
- `HTTPStatus.swift` - HTTP status code handling
- `HTTPError.swift` - Comprehensive error types

Request Building:
- `RequestBuilder.swift` - Result builder for fluent DSL (234 lines)
- `RequestComponents.swift` - Component implementations (headers, auth, query params)
- `RequestBuilderExtensions.swift` - Additional DSL components
- `BodyComponents.swift` - Request body handling (JSON, form data, multipart)

Middleware System:
- `AuthenticationMiddleware.swift` - Bearer token and basic auth
- `RetryMiddleware.swift` - Configurable retry with exponential backoff
- `CachingMiddleware.swift` - Multi-level caching with TTL (27,149 chars)
- `LoggingMiddleware.swift` - Request/response logging with privacy controls
- `ErrorMiddleware.swift` - Error handling and recovery
- `CircuitBreakerMiddleware.swift` - Fault tolerance pattern
- `HeaderSecurityMiddleware.swift` - OWASP security headers
- `NetworkObservabilityMiddleware.swift` - Metrics and monitoring (28,142 chars)
- `ProgressTrackingMiddleware.swift` - Upload/download progress
- `RequestTimingMiddleware.swift` - Performance timing

Configuration:
- `NetworkingConfiguration.swift` - Client configuration
- `ConfigurationComponents.swift` - Configuration DSL (30,006 chars)
- `SecurityConfiguration.swift` - SSL pinning and certificate validation
- `NetworkClientBuilder.swift` - Builder pattern for client creation

File Operations:
- `FileTransferOperations.swift` - Upload/download with progress (27,027 chars)
- `TransferControls.swift` - Pause/resume/cancel controls (27,097 chars)
- `ProgressTracking.swift` - Progress reporting

Response Processing:
- `ResponseProcessing.swift` - Response chain processing
- `ResponseTransformation.swift` - Data transformation
- `ValidatedResponse.swift` - Response validation
- `DecodableResponseTypes.swift` - JSON decoding support
- `CachedResponseTypes.swift` - Cache response handling
- `HTTPResponseBuilder.swift` - Response construction

Utilities:
- `MetricsCollector.swift` - Performance metrics collection (29,236 chars)
- `KeychainService.swift` - Secure token storage
- `ActionableErrorInfo.swift` - Error recovery information
- `ErrorRecoveryStrategies.swift` - Error recovery patterns
- `CacheStorageProviders.swift` - Cache storage implementations
- `TestUtilities.swift` - Testing helpers

Macro Declarations:
- `Macros/API.swift` - @API protocol macro declaration
- `Macros/HTTPMethodMacros.swift` - @GET, @POST, @PUT, @PATCH, @DELETE declarations
- `Macros/ConfigurationMacros.swift` - @DefaultHeaders, @Timeout declarations
- `Macros/MacroError.swift` - Macro error types

Interceptors (New):
- `Interceptors/InterceptorProtocols.swift` - Request/response interceptor protocols
- `Interceptors/InterceptorChain.swift` - Interceptor execution chain
- `Interceptors/InterceptorContext.swift` - Interceptor context
- `Interceptors/InterceptorResult.swift` - Interceptor result types
- `Interceptors/InterceptorError.swift` - Interceptor errors

Testing Support:
- `Testing/MockNetworkClient.swift` - Mock client for testing
- `Testing/MockURLProtocol.swift` - Mock URL protocol

**`Sources/NetworkingMacros/` - Macro Implementation (14 files)**

Plugin:
- `Plugin.swift` - SwiftCompilerPlugin entry point

API Macro:
- `API/APIMacro.swift` - @API macro implementation (generates implementation struct)

HTTP Method Macros:
- `HTTP/GETMacro.swift` - @GET macro with path/query parameter support
- `HTTP/POSTMacro.swift` - @POST macro with body encoding
- `HTTP/PUTMacro.swift` - @PUT macro for full updates
- `HTTP/PATCHMacro.swift` - @PATCH macro for partial updates
- `HTTP/DELETEMacro.swift` - @DELETE macro for deletions

Configuration Macros:
- `Configuration/DefaultHeadersMacro.swift` - @DefaultHeaders implementation
- `Configuration/TimeoutMacro.swift` - @Timeout implementation

Interceptor Macros:
- `Interceptors/InterceptorsMacro.swift` - @Interceptors macro (in development)

Shared Utilities:
- `Shared/MacroHelpers.swift` - Validation, parameter extraction, diagnostics
- `Shared/PathTemplateParser.swift` - REST path template parsing (/users/{id})
- `Shared/SyntaxFactory.swift` - SwiftSyntax code generation utilities

### Test Organization

**`Tests/NetworkingTests/` - Test Suite (35 files, 48,213 total lines)**

Macro Tests:
- `Macros/APIMacroTests.swift` - @API macro validation (15 tests)
- `Macros/GETMacroTests.swift` - @GET macro tests (11 tests)
- `Macros/POSTMacroTests.swift` - @POST macro tests (12 tests)
- `Macros/PUTMacroTests.swift` - @PUT macro tests (10 tests)
- `Macros/PATCHMacroTests.swift` - @PATCH macro tests (12 tests)
- `Macros/DELETEMacroTests.swift` - @DELETE macro tests (11 tests)
- `Macros/ConfigurationMacroTests.swift` - Configuration macro tests (15 tests)
- `Macros/MacroIntegrationTests.swift` - End-to-end macro workflows (7 tests)
- `Macros/MacroTestHelpers.swift` - Test utilities
- `Macros/MacroTestFixtures.swift` - Test fixtures
- `MacroExpansionTests.swift` - Macro expansion validation
- `MacroGenerationTests.swift` - Code generation tests (28,514 chars)

Core Framework Tests:
- `NetworkClientTests.swift` - NetworkClient tests
- `IntegrationTests.swift` - End-to-end integration tests
- `ErrorHandlingTests.swift` - Error handling validation
- `CachingTests.swift` - Caching middleware tests
- `AuthenticationConfigurationTest.swift` - Auth configuration tests
- `HeaderSecurityMiddlewareTests.swift` - Security header tests
- `ProgressTrackingTests.swift` - Progress tracking tests
- `ObservabilityTests.swift` - Metrics and monitoring tests (32,719 chars)
- `ResponseProcessingTests.swift` - Response processing tests
- `ResponseProcessingChainTests.swift` - Response chain tests
- `SpecializedResponseTests.swift` - Specialized response types

Interceptor Tests:
- `Interceptors/InterceptorChainTests.swift` - Chain execution tests
- `Interceptors/RequestInterceptorTests.swift` - Request interceptor tests
- `Interceptors/ResponseInterceptorTests.swift` - Response interceptor tests

Fluent DSL Tests:
- `BasicFluentTests.swift` - Basic DSL usage
- `SimpleFluentTests.swift` - Simple DSL patterns
- `FluentConfigurationTests.swift` - Configuration DSL tests
- `SimplePropertyTests.swift` - Property-based tests
- `SimpleBDDTests.swift` - BDD-style tests

Mocking:
- `MockingTests.swift` - Mock client tests
- `MockNetworkClient.swift` - Mock implementation
- `MockURLProtocol.swift` - Mock URL protocol

### Sample Code

**`Samples/Arena-Playground/PlaygroundDependencies/Tests/` - Examples (13 files)**

- `MacroShowcase.swift` - Complete macro examples (36,583 chars)
- `AdvancedRequestBuilding.swift` - Advanced request patterns (86,068 chars)
- `HTTPMethodsShowcase.swift` - HTTP method examples (31,187 chars)
- `PerformanceOptimization.swift` - Performance patterns (32,335 chars)
- `TestingPatterns.swift` - Testing strategies (31,173 chars)
- `BasicNetworkingExamples.swift` - Basic usage examples
- `RequestBuildingExamples.swift` - Request building patterns
- `AuthenticationExamples.swift` - Authentication patterns
- `MiddlewareExamples.swift` - Middleware usage
- `ConcurrencyShowcase.swift` - Concurrency patterns
- `IntegrationExamples.swift` - Integration examples
- `SampleIndex.swift` - Example index (27,295 chars)

### OpenSpec Structure

**`openspec/` - Spec-Driven Development**

- `project.md` - Project overview and conventions
- `AGENTS.md` - AI agent instructions for spec workflow
- `specs/` - Capability specifications
  - `networking-macros/spec.md` - Macro system specification
- `changes/` - Active change proposals
  - `add-api-client-macros/` - API client macro implementation
  - `add-request-response-interceptors/` - Interceptor system implementation

### Configuration Files

**Code Quality**
- `.swift-format` - swift-format configuration (Google Swift Style Guide, 100 char line length)
- `.swiftlint.yml` - SwiftLint configuration (logic/style only, formatting delegated to swift-format)
- `.pre-commit-config.yaml` - Pre-commit hooks (format, lint, test, warnings-as-errors)

**Git**
- `.gitignore` - Git ignore patterns
- `.gitmessage` - Commit message template

**Documentation**
- `CLAUDE.md` - Project-specific AI instructions
- `CHANGELOG.md` - Version history (Keep a Changelog format)
- `README.md` - Project overview

---

## 3. Getting Started

### Prerequisites

**Required Software**
- macOS 13.0+ (for development)
- Xcode 16.0+ (includes Swift 6.2.1+)
- Git 2.x+

**Optional Tools**
- swift-format: `brew install swift-format`
- SwiftLint: `brew install swiftlint`
- pre-commit: `brew install pre-commit`

**Verify Installation**

```bash
# Check Swift version (should be 6.0+)
swift --version
# Expected: Apple Swift version 6.2.1

# Check Xcode version (should be 16.0+)
xcodebuild -version
# Expected: Xcode 16.0 or higher

# Check git
git --version
```

### Environment Setup

**1. Clone Repository**

```bash
# Clone the repository
git clone https://github.com/brunogama/Networking.git ModernNetworking
cd ModernNetworking

# Check out the development branch
git checkout dev
```

**2. Resolve Dependencies**

```bash
# Resolve Swift Package Manager dependencies
swift package resolve

# Alternative: Update to latest compatible versions
swift package update
```

**3. Install Development Tools (Optional)**

```bash
# Install pre-commit hooks
brew install pre-commit
pre-commit install

# Install formatting and linting tools
brew install swift-format swiftlint

# Verify installations
swift-format --version
swiftlint version
```

### Build the Project

**Using Swift Package Manager (Recommended)**

```bash
# Clean build artifacts
rm -rf .build/

# Build all targets
swift build

# Build with warnings as errors (production mode)
swift build -Xswiftc -warnings-as-errors

# Build for release
swift build -c release
```

**Using Xcode**

```bash
# Generate Xcode project
swift package generate-xcodeproj

# Open in Xcode
open Networking.xcodeproj

# Or use the package directly
xed .
```

### Running Tests

**Run All Tests**

```bash
# Run all tests with swift test
swift test

# Run with verbose output
swift test -v

# Run specific test target
swift test --filter NetworkingTests

# Run tests with xcbeautify (if installed)
swift test | xcbeautify
```

**Run Specific Test Cases**

```bash
# Run macro tests only
swift test --filter NetworkingTests.APIMacroTests

# Run a specific test method
swift test --filter NetworkingTests.GETMacroTests/testGETWithPathParameters
```

**Using Xcode Test Navigator**

1. Open package in Xcode: `xed .`
2. Press `⌘+U` to run all tests
3. Use Test Navigator (⌘+6) to run specific tests
4. Click diamond icons in code gutters to run individual tests

### Running the Project Locally

**Interactive Playground**

```bash
# Open the playground in Xcode
cd Samples/Arena-Playground
open Content.playground
```

**Using the Framework in a Test App**

```swift
// Create a new Swift file to test the framework
import Networking

// Create a client
let client = NetworkClient {
    BaseURL("https://api.github.com")
    EnableLogging()
    DefaultHeader("User-Agent", "ModernNetworking/1.0")
}

// Make a request
Task {
    let response = try await client.execute {
        GET("/users/brunogama")
        Timeout(15.0)
    }

    print("Response: \(response)")
}
```

### Common Setup Issues

**Issue: Swift version mismatch**
```bash
# Error: "package requires minimum Swift version 6.0"
# Solution: Update Xcode to 16.0+
xcode-select --install
```

**Issue: Macro compilation fails**
```bash
# Error: "macro expansion failed"
# Solution: Clean build and rebuild
rm -rf .build/
swift build
```

**Issue: Pre-commit hooks fail**
```bash
# Error: "swift-format: command not found"
# Solution: Install swift-format
brew install swift-format

# Or skip pre-commit hooks temporarily
SKIP=swift-beautifier,swift-sheriff git commit -m "message"
```

**Issue: SwiftLint warnings**
```bash
# Run SwiftLint with auto-fix
swiftlint --fix --config .swiftlint.yml

# Run swift-format
swift-format -i -r Sources/ Tests/
```

---

## 4. Key Components

### Entry Points

**Framework Entry**
- `Sources/Networking/Networking.swift` (lines 1-55)
  - Framework version info
  - Type aliases
  - Comprehensive usage examples
  - Public API surface documentation

**Primary Client**
- `Sources/Networking/NetworkClient.swift` (lines 1-795)
  - HTTPClient implementation
  - Middleware pipeline orchestration
  - URLSession integration
  - Error handling and recovery

### Core Business Logic

**Request Building System**
- `RequestBuilder.swift` (lines 1-234): Result builder for fluent DSL
  - `@resultBuilder` implementation
  - Component composition
  - Type-safe request construction

**Middleware Pipeline**
- `AuthenticationMiddleware.swift`: Bearer token and basic auth
- `RetryMiddleware.swift`: Exponential backoff with jitter
- `CachingMiddleware.swift`: Multi-level caching with TTL
- `LoggingMiddleware.swift`: Privacy-aware logging
- `CircuitBreakerMiddleware.swift`: Fault tolerance
- `NetworkObservabilityMiddleware.swift`: Metrics collection

**Macro System**
- `Sources/NetworkingMacros/API/APIMacro.swift`: Generates implementation struct
- `Sources/NetworkingMacros/HTTP/*.swift`: HTTP method macro implementations
- `Sources/NetworkingMacros/Shared/MacroHelpers.swift`: Validation utilities

### Database Models and Schemas

**Not Applicable** - This is a networking framework with no database layer. All types are value types (structs/enums) representing HTTP primitives.

### API Endpoints and Routes

**Not Applicable** - This is a client-side networking framework. The macro system generates API clients that consume external REST APIs.

**Example Generated Client:**
```swift
@API(baseURL: "https://api.github.com")
protocol GitHubAPI {
    @GET("/users/{username}")
    func getUser(username: String) async throws -> GitHubUser
}

// Compiler generates:
struct GitHubAPIImplementation: GitHubAPI, Sendable {
    let baseURL: String
    // ... implementation
}
```

### Configuration Management

**Client Configuration**
- `ConfigurationComponents.swift` (30,006 chars): DSL components
  - `BaseURL`: Base URL configuration
  - `EnableLogging()`: Logging middleware
  - `EnableRetry()`: Retry middleware
  - `EnableCaching()`: Caching middleware
  - `DefaultHeader()`: Default headers
  - `BearerAuth()`: Bearer token authentication
  - `CircuitBreaker()`: Circuit breaker configuration

**Security Configuration**
- `SecurityConfiguration.swift`: SSL pinning, certificate validation
  - Public key pinning
  - Certificate chain validation
  - Backup pin support
  - SHA-256 checksums (MD5/SHA1 deprecated)

**Build Configuration**
- `Package.swift`: SPM manifest with platform targets, dependencies
- `.swift-format`: Code formatting rules (Google style, 100 char lines)
- `.swiftlint.yml`: Linting rules (logic only, formatting delegated)

### Authentication and Authorization

**Authentication Middleware**
- Bearer token authentication with automatic header injection
- Basic authentication support
- Token refresh mechanism
- Keychain integration for secure storage

**Security Features**
- Header injection prevention (CRLF detection)
- Certificate pinning with backup pins
- Secure token storage via Keychain Services
- Security headers enforcement (CSP, HSTS, X-Frame-Options)

### External Service Integration

**URLSession Integration**
- `NetworkClient.swift` (lines 65-217): URLSession wrapper
  - Async/await support
  - Structured concurrency
  - Background task support
  - Progress tracking

**No External APIs** - Framework is a client library for consuming external APIs.

---

## 5. Development Workflow

### Git Branch Strategy

**Primary Branches**
- `main`: Production-ready releases only
- `dev`: Development integration branch (PR target)

**Feature Branches**
- Pattern: `feature/<feature-name>` or `epic/<epic-name>`
- Example: `feature/add-websocket-support`
- Current: `epic/mvp` (macro implementation)

**Branch Protection**
- Direct commits to `main` and `dev` are blocked by pre-commit hook
- All changes must go through pull requests

### Commit Message Format

**Convention**: Conventional Commits

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code refactoring
- `test`: Test changes
- `chore`: Build/tooling changes
- `perf`: Performance improvements

**Examples**
```
feat(macros): add @Interceptors macro support

Implement @Interceptors macro that allows decorating API protocols
with request/response interceptors. Interceptors execute in order
before/after HTTP requests.

Closes #123
```

```
fix(auth): correct bearer token header injection

HTTPError API usage corrected to use message parameter instead of
deprecated initializer.

Fixes NetworkClient.swift:245
```

**Validation**
- Enforced by commitlint.config.js
- Pre-commit hook validates format
- CHANGELOG.md must be updated for non-trivial changes

### Starting a New Feature

**1. Create Feature Branch**

```bash
# Update dev branch
git checkout dev
git pull origin dev

# Create feature branch
git checkout -b feature/my-feature

# Verify branch
git branch
```

**2. OpenSpec Workflow (for significant changes)**

```bash
# Check existing specs and changes
openspec list
openspec list --specs

# Create new change proposal
# Scaffold: proposal.md, tasks.md, design.md, spec deltas
mkdir -p openspec/changes/add-my-feature

# Validate proposal
openspec validate add-my-feature --strict

# Get approval before implementation
```

**3. Implement Changes**

```bash
# Make changes following project conventions
# - Single responsibility per file
# - [Type]+[Function].swift naming
# - /// DocC comments for public APIs
# - Inline SwiftLint disable for FP patterns

# Format code
swift-format -i -r Sources/ Tests/

# Lint code
swiftlint --fix --config .swiftlint.yml
```

**4. Test Changes**

```bash
# Run tests
swift test

# Run with warnings as errors
swift build -Xswiftc -warnings-as-errors

# All tests must pass before commit
```

### Testing Requirements

**Test Coverage Expectations**
- Unit tests: 80%+ coverage
- Integration tests: 15%
- E2E tests: 5%

**Test Naming**
- Pattern: `test<MethodName><Scenario>`
- Example: `testGETWithPathParameters`

**Test Organization**
- One test file per source file
- Group related tests with `// MARK: - Description`
- Use descriptive test names

**Running Tests Before Commit**

```bash
# Pre-commit hook runs tests automatically
git add .
git commit -m "feat: add new feature"

# Hook runs:
# 1. swift-format (commit-msg stage)
# 2. swiftlint --fix (pre-commit stage)
# 3. swift test (pre-merge-commit, pre-push stages)
# 4. swift build -Xswiftc -warnings-as-errors (pre-push stage)
```

### Code Style and Formatting

**Formatting Tool**: swift-format (Google Swift Style Guide)
- Line length: 100 characters
- Indentation: 2 spaces
- Maximum blank lines: 2

**Linting Tool**: SwiftLint (logic/style validation only)
- Formatting rules disabled (handled by swift-format)
- Focus on code quality, performance, readability

**Run Formatting**

```bash
# Format all Swift files
swift-format -i -r Sources/ Tests/

# Check formatting without modifying
swift-format -r Sources/ Tests/
```

**Run Linting**

```bash
# Lint with auto-fix
swiftlint --fix --config .swiftlint.yml

# Lint without auto-fix
swiftlint --config .swiftlint.yml
```

**Disable Linting for FP Patterns**

```swift
// swiftlint:disable identifier_name
let f: (Int) -> Int = { $0 * 2 }
// swiftlint:enable identifier_name
```

### Pull Request Process

**1. Prepare PR**

```bash
# Ensure branch is up to date
git checkout dev
git pull origin dev
git checkout feature/my-feature
git rebase dev

# Push to remote
git push origin feature/my-feature
```

**2. Create PR**

```bash
# Using gh CLI
gh pr create --title "feat: add new feature" --body "$(cat <<'EOF'
## Summary
- Added new feature X
- Updated tests for feature X

## Test Plan
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Related Issues
Closes #123
EOF
)"

# Or create via GitHub UI
```

**3. PR Requirements**
- All CI checks pass
- Code review from at least one maintainer
- CHANGELOG.md updated
- Documentation updated (if applicable)
- All tests pass
- No warnings (warnings treated as errors)

**4. Merge Strategy**
- Squash and merge (default)
- Rebase and merge (for clean history)
- No merge commits

### CI/CD Pipeline

**GitHub Actions Workflows**

`.github/workflows/advanced-testing.yml`:
- Runs on: push to `dev`, `main`, PRs
- Jobs:
  1. Build (swift build)
  2. Test (swift test)
  3. Lint (swiftlint)
  4. Format check (swift-format)
  5. Warning check (swift build -Xswiftc -warnings-as-errors)
  6. DocC generation

**Pre-commit Hooks**

Stages:
- `commit-msg`: swift-format, trailing whitespace, EOF fixer
- `pre-commit`: swiftlint --fix
- `pre-merge-commit`: tests, warning check, changelog enforcer
- `pre-push`: tests, warning check, branch protection

**Bypass Hooks (Use Sparingly)**

```bash
# Skip specific hook
SKIP=swift-sheriff git commit -m "message"

# Skip all hooks (not recommended)
git commit --no-verify -m "message"
```

### Release Strategy

**Versioning**: Semantic Versioning (semver.org)
- Format: `MAJOR.MINOR.PATCH`
- Example: `1.0.0`

**Release Process**
1. Update version in `Networking.swift`
2. Update CHANGELOG.md with release date
3. Create git tag: `git tag -a 1.0.0 -m "Release 1.0.0"`
4. Push tag: `git push origin 1.0.0`
5. Create GitHub release from tag

**Current Version**: 1.0.0 (pre-release, macro system in development)

---

## 6. Architecture Decisions

### Design Patterns

**1. Middleware Pipeline Pattern**
- **Why**: Separation of concerns for cross-cutting functionality
- **How**: Request → Middleware Chain → Network → Middleware Chain → Response
- **Benefits**: Composable, testable, reusable middleware components

**2. Result Builder Pattern**
- **Why**: Declarative, type-safe request construction
- **How**: `@resultBuilder` with component accumulation
- **Benefits**: Fluent DSL, compile-time validation, readable code

**3. Protocol-Oriented Design**
- **Why**: Testability, abstraction, dependency injection
- **How**: `HTTPClient` protocol with `NetworkClient` implementation
- **Benefits**: Easy mocking, protocol extensions, composition

**4. Macro-Based Code Generation**
- **Why**: Eliminate networking boilerplate, compile-time type safety
- **How**: SwiftSyntax AST manipulation at compile time
- **Benefits**: Zero runtime overhead, type-safe APIs, reduced boilerplate

**5. Circuit Breaker Pattern**
- **Why**: Fault tolerance and system resilience
- **How**: Track failures, open circuit after threshold, auto-recovery
- **Benefits**: Prevent cascading failures, graceful degradation

**6. Interceptor Chain Pattern**
- **Why**: Reusable request/response processing
- **How**: Ordered chain of interceptors with context passing
- **Benefits**: Composable, testable, separation of concerns

### State Management

**Immutable Value Types**
- All request/response types are structs (value semantics)
- No shared mutable state
- Thread-safe by design

**Middleware State**
- Each middleware instance owns its state (e.g., cache storage)
- State isolated by actor or serial queue (Swift 6 concurrency)

**Client State**
- NetworkClient is immutable after initialization
- URLSession shared across requests (thread-safe)

### Error Handling Strategy

**Error Hierarchy**

```swift
HTTPError
├── networkError(_:)           // Network failures (no connection, timeout)
├── invalidURL(_:)             // Malformed URL
├── invalidResponse            // Non-HTTP response
├── statusCode(_:response:)    // HTTP error status (4xx, 5xx)
├── decodingError(_:)          // JSON decoding failure
├── encodingError(_:)          // JSON encoding failure
├── authenticationError(_:)    // Auth failure
├── cancelled                  // Request cancelled
└── unknown(_:)                // Unexpected error
```

**Error Recovery**

1. **Retry Middleware**: Exponential backoff for transient errors
2. **Circuit Breaker**: Stop requests to failing services
3. **Error Middleware**: Custom recovery strategies
4. **Actionable Error Info**: Provide recovery suggestions to users

**Example**

```swift
do {
    let response = try await client.execute(request)
} catch let error as HTTPError {
    switch error {
    case .statusCode(let code, _) where code == 401:
        // Refresh token and retry
    case .networkError:
        // Show offline UI
    default:
        // Generic error handling
    }
}
```

### Logging and Monitoring

**Logging System**
- `LoggingMiddleware.swift`: Request/response logging
- Privacy levels: `.public`, `.private`, `.auto`
- OSLog integration for performance
- Configurable verbosity

**Metrics Collection**
- `MetricsCollector.swift`: Performance tracking (29,236 chars)
- Request duration, bytes transferred, success/failure rates
- Integration with `NetworkObservabilityMiddleware.swift` (28,142 chars)

**Observability**
- Request timing middleware
- Progress tracking for file operations
- Circuit breaker state monitoring

### Security Measures

**OWASP Top 10 Compliance**

1. **Header Injection Prevention**: CRLF detection in `HeaderSecurityMiddleware.swift`
2. **Certificate Pinning**: Public key pinning in `SecurityConfiguration.swift`
3. **Secure Storage**: Keychain Services in `KeychainService.swift`
4. **Input Validation**: Parameter validation in macro helpers
5. **Security Headers**: CSP, HSTS, X-Frame-Options enforcement
6. **Crypto Standards**: SHA-256 checksums (MD5/SHA1 deprecated)

**Implementation**

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    Security {
        CertificatePinning(
            pins: ["sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="],
            backupPins: ["sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="]
        )
        HeaderSecurity {
            ContentSecurityPolicy("default-src 'self'")
            StrictTransportSecurity(maxAge: 31536000)
            XFrameOptions(.deny)
        }
    }
}
```

### Performance Optimizations

**1. Caching**
- Multi-level: Memory, Disk, URLCache
- TTL-based expiration
- Cache key derivation from request
- Storage policies: `.memory`, `.disk`, `.hybrid`

**2. Connection Pooling**
- URLSession connection reuse
- HTTP/2 multiplexing support
- Persistent connections

**3. Request Batching**
- Not currently implemented
- Future enhancement for GraphQL/batch APIs

**4. Macro Expansion Performance**
- Target: <5 seconds for 20 endpoints
- String interpolation for AST generation (faster than node builders)
- Minimal validation overhead

**5. Structured Concurrency**
- Async/await for non-blocking I/O
- Task cancellation support
- Actor isolation for thread safety

---

## 7. Common Tasks

### Adding a New API Endpoint (Using Macros)

**Scenario**: Add a new endpoint to an existing API protocol

```swift
@API(baseURL: "https://api.github.com")
protocol GitHubAPI {
    // Existing endpoints...

    // Add new endpoint
    @GET("/repos/{owner}/{repo}/issues")
    func listIssues(
        owner: String,
        repo: String,
        queryParameters: ["state", "labels"]
    ) async throws -> [Issue]
}
```

**Steps**:
1. Add method to protocol with appropriate macro (@GET, @POST, etc.)
2. Define path parameters in path template (`{owner}`)
3. Specify query parameters in `queryParameters` array
4. Define return type (must conform to `Decodable`)
5. Rebuild: `swift build`
6. Compiler generates implementation automatically

### Adding a New Middleware

**Scenario**: Create custom middleware for API versioning

**1. Define Middleware Protocol Conformance**

```swift
// Sources/Networking/APIVersionMiddleware.swift
import Foundation

/// Adds API version header to all requests
public struct APIVersionMiddleware: HTTPRequestMiddleware {
    private let version: String

    public init(version: String = "v1") {
        self.version = version
    }

    public func process(
        _ request: HTTPRequest,
        next: @escaping (HTTPRequest) async throws -> HTTPResponse
    ) async throws -> HTTPResponse {
        var modifiedRequest = request
        modifiedRequest.headers["X-API-Version"] = version
        return try await next(modifiedRequest)
    }
}
```

**2. Add to Client**

```swift
let client = NetworkClient(
    requestMiddlewares: [
        APIVersionMiddleware(version: "v2"),
        AuthenticationMiddleware()
    ]
)
```

**3. Add Tests**

```swift
// Tests/NetworkingTests/APIVersionMiddlewareTests.swift
import XCTest
@testable import Networking

final class APIVersionMiddlewareTests: XCTestCase {
    func testAPIVersionHeaderAdded() async throws {
        let middleware = APIVersionMiddleware(version: "v3")
        let request = HTTPRequest(method: .get, url: URL(string: "https://api.example.com")!)

        let response = try await middleware.process(request) { req in
            XCTAssertEqual(req.headers["X-API-Version"], "v3")
            return HTTPResponse(statusCode: 200, data: Data())
        }

        XCTAssertEqual(response.statusCode, 200)
    }
}
```

### Creating a New Model

**Scenario**: Add a new response model

**1. Define Model**

```swift
// Sources/Networking/Models/GitHubUser.swift
import Foundation

/// GitHub user model
public struct GitHubUser: Codable, Sendable {
    public let id: Int
    public let login: String
    public let name: String?
    public let avatarUrl: String
    public let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case id
        case login
        case name
        case avatarUrl = "avatar_url"
        case htmlUrl = "html_url"
    }
}
```

**2. Use in API**

```swift
@API(baseURL: "https://api.github.com")
protocol GitHubAPI {
    @GET("/users/{username}")
    func getUser(username: String) async throws -> GitHubUser
}
```

### Writing Unit/Integration Tests

**Unit Test Example**

```swift
// Tests/NetworkingTests/MyFeatureTests.swift
import XCTest
@testable import Networking

final class MyFeatureTests: XCTestCase {
    func testFeatureBehavior() async throws {
        // Arrange
        let client = MockNetworkClient()
        client.mockResponse = HTTPResponse(statusCode: 200, data: testData)

        // Act
        let response = try await client.execute(testRequest)

        // Assert
        XCTAssertEqual(response.statusCode, 200)
    }
}
```

**Integration Test Example**

```swift
// Tests/NetworkingTests/IntegrationTests.swift
func testRealAPICall() async throws {
    let client = NetworkClient {
        BaseURL("https://api.github.com")
        DefaultHeader("User-Agent", "ModernNetworking-Tests/1.0")
    }

    let response = try await client.execute {
        GET("/users/brunogama")
        Timeout(10.0)
    }

    XCTAssertEqual(response.statusCode, 200)

    let user = try response.decode(GitHubUser.self)
    XCTAssertEqual(user.login, "brunogama")
}
```

**Macro Test Example**

```swift
// Tests/NetworkingTests/Macros/GETMacroTests.swift
import MacroTesting
import XCTest

final class GETMacroTests: XCTestCase {
    func testGETExpansion() {
        assertMacro {
            """
            @GET("/users/{id}")
            func getUser(id: String) async throws -> User
            """
        } expansion: {
            """
            func getUser(id: String) async throws -> User {
                var request = HTTPRequest(method: .get, path: "/users/\\(id)", baseURL: baseURL)
                let response = try await client.execute(request)
                return try JSONDecoder().decode(User.self, from: response.data)
            }
            """
        }
    }
}
```

### Debugging Common Runtime Errors

**Error: "Macro expansion failed"**

```bash
# Clean and rebuild
rm -rf .build/
swift build

# Check macro implementation for syntax errors
# Review Sources/NetworkingMacros/
```

**Error: "HTTPError.statusCode(401)"**

```swift
// Check authentication configuration
let client = NetworkClient {
    BaseURL("https://api.example.com")
    BearerAuth(tokenProvider) // Ensure token is valid
}

// Enable logging to inspect request
let client = NetworkClient {
    BaseURL("https://api.example.com")
    EnableLogging() // Logs request/response
    BearerAuth(tokenProvider)
}
```

**Error: "URLError.timedOut"**

```swift
// Increase timeout
let response = try await client.execute {
    GET("/slow-endpoint")
    Timeout(60.0) // Increase from default 30s
}

// Or configure client-wide timeout
let client = NetworkClient {
    BaseURL("https://api.example.com")
    DefaultTimeout(60.0)
}
```

**Error: "DecodingError.keyNotFound"**

```swift
// Check JSON structure matches model
// Enable logging to inspect response
let client = NetworkClient {
    BaseURL("https://api.example.com")
    EnableLogging()
}

// Use custom decoder with strategies
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
decoder.dateDecodingStrategy = .iso8601

let user = try decoder.decode(User.self, from: response.data)
```

### Updating Dependencies

**Update All Dependencies**

```bash
# Update to latest compatible versions
swift package update

# Resolve specific dependency
swift package resolve
```

**Update Specific Dependency**

Edit `Package.swift`:

```swift
.package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0")
// Change to:
.package(url: "https://github.com/swiftlang/swift-syntax.git", from: "601.0.0")
```

Then:

```bash
swift package update swift-syntax
swift build
swift test
```

**Handling Breaking Changes**

1. Read dependency changelog
2. Update code to match new API
3. Run tests: `swift test`
4. Fix deprecation warnings
5. Update CHANGELOG.md
6. Create PR with dependency update

### Running Migrations

**Not Applicable** - No database layer. This section would apply to schema migrations in a different project.

---

## 8. Potential Gotchas

### Hidden Configuration

**Issue**: Environment variables not documented

**Solution**: No environment variables currently required. All configuration is code-based.

**Required Build Settings**:
- Swift 6 strict concurrency: `-warn-concurrency -enable-actor-data-race-checks`
- These are set in `Package.swift` (lines 33-35)

### External Dependencies

**URLSession**:
- Requires network permissions (handled by OS)
- Uses system proxy settings automatically
- Requires HTTPS for production (App Transport Security)

**Keychain Services**:
- Requires keychain entitlement for macOS apps
- Shared keychain access group needed for app extensions

### Known Bugs

**Macro System**:
- Path parameter validation may not catch all edge cases
- Large generated methods (>100 lines) may exceed SwiftLint limits
  - Solution: Excluded in `.swiftlint.yml` (lines 183-197)

**Interceptor System** (In Development):
- Not yet implemented, coming in Phase 6
- Current workaround: Use middleware system

### Performance Bottlenecks

**1. Macro Expansion Time**
- Large API protocols (50+ endpoints) may slow compilation
- Solution: Split into multiple protocols

**2. Response Caching**
- Disk cache I/O can block on large responses
- Solution: Use `.memory` policy for small responses, `.disk` for large

**3. File Uploads**
- Large file uploads without streaming consume memory
- Solution: Use `FileTransferOperations.swift` upload methods with progress tracking

### Technical Debt

**1. Legacy Error Handling**
- Some middleware uses older error handling patterns
- Plan: Migrate to Swift 6 typed throws (when available)

**2. Macro Test Coverage**
- Edge cases in path template parsing need more tests
- Current coverage: 80% (target: 90%)

**3. Documentation**
- DocC coverage incomplete for some middleware
- Plan: Phase 7 documentation sprint

**4. Response Processing Chain**
- Complex chain implementation could be simplified
- Plan: Refactor in Phase 8

---

## 9. Documentation and Resources

### Project Documentation

**Core Documentation**
- `README.md`: Project overview, quick start, features
- `CHANGELOG.md`: Version history (Keep a Changelog format)
- `CLAUDE.md`: AI-specific project instructions
- `docs/project-overview.md`: Comprehensive project overview (200 lines)

**OpenSpec Documentation**
- `openspec/AGENTS.md`: AI agent workflow instructions
- `openspec/project.md`: Project conventions
- `openspec/changes/*/proposal.md`: Change proposals
- `openspec/changes/*/design.md`: Technical design documents
- `openspec/changes/*/tasks.md`: Implementation task lists

### API Documentation

**DocC Documentation**

Located in `Documentation.docc/`:
- `Networking.md`: Framework overview
- `Articles/GETTING_STARTED.md`: Getting started guide
- `Articles/API_REFERENCE.md`: Complete API reference
- `Articles/ARCHITECTURE_GUIDE.md`: Architecture deep dive
- `Articles/MIGRATION_GUIDE.md`: Migration guide
- `Articles/TESTING_GUIDE.md`: Testing strategies
- `Articles/ADVANCED_USAGE.md`: Advanced patterns

**Generate Documentation**

```bash
# Generate DocC archive
swift package generate-documentation

# Generate and serve locally
swift package --disable-sandbox preview-documentation --target Networking

# Open in browser at http://localhost:8080/documentation/networking
```

**Published Documentation**
- Hosted at: `docs-build/` (static HTML)
- View locally: `open docs-build/index.html`

### Internal Wiki

**Not Applicable** - Documentation is in-repo only.

### Database Schemas

**Not Applicable** - No database layer.

### Deployment Guides

**Framework Deployment**

**Swift Package Manager** (Recommended)

Add to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/brunogama/Networking.git", from: "1.0.0")
]
```

**Manual Integration**

1. Download source
2. Drag `Sources/Networking` into Xcode project
3. Add to target dependencies

**CocoaPods** (Not Currently Supported)

Future support planned for Phase 9.

### Style Guides

**Swift Style**
- **Google Swift Style Guide**: Official guide
- Implementation: `.swift-format` configuration
- Line length: 100 characters
- Indentation: 2 spaces
- Documentation: Triple-slash (///) for DocC

**Code Organization**
- File naming: `[Type]+[Function].swift`
- Example: `NetworkClient+Configuration.swift`
- Single responsibility per file
- Group related types in same directory

**Naming Conventions**
- Types: PascalCase (`NetworkClient`)
- Functions: camelCase (`executeRequest`)
- Constants: camelCase (`defaultTimeout`)
- Protocols: Noun or adjective (`HTTPClient`, `Sendable`)

### Coding Standards

**Swift 6 Compliance**
- Strict concurrency enabled
- All public types conform to `Sendable`
- No `@unchecked Sendable` (illegal in production code)
- Actor isolation enforced

**Error Handling**
- No force unwraps (`!`) in production code
- No force try (`try!`) in production code
- No fatalError, preconditionFailure, or assertions in production
  - Exception: Illegal state detection in initializers (prefer types that make illegal states unrepresentable)

**Documentation**
- All public APIs must have DocC documentation
- Enforced by swift-format rule: `AllPublicDeclarationsHaveDocumentation: true`
- Include usage examples for complex APIs

**Testing**
- All new code requires unit tests
- Integration tests for API surface changes
- Property-based tests for complex logic (SwiftCheck)
- BDD tests for behavior specification (Quick/Nimble)

---

## 10. Next Steps - Onboarding Checklist

### Day 1: Environment Setup

- [ ] Install Xcode 16.0+ and verify Swift 6.2.1+
- [ ] Clone repository and checkout `dev` branch
- [ ] Run `swift package resolve` to fetch dependencies
- [ ] Install development tools: `brew install swift-format swiftlint pre-commit`
- [ ] Install pre-commit hooks: `pre-commit install`
- [ ] Build project: `swift build`
- [ ] Run tests: `swift test`
- [ ] Verify all tests pass

### Day 2: Code Familiarization

- [ ] Read `README.md` and `docs/project-overview.md`
- [ ] Review `CHANGELOG.md` to understand recent changes
- [ ] Explore `Sources/Networking/NetworkClient.swift` (main implementation)
- [ ] Review `Sources/Networking/RequestBuilder.swift` (fluent DSL)
- [ ] Examine `Sources/NetworkingMacros/API/APIMacro.swift` (macro implementation)
- [ ] Study one middleware: `AuthenticationMiddleware.swift`
- [ ] Review test structure: `Tests/NetworkingTests/`

### Day 3: Run and Explore

- [ ] Open `Samples/Arena-Playground/Content.playground` in Xcode
- [ ] Run playground examples to see framework in action
- [ ] Review `Samples/Arena-Playground/PlaygroundDependencies/Tests/MacroShowcase.swift`
- [ ] Experiment with creating a simple API client using macros
- [ ] Try adding a custom middleware
- [ ] Run tests with verbose output: `swift test -v`

### Day 4: Make a Test Change

- [ ] Pick a simple enhancement (e.g., add a new convenience method)
- [ ] Create feature branch: `git checkout -b feature/test-change`
- [ ] Make the change following coding standards
- [ ] Add unit tests for the change
- [ ] Run swift-format: `swift-format -i -r Sources/ Tests/`
- [ ] Run SwiftLint: `swiftlint --fix --config .swiftlint.yml`
- [ ] Run tests: `swift test`
- [ ] Verify warnings-as-errors: `swift build -Xswiftc -warnings-as-errors`

### Day 5: Full Test Suite

- [ ] Run all tests: `swift test`
- [ ] Review test output and understand test structure
- [ ] Run specific test: `swift test --filter APIMacroTests`
- [ ] Use Xcode Test Navigator to run tests interactively
- [ ] Review test coverage (if available)
- [ ] Understand mocking patterns: `Tests/NetworkingTests/MockNetworkClient.swift`

### Week 2: Main User Flow

- [ ] Trace a complete request flow from API protocol to response
- [ ] Follow middleware pipeline execution
- [ ] Understand macro expansion process
- [ ] Review error handling path
- [ ] Study caching middleware implementation
- [ ] Examine retry logic and circuit breaker

### Week 2: First Contribution

- [ ] Review open issues on GitHub
- [ ] Pick a "good first issue" or small enhancement
- [ ] Review OpenSpec workflow: `openspec/AGENTS.md`
- [ ] Create change proposal (if needed): `openspec/changes/<id>/proposal.md`
- [ ] Implement the change following all coding standards
- [ ] Write comprehensive tests (unit + integration)
- [ ] Update CHANGELOG.md
- [ ] Create pull request
- [ ] Address review feedback

### Ongoing: Continuous Learning

- [ ] Review Swift 6 concurrency documentation
- [ ] Study SwiftSyntax documentation for macro development
- [ ] Read OWASP Top 10 for security awareness
- [ ] Explore advanced Swift patterns (result builders, property wrappers)
- [ ] Participate in code reviews
- [ ] Contribute to documentation improvements
- [ ] Share knowledge with team

---

## Additional Resources

### External Documentation

**Swift Language**
- [Swift Language Guide](https://docs.swift.org/swift-book/)
- [Swift Evolution](https://github.com/swiftlang/swift-evolution)
- [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)

**SwiftSyntax and Macros**
- [Swift Macros Documentation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/macros/)
- [SwiftSyntax Repository](https://github.com/swiftlang/swift-syntax)
- [Swift AST Explorer](https://swift-ast-explorer.com)

**Testing**
- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Swift Macro Testing](https://github.com/pointfreeco/swift-macro-testing)
- [Quick/Nimble](https://github.com/Quick/Quick)

**Tools**
- [swift-format](https://github.com/swiftlang/swift-format)
- [SwiftLint](https://github.com/realm/SwiftLint)
- [pre-commit](https://pre-commit.com)

### Community

**Support Channels**
- GitHub Issues: Bug reports and feature requests
- GitHub Discussions: Questions and community support
- Pull Requests: Code contributions

**Contact**
- Maintainer: Bruno Gama (@brunogama)
- Repository: https://github.com/brunogama/Networking

---

## Conclusion

You now have a comprehensive understanding of the ModernNetworking framework. Start with the onboarding checklist, explore the codebase, and don't hesitate to ask questions or contribute improvements.

Happy coding!
