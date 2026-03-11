import Foundation

// MARK: - Enhanced Recovery Context (PRP Specification)

extension HTTPError {
  public var recoverySuggestion: String? {
    recoverySuggestions.first?.rawValue
  }

  public var isRetryable: RetryDecision {
    RetryDecision(isTransientError.rawValue)
  }

  public var actionableInfo: ActionableErrorInfo {
    ActionableErrorInfo.analyze(self)
  }

  public func actionableInfo(
    with context: ActionableErrorInfo.ErrorContext
  ) -> ActionableErrorInfo {
    ActionableErrorInfo.analyze(self, context: context)
  }

  public var retryAfter: RetryDelay? {
    switch recoveryCategory {
    case .retryable:
      return NetworkingConfiguration.RetryDelays.immediate

    case .retryableWithDelay:
      switch category {
      case .network(.connectionLost):
        return NetworkingConfiguration.RetryDelays.connectionLost
      case .network(.serverUnreachable):
        return NetworkingConfiguration.RetryDelays.serverUnreachable
      case .http(let status) where status.rawValue == 429:
        return NetworkingConfiguration.RetryDelays.rateLimiting
      case .http(let status) where 500...503 ~= status.rawValue:
        return NetworkingConfiguration.RetryDelays.serverError
      case .timeout:
        return NetworkingConfiguration.RetryDelays.timeout
      default:
        return NetworkingConfiguration.RetryDelays.default
      }

    case .userActionRequired, .nonRecoverable:
      return nil
    }
  }
}
