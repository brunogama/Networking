# Architecture

**Analysis Date:** 2026-02-14

## Pattern Overview

**Overall:** Middleware pipeline with interceptor chain (request → execute → response/error)

**Key Characteristics:**
- Modern Swift 6 async/await first (no callbacks)
- Actor-isolated state with strict concurrency checking
- Interceptor chain of responsibility for request/response/error processing
- Compiler macro support for declarative API endpoint definition
- Builder pattern (result builders) for fluent configuration
- Protocol-oriented design for extensibility

## Layers

**Execution Layer:**
- Purpose: Manage overall HTTP request/response lifecycle with URLSession
- Location: `Sources/Networking/NetworkClient.swift`
- Contains: NetworkClient (main HTTPClient implementation), builder configuration
- Depends on: Interceptors, middleware protocols, HTTP types
- Used by: All consumers of the HTTP client

**Interceptor Layer:**
- Purpose: Transform requests (before network), handle responses (after network), manage errors and retries
- Location: `Sources/Networking/Interceptors/`
- Contains: InterceptorChain orchestration, 9+ interceptor implementations (auth, retry, caching, rate-limit, etc.)
- Depends on: HTTP types, InterceptorContext and InterceptorResult enums
- Used by: NetworkClient during request/response processing

**Middleware Layer (Deprecated/Alternate):**
- Purpose: Protocol-based middleware for request/response/error processing (HTTPRequestMiddleware, HTTPResponseMiddleware, HTTPErrorMiddleware)
- Location: `Sources/Networking/*.swift` (scattered, e.g., AuthenticationMiddleware.swift, ErrorMiddleware.swift)
- Contains: Concrete middleware implementations
- Depends on: HTTP types, middleware protocols
- Used by: NetworkClient initialization (parallel with interceptors)

**HTTP Types Layer:**
- Purpose: Core domain types for HTTP requests, responses, methods, status codes, errors
- Location: `Sources/Networking/HTTP*.swift`
- Contains: HTTPRequest, HTTPResponse, HTTPMethod, HTTPStatus, HTTPError, HTTPClient (protocol)
- Depends on: Foundation
- Used by: All other layers

**Builder/Configuration Layer:**
- Purpose: Provide fluent DSL for constructing requests and configuring clients
- Location: `Sources/Networking/RequestBuilder.swift`, `Sources/Networking/NetworkClientBuilder.swift`
- Contains: RequestBuilder result builder, RequestComponent protocol, configuration components (GET, POST, BearerAuth, etc.)
- Depends on: HTTP types, RequestComponents
- Used by: Application code for request/client construction

**Macro Layer:**
- Purpose: Code generation for declarative API endpoint definitions (@API, @GET, @POST, @PUT, @DELETE)
- Location: `Sources/Networking/Macros/` (swift-syntax based)
- Contains: Macro definitions, parameter attribute macros, macro error handling
- Depends on: Swift Syntax AST library, HTTP types
- Used by: Protocol-based API client definitions (at compile time)

**Testing Support Layer:**
- Purpose: Provide mocks and test utilities for unit and integration testing
- Location: `Sources/Networking/Testing/`
- Contains: MockNetworkClient (in-memory mock), MockURLProtocol (URLSession-level mock), MockDSL (test fixture builder)
- Depends on: HTTP types, HTTPClient protocol
- Used by: Test suites

## Data Flow

**Request Execution Flow:**

1. Consumer calls `NetworkClient.execute(HTTPRequest)` (async throws)
2. Apply request middlewares/interceptors (mutation, validation, auth headers, caching short-circuit)
3. Execute URLSession network request
4. Apply response middlewares/interceptors (caching, validation, transformation)
5. Return HTTPResponse to consumer
6. OR (on error) apply error middlewares/interceptors (retry, fallback recovery)

**Interceptor Chain Execution (within single request):**

1. Request interceptors run sequentially in registration order
   - Each can: proceed → next, short-circuit with cached response, or throw
2. Network execution (if not short-circuited)
3. Response interceptors run sequentially
   - Each can: proceed → next, retry (with configurable delay), or throw
4. Error interceptors run on failure (retry backoff, token refresh, circuit breaker)

**State Management:**
- Immutable request/response objects (value types, Sendable)
- InterceptorContext carries request metadata (path, method, attempt count)
- Shared state (caches, tokens) protected by actor isolation (e.g., actor ResponseCache)
- No global mutable state

