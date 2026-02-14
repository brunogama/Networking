# External Integrations

**Analysis Date:** 2026-02-14

## APIs & External Services

**Not Detected**

This is a library framework, not an application. The Networking library does not integrate with specific external APIs. Instead, it provides infrastructure for other applications to integrate with external services via:

- `NetworkClient` - Generic HTTP client for any REST API
- `GraphQLClient` - GraphQL endpoint integration support
- `HTTPRequest` builder - Configurable request construction
- Interceptor chain - Middleware for cross-cutting concerns (auth, logging, caching, retry)

Applications using this library would integrate external services themselves via the provided abstractions.

## Data Storage

**Databases:**
- Not applicable - This is a networking library, not an application

**File Storage:**
- Local filesystem only
  - File download/upload via `FileTransferOperations` (`Sources/Networking/FileTransferOperations.swift`)
  - Temporary file handling for multipart uploads
  - No cloud storage integrations

**Caching:**
- In-memory response cache
  - Implementation: `CachingMiddleware` (`Sources/Networking/CachingMiddleware.swift`)
  - Actor-protected `ResponseCache` for thread-safe access
  - RFC 7234 HTTP cache compliance
  - No external caching service (Redis, Memcached) required

## Authentication & Identity

**Auth Provider:**
- Custom implementation only
  - No OAuth2 provider integration
  - No OIDC integration
  - No third-party auth SDKs

**Auth Patterns Supported (via middleware):**
- Bearer Token authentication
  - Implementation: `AuthenticationMiddleware` (`Sources/Networking/AuthenticationMiddleware.swift`)
  - Supports token refresh via `TokenRefreshInterceptor`
  - Token storage: iOS Keychain via `KeychainService`

- Certificate Pinning
  - Implementation: `HeaderSecurityMiddleware` (`Sources/Networking/HeaderSecurityMiddleware.swift`)
  - Pins certificates to prevent MITM attacks

- Custom Headers
  - Added via request middleware
  - Validated for CRLF injection attacks (`HeaderSecurityMiddleware`)

**Keychain Integration (Platform-specific):**
- Framework: Security framework (iOS, macOS)
- Implementation: `KeychainService` (`Sources/Networking/KeychainService.swift`)
- Usage:
  - Stores authentication tokens securely
  - Accessible across app lifecycle
  - Supports keychain sharing via access groups
  - iCloud synchronization optional

## Monitoring & Observability

**Error Tracking:**
- Not detected - No built-in error tracking service integration

**Available for Integration:**
- Error information extraction via `ActionableErrorInfo` (`Sources/Networking/ActionableErrorInfo.swift`)
- Error categories: network, HTTP status, decoding, encoding, timeout, configuration
- Applications can integrate their own error tracking service

**Logging:**
- Built-in logging middleware
  - Implementation: `LoggingMiddleware` (`Sources/Networking/LoggingMiddleware.swift`)
  - Logs: Request/response details, timing, errors
  - Configurable log levels
  - No external logging service required

**Metrics & Monitoring:**
- Metrics collection via `MetricsCollector` (`Sources/Networking/MetricsCollector.swift`)
- Available metrics:
  - Request duration
  - Success/failure counts
  - Cache hit rates
  - Retry attempts
- In-memory metrics (no external service)

**Distributed Tracing:**
- Distributed tracing support via `DistributedTracing` (`Sources/Networking/DistributedTracing.swift`)
- W3C Trace Context header generation
- Correlation ID propagation
- Applications can integrate with external tracing systems (Jaeger, DataDog, etc.)

## CI/CD & Deployment

**Hosting:**
- Not applicable - This is a library (not hosted as service)
- Distributed via GitHub as Swift Package

**CI Pipeline:**
- GitHub Actions workflows (location: `.github/workflows/`)
  - Build matrix: iOS 16+, macOS 13+, tvOS 16+, watchOS 9+
  - Verification: format check, lint, build, test, coverage

**No External CI Services Detected**
- Builds and tests run locally with `swift build` and `swift test`
- Pre-commit hooks enforce quality gates locally

## Environment Configuration

**Required env vars:**
- None for library usage

