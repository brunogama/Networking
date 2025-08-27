# Changelog

All notable changes to Networking will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **BREAKING CHANGE**: Renamed package from `ModernNetworking` to `Networking`
  - Updated import statements from `import ModernNetworking` to `import Networking`
  - Updated Package.swift name from "ModernNetworking" to "Networking"
  - Updated all target names and module references
  - Updated all documentation and examples

### Added

#### Core Framework
- =� Complete Swift 6 networking framework with async/await URLSession integration
- <� Fluent DSL for request/response building with result builder patterns
- =' Comprehensive middleware architecture (authentication, retry, caching, logging)
- =� File transfer operations with real-time progress tracking
- =� Circuit breaker pattern for system resilience and fault tolerance
- <� Macro-based code generation for automatic API client creation

#### Security Implementation (OWASP Top 10 Compliance)
- = Header injection prevention with CRLF detection and sanitization
- =� Certificate pinning with custom validation and backup pin support
- = Secure token storage using iOS Keychain Services integration
-  Comprehensive input validation and output encoding for all user data
- =� Security headers enforcement (CSP, HSTS, X-Frame-Options, X-Content-Type-Options)
- L Removed insecure MD5/SHA1 algorithms from checksum operations (replaced with SHA-256)

#### Documentation & Developer Experience
- =� Complete DocC documentation catalog with 10+ comprehensive guides
- =� 100+ public APIs documented with triple-slash comments following Apple DocC standards
- <� API reference organized by functionality with extensive cross-references
- =� 150+ code examples with real-world usage patterns
- =� Architecture guides and best practices documentation
- >� Testing guides and mock implementation examples

#### Configuration & Middleware
- � Declarative client configuration DSL with 35+ configuration components
- = Advanced authentication middleware with automatic token refresh
- = Intelligent retry middleware with exponential backoff strategies
- =� Multi-level caching with TTL, policies, and storage backends
- =� Comprehensive metrics collection with performance tracking and alerting
- =R Request timing and observability middleware

#### Request Building & Processing
- <� Fluent request building with 20+ components (HTTP methods, headers, body, auth)
- = Response processing chain with transformers and validation
- =� Support for JSON, form data, and multipart body encoding
- <� Conditional request building with control flow support
- = Response transformation and validation pipelines

#### Advanced Features
- =� Real-time progress tracking with thread-safe OSAllocatedUnfairLock
- =� File transfer operations with checksum validation (SHA-256)
- =� Performance metrics and alerting system
- <� Validated responses with automatic error recovery strategies
- =
 Network observability with detailed request/response logging

### Fixed

#### Code Quality & Swift 6 Compliance
-  All SwiftLint violations resolved (line length, naming conventions)
- =' Refactored complex functions for better maintainability (NetworkClient.swift:167-244)
-  Ensured full Sendable protocol compliance for strict concurrency
- =� Fixed result builder syntax issues (removed invalid @Self attributes)
- >� Thread-safe operations using OSAllocatedUnfairLock throughout
- � Resolved all compiler warnings and build errors

#### Test Coverage & Validation
- >� Fixed hundreds of test compilation errors across all test files
-  Created comprehensive HeaderSecurityMiddlewareTests.swift (417 lines)
- = Implemented security test coverage for OWASP vulnerability patterns
- >� Added proper concurrency handling in progress tracking tests
-  All tests now pass with no warnings or errors

### Changed

#### Breaking Changes
- = Updated HTTPStatus initialization from raw values to static properties
- = Changed ResponseChain.decode() to require ResponseTransformer instead of Type
- = Updated BaseURL initialization to use non-throwing URL constructor
- = Modified HTTPMethod enum cases to lowercase (`.get`, `.post`, etc.)

#### Improvements
- � Enhanced error handling with actionable error information
- <� Improved API ergonomics with better type safety
- =� Better metrics collection with reduced performance overhead
- = Strengthened security validation throughout the framework
- =� Enhanced documentation coverage across all public APIs

### Developer Tools & Configuration

#### Project Setup
- =� Swift Package Manager configuration with async/await support
- =' SwiftLint configuration with comprehensive rules and baseline
- >� Pre-commit hooks for code quality enforcement (formatting, linting, tests)
- =� Swift formatting configuration (standard and Google styles)
- =� Git commit message template and conventional commit compliance
- =
 CommitLint configuration for conventional commit validation

#### Build & Testing
-  Swift 6 compiler flags with concurrency and data race checking
- >� Comprehensive test suite with macro testing support
- =' Build system optimizations for faster compilation
- =� Code coverage reporting and quality gates

## Technical Specifications

### Platform Support
- iOS 16.0+
- macOS 13.0+
- tvOS 16.0+
- watchOS 9.0+
- Swift 6.0+

### Dependencies
- SwiftSyntax 600.0.0+ (for macro support)
- swift-macro-testing 0.5.2+ (for testing)

### Architecture
- Built with structured concurrency and actor isolation
- Middleware pipeline architecture for extensibility
- Type-safe configuration using result builders
- Compile-time API generation with Swift macros
- Thread-safe operations with modern Swift concurrency primitives

---

**Full Documentation**: See `Sources/ModernNetworking/ModernNetworking.docc/` for comprehensive guides and API reference.

**Migration Guide**: Refer to documentation for upgrading from previous networking solutions.

**Security**: This release includes comprehensive security hardening following OWASP Top 10 guidelines.
