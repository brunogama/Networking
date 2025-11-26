# Changelog

All notable changes to Networking will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

#### Core Framework
- =� Complete Swift 6 networking framework with async/await URLSession integration
- <� Fluent DSL for request/response building with result builder patterns
- =' Comprehensive middleware architecture (authentication, retry, caching, logging)
- =� File transfer operations with real-time progress tracking
- =� Circuit breaker pattern for system resilience and fault tolerance
- <� Macro-based code generation for automatic API client creation

#### Interceptor System (Phase 6 - Request/Response Interceptors)

##### Phase 6.3: Common Interceptor Implementations
- 🔐 **AuthenticationInterceptor**: Automatic Bearer/Basic auth header injection
  - Dynamic token provider support with async token refresh
  - Static token constructor for testing scenarios
  - Sendable-compliant for Swift 6 concurrency
  - 8 comprehensive unit tests covering all authentication patterns
- 📝 **LoggingInterceptor**: Privacy-aware request/response logging
  - Configurable log levels: none, basic, detailed
  - Implements both RequestInterceptor and ResponseInterceptor
  - Custom log handler support for integration with logging frameworks
  - 6 unit tests covering all log levels and privacy scenarios
- 🔄 **TokenRefreshInterceptor**: Automatic token refresh on 401 responses
  - Detects 401 Unauthorized and triggers token refresh workflow
  - Prevents concurrent refresh attempts with actor-based coordination
  - Configurable refresh and token update handlers
  - Returns `.retry()` after successful refresh for transparent retry
  - 9 unit tests including concurrent refresh prevention
- 💾 **CachingInterceptor**: Response caching with TTL and LRU eviction
  - Per-endpoint caching with configurable TTL (time-to-live)
  - LRU (Least Recently Used) eviction policy for memory management
  - Thread-safe actor-based cache storage
  - Configurable max entries limit
  - 13 unit tests covering TTL expiration, LRU eviction, cache hits/misses
- 🔁 **RetryInterceptor**: Intelligent retry with exponential backoff
  - Detects retryable errors (5xx server errors, network failures)
  - Exponential backoff with configurable jitter
  - Respects max attempts from InterceptorContext
  - Returns `.retry(after: duration)` with calculated delay
  - 8 unit tests covering retry conditions, backoff calculation
- ⏱️ **RateLimitInterceptor**: Request rate limiting with sliding window
  - Tracks request timestamps per endpoint
  - Configurable rate limits (requests per window)
  - Two strategies: delay (wait) or reject (error)
  - Convenience presets: strict (10 req/min), lenient (100 req/min), perSecond (60 req/min)
  - 9 unit tests covering sliding window, strategies, edge cases
- 🧪 **Integration Tests**: End-to-end interceptor chain validation
  - Auth + Retry integration (authenticated requests with server error retry)
  - Cache + Rate Limit interaction (cached responses served when rate limited)
  - Token Refresh + Retry flow (automatic token refresh and retry on 401)
  - Full stack integration (auth, rate limit, cache, retry working together)
  - Logging integration with other interceptors
  - Error propagation through interceptor chains
  - Interceptor ordering validation (auth before rate limit)
  - Cache + Retry interaction (cache persistence across retries)
  - Performance benchmarks (100 requests in <5 seconds)
  - 9 comprehensive integration tests

**Test Coverage**: 62 tests passing (AuthenticationInterceptor: 8, LoggingInterceptor: 6, TokenRefreshInterceptor: 9, CachingInterceptor: 13, RetryInterceptor: 8, RateLimitInterceptor: 9, Integration: 9)

**Documentation**: Updated QUICKSTART.md with "Using Interceptors" section including examples for all common interceptors and full chain composition

##### Phase 6.2: Macro Integration
- ✨ **@Interceptors Macro**: Declarative interceptor chain specification at protocol level
  - Applied to @API protocols to specify request/response interceptor arrays
  - Compile-time validation of interceptor array syntax
  - Extracts interceptor expressions for use by APIMacro and HTTP method macros
  - Diagnostic messages for invalid usage patterns
