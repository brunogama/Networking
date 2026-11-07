import NetworkingCore

/// Exposes a concurrency-safe call count for common verification operations.
public protocol MockVerifiable: Sendable {
  /// The number of calls represented by this test double.
  var callCount: MockVerificationCount { get async }
}

// MARK: - Default Verification Methods (Async)

extension MockVerifiable {
  /// Verify that the mock was called exactly once.
  ///
  /// - Throws: `MockError.unexpectedCallCount` if call count is not 1
  public func verifyCalledOnce() async throws {
    try await verifyCalledExactly(1)
  }

  /// Verify that the mock was called an exact number of times.
  ///
  /// - Parameter times: Expected number of calls
  /// - Throws: `MockError.unexpectedCallCount` if actual count doesn't match
  public func verifyCalledExactly(_ times: MockVerificationCount) async throws {
    let actual = await callCount
    guard actual == times else {
      throw MockError.unexpectedCallCount(expected: times, actual: actual)
    }
  }

  /// Verify that the mock was never called.
  ///
  /// - Throws: `MockError.unexpectedCallCount` if call count is not 0
  public func verifyNeverCalled() async throws {
    try await verifyCalledExactly(0)
  }

  /// Verify that the mock was called at least a minimum number of times.
  ///
  /// - Parameter times: Minimum expected number of calls
  /// - Throws: `MockError.unexpectedCallCount` if actual count is less than minimum
  public func verifyCalledAtLeast(_ times: MockVerificationCount) async throws {
    let actual = await callCount
    guard actual >= times else {
      throw MockError.unexpectedCallCount(expected: times, actual: actual)
    }
  }
}
