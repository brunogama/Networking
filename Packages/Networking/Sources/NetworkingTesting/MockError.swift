import NetworkingCore

/// Error types for mock verification failures.
///
/// Provides structured error reporting for mock expectations and stubbing issues.
public enum MockError: Error, Equatable, CustomStringConvertible {

  case notStubbed(ExpectationDescriptionText)

  case unexpectedCallCount(expected: MockVerificationCount, actual: MockVerificationCount)

  case unexpectedArgument(description: ExpectationDescriptionText)

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
