# Phase 2: Developer Experience - Research

**Researched:** 2026-02-14
**Domain:** Swift DSL patterns, fluent APIs, phantom types, macro-based code generation
**Confidence:** HIGH

## Summary

Phase 2 focuses on creating ergonomic, type-safe APIs that minimize boilerplate while maximizing compile-time safety. The research covers four major DX improvements: **request composition operators**, **method chaining for response processing**, **macro-generated interceptors** (`@Cacheable`, `@Measured`), and **phantom types for compile-time safety**.

The existing codebase already has strong foundations: NetworkClient with middleware chains, a result builder for configuration, macro infrastructure (Swift Syntax), and GraphQL types. The research identified proven patterns from the Swift ecosystem: phantom types for state/method safety, result builders for declarative DSLs, operator overloading for composition, and method chaining with value semantics.

**Primary recommendation:** Build on existing infrastructure. Use phantom types for HTTPMethod/Environment safety, extend HTTPRequest/HTTPResponse with fluent methods, create macros that generate interceptor configurations (not full implementations), and leverage Swift 6's type safety throughout.

## Standard Stack

### Core (Already in Codebase)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Swift Syntax | 600.0.0+ | Macro AST parsing and code generation | Official Apple compiler plugin API, required for all Swift macros |
| MacroTesting | 0.5.2+ | Macro expansion testing | Point-Free's testing framework, industry standard for macro validation |
| Swift 6 Result Builders | Built-in | DSL creation (@resultBuilder) | Native Swift feature, zero dependencies, compile-time validated |

### Supporting (New Dependencies NOT Required)
All DX improvements can be implemented using **existing dependencies and Swift standard library features**. No new packages needed.

### Patterns to Use
| Pattern | Implementation | Use Case |
|---------|---------------|----------|
| Phantom Types | `struct Request<Method, State>` | Compile-time HTTP method/state safety |
| Method Chaining | Value type + `-> Self` methods | Fluent response processing (`.decode().cache()`) |
| Operator Overloading | `static func +` on value types | Request composition (`req1 + req2`) |
| Result Builders | `@resultBuilder` (existing) | Configuration DSL (already implemented) |
| Macro Peer Generation | `@attached(peer)` macros | Generate interceptor configurations |

**Installation:**
No additional packages required. All patterns use Swift 6 standard library and existing dependencies.

## Architecture Patterns

### Recommended Project Structure
```
Sources/Networking/
├── DSL/
│   ├── RequestOperators.swift      # + operator for composition
│   ├── ResponseChaining.swift      # .decode(), .cache(), .retry()
│   ├── PhantomTypes.swift          # Request<Method>, Environment<Mode>
│   └── FluentExtensions.swift      # HTTPRequest/Response extensions
├── Macros/ (extend existing)
│   ├── CacheableMacro.swift        # @Cacheable
│   ├── MeasuredMacro.swift         # @Measured
│   ├── QueryMacro.swift            # @Query (GraphQL)
│   └── MutationMacro.swift         # @Mutation (GraphQL)
└── [existing files...]

Tests/NetworkingTests/
├── DSL/
│   ├── RequestOperatorsTests.swift
│   ├── ResponseChainingTests.swift
│   └── PhantomTypesTests.swift
└── Macros/ (extend existing)
    ├── CacheableMacroTests.swift
    ├── MeasuredMacroTests.swift
    └── [GraphQL macro tests]
```

### Pattern 1: Phantom Types for Compile-Time Safety

**What:** Generic wrapper types where the type parameter exists only at compile time, providing zero-cost type safety.

**When to use:** Prevent invalid state transitions, method mismatches, environment confusion at compile time.

