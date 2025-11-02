<!-- Generated: 2025-08-27 00:00:00 UTC -->

# ModernNetworking Project Overview

## Overview

ModernNetworking is a Swift 6 compliant networking framework designed for modern iOS, macOS, tvOS, and watchOS applications. The framework provides a comprehensive HTTP client implementation with async/await support, structured concurrency, and a powerful middleware system. Built on top of URLSession, it offers both a fluent DSL for request construction and Swift macro-generated API clients for type-safe networking.

The framework's core value proposition lies in its combination of Swift 6 strict concurrency compliance, middleware-driven architecture, and declarative request building patterns. The API Client Macro System (inspired by Retrofit for Android) enables developers to define complete REST APIs using protocol annotations, with the compiler generating type-safe implementations at build time. This eliminates networking boilerplate while maintaining compile-time validation of endpoints, parameters, and types.

The framework supports advanced features including authentication management, automatic retry mechanisms, response caching, circuit breakers, and comprehensive error handling while maintaining full thread safety and `Sendable` conformance throughout the API surface.

## Key Files

**Main Framework Entry**
- `Sources/Networking/Networking.swift` (lines 1-55) - Framework version info, type aliases, and comprehensive usage examples
- `Sources/Networking/NetworkClient.swift` (lines 1-795) - Primary HTTPClient implementation with middleware pipeline
- `Sources/Networking/HTTPClient.swift` - Core networking protocol definition

**Request Building System**
- `Sources/Networking/RequestBuilder.swift` (lines 1-234) - Result builder for fluent request construction
- `Sources/Networking/RequestComponents.swift` - Component implementations (headers, auth, query params)
- `Sources/Networking/RequestBuilderExtensions.swift` - Additional DSL components

**Middleware Architecture**
- `Sources/Networking/AuthenticationMiddleware.swift` - Bearer token and basic auth handling
- `Sources/Networking/RetryMiddleware.swift` - Configurable retry strategies with backoff
- `Sources/Networking/CachingMiddleware.swift` - Response caching with cache storage providers
- `Sources/Networking/LoggingMiddleware.swift` - Request/response logging and debugging

**Macro System** (Planned - See `specs/001-api-client-macro/`)
- `Sources/Networking/Macros/` - Public macro declarations (9 macros)
  - `API.swift` - @API protocol macro for base configuration
  - `HTTPMethod.swift` - @GET, @POST, @PUT, @PATCH, @DELETE method macros
  - `Parameters.swift` - Parameter handling (path templates, query params, body)
  - `Configuration.swift` - @DefaultHeaders, @Timeout configuration macros
  - `MacroError.swift` - Compile-time validation error types
- `Sources/NetworkingMacros/` - Macro implementation using SwiftSyntax
  - `API/APIMacro.swift` - Generates `Sendable` implementation struct
  - `HTTPMethod/` - HTTP method macro implementations (GET, POST, PUT, PATCH, DELETE)
  - `Parameters/` - Parameter extraction and validation logic
  - `Shared/MacroHelpers.swift` - Validation utilities and AST node generation
- `Sources/NetworkingClient/plugin.swift` - Compiler plugin exposing macros

## Technology Stack

**Swift Language & Concurrency**
- Swift 6.0 (Package.swift line 1) with strict concurrency enabled
- Full async/await integration throughout API surface
- Structured concurrency with proper cancellation support
- `Sendable` conformance for all public types

**Apple Frameworks**
- Foundation URLSession (NetworkClient.swift lines 65-217) for HTTP transport
- Security framework integration for SSL pinning and certificate validation
- Keychain Services for secure token storage (KeychainService.swift)

**Build System & Dependencies**
- Swift Package Manager with macro plugin support (Package.swift lines 36-44)
- SwiftSyntax 600.0.0+ for macro implementations
- swift-macro-testing 0.5.2+ for macro unit testing

**Testing Infrastructure**
- XCTest framework integration with async test support
- MacroTesting for Swift macro validation and expansion testing
- Comprehensive test coverage across NetworkingTests/ directory

## Platform Support

**Minimum Platform Requirements** (Package.swift lines 9-14)
- iOS 16.0+ - Full feature support including background tasks and network extensions
- macOS 13.0+ - Complete API availability with security framework integration  
- tvOS 16.0+ - Core networking with platform-appropriate error handling
- watchOS 9.0+ - Optimized for constrained resources and background execution

**Platform-Specific Implementations**
- `Sources/Networking/SecurityConfiguration.swift` - SSL pinning and certificate validation
- `Sources/Networking/KeychainService.swift` - Secure credential storage across platforms
- `Sources/Networking/MetricsCollector.swift` - Platform-appropriate performance monitoring
- `Samples/Arena-Playground/` - Interactive examples and testing environment for all platforms

## API Client Macro System (Feature Branch: 001-api-client-macro)

**Status**: Planning Complete - Implementation Pending
**Documentation**: `specs/001-api-client-macro/` (spec.md, plan.md, data-model.md, quickstart.md)
**Tasks**: 111 tasks across 7 implementation phases (see tasks.md)

