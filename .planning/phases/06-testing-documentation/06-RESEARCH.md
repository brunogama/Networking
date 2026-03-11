# Phase 6: Testing & Documentation - Research

**Researched:** 2026-02-15
**Domain:** Swift Testing, Property-Based Testing, BDD, DocC Documentation
**Confidence:** HIGH

## Summary

Phase 6 focuses on completing test coverage and documentation for the ModernNetworking library's production release. The codebase already has substantial testing infrastructure including MockNetworkClient, MockURLProtocol utilities, property-based tests using SwiftCheck, and BDD tests with Quick/Nimble. The Mock DSL implementation (Expect/Respond builders) exists but requires enhancement for sequential expectation chaining.

The existing Documentation.docc structure contains multiple articles (GETTING_STARTED.md, MIGRATION_GUIDE.md, TESTING_GUIDE.md, etc.) that provide solid foundations. The phase requires completing the Expect/Respond DSL for test mocking, adding property-based tests for retry backoff and interceptor chain behaviors, writing BDD specs for user-facing behaviors, and ensuring DocC catalog completeness.

**Primary recommendation:** Enhance the existing Mock DSL with sequential chaining capabilities, extend property-based tests with SwiftCheck's Arbitrary protocol conformance pattern already established in the codebase, add BDD specs using the Quick/Nimble integration already in place, and audit DocC coverage against all public APIs.

## Standard Stack

### Core Testing

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| XCTest | Built-in | Unit tests, async testing | Apple's official framework, Swift 6 native |
| Swift Testing | Built-in | Modern parameterized tests | Apple's new testing framework, #expect macro |
| SwiftCheck | 0.12.0+ | Property-based testing | QuickCheck port for Swift, Arbitrary protocol |
| Quick | 7.4.0+ | BDD test framework | Industry standard BDD specs |
| Nimble | 13.0.0+ | Assertion matchers | Expressive matchers with async support |
| MacroTesting | Latest | Macro expansion tests | Point-Free's cleaner API for macro testing |

### Documentation

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Swift-DocC | Built-in | API documentation | Apple's native documentation compiler |
| DocC Plugin | SPM integrated | Build docs from CLI | Automates documentation generation |

### Already in Package.swift

```swift
// Test dependencies (already configured)
.package(url: "https://github.com/typelift/SwiftCheck.git", from: "0.12.0"),
.package(url: "https://github.com/Quick/Quick.git", from: "7.4.0"),
.package(url: "https://github.com/Quick/Nimble.git", from: "13.0.0"),
```

## Architecture Patterns

### Recommended Test Structure

```
Tests/NetworkingTests/
|-- Interceptors/          # Per-interceptor unit tests
|-- PropertyTests/         # SwiftCheck property-based tests
|   |-- RetryBackoffPropertyTests.swift
|   |-- InterceptorChainMonoidTests.swift
|   |-- CircuitBreakerFSMPropertyTests.swift
|   `-- HeaderSecurityPropertyTests.swift
|-- DSL/                   # DSL-specific tests
|   |-- PhantomTypesTests.swift
|   |-- ResponseChainingTests.swift
|   `-- ResponseChainingIntegrationTests.swift
|-- BDD/                   # Quick/Nimble BDD specs (NEW)
|   |-- NetworkClientSpec.swift
|   |-- InterceptorChainSpec.swift
|   `-- ErrorHandlingSpec.swift
|-- MockDSLTests.swift     # Expect/Respond DSL tests
`-- IntegrationTests.swift # End-to-end component tests
```

### Pattern 1: Expect/Respond DSL Enhancement (TEST-01, TEST-02, TEST-03)

**What:** Extend existing MockDSL with sequential expectation chaining
**When to use:** Testing request/response sequences, multi-step API flows
**Current Implementation:**
```swift
// Source: Packages/Networking/Sources/Networking/Testing/MockDSL.swift
let mock = try NetworkingMock {
    Expect {
        Method(.get)
        Path("/users/123")
    }
    Respond {
        Status(.ok)
        jsonBody
    }
}
```

**Enhanced Sequential Pattern:**
```swift
// Sequential chaining for multi-request tests
let mock = try NetworkingMock {
    // First request
    Expect { Method(.get); Path("/auth/token") }
    Respond { Status(.ok); MockJSONBody(TokenResponse(token: "abc")) }

    // Second request (uses token from first)
    Expect { Method(.get); Path("/users/me"); HeaderValue("Authorization", "Bearer abc") }
    Respond { Status(.ok); MockJSONBody(User(id: 1, name: "Test")) }
}

// Execute sequentially
let token = try await mock.client.execute(tokenRequest)
let user = try await mock.client.execute(userRequest)
```