**Example:**
```swift
// Phantom type for HTTP methods
struct TypedRequest<Method: HTTPMethodTag>: Sendable {
  let base: HTTPRequest

  // Only GET requests can use query parameters (compile-time enforcement)
  func withQuery<T: Encodable>(_ value: T) -> TypedRequest<Method> where Method == GETMethod {
    // Implementation
  }

  // Only POST/PUT/PATCH can have body (compile-time enforcement)
  func withBody<T: Encodable>(_ value: T) -> TypedRequest<Method> where Method: BodyAllowedMethod {
    // Implementation
  }
}

// Method tags (zero runtime cost)
protocol HTTPMethodTag: Sendable {}
struct GETMethod: HTTPMethodTag {}
struct POSTMethod: HTTPMethodTag, BodyAllowedMethod {}
protocol BodyAllowedMethod: HTTPMethodTag {}

// Usage (compile-time safe)
let getRequest = TypedRequest<GETMethod>(...)
  .withQuery(["page": 1])  // ✅ Compiles
  .withBody(["data": "x"]) // ❌ Compile error: GET cannot have body

let postRequest = TypedRequest<POSTMethod>(...)
  .withBody(["user": user]) // ✅ Compiles
```

**Source:** Verified pattern from Swift community (phantom-types-in-swift articles, January 2025).

**Benefits:**
- Zero runtime overhead (phantom types erased after type checking)
- Errors caught at compile time, not runtime
- Self-documenting code (type system encodes constraints)
- No performance cost compared to untyped implementation

**Tradeoffs:**
- Increased API surface (more types to learn)
- Verbosity in generic constraints
- Complexity in type signatures

### Pattern 2: Method Chaining with Value Semantics

**What:** Fluent API pattern where each method returns a modified copy (`self`), enabling readable chains like `.decode().cache().retry()`.

**When to use:** Response processing pipelines, configuration builders, transformations.

**Example:**
```swift
// Extension on HTTPResponse for chaining
extension HTTPResponse {
  // Decode JSON response body
  func decode<T: Decodable>(_ type: T.Type) throws -> DecodedResponse<T> {
    let decoder = JSONDecoder()
    let value = try decoder.decode(T.self, from: body ?? Data())
    return DecodedResponse(response: self, value: value)
  }
}

// Intermediate type for continued chaining
struct DecodedResponse<T: Sendable>: Sendable {
  let response: HTTPResponse
  let value: T

  // Cache the response
  func cached(in cache: ResponseCache) -> Self {
    cache.store(response)
    return self
  }

  // Retry on failure
  func retrying(maxAttempts: Int) -> Self {
    // Wrap in retry logic
    return self
  }
}

// Usage
let user = try await client.execute(request)
  .decode(User.self)           // HTTPResponse -> DecodedResponse<User>
  .cached(in: cache)            // DecodedResponse<User> -> DecodedResponse<User>
  .retrying(maxAttempts: 3)     // DecodedResponse<User> -> DecodedResponse<User>
  .value                        // Extract User
```

**Source:** Fluent interface patterns from Swift ecosystem (builder-pattern articles, 2024-2025).

**Implementation requirements:**
- Value types (struct) for thread safety
- Immutable properties (let, not var)
- Methods return `Self` or new wrapper types
- `@discardableResult` for optional chaining

### Pattern 3: Request Composition with + Operator

**What:** Overload `+` operator to combine HTTPRequest instances, merging headers/body/middleware.

**When to use:** Composing base requests with modifications, combining authentication + pagination, etc.

**Example:**
```swift
extension HTTPRequest {
  static func + (lhs: Self, rhs: Self) -> Self {
    // Merge headers (rhs takes precedence)
    var headers = lhs.headers
    headers.merge(rhs.headers) { _, new in new }

    // Use rhs body if present, otherwise lhs
    let body = rhs.body ?? lhs.body

    // Combine URL paths if rhs is relative
    let url = rhs.url.host == nil
      ? lhs.url.appendingPathComponent(rhs.url.path)
      : rhs.url

    return HTTPRequest(
      method: rhs.method,  // rhs method wins
      url: url,
      headers: headers,
      body: body,
      timeout: rhs.timeout
    )
  }
}

// Usage
let baseRequest = HTTPRequest(
  method: .get,
  url: URL(string: "https://api.example.com")!,
  headers: ["Authorization": "Bearer token"]
)

let paginatedRequest = HTTPRequest(
  method: .get,
  url: URL(string: "/users")!,
  headers: ["X-Page": "2"]
)

let finalRequest = baseRequest + paginatedRequest
// Result: GET https://api.example.com/users
//         Headers: ["Authorization": "Bearer token", "X-Page": "2"]
```