## Key Abstractions

**HTTPClient Protocol:**
- Purpose: Abstraction for HTTP execution (URLSession implementation, mock for testing)
- Examples: `NetworkClient` (real), `MockNetworkClient` (test)
- Pattern: Async throwing function accepting HTTPRequest, returning HTTPResponse

**RequestInterceptor / ResponseInterceptor Protocols:**
- Purpose: Chain-of-responsibility for transforming/handling requests and responses
- Examples: `AuthenticationInterceptor`, `RetryInterceptor`, `CachingInterceptor`
- Pattern: Each interceptor receives request/response context, returns InterceptorResult (proceed/short-circuit/retry)

**RequestComponent Protocol:**
- Purpose: Composable builders for fluent request/client construction
- Examples: `GET(path)`, `BearerAuth(token)`, `QueryParam(key, value)`
- Pattern: Result builder components applied to PartialRequest

**Sendable Types:**
- Purpose: Enable safe concurrent access across actor boundaries (Swift 6 strict concurrency)
- Pattern: All public types are `Sendable`; all closures at isolation boundaries are `@Sendable`

**InterceptorContext:**
- Purpose: Immutable metadata about request being processed (path, method, attempt count)
- Pattern: Passed to each interceptor to provide context

## Entry Points

**NetworkClient.execute(_:):**
- Location: `Sources/Networking/NetworkClient.swift` (public method)
- Triggers: Consumer code calling async throwing method
- Responsibilities: Orchestrate request/response pipeline, apply middlewares, handle errors

**RequestBuilder.build(_:):**
- Location: `Sources/Networking/RequestBuilder.swift` (result builder)
- Triggers: Consumer code in @RequestBuilder context
- Responsibilities: Process RequestComponent instances into HTTPRequest

**@API, @GET, @POST, @PUT, @DELETE Macros:**
- Location: `Sources/Networking/Macros/HTTPMethodMacros.swift`
- Triggers: Compile time (protocol method annotation)
- Responsibilities: Generate async throwing function implementations with interceptor chain execution

**MockNetworkClient.execute(_:):**
- Location: `Sources/Networking/Testing/MockNetworkClient.swift` (test mock)
- Triggers: Test code calling async throwing method
- Responsibilities: Match request expectations, return stubbed responses, track calls

## Error Handling

**Strategy:** Structured error enum (HTTPError) with categories and recovery information

**Patterns:**
- HTTPError enums: Category (network, http, decoding, encoding, timeout, etc.)
- Recovery categories: RetryableWithDelay, RetryableImmediate, UserActionRequired, NonRecoverable
- Severity levels: Low, Medium, High, Critical
- Middleware/interceptors catch HTTPError, transform or retry based on category
- Context preserved: HTTPError carries original request, response, underlying system error

**Error Recovery:**
- RetryInterceptor: Exponential backoff, max attempts, jitter
- TokenRefreshInterceptor: Intercepts 401, refreshes token, retries request
- CircuitBreakerMiddleware: Fails fast after consecutive failures, half-open state for recovery
- ErrorMiddleware: Generic error handling, logging, default recovery actions

## Cross-Cutting Concerns

**Logging:**
- LoggingInterceptor logs request/response details at configurable levels
- No debug prints in production code
- Uses console (no external logging framework dependency)

**Validation:**
- HTTPRequest validates URL, headers (CRLF injection prevention)
- RequestBuilder validates all required components present
- Macros validate path parameter names match function parameters

**Authentication:**
- AuthenticationInterceptor adds Bearer token headers
- TokenRefreshInterceptor detects 401 responses, refreshes token via provider protocol
- Tokens stored in iOS Keychain (KeychainService abstraction)
- Multiple auth strategies: Bearer, Basic, Custom (via protocol)

**Concurrency/Safety:**
- All types Sendable (immutable structs or actor-isolated)
- All closures @Sendable at isolation boundaries
- URLSession access from main thread (thread-safe by design)
- Cache access protected by actor isolation
- No global mutable state

**Retry Logic:**
- RetryInterceptor implements exponential backoff with jitter
- Configurable per interceptor: base delay, max attempts, backoff multiplier
- Property-based tests verify backoff calculation correctness

---

*Architecture analysis: 2026-02-14*
