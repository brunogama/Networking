# Codebase Structure

**Analysis Date:** 2026-02-14

## Directory Layout

```
ModernNetworking/
├── Sources/
│   ├── Networking/                          # Main library target
│   │   ├── NetworkClient.swift              # Primary HTTP client implementation
│   │   ├── HTTPClient.swift                 # HTTPClient protocol
│   │   ├── HTTPRequest.swift                # HTTPRequest value type
│   │   ├── HTTPResponse.swift               # HTTPResponse value type
│   │   ├── HTTPMethod.swift                 # HTTP methods (GET, POST, etc)
│   │   ├── HTTPStatus.swift                 # HTTP status codes
│   │   ├── HTTPError.swift                  # Error enum with categories
│   │   ├── RequestBuilder.swift             # Result builder for fluent request construction
│   │   ├── NetworkClientBuilder.swift       # Builder for NetworkClient configuration
│   │   ├── RequestComponents.swift          # Builder components (GET, POST, BearerAuth, etc)
│   │   ├── RequestBuilderExtensions.swift   # Extension methods for RequestBuilder
│   │   ├── RequestCompositionOperators.swift # Operators for combining requests
│   │   ├── ResponseProcessing.swift         # Response handling utilities
│   │   ├── ResponseTransformation.swift     # Response transformation protocols
│   │   ├── ErrorMiddleware.swift            # Error handling middleware
│   │   ├── ErrorRecoveryStrategies.swift    # Error recovery strategy implementations
│   │   ├── ActionableErrorInfo.swift        # Error information for UI display
│   │   │
│   │   ├── Interceptors/                    # Interceptor implementations
│   │   │   ├── InterceptorChain.swift       # Chain orchestration
│   │   │   ├── InterceptorProtocols.swift   # RequestInterceptor, ResponseInterceptor protocols
│   │   │   ├── InterceptorContext.swift     # Metadata for request being processed
│   │   │   ├── InterceptorResult.swift      # Control flow enum (proceed, short-circuit, retry)
│   │   │   ├── InterceptorError.swift       # Interceptor-specific errors
│   │   │   ├── AuthenticationInterceptor.swift    # Adds Bearer token headers
│   │   │   ├── TokenRefreshInterceptor.swift     # Handles 401, refreshes token, retries
│   │   │   ├── RetryInterceptor.swift            # Exponential backoff retry logic
│   │   │   ├── CachingInterceptor.swift          # HTTP caching (RFC 7234)
│   │   │   ├── RateLimitInterceptor.swift        # Rate limit handling
│   │   │   ├── LoggingInterceptor.swift          # Request/response logging
│   │   │   ├── CircuitBreakerFSM.swift          # Circuit breaker state machine
│   │   │   └── [Others]                          # Additional interceptor implementations
│   │   │
│   │   ├── Middleware/                      # Alternative/legacy middleware protocols
│   │   │   ├── AuthenticationMiddleware.swift
│   │   │   ├── CachingMiddleware.swift
│   │   │   ├── CircuitBreakerMiddleware.swift
│   │   │   ├── RetryMiddleware.swift
│   │   │   ├── ProgressTrackingMiddleware.swift
│   │   │   ├── RequestTimingMiddleware.swift
│   │   │   ├── HeaderSecurityMiddleware.swift
│   │   │   ├── LoggingMiddleware.swift
│   │   │   └── [Others]
│   │   │
│   │   ├── Macros/                         # Compiler macro implementations
│   │   │   ├── HTTPMethodMacros.swift      # @GET, @POST, @PUT, @DELETE, @PATCH macros
│   │   │   ├── API.swift                   # @API macro for protocol decoration
│   │   │   ├── ConfigurationMacros.swift   # Configuration and setup macros
│   │   │   ├── ParameterAttributeMacros.swift # @Body, @Header, @Path, @Query macros
│   │   │   ├── HeaderBuilder.swift         # Header construction utilities
│   │   │   ├── HeaderComponent.swift       # Header value types
│   │   │   └── MacroError.swift            # Macro compilation error types
│   │   │
│   │   ├── Testing/                        # Testing utilities
│   │   │   ├── MockNetworkClient.swift     # In-memory HTTP mock with expectations
│   │   │   ├── MockURLProtocol.swift       # URLSession-level mock
│   │   │   ├── MockDSL.swift               # Test fixture builder DSL
│   │   │   └── README.md                   # Testing utilities guide
│   │   │
│   │   ├── Security/                       # Security-related implementations
│   │   │   ├── KeychainService.swift       # iOS Keychain token storage
│   │   │   ├── SecurityConfiguration.swift # Certificate pinning, validation
│   │   │   ├── HeaderSecurityMiddleware.swift # Security headers (CSP, HSTS, etc)
│   │   │   └── CacheStorageProviders.swift # Secure cache storage backends
│   │   │
│   │   ├── BDD/                            # BDD test framework integration (excluded)
│   │   │   ├── Core/                       # Core BDD infrastructure
│   │   │   ├── Matchers/                   # Quick/Nimble matchers
│   │   │   ├── Steps/                      # Step definitions
│   │   │   ├── Parser/                     # Feature file parsing
│   │   │   ├── Quick/                      # Quick framework integration
│   │   │   └── [Others]                    # Additional BDD components
│   │   │
│   │   ├── Networking.docc/                # Swift documentation catalog
│   │   │   ├── Networking.md               # Main documentation page
│   │   │   ├── Getting-Started.md          # Quick start guide
│   │   │   ├── Client-Configuration.md     # Configuration guide
│   │   │   ├── Request-Building.md         # Request builder guide
│   │   │   ├── Authentication.md           # Auth strategies guide
│   │   │   ├── Middleware-Guide.md         # Custom middleware guide
│   │   │   ├── Error-Handling.md           # Error handling patterns
│   │   │   ├── Security-Features.md        # Security features documentation
│   │   │   ├── Core-Networking.md          # Core types documentation
│   │   │   └── API-Reference.md            # API reference index
│   │   │
│   │   ├── Advanced Features
│   │   │   ├── WebSocketClient.swift       # WebSocket support
│   │   │   ├── WebSocketMessage.swift      # WebSocket message types
│   │   │   ├── GraphQLClient.swift         # GraphQL client wrapper
│   │   │   ├── GraphQLTypes.swift          # GraphQL type definitions
│   │   │   ├── BatchOperations.swift       # Batch request support
│   │   │   ├── DistributedTracing.swift    # Distributed tracing integration
│   │   │   ├── MetricsCollector.swift      # Metrics collection
│   │   │   ├── ProgressTracking.swift      # Upload/download progress
│   │   │   ├── ProgressTrackingMiddleware.swift
│   │   │   ├── NetworkActor.swift          # Actor-based network coordinator
│   │   │   └── TypedHTTPRequest.swift      # Typed request wrapper
│   │   │
│   │   ├── CLAUDE.md                       # Core library development guide
│   │   └── Networking.swift                # Module public exports
│   │
│   └── NetworkingMacros/                   # Macro implementation target
│       ├── NetworkingMacro.swift           # Main macro definitions
│       ├── [Macro implementations]         # Swift Syntax AST code generation
│       └── [Error handling]
│
├── Tests/
│   └── NetworkingTests/                    # Test suite
│       ├── NetworkClientTests.swift        # NetworkClient unit tests
│       ├── IntegrationTests.swift          # End-to-end tests with MockURLProtocol
│       ├── MockingTests.swift              # MockNetworkClient tests
│       ├── MockDSLTests.swift              # Test fixture builder tests
│       │
│       ├── Interceptors/                   # Interceptor-specific tests
│       │   ├── AuthenticationInterceptorTests.swift
│       │   ├── RetryInterceptorTests.swift
│       │   ├── CachingInterceptorTests.swift
│       │   ├── RateLimitInterceptorTests.swift
│       │   └── [Others]
│       │
│       ├── Macros/                         # Macro expansion tests
│       │   ├── GETMacroTests.swift
│       │   ├── POSTMacroTests.swift
│       │   ├── APIMacroTests.swift
│       │   ├── AttachedMacroIntegrationTests.swift
│       │   └── [Other macro tests]
│       │
│       ├── PropertyTests/                  # Property-based tests (SwiftCheck)
│       │   ├── RetryBackoffPropertyTests.swift
│       │   ├── InterceptorChainMonoidTests.swift
│       │   ├── CircuitBreakerFSMPropertyTests.swift
│       │   └── [Others]
│       │
│       ├── CachingTests.swift              # Caching behavior tests
│       ├── ErrorHandlingTests.swift        # Error handling tests
│       ├── SecurityConfigurationTests.swift # Security tests
│       ├── HeaderSecurityMiddlewareTests.swift
│       ├── KeychainServiceTests.swift      # Keychain tests
│       ├── FluentConfigurationTests.swift  # Builder tests
│       ├── ResponseProcessingTests.swift   # Response handling tests
│       ├── ProgressTrackingTests.swift     # Progress tracking tests
│       ├── WebSocketClientTests.swift      # WebSocket tests
│       ├── GraphQLClientTests.swift        # GraphQL client tests
│       ├── BatchOperationsTests.swift      # Batch operations tests
│       ├── DistributedTracingTests.swift   # Tracing integration tests
│       ├── ObservabilityTests.swift        # Observability features tests
│       ├── TypedHTTPRequestTests.swift     # Typed request tests
│       ├── RequestCompositionTests.swift   # Request composition tests
│       ├── NetworkActorTests.swift         # NetworkActor tests
│       ├── FileTransferOperationsTests.swift
│       ├── TransferControlsTests.swift     # Transfer control tests
│       ├── CircuitBreakerMiddlewareTests.swift
│       ├── ErrorRecoveryStrategiesTests.swift
│       │
│       ├── SimpleBDDTests.swift            # BDD test examples
│       ├── SimpleFluentTests.swift         # Fluent API examples
│       ├── SimplePropertyTests.swift       # Property test examples
│       ├── BasicFluentTests.swift          # Basic builder examples
│       ├── SpecializedResponseTests.swift
│       │
│       ├── CLAUDE.md                       # Testing guide
│       └── [Other test files]
│
├── Package.swift                           # SPM manifest
├── CLAUDE.md                               # Project development guide
├── RULES.md                                # AI agent coding rules
├── .swiftlint.yml                         # SwiftLint configuration
├── .swift-format                          # swift-format configuration
├── .github/workflows/                     # CI/CD workflows
├── .gitignore
└── README.md
```