### Pattern 2: Property-Based Testing with SwiftCheck

**What:** Test mathematical properties of algorithms with generated inputs
**When to use:** Retry backoff calculations, interceptor chain composition
**Existing Pattern:**
```swift
// Source: Tests/NetworkingTests/PropertyTests/RetryBackoffPropertyTests.swift
func testDelayIsNonNegative() {
    property("Delay is always non-negative")
        <- forAll(RetryConfigGen.arbitrary, Gen.choose((0, 20))) {
            (config: RetryConfig, attemptCount: Int) in
            let delay = Self.calculateDelay(
                attemptCount: attemptCount,
                baseDelay: config.baseDelay,
                maxDelay: config.maxDelay
            )
            return delay >= 0
        }
}
```

**Arbitrary Conformance Pattern:**
```swift
// Source: Tests/NetworkingTests/PropertyTests/InterceptorChainMonoidTests.swift
extension InterceptorChain: Arbitrary {
    public static var arbitrary: Gen<InterceptorChain> {
        Gen<InterceptorChain>.compose { composer in
            let requestCount = composer.generate(using: Gen.choose((0, 5)))
            let requestInterceptors: [any RequestInterceptor] = (0..<requestCount).map { i in
                TestRequestInterceptor(id: "req-\(i)")
            }
            // ...
            return InterceptorChain(
                requestInterceptors: requestInterceptors,
                responseInterceptors: responseInterceptors
            )
        }
    }
}
```

### Pattern 3: BDD Specs with Quick/Nimble

**What:** Behavior-driven specs for user-facing behaviors
**When to use:** Document expected behaviors, readable test descriptions
**Existing Pattern:**
```swift
// Source: Tests/NetworkingTests/SimpleBDDTests.swift
final class SimpleBDDTests: QuickSpec {
    override class func spec() {
        describe("HTTPRequest") {
            context("when creating a basic request") {
                it("should have the correct properties") {
                    let request = HTTPRequest(method: .get, url: url)
                    expect(request.method).to(equal(.get))
                    expect(request.headers).to(beEmpty())
                }
            }
        }
    }
}
```

### Pattern 4: DocC Documentation Catalog

**What:** Structured documentation with tutorials and API reference
**When to use:** Public API documentation, getting started guides, migration guides
**Current Structure:**
```
Documentation.docc/
|-- Networking.md          # Main catalog page (Topics section)
|-- Articles/
|   |-- GETTING_STARTED.md
|   |-- MIGRATION_GUIDE.md
|   |-- TESTING_GUIDE.md
|   |-- ARCHITECTURE_GUIDE.md
|   |-- API_REFERENCE.md
|   |-- MIDDLEWARE_DOCUMENTATION.md
|   `-- FLUENT_DSL_DOCUMENTATION.md
```

**DocC Link Format:**
```markdown
## Topics

### Essentials
- <doc:GettingStarted>
- <doc:API_REFERENCE>

