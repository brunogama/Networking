# Design: API Client Macro System

## Context

ModernNetworking provides a NetworkClient with middleware pipeline, but developers must manually construct HTTP requests for each API endpoint. This creates repetitive boilerplate code. We're adding Swift macros to generate type-safe API client implementations from annotated protocol declarations, inspired by Retrofit for Android.

**Constraints**:
- Swift 6 strict concurrency required
- Must integrate with existing NetworkClient infrastructure
- Compile-time validation preferred over runtime errors
- No new external dependencies beyond SwiftSyntax (already used)

**Stakeholders**:
- Framework users wanting declarative API definitions
- Framework maintainers ensuring type safety and performance

## Goals / Non-Goals

### Goals
- Enable declarative API client definitions using protocol annotations
- Generate Sendable-conforming implementations at compile time
- Provide compile-time validation of paths, parameters, and types
- Integrate seamlessly with existing NetworkClient middleware and security features
- Support all HTTP methods (GET, POST, PUT, PATCH, DELETE)
- Match or exceed hand-written NetworkClient code performance

### Non-Goals
- Runtime reflection or code generation
- Supporting non-NetworkClient HTTP libraries
- GraphQL, WebSocket, or non-REST protocols
- Code generation from OpenAPI/Swagger specs (future consideration)
- Mocking or test utilities (use existing MockNetworkClient)

## Decisions

### Decision 1: Attached Member + Peer Macro Architecture

**What**: Use `@attached(member)` for `@API` protocol macro to generate implementation struct, and `@attached(peer)` for HTTP method macros (`@GET`, `@POST`, etc.).

**Why**:
- Swift macros cannot attach directly to function parameters (`@Path id: String` unsupported)
- Member macros can generate complete struct implementations from protocols
- Peer macros allow method-specific metadata while keeping protocols clean
- Matches Retrofit's conceptual model within Swift's macro constraints

**Alternatives Considered**:
1. **Direct parameter annotations** - Rejected: Not supported by Swift macro system
2. **Property wrapper parameters** - Rejected: Verbose, not idiomatic for functions
3. **String-based parameter mapping** - Rejected: No compile-time validation

**Trade-offs**:
- ✅ Type safety with compile-time validation
- ✅ Clear error messages at build time
- ❌ Slightly more verbose than Retrofit (parameters inferred from path/attributes vs direct annotations)

### Decision 2: SwiftSyntax String Interpolation for Code Generation

**What**: Use SwiftSyntax string interpolation for generating method implementations:

```swift
try FunctionDeclSyntax("""
func \(methodName)(\(parameters)) async throws -> \(returnType) {
    let request = HTTPRequest {
        \(httpMethod)("\(path)")
        BaseURL("\(baseURL)")
    }
    let response = try await client.execute(request)
    return try response.decode(\(returnType).self)
}
""")
```

**Why**:
- Most readable and maintainable approach
- Easier to review in macro expansion tests
- Allows embedding complex logic naturally
- Compile-time syntax validation

**Alternatives Considered**:
1. **Result builders** - More verbose, harder to maintain for large code blocks
2. **Manual node construction** - Very verbose, poor readability

### Decision 3: Method-Level Parameter Encoding

**What**: Encode parameter semantics at method level using macro attributes:

```swift
@GET("/users/{id}")  // Path parameter inferred from template
func getUser(id: String) async throws -> User

@GET("/search", queryParameters: ["q", "limit"])  // Explicit query params
func search(q: String, limit: Int?) async throws -> [Result]

@POST("/users", body: "user")  // Explicit body parameter
func createUser(user: User) async throws -> User
```

**Why**:
- Compile-time validation of parameter names against path template
- Clear error messages when parameters don't match
- Type safety from function signature
- Supports optional parameters naturally

**Validation Rules**:
- Path parameters: Extract from `{param}` syntax, validate existence in function signature
- Query parameters: Validate all listed parameters exist in function signature
- Body parameters: Validate specified parameter exists and conforms to Encodable
- Return types: Validate conform to Decodable (except Void)

