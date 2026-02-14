/// # Networking Framework Test Utilities
///
/// This file provides access to testing utilities for the Networking framework.
/// These utilities help users write comprehensive tests for their networking code.
///
/// ## Available Testing Tools
///
/// - **MockURLProtocol**: URLProtocol-based mock for response stubbing
/// - **MockNetworkClient**: Expectation-based mock client for declarative testing
/// - **AsyncExpectation**: Testing utilities for async/await code
///
/// ## Usage Example
///
/// ```swift
/// import Networking
///
/// // Set up mock responses
/// MockURLProtocol.stub(
///   matching: .url("https://api.example.com/users"),
///   response: .success(statusCode: 200, data: userData)
/// )
///
/// // Use mock client
/// let mockClient = MockNetworkClient()
/// mockClient.expectGET("/users")
///   .andReturn(.success(statusCode: 200, data: userData))
///   .once()
/// ```
///
/// Created by: Networking Framework
/// Swift Version: 6.0

import Foundation

#if DEBUG || TESTING || TEST

// MARK: - Testing Support

/// Indicates whether testing utilities are available
public let isTestingSupportEnabled = true

/// Testing utilities namespace
public enum NetworkingTestUtilities {
  /// Framework version for testing utilities
  public static let version = "1.0.0"

  /// Available testing tools
  public static let availableTools = [
    "MockURLProtocol",
    "MockNetworkClient",
    "AsyncExpectation",
    "Swift Testing Integration",
  ]
}

// MARK: - Async Testing Support

/// Expectation for async/await testing
///
/// - Note: `@unchecked Sendable` justification:
///   Mutable state (`isFulfilled`) is protected by an internal `NSLock`.
///   All access is synchronized through this lock.
public final class AsyncExpectation: @unchecked Sendable {
  private let description: String
  private var isFulfilled = false
  private let lock = NSLock()

  public init(_ description: String) {
    self.description = description
  }

  public func fulfill() {
    lock.withLock {
      isFulfilled = true
    }
  }

  public var isFullfilled: Bool {
    lock.withLock { isFulfilled }
  }
}

#else

// MARK: - Production Build

/// Testing utilities are not available in production builds
public let isTestingSupportEnabled = false

#endif