- 🏗️ **APIMacro Interceptor Support**: Automatic interceptor chain initialization
  - Detects @Interceptors attribute on protocol declarations
  - Generates `private let interceptors: InterceptorChain` property
  - Initializes chain with request and response interceptors from @Interceptors
  - Backward compatible: works with or without @Interceptors
- 🔧 **InterceptorCodeGenerator**: Centralized code generation for interceptor integration
  - `generateContextCreation()`: Creates InterceptorContext with path, method, attempt count
  - `generateRequestInterceptorHook()`: Executes request interceptor chain with short-circuit support
  - `generateResponseInterceptorHook()`: Executes response interceptor chain with retry support
  - `generateMethodImplementation()`: Complete method generation with conditional interceptor support
  - Handles `.proceed`, `.shortCircuit(response)`, and `.retry(after:)` results
- 🚀 **HTTP Method Macro Updates**: All macros support interceptor integration
  - GETMacro: Detects @Interceptors and generates hooks for GET requests
  - POSTMacro: Full interceptor support with request body encoding
  - PUTMacro: Interceptor hooks for PUT operations
  - PATCHMacro: Partial update operations with interceptors
  - DELETEMacro: DELETE requests with interceptor chain execution
  - Conditional code generation: interceptor code only when @Interceptors present
  - Maintains existing functionality (path params, query params, headers, body)
- 🧪 **Macro Expansion Tests**: Comprehensive test coverage for macro-generated interceptor code
  - testAPIWithInterceptorsGeneratesChainProperty: Verifies interceptor chain property generation
  - testAPIWithMultipleInterceptors: Tests multiple interceptor initialization
  - testCompleteAPIWithInterceptorsAndGET: End-to-end @API + @Interceptors + @GET integration
  - testCompleteAPIWithInterceptorsAndPOST: End-to-end @API + @Interceptors + @POST integration
  - testGETWithoutInterceptorsGeneratesPhase52Code: Backward compatibility verification
  - testPOSTWithoutInterceptorsGeneratesPhase52Code: Backward compatibility for POST
  - testInterceptorsRequiresNonEmptyArray: Validation of empty interceptor arrays
  - testInterceptorsRequiresProtocol: Compile-time enforcement of protocol usage
  - 8 interceptor macro tests + all existing 76 macro tests = 84 total macro tests passing

**Test Coverage**: 84 macro tests passing (up from 83), all HTTP method macros support interceptors

**Backward Compatibility**: All existing code without @Interceptors continues to work unchanged

##### Phase 6.1: Core Interceptor Infrastructure
- 🏗️ **InterceptorProtocols**: Foundational protocols for request/response interception
  - `RequestInterceptor` protocol with `intercept(request:context:) async throws -> InterceptorResult`
  - `ResponseInterceptor` protocol with `intercept(response:context:) async throws -> InterceptorResult`
  - Both protocols marked as `Sendable` for Swift 6 strict concurrency compliance
  - Comprehensive DocC documentation with usage examples
- 📋 **InterceptorContext**: Thread-safe context for interceptor execution
  - Properties: `path`, `method`, `attemptCount`, `metadata` dictionary
  - Marked as `Sendable` struct for actor-isolated access
  - Carries request metadata through interceptor chain
  - Enables stateless interceptor design with shared context
- 🎯 **InterceptorResult**: Enum defining interceptor chain control flow
  - `.proceed`: Continue to next interceptor or network execution
  - `.shortCircuit(HTTPResponse)`: Return cached/mocked response, skip network call
  - `.retry(after: TimeInterval?)`: Trigger retry with optional delay
  - Marked as `Sendable` for thread-safe result passing
  - Used `TimeInterval` instead of `Duration` for iOS 16+ compatibility