### See Also
- ``NetworkClient``
- ``HTTPRequest``
```

### Anti-Patterns to Avoid

- **Sleep in async tests:** Use `Task.sleep(nanoseconds:)` or expectations, never `Thread.sleep`
- **Hardcoded test data:** Use Arbitrary generators and test factories
- **Testing implementation details:** Test public behavior, not private methods
- **Missing @Sendable on test closures:** All async test closures need `@Sendable`
- **Incomplete error path testing:** Always test timeout, network failure, invalid response cases
- **Documentation without examples:** Every public API should have usage examples in DocC

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Property generation | Custom random generators | SwiftCheck `Gen` + `Arbitrary` | Shrinking, edge cases, seed reproducibility |
| BDD assertions | Custom expect functions | Nimble matchers | Async support, readable errors, extensible |
| Mock responses | Manual Data construction | MockDSL Respond builder | Type-safe, consistent JSON encoding |
| Documentation | Markdown files | DocC catalog | Symbol linking, Xcode integration, versioning |
| Test doubles | Manual mock classes | MockNetworkClient | Actor-based, thread-safe, DSL integration |

**Key insight:** The codebase already has well-designed test infrastructure. Extend existing patterns rather than creating parallel systems.

## Common Pitfalls

### Pitfall 1: Flaky Property-Based Tests

**What goes wrong:** Tests pass sometimes, fail others due to random generation
**Why it happens:** Not handling edge cases (empty arrays, zero values, max Int)
**How to avoid:**
- Use `forAll` with explicit edge case generators
- Set `CheckerArguments(replay: .random(123))` for reproducibility during debugging
- Ensure Arbitrary implementations generate meaningful edge cases
**Warning signs:** Tests fail in CI but pass locally, different results on each run

### Pitfall 2: Actor Isolation in BDD Tests

**What goes wrong:** Quick specs using shared mutable state cause data races
**Why it happens:** Quick's `beforeEach`/`afterEach` run on different contexts
**How to avoid:**
- Use actor-based test state (existing MockNetworkClient is already actor-safe)
- Mark shared closures as `@Sendable`
- Use `await` for all actor-isolated state access
**Warning signs:** Swift 6 warnings about data race, intermittent test failures

### Pitfall 3: Incomplete DocC Symbol Links

**What goes wrong:** DocC fails to build or shows broken links
**Why it happens:** Symbol names don't match public API exactly
**How to avoid:**
- Use double-backtick syntax exactly: ``NetworkClient``
- Verify symbol names match public declarations
- Run `swift package generate-documentation --warnings-as-errors`
**Warning signs:** Xcode warnings during doc generation, missing symbols in output

### Pitfall 4: Sequential Mock Expectations Not Matching

**What goes wrong:** Mock returns wrong response for sequential requests
**Why it happens:** Expectations matched by first-fit, not sequential order
**How to avoid:**
- Implement ordered expectation queue in MockDSL enhancement
- Track call counts and order explicitly
- Use `exactly(n)` constraints
**Warning signs:** Tests pass with single request, fail with multiple

### Pitfall 5: Missing Async Context in Tests

**What goes wrong:** `async` functions called without `await`
**Why it happens:** Test methods not marked `async`
**How to avoid:**
- Mark all test functions as `async throws` when testing async APIs
- Use `@Test` macro (Swift Testing) which handles async naturally
- For XCTest, use `async` test method signature
**Warning signs:** Compiler errors about missing `await`, tests not actually waiting

## Code Examples

### Sequential Expectation Chaining (TEST-03)

```swift
// Enhanced MockDSL for sequential expectations
public struct SequentialMock: Sendable {
    private let expectations: [MockRule]
    private let callIndex: AtomicInt // Thread-safe call counter

    public init(@MockRuleBuilder _ content: () throws -> [MockRule]) throws {
        self.expectations = try content()
        self.callIndex = AtomicInt(0)
    }

    public func nextResponse(for request: HTTPRequest) throws -> HTTPResponse {
        let index = callIndex.increment() - 1
        guard index < expectations.count else {
            throw MockError.unexpectedCall(index: index, request: request)
        }

        let rule = expectations[index]
        guard rule.expectation.matches(request) else {
            throw MockError.requestMismatch(
                expected: rule.expectation,
                actual: request,
                atIndex: index
            )
        }

        return rule.response.build()
    }
}
```

### Property Test for Interceptor Chain Monoid Laws (TEST-05)

```swift
// Source: Pattern from Tests/NetworkingTests/PropertyTests/InterceptorChainMonoidTests.swift
func testAssociativity() {
    property("Associativity: (a.appending(b)).appending(c) == a.appending(b.appending(c))")
        <- forAll(
            InterceptorChainGen.arbitrary,
            InterceptorChainGen.arbitrary,
            InterceptorChainGen.arbitrary
        ) { (a: InterceptorChain, b: InterceptorChain, c: InterceptorChain) in
            let leftAssoc = (a.appending(b)).appending(c)
            let rightAssoc = a.appending(b.appending(c))
            return Self.chainsAreEquivalent(leftAssoc, rightAssoc)
        }
}
```

### BDD Spec for User-Facing Behavior (TEST-06)

```swift
// New BDD spec pattern for user-facing behaviors
final class NetworkClientBehaviorSpec: QuickSpec {
    override class func spec() {
        describe("NetworkClient") {
            describe("executing authenticated requests") {
                context("when the token is valid") {
                    it("should include Authorization header") {
                        // Given
                        let mock = try! NetworkingMock {
                            Expect {
                                Method(.get)
                                Path("/protected")
                                HeaderPresent("Authorization")
                            }
                            Respond {
                                Status(.ok)
                                Body(Data("success".utf8))
                            }
                        }

                        // When
                        let response = try! await mock.client.execute(
                            HTTPRequest(
                                method: .get,
                                url: URL(string: "https://api.example.com/protected")!,
                                headers: ["Authorization": "Bearer token"]
                            )
                        )

                        // Then
                        expect(response.status.rawValue).to(equal(200))
                    }
                }

                context("when the token is expired") {
                    it("should attempt token refresh before failing") {
                        // BDD scenario for token refresh flow
                    }
                }
            }
        }
    }
}
```

### DocC Getting Started Guide Structure (DOC-02)

```markdown
# Getting Started with Networking

