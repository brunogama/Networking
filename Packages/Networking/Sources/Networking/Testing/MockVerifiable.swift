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
/// ## Usage Example
/// ```swift
/// let mock = MockBearerTokenProvider()
/// mock.stubToken("test-token")
/// _ = try await mock.getCurrentToken()
/// try mock.verifyCalledOnce()
/// ```
///
/// ## Implementation Pattern
/// ```swift
/// public final class MockBearerTokenProvider: BearerTokenProvider, MockVerifiable, @unchecked Sendable {
///   private let queue = DispatchQueue(label: "mock.token.provider", attributes: .concurrent)
///   private var _callCount: Int = 0
///
///   public var callCount: Int {
///     queue.sync { _callCount }
///   }
///
///   public func getCurrentToken() async throws -> String? {
///     queue.sync(flags: .barrier) { _callCount += 1 }
///     // ...
///   }
/// }
/// ```
public protocol MockVerifiable {
  /// Total number of calls made to this mock
  ///
  /// Implementations must ensure thread-safe access to call count tracking.
  /// Use DispatchQueue with concurrent reads and barrier writes.
  var callCount: Int { get }
}

// MARK: - Default Verification Methods

extension MockVerifiable {
  /// Verify that the mock was called exactly once
  ///
  /// - Throws: `MockError.unexpectedCallCount` if call count is not 1
  public func verifyCalledOnce() throws {
    try verifyCalledExactly(1)
  }

  /// Verify that the mock was called an exact number of times
  ///
  /// - Parameter times: Expected number of calls
  /// - Throws: `MockError.unexpectedCallCount` if actual count doesn't match
  public func verifyCalledExactly(_ times: Int) throws {
    let actual = callCount
    guard actual == times else {
      throw MockError.unexpectedCallCount(expected: times, actual: actual)
    }
  }

  /// Verify that the mock was never called
  ///
  /// - Throws: `MockError.unexpectedCallCount` if call count is not 0
  public func verifyNeverCalled() throws {
    try verifyCalledExactly(0)
  }

  /// Verify that the mock was called at least a minimum number of times
  ///
  /// - Parameter times: Minimum expected number of calls
  /// - Throws: `MockError.unexpectedCallCount` if actual count is less than minimum
  public func verifyCalledAtLeast(_ times: Int) throws {
    let actual = callCount
    guard actual >= times else {
      throw MockError.unexpectedCallCount(expected: times, actual: actual)
    }
  }
}