- ⛓️ **InterceptorChain**: Sequential interceptor execution with retry support
  - Stores arrays of `RequestInterceptor` and `ResponseInterceptor` instances
  - `executeRequestInterceptors(request:context:) async throws -> InterceptorResult`
  - `executeResponseInterceptors(response:context:) async throws -> InterceptorResult`
  - Retry loop logic with max attempts tracking in context
  - Short-circuit support for cache hits and mock responses
  - Marked as `Sendable` struct for concurrent access
- ⚠️ **InterceptorError**: Typed errors for interceptor failures
  - `.maxRetriesExceeded`: Retry limit reached
  - `.interceptorFailed(Error)`: Interceptor threw error
  - `.invalidResult`: Unexpected interceptor result state
  - `.rateLimitExceeded(path:limit:window:)`: Rate limit violation
  - Conforms to `Error`, `Sendable`, and `LocalizedError` for proper error reporting
- 🧪 **Comprehensive Unit Tests**: 43 tests covering all infrastructure components
  - InterceptorChainTests: 16 tests (sequential execution, short-circuit, retry, error propagation, empty chain)
  - RequestInterceptorTests: 12 tests (modification, inspection, context usage, async, Sendable)
  - ResponseInterceptorTests: 15 tests (inspection, replacement, retry triggers, context, Sendable)

**Test Coverage**: 43 tests passing, all Swift 6 Sendable compliant, full DocC documentation

**Design Principles**:
- Interceptor chain executes sequentially (order matters)
- Request interceptors run before network call
- Response interceptors run after network response
- Short-circuit capability for caching/mocking
- Retry support with exponential backoff
- Thread-safe with Swift 6 strict concurrency
- Stateless interceptors with shared context
- Composable and testable architecture

#### Swift Macros - API Client Generation (Phase 5.2 - Custom Headers Support)
- ✨ Added custom headers parameter support to all HTTP method macros
  - `headers: [String: String]` parameter in @GET, @POST, @PUT, @PATCH, @DELETE macros
  - Alphabetically sorted header generation for consistent test outputs
  - Headers added via `request.addHeader(name:value:)` in generated code
- 📝 Comprehensive test coverage for custom headers feature
  - Added testGETWithCustomHeaders to GETMacroTests (11/11 tests passing)
  - Added testDELETEWithCustomHeaders to DELETEMacroTests (11/11 tests passing)
  - POST/PUT/PATCH already had header tests from Phase 4 (all passing)
- 🔧 Fixed dictionary ordering consistency in APIMacro
  - Sorted defaultHeaders generation alphabetically
  - Ensures deterministic test output across all platforms
- ✅ All 83 macro tests passing (GET: 11, POST: 12, PATCH: 12, PUT: 10, DELETE: 11, API: 15, Integration: 6, Configuration: 6)
- 🎯 SwiftLint configuration optimized
  - Comprehensive analysis of swift-format rules
  - Disabled all 20+ formatting-related SwiftLint rules
  - Clear separation: swift-format handles ALL formatting, SwiftLint handles logic/style validation
  - Eliminated circular validation deadlocks between tools

#### Swift Macros - API Client Generation (Phase 5.1 - HTTPRequest Infrastructure)
- 🏗️ HTTPRequestMacroSupport infrastructure for macro-generated code
  - Path-based HTTPRequest initializer for macro convenience (method, path, baseURL)
  - Mutating methods maintaining immutability: addQueryParameter, setBody, addHeader, setHeaders
  - Foundation for Phase 5.2 custom headers support
- 🔧 Fixed fundamental API mismatch in all HTTP method macros
  - Updated all macros (GET, POST, PUT, PATCH, DELETE) to pass baseURL parameter
  - Corrected HTTPRequest initialization to use proper API
  - All macro-generated code now compiles and works correctly