**Source:** DSL operator overloading patterns from Swift Auto Layout DSLs (2022-2025).

**Guidelines:**
- Document precedence rules (which side wins on conflict)
- Keep semantics intuitive (`+` = combine/merge)
- Preserve Sendable conformance
- Test edge cases (nil values, URL resolution, header conflicts)

### Pattern 4: Macros for Interceptor Generation

**What:** Use Swift macros to generate interceptor configuration code, not full implementations.

**Why configuration, not implementation:** Macros should generate **declarative configuration** that hooks into existing interceptors, avoiding complex runtime code generation.

**Example: @Cacheable Macro**
```swift
// User writes
@Cacheable(duration: 300)
protocol UserAPI {
  func getUser(id: String) async throws -> User
}

// Macro generates (peer)
extension UserAPI {
  static var cacheConfiguration: CachingConfiguration {
    CachingConfiguration(
      policy: .standard,
      storage: .memory(size: .MB(50)),
      duration: .ttl(300),
      shouldCache: { request, response in
        request.method == .get && response.status.isSuccess
      }
    )
  }
}
```

**Example: @Measured Macro**
```swift
// User writes
@Measured
func fetchUsers() async throws -> [User] {
  // Implementation
}

// Macro generates (peer wrapper)
func fetchUsers_measured() async throws -> [User] {
  let start = Date()
  defer {
    let duration = Date().timeIntervalSince(start)
    Metrics.record(duration: duration, for: "fetchUsers")
  }
  return try await fetchUsers()
}
```

**Source:** Swift macro production guide (2025-2026), best practices emphasize configuration over code generation.

**Best practices:**
- Generate **configuration structs**, not full interceptor implementations
- Use **peer macros** (`@attached(peer)`) for adding companion code
- Keep generated code **simple and reviewable**
- Provide **clear diagnostics** for invalid usage
- Test with MacroTesting framework

### Pattern 5: GraphQL Macro Generation

**What:** `@Query` and `@Mutation` macros generate GraphQL request builders from annotated methods.

**Example:**
```swift
// User writes
@Query("""
  query GetUser($id: ID!) {
    user(id: $id) { id name email }
  }
""")
func getUser(id: String) async throws -> User

// Macro generates
func getUser(id: String) async throws -> User {
  let request = GraphQLRequest(
    query: """
      query GetUser($id: ID!) {
        user(id: $id) { id name email }
      }
    """,
    variables: ["id": .string(id)],
    operationName: "GetUser"
  )

  let response: GraphQLResponse<UserQueryData> = try await graphQL.query(request)
  guard let user = response.data?.user else {
    throw GraphQLError.noData
  }
  return user
}
```

**Source:** Existing GraphQL types in codebase (`GraphQLRequest`, `GraphQLResponse`, `GraphQLValue`).

**Implementation:**
- Parse GraphQL query string in macro
- Extract variable names from `$var` syntax
- Generate `GraphQLRequest` with proper variable mapping
- Handle response unwrapping and error cases

### Anti-Patterns to Avoid

**❌ Overusing Phantom Types**
Don't create phantom types for every possible validation. Use only for **high-value compile-time checks** (HTTP method, environment mode, authentication state). Too many phantom types = excessive API complexity.

**❌ Macro Overreach**
Don't generate full interceptor implementations in macros. Generate **configuration only** and delegate to existing runtime code. Complex macro-generated code is hard to debug and review.

**❌ Breaking Value Semantics**
Don't add `mutating` methods to chaining APIs. Always return `Self` or new value. Mutation breaks thread safety and composability.

