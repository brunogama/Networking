# Coding Conventions

**Analysis Date:** 2026-02-14

## Naming Patterns

**Files:**
- Patterns: Descriptive English names, PascalCase for types + components
- Examples: `NetworkClient.swift`, `CachingMiddleware.swift`, `RetryInterceptor.swift`
- Location convention: One primary public type per file (exception: small internal helpers)
- Macros in subdirectory: `Sources/NetworkingMacros/`
- Tests follow component name: `ComponentTests.swift` or `Component/ComponentTests.swift`

**Functions:**
- Patterns: camelCase with verb prefix, descriptive of behavior not implementation
- Public: `execute()`, `process()`, `withTimeout()`, `expectGET()`, `andReturn()`
- Private: `applyRequestMiddlewares()`, `performRequest()`, `mapURLError()`
- Test methods: `test_<component>_<behavior>_<condition>()` or `@Test("<description>")`
- Builder methods: `withTimeout()`, `withHeader()`, `andReturn()` (fluent API convention)

**Variables:**
- Patterns: camelCase, descriptive English names
- Constants: UPPER_SNAKE_CASE or camelCase (context-dependent)
- Type inference used heavily: `let request = HTTPRequest(...)`
- Abbreviations in standard acronyms: `HTTPRequest`, `URLSession`, `URLResponse`, `ID`, `URL`
- Single-letter variables avoided (exception: generic type parameters `T`, loop indices `i`, `j`)

**Types:**
- PascalCase: `HTTPRequest`, `HTTPResponse`, `NetworkClient`, `InterceptorChain`
- Protocols end with semantic meaning: `HTTPClient`, `HTTPInterceptor`, `HTTPRequestMiddleware`
- Error enums: `HTTPError` with associated values
- Nested types organized in declaration order
- @unchecked Sendable used carefully for special cases (MockNetworkClient.RequestExpectation)

## Code Style

**Formatting:**
- Tool: `swift-format` (version 600.0.0+)
- Line length: Hard limit 100 characters (ignores URLs, function declarations, comments)
- Indentation: 2 spaces (configured in `.swift-format`)
- Maximum blank lines: 2 consecutive blank lines allowed
- Line break before each argument in multi-line calls (lineBreakBeforeEachArgument: true)
- Respect existing line breaks enabled (respectsExistingLineBreaks: true)

**Linting:**
- Tool: SwiftLint with `.swiftlint.yml` configuration
- Integration: SwiftLint handles logic/style validation, swift-format handles formatting
- File length: Warning at 200 lines, error at 400 lines (macros excluded)
- Type body length: Warning at 200 lines, error at 300 lines
- Function body length: Warning at 40 lines, error at 80 lines (macros excluded)
- Cyclomatic complexity: Warning at 4, error at 5 (macros excluded)
- Nesting: Type nesting ≤2 levels, function nesting ≤3 levels
- Function parameters: Warning at 4, error at 6