Learn how to make your first HTTP request with the Networking framework.

## Overview

Networking provides a modern, Swift 6 compliant HTTP client with async/await support.

## Creating a Client

Create a ``NetworkClient`` with fluent configuration:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    EnableLogging()
    EnableRetry()
}
```

## Making Requests

Execute requests using the DSL builder:

```swift
let response = try await client.execute {
    GET("/users/123")
    BearerAuth(token)
}
```

## Topics

### Essentials
- ``NetworkClient``
- ``HTTPRequest``
- ``HTTPResponse``

### Configuration
- <doc:ClientConfiguration>
- <doc:MiddlewareOverview>
```

### DocC Migration Guide Structure (DOC-03)

```markdown
# Migrating to Networking

Migrate from URLSession, Alamofire, or other networking frameworks.

## Overview

This guide covers migration patterns from common networking solutions to Networking.

## From URLSession

### Before (URLSession)
```swift
let (data, response) = try await URLSession.shared.data(from: url)
```

### After (Networking)
```swift
let response = try await client.execute {
    GET("/endpoint")
}
```

## From Alamofire

[Migration examples...]

## Topics

### Migration Guides
- <doc:URLSessionMigration>
- <doc:AlamofireMigration>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| XCTest completion handlers | Swift Testing `@Test` + async | Swift 5.9+ / 2024 | Simpler async tests |
| Manual mock classes | Actor-based MockNetworkClient | Swift 6 / 2024 | Thread-safe mocking |
| Separate doc files | DocC integrated catalog | Xcode 13+ / 2022 | Symbol linking, versioning |
| SwiftSyntaxMacrosTestSupport | MacroTesting library | 2023 | Cleaner assertion API |

**Current ecosystem notes:**
- Swift Testing framework is stable and recommended for new tests
- Quick 7.4+ has full Swift 6 concurrency support
- Nimble 13+ has async matchers (`expect(...).toEventually(...)`)
- DocC supports article organization and cross-symbol linking

## Open Questions

1. **Sequential vs Parallel Mock Expectations**
   - What we know: Current MockDSL matches first-fit, not sequential
   - What's unclear: Best API design for ordered vs unordered expectations
   - Recommendation: Implement separate `SequentialMock` wrapper, keep existing `NetworkingMock` for unordered

2. **Property Test Coverage Completeness**
   - What we know: Retry backoff and interceptor chain have property tests
   - What's unclear: Which other algorithms warrant property testing
   - Recommendation: Add property tests for rate limiting calculations, cache key generation

3. **DocC vs README Duplication**
   - What we know: DocC catalog has articles, root has separate README
   - What's unclear: How to avoid content duplication
   - Recommendation: Keep README minimal (installation only), link to DocC for content

## Sources

### Primary (HIGH confidence)
- Packages/Networking/Sources/Networking/Testing/MockDSL.swift - Existing DSL implementation
- Tests/NetworkingTests/PropertyTests/ - Existing property test patterns
- Tests/NetworkingTests/SimpleBDDTests.swift - Existing BDD pattern
- Documentation.docc/ - Existing documentation structure

### Secondary (MEDIUM confidence)
- https://github.com/typelift/SwiftCheck - SwiftCheck documentation
- https://quick.github.io/Quick/ - Quick/Nimble reference
- https://developer.apple.com/videos/play/wwdc2022/110368/ - DocC WWDC session

### Tertiary (LOW confidence)
- https://forums.swift.org/t/propertybased-easy-quickcheck-for-swift-testing-on-all-platforms/82222 - PropertyBased alternative (not using, but noted)

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH - Dependencies already in Package.swift, patterns established
- Architecture: HIGH - Extending existing patterns from codebase
- Pitfalls: HIGH - Based on actual code review and Swift 6 concurrency requirements

**Research date:** 2026-02-15
**Valid until:** 60 days (stable libraries, established patterns)
