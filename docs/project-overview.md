<!-- Generated: 2025-08-27 00:00:00 UTC -->

# ModernNetworking Project Overview

## Overview

ModernNetworking is a Swift 6 compliant networking framework designed for modern iOS, macOS, tvOS, and watchOS applications. The framework provides a comprehensive HTTP client implementation with async/await support, structured concurrency, and a powerful middleware system. Built on top of URLSession, it offers both a fluent DSL for request construction and Swift macro-generated API clients for type-safe networking.

The framework's core value proposition lies in its combination of Swift 6 strict concurrency compliance, middleware-driven architecture, and declarative request building patterns. It supports advanced features including authentication management, automatic retry mechanisms, response caching, circuit breakers, and comprehensive error handling while maintaining full thread safety and `Sendable` conformance throughout the API surface.

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

**Macro System**
- `Sources/NetworkingMacros/APIMacro.swift` - @API protocol generation macro
- `Sources/NetworkingMacros/HTTPMethodMacros.swift` - @GET, @POST, @PUT, @DELETE method macros
- `Sources/NetworkingMacros/ParameterMacros.swift` - @Path, @Query, @Body parameter macros

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