## Directory Purposes

**Sources/Networking/:**
- Purpose: Main HTTP client library—core types, middleware, interceptors, testing utilities
- Contains: All production code for the Networking framework
- Key files: `NetworkClient.swift`, `HTTPRequest.swift`, `HTTPResponse.swift`

**Sources/Networking/Interceptors/:**
- Purpose: Request/response transformation and error recovery chain implementations
- Contains: InterceptorChain orchestration, 9+ interceptor types
- Key files: `InterceptorChain.swift`, `InterceptorProtocols.swift`, individual interceptor implementations

**Sources/Networking/Macros/:**
- Purpose: Swift Syntax-based code generation for declarative API client definitions
- Contains: Macro implementations (@API, @GET, @POST, etc)
- Key files: `HTTPMethodMacros.swift`, `API.swift`, `ParameterAttributeMacros.swift`

**Sources/Networking/Testing/:**
- Purpose: In-memory and URLSession-level mocks for comprehensive testing
- Contains: MockNetworkClient (expectation-based), MockURLProtocol (URLSession-level)
- Key files: `MockNetworkClient.swift`, `MockURLProtocol.swift`, `MockDSL.swift`

**Sources/NetworkingMacros/:**
- Purpose: Compiler plugin target for macro implementations (separate compilation)
- Contains: Swift Syntax AST code generation
- Key files: Macro entry points and code generation logic