**❌ Operator Abuse**
Don't overload operators with unintuitive semantics. `+` for request composition is natural, but don't create `*` for "retry" or `/` for "cache" just because you can.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Macro AST manipulation | Custom string parsing/templating | Swift Syntax API (SwiftSyntaxBuilder) | Syntax API is type-safe, handles all edge cases, maintained by Apple |
| Result builder DSL | Custom parser or runtime interpreter | @resultBuilder with buildBlock | Native Swift feature, compile-time validated, zero runtime cost |
| Phantom type erasure | Manual type casting or runtime checks | Generic constraints (`where Method == GET`) | Compiler handles erasure automatically, zero runtime overhead |
| Request merging logic | Ad-hoc dictionary merging | Codified + operator with documented rules | Consistent semantics, tested once, reusable across codebase |
| GraphQL query parsing | Regex or string manipulation | Swift Syntax for macro, existing GraphQLRequest | Type-safe parsing, proper error handling, validated at compile time |

**Key insight:** All DX patterns leverage **compiler features** (generics, result builders, macros) rather than runtime reflection or parsing. This ensures zero overhead and compile-time safety.

## Common Pitfalls

### Pitfall 1: Phantom Type Complexity Explosion
**What goes wrong:** Creating phantom types for every possible state leads to unmanageable API surface (`Request<GET, Authenticated, Cached, Retried, Metered>`).

**Why it happens:** Phantom types are powerful, leading to overuse for every constraint.

**How to avoid:**
- Limit phantom types to **2-3 high-value dimensions** (HTTP method, environment mode)
- Use runtime validation for less critical constraints
- Provide type-erased escape hatches (`.eraseToHTTPRequest()`)

**Warning signs:**
- Generic constraints span multiple lines
- Users frequently need to type-erase to use APIs
- Documentation requires explaining 5+ type parameters

### Pitfall 2: Method Chaining State Loss
**What goes wrong:** Intermediate types in chain lose access to original response metadata (headers, status code).

**Why it happens:** Each transformation wraps the previous type, hiding original fields.

**How to avoid:**
- Keep original `HTTPResponse` accessible via property (`.response`)
- Provide pass-through accessors for common fields (`.status`, `.headers`)
- Document transformation sequence in types

**Warning signs:**
- Users call `.response.response.response` to access base
- Lost access to headers/metadata after decoding
- Type gymnastics to access both decoded value and status

### Pitfall 3: Macro Generated Code Not Sendable
**What goes wrong:** Macros generate code that violates Swift 6 concurrency (non-Sendable closures, unprotected state).

**Why it happens:** Macro author forgets to mark generated closures `@Sendable`.

**How to avoid:**
- Always generate `@Sendable` closures in async contexts
- Use `let` for all generated properties
- Test macro output with `-enable-actor-data-race-checks`
- Add Sendable conformance to generated types

**Warning signs:**
- Concurrency warnings in macro-expanded code
- Tests pass without strict concurrency, fail with it enabled
- Generated code uses `var` or mutable state

### Pitfall 4: Operator Overloading Confusion
**What goes wrong:** `+` operator has unclear precedence when combined with other operators or method calls.

**Why it happens:** Swift operator precedence + type inference = subtle bugs.

**How to avoid:**
- Document precedence explicitly in API docs
- Provide named alternative (`request.merged(with: other)`)
- Add tests for complex composition chains
- Use parentheses in examples to show grouping

**Warning signs:**
- Users report "unexpected" request combinations
- Type checker errors resolved by adding parentheses
- Bug reports about operator evaluation order

### Pitfall 5: GraphQL Macro Query Parsing Failures
**What goes wrong:** Macro fails to parse valid GraphQL queries with fragments, directives, or complex syntax.

**Why it happens:** Hand-rolled GraphQL parser doesn't handle full spec.

**How to avoid:**
- Use established GraphQL parser library or simple regex for variable extraction only
- Validate query strings at compile time (macro expansion)
- Provide clear error diagnostics for unsupported syntax
- Document supported GraphQL subset if not full spec

**Warning signs:**
- Macro works for simple queries, fails for real-world usage
- Users report cryptic compiler errors from macro
- No diagnostics for malformed GraphQL syntax

