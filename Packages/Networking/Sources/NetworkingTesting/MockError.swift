import NetworkingCore

/// Error types for mock verification failures.
///
/// Provides structured error reporting for mock expectations and stubbing issues.
public enum MockError: Error, Equatable, CustomStringConvertible {
  /// Thrown when a stubbed value is required but not set.
  case notStubbed(ExpectationDescriptionText)

  /// Thrown when verification fails due to unexpected call count.
  case unexpectedCallCount(expected: MockVerificationCount, actual: MockVerificationCount)

  /// Thrown when a mock receives an argument it doesn't expect.
  case unexpectedArgument(description: ExpectationDescriptionText)

  /// Describes the failed mock expectation.
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