**Tests/NetworkingTests/:**
- Purpose: Complete test suite covering unit, integration, property-based, and macro tests
- Contains: 60+ test files organized by component
- Key files: `IntegrationTests.swift`, `NetworkClientTests.swift`, macro tests

**Tests/NetworkingTests/PropertyTests/:**
- Purpose: Property-based testing using SwiftCheck for algorithmic correctness
- Contains: Backoff calculation verification, FSM state transitions, etc
- Key files: `RetryBackoffPropertyTests.swift`, `CircuitBreakerFSMPropertyTests.swift`

## Key File Locations

**Entry Points:**
- `Sources/Networking/NetworkClient.swift`: Primary HTTP client (execute method)
- `Sources/Networking/RequestBuilder.swift`: Fluent request construction (build result builder)
- `Sources/Networking/Macros/HTTPMethodMacros.swift`: Compile-time API client generation

**Configuration:**
- `Sources/Networking/NetworkClientBuilder.swift`: Client setup DSL
- `Sources/Networking/RequestComponents.swift`: Builder components (GET, POST, BearerAuth, etc)
- `Sources/Networking/SecurityConfiguration.swift`: Security settings (certificate pinning)

**Core Logic:**
- `Sources/Networking/Interceptors/InterceptorChain.swift`: Request/response pipeline
- `Sources/Networking/HTTPError.swift`: Error types and recovery strategies
- `Sources/Networking/Interceptors/RetryInterceptor.swift`: Retry logic with backoff

**Testing:**
- `Sources/Networking/Testing/MockNetworkClient.swift`: Mock for unit tests
- `Sources/Networking/Testing/MockURLProtocol.swift`: Mock for integration tests
- `Tests/NetworkingTests/IntegrationTests.swift`: End-to-end test patterns

## Naming Conventions

**Files:**
- `[Component].swift` - Single type or cohesive component (e.g., `NetworkClient.swift`, `HTTPRequest.swift`)
- `[Component]Tests.swift` - Tests for component (e.g., `NetworkClientTests.swift`)
- `[Feature]+[Aspect].swift` - Extension or specialized version (e.g., `RequestBuilder.swift`, `RequestBuilderExtensions.swift`)
- `[Name]Protocol.swift` - Protocol definitions (e.g., `InterceptorProtocols.swift`)

