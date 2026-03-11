# API Reference

Complete reference for all public APIs in Networking.

## Overview

This comprehensive API reference covers all public types, protocols, and functions available in Networking, organized by functionality.

`Networking` re-exports the split package graph for compatibility. Advanced users can depend on
smaller modules directly when they want tighter package boundaries.

## Package Layout

- `NetworkingCore`: HTTP primitives and foundational contracts
- `NetworkingRuntime`: concrete runtime and middleware implementations
- `NetworkingDSL`: request/response composition APIs
- `NetworkingRuntimeDSL`: runtime-to-DSL bridge conveniences
- `NetworkingObservability`: generic observability interfaces and middleware
- `NetworkingObservabilityOTLP`: OTLP exporters and configuration
- `NetworkingTesting`: mocks, fakes, and testing helpers
- `NetworkingInterceptorsCompat`: compatibility-only interceptor APIs

## Core Networking Types

### HTTPClient Protocol

The fundamental protocol for executing HTTP requests.

- ``HTTPClient``

### HTTP Primitives

Core types representing HTTP concepts:

- ``HTTPRequest``
- ``HTTPResponse`` 
- ``HTTPMethod``
- ``HTTPStatus``
- ``HTTPError``

## Client Implementation

### NetworkClient

The main HTTP client implementation:

- ``NetworkClient``
- ``NetworkClientBuilder``

### Configuration Components

Client configuration using the declarative DSL:

#### Basic Configuration
- ``ClientBaseURL``
- ``DefaultTimeout``
- ``DefaultHeader``
- ``CustomSession``

#### Authentication Configuration  
- ``Authentication``
- ``AuthenticationConfiguration``
- ``AuthenticationStrategy``
- ``AuthRefreshStrategy``
- ``BearerTokenProvider``
- ``CustomAuthProvider``
- ``BearerToken``
- ``ClientBasicAuth``
- ``CustomAuth``
- ``StaticTokenProvider``
- ``ClosureBearerTokenProvider``

#### Retry Configuration
- ``Retry``
- ``RetryConfiguration``
- ``RetryBackoffStrategy``
- ``MaxAttempts``
- ``BackoffStrategyComponent``
- ``InitialDelay``
- ``RetryWhen``

#### Caching Configuration
- ``Caching``
- ``CachingConfiguration``
- ``CachingPolicy``
- ``CacheStorage``
- ``StorageSize``
- ``CacheDuration``
- ``Policy``
- ``Storage``
- ``Duration``
- ``CacheWhen``

#### Session Configuration
- ``Session``
- ``SessionConfiguration``
- ``SessionTimeout``
- ``AllowsCellular``
- ``AllowsExpensiveNetworkAccess``
- ``AllowsConstrainedNetworkAccess``
- ``WaitsForConnectivity``
- ``MaxConnectionsPerHost``
- ``RequestCachePolicy``

#### Security Configuration
- ``EnableSecurity``
- ``SecurityConfiguration``

## Request Building

### Request Builder

Fluent API for constructing HTTP requests:

- ``RequestBuilder``
- ``RequestComponent``

### HTTP Method Components

Components for specifying HTTP methods:

- ``GET``
- ``POST`` 
- ``PUT``
- ``DELETE``

### Request Components

Components for building request details:

#### URL and Path Components
- ``RequestBaseURL``

#### Header Components  
- ``Header``
- ``ContentType``
- ``AcceptHeader``
- ``UserAgent``

#### Authentication Components
- ``BearerAuth``
- ``RequestBasicAuth``
- ``APIKey``

#### Body Components
- ``JSONBody``
- ``DataBody``
- ``FormBody``

#### Query and Parameter Components
- ``QueryParam``
- ``RequestQueryParam``
- ``QueryParams``

#### Conditional Components
- ``ConditionalComponent``
- ``if(_:_:)``
- ``EnvironmentAware``
- ``SwitchComponent``

#### Cache Control Components  
- ``CacheControl``
- ``IfNoneMatch``
- ``IfModifiedSince``

#### Utility Components
- ``Timeout``
- ``RequestTimeout``
- ``EmptyComponent``
- ``CompositeComponent``

### Request Extensions

Extensions providing additional functionality:

- Request combination operators (`+`, `|>`)
- Fluent chaining support

## Response Processing

### Response Transformation

Transform and process HTTP responses:

- ``ResponseTransformationPipeline``
- ``ChainedTransformationPipeline``
- ``AsyncResponseTransformer``
- ``SyncResponseTransformer``
- ``AsyncTransformerAdapter``
- ``AsyncTransformationChain``

### Built-in Transformers

Pre-built transformation components:

- ``AsyncJSONDecoderTransformer``
- ``AsyncImageDecoderTransformer``
- ``HTTPResponseToDataPipeline``
- ``AsyncTransformerPipeline``

### Response Validation

Validate responses with structured validation:

- ``ValidatedResponseProtocol``
- ``ValidatedResponse``
- ``SuccessValidatedResponse``
- ``ContentTypeValidatedResponse``
- ``MultiValidatedResponse``
- ``StatusCodeValidationMiddleware``
- ``ContentTypeValidationMiddleware``

## Middleware System

### Middleware Protocols

Core middleware interfaces:

- ``HTTPRequestMiddleware``
- ``HTTPResponseMiddleware``
- ``HTTPErrorMiddleware``

### Built-in Middleware

Production-ready middleware implementations:

#### Authentication
- ``AuthenticationMiddleware``

#### Logging
- ``LoggingMiddleware``

#### Retry Logic
- ``RetryMiddleware``

#### Caching
- ``CachingMiddleware``

#### Security
- ``HeaderSecurityMiddleware``

#### Observability
- ``NetworkObservabilityMiddleware``
- ``RequestTimingMiddleware``
- ``ProgressTrackingMiddleware``

#### Circuit Breaker
- ``CircuitBreakerMiddleware``

## Security Features

### SSL Pinning and Certificate Validation

Security components for protecting network communications:

- ``SecurityConfiguration``
- ``HeaderSecurityMiddleware``

### Keychain Integration

Secure credential storage:

- ``KeychainService``

### Security Headers

HTTP security header management:

- ``HeaderSecurity``

## Progress Tracking

Monitor upload and download progress:

- ``ProgressTracking``
- ``TransferControls``

## File Transfer Operations

Handle file uploads and downloads:

- ``FileTransferOperations``

## Caching System

### Cache Storage Providers

Different caching backend implementations:

- ``CacheStorageProviders``
- ``CachePolicy``
- ``CacheSizePolicy``
- ``ExpirationStrategy``
- ``CacheMetrics``

## Metrics and Observability

### Metrics Collection

Collect and report networking metrics:

- ``MetricsCollector``

## Error Handling

### Error Types and Recovery

Comprehensive error handling and recovery:

- ``HTTPError``
- ``ErrorRecoveryStrategies``
- ``ActionableErrorInfo``
- ``CircuitBreakerError``

## Generated API Clients

### Macro Declarations

Macros for generating type-safe API clients:

#### API Generation
- ``@API(baseURL:)``

#### HTTP Methods
- ``@GET(_:)``
- ``@POST(_:)``
- ``@PUT(_:)``
- ``@DELETE(_:)``

#### Parameters
- ``@Path(_:)``
- ``@Query(_:)``
- ``@Body()``
- ``@Header(_:)``

#### Caching
- ``@Cacheable(ttl:tags:key:)``
- ``@CacheInvalidation(tags:pattern:keys:)``

## Type Aliases and Utilities

### Common Type Aliases

Convenient type aliases for common use cases:

- ``HTTPResult``

### Framework Information

Version and compatibility information:

- ``Networking``
  - `version`: Framework version string
  - `swiftVersion`: Required Swift version

## Configuration Protocols

### Base Configuration Protocols

Protocols for configuration components:

- ``ConfigurationComponent``
- ``AuthenticationComponent`` 
- ``RetryComponent``
- ``CachingComponent``
- ``SessionComponent``

## Extensions and Utilities

### Foundation Extensions

Extensions to Foundation types:

- HTTPStatus extensions for semantic status checking
- URL extensions for request building
- Data extensions for response processing

### Swift Standard Library Extensions

Extensions providing additional functionality:

- Result type extensions for HTTP operations
- Optional extensions for safe unwrapping

## Sendable Compliance

All public APIs are designed with Swift 6 concurrency in mind:

- All public types conform to `Sendable` where appropriate
- Actor-based isolation for mutable shared state
- Structured concurrency support throughout
- Thread-safe access patterns

## Deprecated APIs

### Migration Guide

Compatibility guidance for the split architecture:

- `Networking` remains the primary consumer-facing import during the migration
- Prefer `HTTPRequestMiddleware`, `HTTPResponseMiddleware`, and `HTTPErrorMiddleware` for new
  runtime extensibility work
- Treat `NetworkingInterceptorsCompat` as compatibility-only for legacy interceptor pipelines
- Use `NetworkingTesting` for fakes, mocks, and `MockURLProtocol` instead of widening public API
- See <doc:Module-Migration> for direct module dependency guidance

## Platform Availability

### Supported Platforms

Framework availability across Apple platforms:

- iOS 13.0+
- macOS 10.15+  
- tvOS 13.0+
- watchOS 6.0+

### Swift Compatibility

- Swift 5.9+ required
- Swift 6 compliant
- Xcode 15.0+ required

## Related Documentation

### Guides and Tutorials

- <doc:Getting-Started>: Basic usage and setup
- <doc:Client-Configuration>: Complete configuration guide  
- <doc:Middleware-Guide>: Custom middleware development
- <doc:Security-Features>: Security implementation guide

### Core Concepts

- <doc:Core-Networking>: Fundamental networking concepts
- <doc:Request-Building>: Request construction patterns
- <doc:Response-Processing>: Response handling strategies
- <doc:Error-Handling>: Error management approaches