- ✅ Updated 74 macro tests to match new API expectations
- ⚙️ Disabled SwiftLint opening_brace rule to prevent circular conflict with swift-format

#### Swift Macros - API Client Generation (Phase 4 Complete - Configuration & DELETE Support)
- ✨ @API macro for declarative protocol-based API client generation with automatic implementation struct creation
- 🔧 HTTP method macros (@GET, @POST, @PUT, @PATCH, @DELETE) declarations with comprehensive DocC documentation
- ⚙️ Configuration macros (@DefaultHeaders, @Timeout) for protocol-level settings
- 🏗️ APIMacro implementation conforming to SwiftSyntax MemberMacro protocol with configuration extraction
  - Extracts @DefaultHeaders and @Timeout from protocol attributes
  - Generates implementation struct properties: baseURL, defaultHeaders, defaultTimeout
- 🚀 GETMacro implementation with full code generation for GET endpoints
  - Path parameter substitution with compile-time validation
  - Query parameter handling and validation
  - Automatic URL construction from base URL + path template
  - JSON response decoding with type safety
  - HTTPRequest builder integration
- 📤 POSTMacro, PUTMacro, PATCHMacro implementations with request body support
  - Automatic JSONEncoder integration for request bodies
  - Content-Type: application/json header generation
  - Body parameter validation and encoding
  - Mixed path parameters, query parameters, and request bodies
  - Custom header support for all HTTP methods
  - Compile-time validation of body parameter existence
- 🗑️ DELETEMacro implementation for resource deletion operations
  - Supports both Void and typed return values
  - Full path parameter and query parameter support
  - Optional response decoding for DELETE operations that return data
- 🎛️ DefaultHeadersMacro for protocol-level default headers applied to all endpoints
  - Validates dictionary syntax at compile-time
  - Provides extraction helper for APIMacro integration
- ⏱️ TimeoutMacro for protocol-level timeout configuration
  - Validates positive numeric values (Int or Double)
  - Provides extraction helper for APIMacro integration
- 📋 MacroHelpers utilities for validation, parameter extraction, and diagnostic reporting
- 🛠️ PathTemplateParser for REST path template parsing (e.g., "/users/{id}")
- ⚙️ SyntaxFactory utilities for SwiftSyntax code generation
- 🔒 Swift 6 strict concurrency compliance with Sendable conformance
- ✅ Centralized error handling with descriptive diagnostics (MacroExpansionError)
- 🧪 Comprehensive unit test suite (81 tests total) covering success and error cases
  - APIMacroTests: Protocol validation, base URL handling, error scenarios
  - GETMacroTests: Path params, query params, async/throws validation, diagnostics
  - POSTMacroTests: Body params, path/query params, headers, error cases (12 tests)
  - PUTMacroTests: Full update operations with body encoding (10 tests)
  - PATCHMacroTests: Partial updates, all features combined (12 tests)
  - DELETEMacroTests: DELETE operations, return types, query params (9 tests)
  - ConfigurationMacroTests: @DefaultHeaders and @Timeout validation (15 tests)
  - MacroIntegrationTests: End-to-end macro workflows with configuration (7 tests)

#### Security Implementation (OWASP Top 10 Compliance)
- = Header injection prevention with CRLF detection and sanitization
- =� Certificate pinning with custom validation and backup pin support
- = Secure token storage using iOS Keychain Services integration
-  Comprehensive input validation and output encoding for all user data
- =� Security headers enforcement (CSP, HSTS, X-Frame-Options, X-Content-Type-Options)
- L Removed insecure MD5/SHA1 algorithms from checksum operations (replaced with SHA-256)

#### Documentation & Developer Experience
- =� Complete DocC documentation catalog with 10+ comprehensive guides
- =� 100+ public APIs documented with triple-slash comments following Apple DocC standards
- <� API reference organized by functionality with extensive cross-references
- =� 150+ code examples with real-world usage patterns
- =� Architecture guides and best practices documentation
- >� Testing guides and mock implementation examples

