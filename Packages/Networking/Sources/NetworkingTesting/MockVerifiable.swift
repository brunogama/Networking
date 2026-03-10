import NetworkingRuntime
import NetworkingInterceptorsCompat
import NetworkingObservability
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Error types for mock verification failures
///
/// Provides structured error reporting for mock expectations and stubbing issues.
public enum MockError: Error, Equatable, CustomStringConvertible {
  /// Thrown when a stubbed value is required but not set
  case notStubbed(String)

  /// Thrown when verification fails due to unexpected call count
  case unexpectedCallCount(expected: Int, actual: Int)

  /// Thrown when a mock receives an argument it doesn't expect
  case unexpectedArgument(description: String)

  public var description: String {
    switch self {
    case .notStubbed(let message):
      return "Not stubbed: \(message)"

    case .unexpectedCallCount(let expected, let actual):
      return "Expected \(expected) call(s), but got \(actual)"

    case .unexpectedArgument(let description):
      return "Unexpected argument: \(description)"
    }
  }
}

/// Protocol for verifiable mock objects
///
/// Provides shared verification methods for all mock implementations.
/// Mocks conforming to this protocol can use default verification methods
/// via protocol extensions.
///
/// ## Usage Example (Class-based Mock)
/// ```swift
/// let mock = MockBearerTokenProvider()
/// mock.stubToken("test-token")
/// _ = try await mock.getCurrentToken()
/// try await mock.verifyCalledOnce()
/// ```
///
/// ## Usage Example (Actor-based Mock)
/// ```swift
/// let mock = MockCacheStorage()
/// await mock.stub(key: "test", entry: entry)
/// try await mock.verifyCalledOnce()
/// ```
///
/// ## Implementation Pattern (Class-based)
/// ```swift
/// public final class MockBearerTokenProvider: BearerTokenProvider, MockVerifiable, @unchecked Sendable {
///   private let queue = DispatchQueue(label: "mock.token.provider", attributes: .concurrent)
///   private var _callCount: Int = 0
///
///   nonisolated public var callCount: Int {
///     get async { queue.sync { _callCount } }
///   }
///
///   public func getCurrentToken() async throws -> String? {
///     queue.sync(flags: .barrier) { _callCount += 1 }
///     // ...
///   }
/// }
/// ```
///
/// ## Implementation Pattern (Actor-based)
/// ```swift
/// public actor MockCacheStorage: CachingMiddleware.CacheStorage, MockVerifiable {
///   private var getCalls: [String] = []
///
///   nonisolated public var callCount: Int {
///     get async { await getCalls.count }
///   }
/// }
/// ```
public protocol MockVerifiable {
  /// Total number of calls made to this mock
  ///
  /// Implementations must ensure thread-safe access to call count tracking.
  /// - For class-based mocks: Use DispatchQueue with concurrent reads, return via `get async`
  /// - For actor-based mocks: Use `nonisolated` with `get async` to expose actor state safely
  ///
  /// - Note: All implementations should use `get async` for Swift 6 concurrency compliance
  var callCount: Int { get async }
}

// MARK: - Default Verification Methods (Async)

extension MockVerifiable {
  /// Verify that the mock was called exactly once
  ///
  /// - Throws: `MockError.unexpectedCallCount` if call count is not 1
  public func verifyCalledOnce() async throws {
    try await verifyCalledExactly(1)
  }

  /// Verify that the mock was called an exact number of times
  ///
  /// - Parameter times: Expected number of calls
  /// - Throws: `MockError.unexpectedCallCount` if actual count doesn't match
  public func verifyCalledExactly(_ times: Int) async throws {
    let actual = await callCount
    guard actual == times else {
      throw MockError.unexpectedCallCount(expected: times, actual: actual)
    }
  }

  /// Verify that the mock was never called
  ///
  /// - Throws: `MockError.unexpectedCallCount` if call count is not 0
  public func verifyNeverCalled() async throws {
    try await verifyCalledExactly(0)
  }

  /// Verify that the mock was called at least a minimum number of times
  ///
  /// - Parameter times: Minimum expected number of calls
  /// - Throws: `MockError.unexpectedCallCount` if actual count is less than minimum
  public func verifyCalledAtLeast(_ times: Int) async throws {
    let actual = await callCount
    guard actual >= times else {
      throw MockError.unexpectedCallCount(expected: times, actual: actual)
    }
  }
}