### Feature Overview

The API Client Macro System enables declarative API client definitions using Swift macros, eliminating networking boilerplate while maintaining compile-time type safety. Inspired by Retrofit for Android, developers annotate protocol methods with HTTP operation macros (@GET, @POST, etc.), and the compiler generates complete NetworkClient-based implementations.

**Example Usage**:

```swift
@API(baseURL: "https://api.github.com")
protocol GitHubAPI {
    @GET("/users/{username}")
    func getUser(username: String) async throws -> GitHubUser

    @POST("/repos/{owner}/{repo}/issues", body: "issue")
    func createIssue(owner: String, repo: String, issue: NewIssue) async throws -> Issue
}

// Compiler generates GitHubAPIImplementation with full NetworkClient integration
let api = GitHubAPIImplementation()
let user = try await api.getUser(username: "brunogama")
```

### Macro Architecture

**9 Public Macros**:

- `@API(baseURL:)` - Attached member macro generating implementation struct
- `@GET/POST/PUT/PATCH/DELETE(_:)` - HTTP method macros with path templates
- `@DefaultHeaders(_:)` - Protocol-level default headers
- `@Timeout(_:)` - Request timeout configuration

**Parameter Handling**:


- Path parameters via template syntax: `/users/{id}` matches function parameter `id`
- Query parameters: `@GET("/search", queryParameters: ["q", "page"])`
- Request body: `@POST("/users", body: "user")` specifies which parameter is the body
- Custom headers: `@POST("/users", headers: ["X-Custom": "value"])`

**Compile-Time Validation**:

- Path parameter existence checks (emits diagnostic if `{userId}` not in function signature)
- Body parameter validation (verifies specified parameter exists and conforms to Encodable)
- HTTP method conflicts (prevents multiple method macros on single function)
- Async/throws requirement enforcement (all API methods must be `async throws`)

### Implementation Strategy

**Three-Target Swift Package**:

1. **Networking** (library) - Public macro declarations + existing framework
2. **NetworkingMacros** (macro) - SwiftSyntax-based macro implementations
3. **NetworkingClient** (plugin) - Compiler plugin exposing macros

**Code Generation Approach**:

- Uses SwiftSyntax string interpolation for AST node creation
- Generates `Sendable`-conforming implementation structs
- Integrates with existing NetworkClient (inherits all middleware, security features)
- No runtime reflection - pure compile-time code generation

**Key Technical Decisions** (see research.md):

- Attached member + peer macro types (not parameter-level due to Swift limitation)
- Method-level parameter encoding via macro attributes
- Path template validation using regex pattern matching
- Generated code uses existing HTTPRequest result builder

### Integration with Existing Framework

Generated macro implementations are first-class NetworkClient citizens:

- **Middleware Support**: Authentication, retry, logging, caching automatically applies
- **Security Features**: Certificate pinning, SSL validation, header security inherited
- **Error Handling**: Uses existing APIClientError type hierarchy
- **Testing**: Supports dependency injection with MockNetworkClient

### Implementation Phases

**MVP (42 tasks)**: Setup + Foundational + User Story 1 (GET endpoints)

- Phase 1: Package structure, SwiftSyntax dependencies, compiler plugin setup
- Phase 2: Core macro protocols, validation utilities, error types
- Phase 3: @API + @GET macros with path parameters and query params

**Incremental Features**:

- User Story 2 (24 tasks): POST/PUT/PATCH with request bodies and headers
- User Story 3 (16 tasks): @DefaultHeaders, @Timeout configuration
- DELETE Support (7 tasks): @DELETE macro implementation
- Polish (18 tasks): Advanced validation, diagnostic improvements, DocC documentation

**Parallelization**: 44 tasks marked for concurrent execution (independent macro implementations, test suites)

### Success Criteria

1. **Functional**: All 5 HTTP methods supported with path/query/body parameters
2. **Type Safety**: Compile-time validation of all endpoint declarations
3. **Performance**: Macro expansion <5s for 20 endpoints, generated code performs identically to hand-written
4. **Integration**: Seamless NetworkClient integration, all middleware/security features work
5. **Testing**: 80% unit test coverage (macro expansion), 15% integration tests, 5% E2E
6. **Documentation**: Complete DocC coverage, quickstart guide, 3+ contract examples
7. **Constitution**: No violations of 10 core principles (verified in plan.md)

### Planning Documents

- **spec.md**: 3 user stories (P1: GET, P2: POST/PUT/PATCH, P3: Configuration)
- **plan.md**: Technical context, constitution verification, project structure
- **research.md**: Swift macro architecture decisions, SwiftSyntax approach
- **data-model.md**: Complete type system (9 macros, 2 error enums, validation rules)
- **quickstart.md**: Developer usage guide with examples
- **contracts/**: 3 example files showing input protocols and generated output
- **tasks.md**: 111 implementation tasks with dependencies and parallel execution markers
