# Proposal: Add Request/Response Interceptors to Macro System

## Change ID

`add-request-response-interceptors`

## Overview

Implement a request/response interceptor system that allows developers to define reusable middleware components for cross-cutting concerns like authentication, logging, retry logic, and caching. Interceptors execute before/after HTTP requests in macro-generated API clients, providing clean separation of concerns and eliminating repetitive boilerplate code.

## Why

### Current State (Phase 5.2)

Developers using the macro-generated API clients must manually implement cross-cutting concerns in every endpoint:

```swift
@API(baseURL: "https://api.example.com")
protocol UserAPI {
  @GET("/users/{id}")
  func getUser(id: String) async throws -> User
}

// Usage requires manual auth, logging, retry logic
let client = UserAPIImplementation()
// No built-in way to add authentication tokens
// No built-in way to log requests/responses
// No built-in way to retry failed requests
// No built-in way to cache responses
let user = try await client.getUser(id: "123")
```

### Problems

1. **Boilerplate Explosion**: Every API client needs manual auth header injection, logging, and error handling
2. **No Reusability**: Common patterns (token refresh, retry with backoff) must be reimplemented per client
3. **Poor Separation of Concerns**: Business logic mixed with cross-cutting concerns
4. **Testing Complexity**: Mocking auth/logging/retry behavior requires complex test setup
5. **Inconsistent Behavior**: Different clients handle auth/logging differently

### Proposed Solution

Add a declarative interceptor system integrated with the macro framework:

```swift
@API(baseURL: "https://api.example.com")
@Interceptors([
  AuthenticationInterceptor(tokenProvider: .shared),
  LoggingInterceptor(),
  RetryInterceptor(maxAttempts: 3)
])
protocol UserAPI {
  @GET("/users/{id}")
  func getUser(id: String) async throws -> User
}

// Usage is clean - interceptors handle auth, logging, retry automatically
let client = UserAPIImplementation()
let user = try await client.getUser(id: "123")
// ✅ Authentication header added automatically
// ✅ Request/response logged automatically
// ✅ Retries on failure with exponential backoff
```

### Benefits

1. **80% Reduction in Boilerplate**: Auth/logging/retry code written once, applied everywhere
2. **Composable Middleware**: Mix and match interceptors per API client
3. **Testable**: Mock interceptors easily for unit tests
4. **Consistent Behavior**: All API clients use same auth/logging/retry patterns
5. **Type-Safe**: Interceptor chain validated at compile-time
6. **Swift 6 Compliant**: All interceptors are Sendable with structured concurrency

## Impact Assessment

### Dependencies

- **Requires**: Phase 5.2 (Custom Headers Support) - interceptors need to modify request headers
- **Blocks**: None - this is an additive feature
- **Related**: `add-api-client-macros` (Change ID from Phase 1-5)

### Affected Components

#### New Components (This Change)

- `Sources/Networking/Interceptors/` - Public interceptor protocols and execution chain
- `Sources/NetworkingMacros/Interceptors/` - Macro implementation for @Interceptors annotation
- `Tests/NetworkingTests/Interceptors/` - Comprehensive test suite for interceptor logic

#### Modified Components

- `Sources/NetworkingMacros/API/APIMacro.swift` - Add interceptor chain initialization
- `Sources/NetworkingMacros/HTTP/*.swift` - Inject interceptor hooks in all HTTP method macros

#### No Changes Required

- Existing public API remains unchanged
- All 83 existing macro tests continue to pass
- Zero breaking changes for Phase 5.2 users

### Backward Compatibility

**100% Backward Compatible**

- Interceptors are opt-in via `@Interceptors` annotation
- Existing code without `@Interceptors` works identically to Phase 5.2
- No changes to HTTPRequest, NetworkClient, or core framework APIs
- All existing tests pass without modification

### Migration Path

No migration required - this is a pure additive feature:

```swift
// Phase 5.2 code (still works identically)
@API(baseURL: "https://api.example.com")
protocol OldAPI {
  @GET("/data")
  func getData() async throws -> Data
}

// Phase 6 code (opt-in to interceptors)
@API(baseURL: "https://api.example.com")
@Interceptors([LoggingInterceptor()])
protocol NewAPI {
  @GET("/data")
  func getData() async throws -> Data
}
```

## Technical Scope

### Phase 6.1: Core Infrastructure (Week 1)

- Define `RequestInterceptor` and `ResponseInterceptor` protocols
- Implement `InterceptorChain` sequential execution engine
- Create `InterceptorContext`, `InterceptorResult`, and `InterceptorError` types
- Unit tests for chain execution, short-circuit, retry logic

### Phase 6.2: Macro Integration (Week 2)

- Implement `@Interceptors` macro annotation
- Modify `APIMacro` to generate interceptor chain initialization
- Update all HTTP method macros to inject interceptor hooks
- Integration tests with macro-generated API clients

### Phase 6.3: Common Implementations (Week 3)

- Production-ready interceptor examples:
  - `AuthenticationInterceptor` - Bearer token injection
  - `LoggingInterceptor` - Request/response logging
  - `TokenRefreshInterceptor` - Auto-refresh on 401
  - `CachingInterceptor` - Cache GET responses
  - `RetryInterceptor` - Exponential backoff retry
  - `RateLimitInterceptor` - Request rate limiting

### Phase 6.4: Polish & Documentation (Week 4)

- Conditional interceptors (path patterns, HTTP method filters)
- Performance optimization (fast-path for zero interceptors)
- Comprehensive DocC documentation
- Example app demonstrating patterns

## Success Metrics

- **Code Reduction**: 80% reduction in auth/logging boilerplate
- **Build Time**: <2s additional macro expansion overhead
- **Runtime Overhead**: <1ms per interceptor
- **Test Coverage**: 90% of interceptor chain and macro code
- **Developer Satisfaction**: 95%+ positive feedback on interceptor API
- **All Tests Passing**: 100% of existing 83 macro tests + new interceptor tests

## Timeline

- **Week 1**: Phase 6.1 (Core infrastructure)
- **Week 2**: Phase 6.2 (Macro integration)
- **Week 3**: Phase 6.3 (Common implementations)
- **Week 4**: Phase 6.4 (Polish & documentation)

**Total Duration**: 4 weeks

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Macro complexity explosion | Medium | High | Keep interceptor logic in runtime code, macro only generates chain initialization |
| Performance regression | Medium | Medium | Benchmark every phase, fast-path for zero interceptors |
| Swift 6 concurrency issues | Low | High | All interceptors marked Sendable, comprehensive concurrency tests |
| Breaking changes | Low | High | Interceptors are opt-in, existing code unchanged |

## Approval Checklist

- [x] Reviewed by project maintainers
- [x] Constitution compliance verified (Swift 6, testing, security, SOLID)
- [x] Backward compatibility confirmed
- [x] Test strategy approved
- [x] Timeline accepted
- [x] Risk mitigation plans reviewed

## Approval Status

**Status**: APPROVED
**Approved Date**: 2025-11-02
**Approved By**: Project Owner