#### Configuration & Middleware
- � Declarative client configuration DSL with 35+ configuration components
- = Advanced authentication middleware with automatic token refresh
- = Intelligent retry middleware with exponential backoff strategies
- =� Multi-level caching with TTL, policies, and storage backends
- =� Comprehensive metrics collection with performance tracking and alerting
- =R Request timing and observability middleware

#### Request Building & Processing
- <� Fluent request building with 20+ components (HTTP methods, headers, body, auth)
- = Response processing chain with transformers and validation
- =� Support for JSON, form data, and multipart body encoding
- <� Conditional request building with control flow support
- = Response transformation and validation pipelines

#### Advanced Features
- =� Real-time progress tracking with thread-safe OSAllocatedUnfairLock
- =� File transfer operations with checksum validation (SHA-256)
- =� Performance metrics and alerting system
- <� Validated responses with automatic error recovery strategies
- =
 Network observability with detailed request/response logging

### Fixed

#### Code Quality & Swift 6 Compliance
- 🎨 Improved code formatting consistency across all source files (brace placement, line breaks)
-  All SwiftLint violations resolved (line length, naming conventions)
- =' Refactored complex functions for better maintainability (NetworkClient.swift:167-244)
-  Ensured full Sendable protocol compliance for strict concurrency
- =� Fixed result builder syntax issues (removed invalid @Self attributes)
- >� Thread-safe operations using OSAllocatedUnfairLock throughout
- � Resolved all compiler warnings and build errors

#### Test Coverage & Validation
- >� Fixed hundreds of test compilation errors across all test files
-  Created comprehensive HeaderSecurityMiddlewareTests.swift (417 lines)
- = Implemented security test coverage for OWASP vulnerability patterns
- >� Added proper concurrency handling in progress tracking tests
-  All tests now pass with no warnings or errors

### Changed

#### Breaking Changes
- = Updated HTTPStatus initialization from raw values to static properties
- = Changed ResponseChain.decode() to require ResponseTransformer instead of Type
- = Updated BaseURL initialization to use non-throwing URL constructor
- = Modified HTTPMethod enum cases to lowercase (`.get`, `.post`, etc.)

#### Improvements
- � Enhanced error handling with actionable error information
- <� Improved API ergonomics with better type safety
- =� Better metrics collection with reduced performance overhead
- = Strengthened security validation throughout the framework
- =� Enhanced documentation coverage across all public APIs

### Developer Tools & Configuration

#### Project Setup
- =� Swift Package Manager configuration with async/await support
- =' SwiftLint configuration with comprehensive rules and baseline
- >� Pre-commit hooks for code quality enforcement (formatting, linting, tests)
- =� Swift formatting configuration (standard and Google styles)
- =� Git commit message template and conventional commit compliance
- =
 CommitLint configuration for conventional commit validation

#### Build & Testing
-  Swift 6 compiler flags with concurrency and data race checking
- >� Comprehensive test suite with macro testing support
- =' Build system optimizations for faster compilation
- =� Code coverage reporting and quality gates

## Technical Specifications

### Platform Support
- iOS 16.0+
- macOS 13.0+
- tvOS 16.0+
- watchOS 9.0+
- Swift 6.0+

### Dependencies
- SwiftSyntax 600.0.0+ (for macro support)
- swift-macro-testing 0.5.2+ (for testing)

### Architecture
- Built with structured concurrency and actor isolation
- Middleware pipeline architecture for extensibility
- Type-safe configuration using result builders
- Compile-time API generation with Swift macros
- Thread-safe operations with modern Swift concurrency primitives

---

**Full Documentation**: See `Sources/Networking/Networking.docc/` for comprehensive guides and API reference.

**Migration Guide**: Refer to documentation for upgrading from previous networking solutions.

**Security**: This release includes comprehensive security hardening following OWASP Top 10 guidelines.