**Optional env vars (application-level):**
- Applications using this library may set:
  - `API_BASE_URL` - Base URL for API endpoints (not enforced by library)
  - `AUTH_TOKEN` - Bearer token (application responsibility to set)
  - Other app-specific configuration

**Configuration Approach:**
- Builder pattern in `NetworkClient` (configuration DSL)
  - Location: `Sources/Networking/NetworkClient.swift`
  - Example: `NetworkClient { BaseURL(...); BearerAuth(...) }`

- Programmatic configuration via `NetworkingConfiguration` (`Sources/Networking/NetworkingConfiguration.swift`)

**Secrets Location:**
- Keychain (iOS/macOS) - Via `KeychainService` for sensitive tokens
- Environment variables - Application responsibility
- No .env file support built-in (applications should use own approach)

## Webhooks & Callbacks

**Incoming Webhooks:**
- Not applicable - This is a client library, not a server

**Outgoing Webhooks:**
- Not applicable - No built-in webhook client
- Applications can use `NetworkClient` to make webhook calls themselves

**Callback Patterns:**
- No callback-based APIs in library (Swift 6 async/await only)
- Middleware chains provide request/response transformation points
  - `HTTPRequestMiddleware` - Transform requests before sending
  - `HTTPResponseMiddleware` - Transform responses after receiving
  - `HTTPErrorMiddleware` - Handle errors and provide recovery strategies

## GraphQL Integration

**GraphQL Client:**
- Built-in GraphQL support
  - Implementation: `GraphQLClient` (`Sources/Networking/GraphQLClient.swift`)
  - Types: `GraphQLResponse`, `GraphQLError` (`Sources/Networking/GraphQLTypes.swift`)
  - Supports queries, mutations, subscriptions
  - Automatic JSON encoding/decoding
  - No external GraphQL schema validation service

## WebSocket Support

**WebSocket Client:**
- WebSocket support available
  - Implementation: `WebSocketClient` (`Sources/Networking/WebSocketClient.swift`)
  - Message types: `WebSocketMessage` (`Sources/Networking/WebSocketMessage.swift`)
  - Sends and receives WebSocket frames
  - No specific WebSocket service integration (uses standard WebSocket protocol)

## Batch Operations

**Batch Request Support:**
- Available via `BatchOperations` (`Sources/Networking/BatchOperations.swift`)
- Combines multiple HTTP requests
- Supports parallel and sequential execution
- No external batch processing service

## Advanced Features

**Circuit Breaker:**
- Implementation: `CircuitBreakerMiddleware` (`Sources/Networking/CircuitBreakerMiddleware.swift`)
- Prevents cascading failures
- Configurable thresholds and timeout
- Local state management (no external circuit breaker service)

**Rate Limiting:**
- Rate limit handling via retry strategies
- Interceptor for rate limit headers
- Local rate limit enforcement (no external service)

**Request Composition:**
- Operator overloading for request building
  - Implementation: `RequestCompositionOperators` (`Sources/Networking/RequestCompositionOperators.swift`)
  - Fluent API for complex requests

**Network Actor:**
- Actor-based concurrent request execution
  - Implementation: `NetworkActor` (`Sources/Networking/NetworkActor.swift`)
  - Thread-safe request queuing
  - Isolation of mutable network state

## Platform-Specific Integrations

**iOS/macOS:**
- Keychain integration via Security framework
- URLSession native integration
- File transfer with resume support

**Linux:**
- FoundationNetworking for HTTP compatibility
- No Keychain support (uses alternative secure storage)

**tvOS/watchOS:**
- Limited Keychain support
- URLSession integration for resource-constrained environments

## No Third-Party Service Dependencies

This library does **not** require or depend on:
- Cloud storage services (AWS S3, Google Cloud Storage, Azure Blob)
- CDN services
- API management platforms
- Authentication services (Auth0, Okta, Firebase Auth)
- Error tracking services (Sentry, Rollbar, Crashlytics)
- APM services (DataDog, New Relic, Splunk)
- Message queues or event buses
- Database servers
- Cache servers (Redis, Memcached)

All infrastructure is application-specific and managed by consuming applications.

---

*Integration audit: 2026-02-14*