**Applied Rules (Swift-Format):**
- AllPublicDeclarationsHaveDocumentation: true (enforced)
- AlwaysUseLowerCamelCase: true (enforced)
- BeginDocumentationCommentWithOneLineSummary: true
- DoNotUseSemicolons: true
- NeverForceUnwrap: false (allowed with inline justification in tests)
- NeverUseForceTry: false (allowed with inline justification in tests)
- UseTripleSlashForDocumentationComments: true (/// preferred)

## Import Organization

**Order:**
1. Standard library imports (`Foundation`, `UIKit`, etc.)
2. Conditional platform imports (`#if canImport(FoundationNetworking)`)
3. Third-party frameworks (SwiftCheck, Quick, Nimble, swift-syntax, etc.)
4. Internal module imports (`@testable import Networking`)

**Example Pattern (Production):**
```swift
import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
```

**Example Pattern (Tests):**
```swift
import Testing
import Foundation
import SwiftCheck
import XCTest

@testable import Networking
```

**Path Aliases:**
- No custom path aliases configured
- Absolute imports used (e.g., `import Networking` not `import ../Sources/Networking`)
- Relative imports not used in swift-format configuration (`OrderedImports: false`)

## Error Handling

**Patterns:**
- Primary error type: `HTTPError` enum with associated values
- Error categories: `.configuration`, `.network`, `.server`, `.client`, `.unknown`
- Throwing functions marked `async throws` (never callback-based)
- Guard statements for early exits in error paths
- Switch statements with case binding for specific error types
- Custom error mapping: `mapURLError(_:for:)` for URLError → HTTPError conversion

**Example Pattern:**
```swift
do {
  let (data, response) = try await session.data(from: request.url)
  guard let httpResponse = response as? HTTPURLResponse else {
    throw HTTPError(category: .network("Invalid response type"))
  }
  return HTTPResponse(status: HTTPStatus(httpResponse.statusCode), body: data)
} catch let error as HTTPError {
  throw error
} catch {
  throw mapURLError(error, for: request)
}
```

**Error Type Matching:**
- Specific error types caught first
- Default catch clause for unexpected errors
- Actor isolation preserved with error propagation
- Result<T, Error> used in some interceptor contexts

## Logging

**Framework:** Not formally configured in conventions (no global logger enforced)

**Patterns Observed:**
- Print statements removed from production code (SwiftLint rule: `no_print`)
- Allowed in tests and benchmarks (excluded in swiftlint.yml)
- Error logging expected in middleware but implementation detail left to consumer
- MetricsCollector captures observability (custom implementation)
- NetworkObservabilityMiddleware provides request/response observability

**When to Log:**
- Errors and exceptions (via thrown HTTPError)
- Security incidents (certificate pinning failures)
- Performance metrics (through MetricsCollector)
- Request/response traces (through NetworkObservabilityMiddleware)

## Comments

**When to Comment:**
- MARK: sections for organizing large types (// MARK: - Section Name)
- TODO comments allowed (SwiftLint rule: `todo` enabled)
- FIXME comments not explicitly forbidden
- Justification comments for SwiftLint disables (inline with code)

**Example Pattern:**
```swift
// MARK: - Properties

private let session: URLSession

// MARK: - Initialization

public init(session: URLSession = .shared) {
  self.session = session
}

// MARK: - HTTPClient Implementation

public func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
  // Implementation
}
```

**JSDoc/TSDoc:**
- Framework: Triple-slash documentation (///) - enforced by swift-format
- Placement: Immediately before declaration (no blank lines)
- Required for all public declarations (enforced by swift-format rule)
- One-line summary before detailed description
- Example code blocks with triple-backtick markdown

**Example Pattern:**
```swift
/// Modern HTTP client implementation using URLSession and structured concurrency.
///
/// `NetworkClient` is the primary implementation of ``HTTPClient`` that provides
/// comprehensive networking solution built on URLSession. It supports a middleware
/// pipeline for request and response processing.
///
/// ## Usage
///
/// ```swift
/// let client = NetworkClient()
/// let response = try await client.execute(request)
/// ```
///
/// ## Architecture
///
/// The client processes requests through a three-stage middleware pipeline:
/// 1. Request Middleware (authentication, logging)
/// 2. Network Execution (URLSession)
/// 3. Response Middleware (caching, validation)
public final class NetworkClient: HTTPClient {
  // Implementation
}
```

## Function Design

**Size:**
- Target: ≤40 lines (warning threshold in SwiftLint)
- Hard limit: 80 lines (error threshold)
- Approach: Extract private helpers when approaching 40-line warning

**Parameters:**
- Recommendation: ≤4 parameters (warning at 4, error at 6)
- Strategy: Use parameter objects for >4 params (e.g., `RequestConfiguration`)
- Example: Builder pattern (result builders) instead of many initializer parameters

**Return Values:**
- Pattern: `async throws -> T` for network operations (primary pattern)
- Alternative: `Result<T, Error>` in some interceptor contexts
- Void returns used where side effects are primary (middleware chain returns)
- Multiple returns use tuples or custom types (not out parameters)

**Example Pattern (Under Budget):**
```swift
private func applyRequestMiddlewares(_ request: HTTPRequest) async throws -> HTTPRequest {
  var processedRequest = request

  for middleware in requestMiddlewares {
    processedRequest = try await middleware.process(processedRequest)
  }

  return processedRequest
}
```

## Module Design

**Exports:**
- Public API explicitly marked `public`
- Types, functions, and properties have visibility modifier
- Test target uses `@testable import Networking` for internal access
- Main target excludes BDD module (incomplete integration)

**Barrel Files:**
- Not used in this codebase
- Each file exports directly imported types

**File Organization Pattern:**
```swift
// MARK: - Imports
import Foundation

// MARK: - Types & Protocols (top level)
public protocol HTTPClient {
  // Protocol definition
}

// MARK: - Implementation
public final class NetworkClient: HTTPClient {
  // MARK: - Properties
  // MARK: - Initialization
  // MARK: - HTTPClient
  // MARK: - Private Methods
}

// MARK: - Extensions
extension NetworkClient {
  // Additional functionality
}
```

## Concurrency & Sendable

**Patterns:**
- All public network operations are `async throws`
- Closures passed across isolation boundaries marked `@Sendable`
- Value types (struct) preferred for Sendable conformance
- Actor isolation for mutable shared state (e.g., caches)
- URLSession access thread-safe (no special isolation needed)

**Example Pattern:**
```swift
/// Request middleware type - closure must be @Sendable for actor safety
typealias RequestMiddleware = @Sendable (HTTPRequest) async throws -> HTTPRequest

public struct HTTPRequest: Sendable {
  public let method: HTTPMethod
  public let url: URL
  public let headers: [String: String]
}

actor ResponseCache {
  private var cache: [String: HTTPResponse] = [:]

  func getCached(for url: URL) -> HTTPResponse? {
    cache[url.absoluteString]
  }
}
```

## Builder Pattern & DSL

**Pattern:** Result builders for configuration (NetworkClientBuilder)

**Syntax:**
```swift
let client = NetworkClient {
  BaseURL("https://api.example.com")
  DefaultHeader("User-Agent", "MyApp/1.0")
  BearerAuth("token123")
  EnableRetry(maxAttempts: 3)
  EnableLogging()
}
```

**Implementation:** Uses `@resultBuilder` attribute on configuration builder type

## Type Patterns

**Preference Order:**
1. Struct (value semantics) - default choice
2. Enum (sum types, associated values) - for HTTPError, HTTPStatus
3. Class (reference semantics) - only when shared mutable state required
4. Protocol (abstractions) - for client contracts and middleware

**Example Protocol Pattern:**
```swift
public protocol HTTPClient: Sendable {
  func execute(_ request: HTTPRequest) async throws -> HTTPResponse
}

public protocol HTTPInterceptor: Sendable {
  func process(_ request: HTTPRequest, context: InterceptorContext) async throws -> HTTPRequest
}
```

## Access Control

**Levels Used:**
- `public`: Public API (types, functions, properties intended for external use)
- `internal`: Default, module-level (rarely explicit)
- `private`: Encapsulation within types or small scopes
- `fileprivate`: Not used (private preferred for single-file scope)

**Pattern:**
```swift
public final class NetworkClient: HTTPClient {
  private let session: URLSession
  private let requestMiddlewares: [any HTTPRequestMiddleware]

  public func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    // Public API
  }

  private func applyRequestMiddlewares(_ request: HTTPRequest) async throws -> HTTPRequest {
    // Private helper
  }
}
```

## Coding Guardrails

**MUST NOT:**
- Force-unwrap (`!`) in production code (only in tests with justification)
- `fatalError()` in production code (defensive programming only)
- `precondition()` in production code (invariant enforcement in init)
- `assert()` in production code (test-only assertions)
- Force try (`try!`) in production code (explicit error handling required)
- Print statements in production code (SwiftLint enforced rule)
- Mutable global state (actor-protected or immutable preferred)

**SHOULD:**
- Use guards for early exits (prefer to deep nesting)
- Extract functions when >10-15 lines (single responsibility)
- Use value types by default (struct unless reference semantics needed)
- Validate external input (URLs, headers, response bodies)
- Specify timeout for network operations
- Use Keychain for sensitive tokens (never UserDefaults or hardcoded)

## Type Inference & Explicit Types

**Pattern:**
- Type inference used when obvious from context: `let request = HTTPRequest(...)`
- Explicit types for clarity: `let status: HTTPStatus = .ok`
- Collection types often inferred: `let headers = ["Content-Type": "application/json"]`
- Function return types always explicit in signatures (no inference at function boundary)

## Self References

**Pattern:**
- `self` used only when necessary (property disambiguation or closure captures)
- `Self` used in protocol extensions and type methods
- SwiftLint rule: `prefer_self_in_static_references` enforced

---

*Convention analysis: 2026-02-14*