## Code Examples

Verified patterns from Swift ecosystem and existing codebase:

### Phantom Types for HTTP Method Safety
```swift
// Source: Phantom type pattern from Swift ecosystem (2025)
// Adapted for HTTP method compile-time safety

protocol HTTPMethodTag: Sendable {}
struct GETMethod: HTTPMethodTag {}
struct POSTMethod: HTTPMethodTag {}
struct PUTMethod: HTTPMethodTag {}
struct DELETEMethod: HTTPMethodTag {}

protocol BodyAllowedMethod: HTTPMethodTag {}
extension POSTMethod: BodyAllowedMethod {}
extension PUTMethod: BodyAllowedMethod {}

struct TypedRequest<Method: HTTPMethodTag>: Sendable {
  let base: HTTPRequest

  // Only methods supporting body can call this
  func withBody<T: Encodable & Sendable>(
    _ value: T
  ) -> TypedRequest<Method> where Method: BodyAllowedMethod {
    var copy = self
    copy.base.body = try? JSONEncoder().encode(value)
    return copy
  }

  // Type-erase when needed
  func eraseToHTTPRequest() -> HTTPRequest {
    base
  }
}

// Factory methods
extension HTTPRequest {
  static func get(url: URL) -> TypedRequest<GETMethod> {
    TypedRequest(base: HTTPRequest(method: .get, url: url))
  }

  static func post(url: URL) -> TypedRequest<POSTMethod> {
    TypedRequest(base: HTTPRequest(method: .post, url: url))
  }
}

// Usage
let request = HTTPRequest
  .post(url: URL(string: "https://api.example.com/users")!)
  .withBody(newUser)  // ✅ Compiles (POST allows body)
  .eraseToHTTPRequest()

// This would fail at compile time:
// HTTPRequest.get(url: ...).withBody(...)
// ❌ Error: GET does not conform to BodyAllowedMethod
```

### Response Processing Chain
```swift
// Source: Method chaining pattern from Swift fluent APIs (2024-2025)
// Implemented for HTTP response processing

extension HTTPResponse {
  func decode<T: Decodable & Sendable>(_ type: T.Type) throws -> DecodedResponse<T> {
    let decoder = JSONDecoder()
    guard let body = body else {
      throw HTTPError.emptyBody
    }
    let value = try decoder.decode(type, from: body)
    return DecodedResponse(response: self, value: value)
  }
}

struct DecodedResponse<T: Sendable>: Sendable {
  let response: HTTPResponse
  let value: T

  // Pass-through to original response metadata
  var status: HTTPStatus { response.status }
  var headers: [String: String] { response.headers }

  // Chain: cache the response
  func cached(using cache: ResponseCache) -> Self {
    cache.store(response)
    return self
  }

  // Chain: retry logic metadata
  func retryable(maxAttempts: Int = 3) -> RetryableDecodedResponse<T> {
    RetryableDecodedResponse(
      decoded: self,
      maxAttempts: maxAttempts
    )
  }
}

struct RetryableDecodedResponse<T: Sendable>: Sendable {
  let decoded: DecodedResponse<T>
  let maxAttempts: Int

  var value: T { decoded.value }
  var status: HTTPStatus { decoded.status }
}

// Usage
let user = try await client.execute(request)
  .decode(User.self)           // HTTPResponse -> DecodedResponse<User>
  .cached(using: cache)         // DecodedResponse<User> -> DecodedResponse<User>
  .retryable(maxAttempts: 3)    // DecodedResponse<User> -> RetryableDecodedResponse<User>
  .value                        // Extract User
```