### Decision 4: NetworkClient Integration Pattern

**What**: Generated implementations use existing NetworkClient with HTTPRequest result builder:

```swift
struct UserAPIImplementation: UserAPI, Sendable {
    private let client: NetworkClient

    init(client: NetworkClient = .shared) {
        self.client = client
    }

    func getUser(id: String) async throws -> User {
        let request = HTTPRequest {
            GET("/users/\(id)")
            BaseURL("https://api.example.com")
        }
        let response = try await client.execute(request)
        return try response.decode(User.self)
    }
}
```

**Why**:
- Zero runtime overhead - generates identical code to hand-written implementation
- Inherits all NetworkClient features (middleware, security, caching, retry)
- Testable using existing MockNetworkClient
- No new API surface to learn

**Benefits**:
- Middleware automatically applies (authentication, logging, etc.)
- Certificate pinning and SSL validation work without changes
- Circuit breaker and retry logic inherited
- Metrics and observability work out of box

### Decision 5: Three-Target Swift Package Structure

**What**:
1. **Networking** (library) - Public macro declarations + existing framework
2. **NetworkingMacros** (macro) - SwiftSyntax-based implementations
3. **NetworkingClient** (plugin) - Compiler plugin exposing macros

**Why**:
- Standard Swift Package Manager macro pattern
- Separates public API from implementation details
- Enables independent testing of macro expansion logic
- Plugin target required by Swift compiler

## Risks / Trade-offs

### Risk 1: Macro Expansion Complexity

**Risk**: Complex path templates or parameter combinations could cause confusing compiler errors.

**Mitigation**:
- Extensive unit tests for all parameter combinations
- Clear diagnostic messages with Fix-It suggestions
- Comprehensive error handling with recovery suggestions
- Detailed documentation of supported patterns

### Risk 2: Swift 6 Concurrency Compliance

**Risk**: Generated code might not comply with strict concurrency requirements.

**Mitigation**:
- All generated structs marked `Sendable`
- NetworkClient already `Sendable`-compliant
- Explicit testing with Swift 6 strict concurrency enabled
- No shared mutable state in generated code

### Risk 3: Performance of Macro Expansion

**Risk**: Large APIs with many endpoints could slow build times.

**Mitigation**:
- String interpolation faster than manual AST construction
- Benchmark target: <5s expansion time for 20 endpoints
- Performance tests in CI pipeline
- Lazy evaluation where possible

### Trade-off: Verbosity vs Type Safety

**Trade-off**: Method-level parameter encoding more verbose than direct parameter annotations (like Retrofit).

**Chosen**: Type safety and compile-time validation over terseness.

**Impact**: Developers write slightly more annotations, but get immediate feedback on errors.

## Migration Plan

### Phase 1: Infrastructure (Complete ✅)
- Directory structure created
- Error types implemented
- Validation utilities implemented
- Test infrastructure ready

### Phase 2: MVP - GET Endpoints (Current)
- Implement @API and @GET macros
- Path parameter substitution
- Query parameter handling
- Response decoding
- Comprehensive tests

### Phase 3: Full CRUD
- Implement @POST, @PUT, @PATCH, @DELETE
- Request body handling
- Custom header support
- Content-Type management

### Phase 4: Configuration
- Implement @DefaultHeaders, @Timeout
- Protocol-level configuration inheritance
- Method-level overrides

### Phase 5: Polish
- DocC documentation
- Diagnostic improvements
- Quickstart guide
- Performance validation

### Rollback Plan
- Change is additive - no breaking changes to existing NetworkClient
- Users can opt-in incrementally
- Macro declarations can be deprecated if needed
- Generated code has no runtime dependency on macro logic

## Open Questions

None. All architectural decisions have been made and validated against project constitution.

## References

- Swift Macros documentation: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/macros/
- SwiftSyntax package: https://github.com/swiftlang/swift-syntax
- Retrofit documentation (inspiration): https://square.github.io/retrofit/
- Project constitution: `.specify/memory/constitution.md`
- Existing planning: `specs/001-api-client-macro/`