**Directories:**
- Lowercase plural for grouping related components (e.g., `Interceptors/`, `Macros/`, `Testing/`)
- One primary type per file (exception: tightly coupled internal helpers)

## Where to Add New Code

**New Interceptor:**
- Primary code: `Sources/Networking/Interceptors/[Name]Interceptor.swift`
- Tests: `Tests/NetworkingTests/Interceptors/[Name]InterceptorTests.swift`
- Pattern: Conform to `RequestInterceptor` or `ResponseInterceptor` protocol, mark `Sendable`

**New Middleware:**
- Primary code: `Sources/Networking/[Name]Middleware.swift`
- Tests: `Tests/NetworkingTests/[Name]MiddlewareTests.swift`
- Pattern: Conform to `HTTPRequestMiddleware`, `HTTPResponseMiddleware`, or `HTTPErrorMiddleware`

**New HTTP Type (Request/Response Component):**
- Primary code: `Sources/Networking/[Name].swift`
- Tests: `Tests/NetworkingTests/[Name]Tests.swift`
- Pattern: Struct with Sendable conformance, immutable properties

**New Builder Component:**
- Primary code: `Sources/Networking/RequestComponents.swift` (add to existing file) or new file if complex
- Tests: `Tests/NetworkingTests/FluentConfigurationTests.swift` or new file
- Pattern: Conform to `RequestComponent`, implement `apply(to:)` method

**New Macro:**
- Macro definition: `Sources/Networking/Macros/[Name]Macros.swift`
- Implementation: `Sources/NetworkingMacros/[Name]Macro.swift`
- Tests: `Tests/NetworkingTests/Macros/[Name]MacroTests.swift`
- Pattern: Use SwiftSyntax for AST parsing, generate async throwing function implementations

**Utilities/Helpers:**
- Shared helpers: `Sources/Networking/[Domain][Utility].swift`
- Non-public helpers: Use module scope (internal) or nest inside type
- Test utilities: `Sources/Networking/Testing/[Utility].swift`

## Special Directories

**Sources/Networking/BDD/:**
- Purpose: BDD test framework integration (Quick/Nimble)
- Generated: No
- Committed: Yes, but excluded from main target build
- Status: Incomplete integration code—available but not used in primary build

**Sources/Networking/Networking.docc/:**
- Purpose: Swift documentation catalog (rendered as HTML by DocC)
- Generated: No (manually maintained)
- Committed: Yes
- Content: Tutorials, guides, API reference documentation

**Tests/NetworkingTests/PropertyTests/:**
- Purpose: Property-based testing with SwiftCheck
- Generated: No
- Committed: Yes
- Pattern: Parametrized tests verifying algorithmic correctness

**.planning/codebase/:**
- Purpose: Architecture and structure analysis documents (written by GSD mapper)
- Generated: Yes (by agent)
- Committed: Yes (reference documents)
- Content: ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, CONCERNS.md

## Key File Purposes

| File | Purpose | Lines | Status |
|------|---------|-------|--------|
| `NetworkClient.swift` | Primary HTTP client | ~450 | Stable |
| `HTTPRequest.swift` | Request value type | ~120 | Stable |
| `HTTPResponse.swift` | Response value type | ~80 | Stable |
| `HTTPError.swift` | Error enum + categories | ~200 | Stable |
| `InterceptorChain.swift` | Request/response pipeline | ~300 | Stable |
| `InterceptorProtocols.swift` | Protocol definitions | ~150 | Stable |
| `RequestBuilder.swift` | Result builder DSL | ~250 | Stable |
| `MockNetworkClient.swift` | In-memory HTTP mock | ~350 | Stable |
| `IntegrationTests.swift` | End-to-end tests | ~800 | Stable |

## Code Organization Patterns

**Interceptor Pattern (Extensible):**
```
Interceptors/
├── InterceptorProtocols.swift  # Protocol definitions
├── InterceptorChain.swift      # Orchestrator
├── [Name]Interceptor.swift     # Individual implementations
└── Tests/[Name]InterceptorTests.swift
```

**Builder Pattern (Fluent API):**
```
RequestBuilder.swift            # Result builder
RequestComponents.swift         # Component implementations
RequestBuilderExtensions.swift  # Convenience methods
FluentConfigurationTests.swift  # Builder tests
```

**Macro Pattern (Code Generation):**
```
Macros/[Name]Macros.swift      # Public macro definition
../NetworkingMacros/[Name].swift # Implementation
Tests/Macros/[Name]MacroTests.swift # Macro expansion tests
```

**Middleware Pattern (Protocol-based):**
```
[Feature]Middleware.swift       # Middleware implementation
[Feature]MiddlewareTests.swift  # Middleware tests
```

---

*Structure analysis: 2026-02-14*