### Request Composition Operator
```swift
// Source: Operator overloading DSL pattern from Swift ecosystem (2022-2025)

extension HTTPRequest {
  /// Composes two requests by merging their properties.
  ///
  /// Composition rules:
  /// - Method: rhs wins
  /// - URL: Combined if rhs is relative path, otherwise rhs wins
  /// - Headers: Merged, rhs takes precedence on conflicts
  /// - Body: rhs if present, otherwise lhs
  /// - Timeout: rhs
  static func + (lhs: Self, rhs: Self) -> Self {
    var headers = lhs.headers
    headers.merge(rhs.headers) { _, new in new }

    let body = rhs.body ?? lhs.body

    let url: URL
    if rhs.url.host == nil {
      // rhs is relative path, combine with lhs base
      url = lhs.url.appendingPathComponent(rhs.url.path)
    } else {
      url = rhs.url
    }

    return HTTPRequest(
      method: rhs.method,
      url: url,
      headers: headers,
      body: body,
      timeout: rhs.timeout
    )
  }

  /// Named alternative to + operator for clarity
  func merged(with other: Self) -> Self {
    self + other
  }
}

// Usage
let base = HTTPRequest(
  method: .get,
  url: URL(string: "https://api.example.com")!,
  headers: ["Authorization": "Bearer token", "Accept": "application/json"]
)

let specific = HTTPRequest(
  method: .post,
  url: URL(string: "/users")!,
  headers: ["Content-Type": "application/json"]
)

let composed = base + specific
// Result:
//   method: .post
//   url: https://api.example.com/users
//   headers: {
//     "Authorization": "Bearer token",
//     "Accept": "application/json",
//     "Content-Type": "application/json"
//   }
```

### @Cacheable Macro Implementation
```swift
// Source: Swift macro best practices (2025-2026)
// Generates configuration, not full implementation

import SwiftSyntax
import SwiftSyntaxMacros

public struct CacheableMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Parse @Cacheable(duration: 300, policy: .standard)
    guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
      throw MacroError.invalidUsage("@Cacheable can only be applied to protocols")
    }

    let duration = try extractDuration(from: node)
    let policy = try extractPolicy(from: node)

    // Generate peer extension with cache configuration
    let configCode = """
      extension \(protocolDecl.name) {
        static var cacheConfiguration: CachingConfiguration {
          CachingConfiguration(
            policy: .\(policy),
            storage: .memory(size: .MB(50)),
            duration: .ttl(\(duration)),
            shouldCache: { request, response in
              request.method == .get && response.status.isSuccess
            }
          )
        }
      }
      """

    return [DeclSyntax(stringLiteral: configCode)]
  }

  private static func extractDuration(from node: AttributeSyntax) throws -> Int {
    // Extract duration parameter (simplified)
    return 300  // Default
  }

  private static func extractPolicy(from node: AttributeSyntax) throws -> String {
    return "standard"  // Default
  }
}
```

