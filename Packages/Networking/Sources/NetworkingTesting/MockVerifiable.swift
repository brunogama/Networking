import NetworkingCore

/// Exposes a concurrency-safe call count for common verification operations.
public protocol MockVerifiable: Sendable {

  var callCount: MockVerificationCount { get async }
}

// MARK: - Default Verification Methods (Async)

extension MockVerifiable {

  public func verifyCalledOnce() async throws {
    try await verifyCalledExactly(1)
  }

  public func verifyCalledExactly(_ times: MockVerificationCount) async throws {
    let actual = await callCount
    guard actual == times else {
      throw MockError.unexpectedCallCount(expected: times, actual: actual)
    }
  }

  public func verifyNeverCalled() async throws {
    try await verifyCalledExactly(0)
  }

  public func verifyCalledAtLeast(_ times: MockVerificationCount) async throws {
    let actual = await callCount
    guard actual >= times else {
      throw MockError.unexpectedCallCount(expected: times, actual: actual)
    }
  }
}
