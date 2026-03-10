import NetworkingRuntime
import NetworkingInterceptorsCompat
import NetworkingObservability
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Networking Mocks

/*
 # Networking Mocks

 This module provides mock implementations for all major Networking protocols.
 All mocks conform to `MockVerifiable` for consistent verification.

 ## Available Mocks

 ### Core
 - `MockHTTPClient` (alias for `MockNetworkClient`)
 - `MockBearerTokenProvider`
 - `MockCustomAuthProvider`

 ### Middleware
 - `MockHTTPRequestMiddleware`
 - `MockHTTPResponseMiddleware`
 - `MockHTTPErrorMiddleware`

 ### Interceptors
 - `MockRequestInterceptor`
 - `MockResponseInterceptor`

 ### Infrastructure
 - `MockCacheStorage`
 - `MockTimeProvider`
 - `MockMetricsCollector`
 - `MockTraceExporter`

 ## Usage

 ```swift
 import Networking

 // Core HTTP client mocking
 let mockClient = MockHTTPClient()
 mockClient.expectGET("/users").andReturnJSON(users)

 // Authentication mocking
 let mockTokenProvider = MockBearerTokenProvider()
 mockTokenProvider.stubToken("test-token")

 // Middleware mocking
 let mockMiddleware = MockHTTPRequestMiddleware()
 mockMiddleware.stubRequestTransform { request in
   var modified = request
   modified.headers["X-Test"] = "value"
   return modified
 }

 // Infrastructure mocking
 let mockCache = MockCacheStorage()
 let mockMetrics = MockMetricsCollector()
 let mockTracer = MockTraceExporter()
 ```

 ## Verification

 All mocks implement `MockVerifiable` with common verification methods:

 ```swift
 // Verify call counts
 try mock.verifyCalledOnce()
 try mock.verifyCalledExactly(3)
 try mock.verifyNeverCalled()
 try mock.verifyCalledAtLeast(1)

 // Mock-specific verification
 try await mockMetrics.verifyEventRecorded { event in
   if case .requestStarted = event { return true }
   return false
 }

 try await mockTracer.verifySpanExported(withName: "GET /users")
 ```
 */

// MARK: - Type Aliases

/// Typealias for `MockNetworkClient` conforming to `HTTPClient`.
/// Use this name when mocking the `HTTPClient` protocol in tests.
///
/// ## Example
/// ```swift
/// let mockClient = MockHTTPClient()
/// mockClient.expectGET("/users").andReturnJSON(users)
///
/// let response = try await mockClient.execute(request)
/// try mockClient.verifyCalledOnce()
/// ```
public typealias MockHTTPClient = MockNetworkClient