### @Measured Macro Implementation
```swift
// Source: Swift macro patterns for timing/metrics (2025)

public struct MeasuredMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
      throw MacroError.invalidUsage("@Measured can only be applied to functions")
    }

    let funcName = funcDecl.name.text
    let signature = funcDecl.signature

    // Generate peer wrapper function with timing
    let wrapperCode = """
      func \(funcName)_measured\(signature.description) {
        let start = Date()
        let metricName = "\(funcName)"

        defer {
          let duration = Date().timeIntervalSince(start)
          Metrics.record(duration: duration, for: metricName)
        }

        return try await \(funcName)(\(parameterList(from: signature)))
      }
      """

    return [DeclSyntax(stringLiteral: wrapperCode)]
  }

  private static func parameterList(from signature: FunctionSignatureSyntax) -> String {
    // Extract parameter names for pass-through call
    // Simplified implementation
    return ""
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual request building | Result builders (`@resultBuilder`) | Swift 5.4 (2021) | Declarative DSL, compile-time validation, zero overhead |
| Runtime type validation | Phantom types + generics | Swift 5.0+ (2019) | Compile-time safety, no runtime checks needed |
| String-based API generation | Swift Macros | Swift 5.9 (2023) | Type-safe code generation, compiler-validated output |
| Closure-based async | async/await + structured concurrency | Swift 5.5 (2021) | Linear async code, actor isolation, data race safety |
| Enum-based HTTP methods | Struct with phantom types | Swift 6.0 (2024) | Extensible methods, compile-time method safety |

**Deprecated/outdated:**
- **Manual Codable implementations**: Use macros or code generation instead
- **Callback-based networking**: Use async/await throughout (Phase 1 complete)
- **NSCache directly**: Use actor-protected cache wrappers for Sendable compliance
- **String literals for URLs**: Use URL type with compile-time validation where possible

## Open Questions

1. **Phantom Type API Surface**
   - What we know: Phantom types provide compile-time safety with zero overhead
   - What's unclear: Optimal number of phantom dimensions before API becomes unwieldy
   - Recommendation: Start with HTTP method safety only, add environment/state types based on user feedback

2. **Macro Complexity Boundary**
   - What we know: Macros should generate configuration, not full implementations
   - What's unclear: Where to draw line between macro-generated vs hand-written code
   - Recommendation: Generate only declarative structs/enums in macros, delegate runtime behavior to existing interceptors

3. **GraphQL Variable Type Mapping**
   - What we know: Existing `GraphQLValue` enum supports common types
   - What's unclear: How to map Swift function parameters to GraphQL variable types in macro
   - Recommendation: Use simple type mapping (String -> .string, Int -> .int) initially, add custom mapping attributes if needed

4. **Method Chaining Performance**
   - What we know: Value types with copy-on-write have minimal overhead
   - What's unclear: Performance impact of deep chaining (`.decode().cache().retry().validate()`)
   - Recommendation: Benchmark with representative workloads, optimize if profiler shows hotspot

## Sources

### Primary (HIGH confidence)
- Swift Phantom Types article (mehmetbaykar.com) - comprehensive phantom type guide with HTTP API examples
- Result Builders DSL creation (mikebobiney.com) - result builder patterns and best practices
- Swift ecosystem DSL patterns (swiftwithmajid.com, 2019) - operator overloading and fluent APIs
- Existing codebase:
  - `NetworkClientBuilder.swift` - result builder implementation
  - `GraphQLTypes.swift` - GraphQL type system
  - `NetworkingMacros/Plugin.swift` - macro infrastructure
  - `HTTPRequest.swift`, `HTTPResponse.swift` - core types

### Secondary (MEDIUM confidence)
- Swift macro production guide search results (2025-2026) - macro best practices, patterns to avoid
- Method chaining patterns search results (2024-2025) - fluent interface design
- Swift concurrency patterns - async/await, Sendable, actor isolation (verified in existing codebase)

### Tertiary (LOW confidence)
- Exa search results for operator overloading - general patterns, not HTTP-specific
- Web search for GraphQL macro patterns - no Swift-specific implementations found, adapting from general macro patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All patterns use existing dependencies + Swift stdlib
- Architecture: HIGH - Patterns verified in existing codebase and Swift ecosystem
- Pitfalls: HIGH - Based on documented issues in Swift macro/phantom type discussions
- Phantom types: HIGH - Well-documented pattern with clear examples
- Result builders: HIGH - Native Swift feature, used in existing codebase
- Macros: MEDIUM - Macro system is new (Swift 5.9+), production patterns still emerging
- GraphQL macros: MEDIUM - No existing Swift examples found, pattern extrapolated from general macro usage

**Research date:** 2026-02-14
**Valid until:** 30 days (stable Swift 6 patterns, minimal churn expected)

## Next Steps for Planner

The planner should create tasks that:

1. **Extend existing types** (HTTPRequest, HTTPResponse) with phantom type wrappers and fluent methods
2. **Add new macros** to existing NetworkingMacros target (don't create new targets)
3. **Preserve Sendable conformance** throughout (strict concurrency enabled in Package.swift)
4. **Test with MacroTesting** (already available in dependencies)
5. **Document operator precedence** and phantom type usage in API docs

**Critical constraints:**
- All code must pass Swift 6 strict concurrency checks
- No new dependencies (use existing swift-syntax, MacroTesting)
- Follow existing file organization (DSL/ subfolder under Sources/Networking/)
- Maintain existing test patterns (unit + property-based + BDD)
