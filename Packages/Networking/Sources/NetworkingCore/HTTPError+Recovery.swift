import Foundation

// MARK: - Error Analysis and Recovery

extension HTTPError {
  public var severity: ErrorSeverity {
    switch category {
    case .network(let networkError):
      switch networkError {
      case .noConnection, .connectionLost:
        return .high
      case .dnsFailure, .serverUnreachable:
        return .medium
      case .sslError:
        return .critical
      }

    case .http(let status):
      switch status.rawValue {
      case 400...499:
        return status.rawValue == 401 || status.rawValue == 403 ? .high : .medium
      case 500...599:
        return .high
      default:
        return .low
      }

    case .timeout:
      return .medium
    case .cancelled:
      return .low
    case .decoding, .encoding:
      return .medium
    case .configuration:
      return .critical
    case .custom(let type, _):
      return type.lowercased() == "security" ? .high : .medium
    }
  }

  public var recoveryCategory: RecoveryCategory {
    switch category {
    case .network(let networkError):
      switch networkError {
      case .noConnection, .connectionLost, .serverUnreachable:
        return .retryableWithDelay
      case .dnsFailure, .sslError:
        return .userActionRequired
      }

    case .http(let status):
      switch status.rawValue {
      case 401, 403:
        return .userActionRequired
      case 404:
        return .nonRecoverable
      case 408, 429, 500...503:
        return .retryableWithDelay
      case 504, 505...599:
        return .nonRecoverable
      default:
        return .retryable
      }

    case .timeout:
      return .retryableWithDelay
    case .cancelled:
      return .nonRecoverable
    case .decoding, .encoding:
      return .nonRecoverable
    case .configuration:
      return .userActionRequired
    case .custom(let type, _):
      return type.lowercased() == "security" ? .userActionRequired : .retryableWithDelay
    }
  }

  public var isClientError: HTTPErrorClientSideFlag {
    switch category {
    case .http(let status):
      return HTTPErrorClientSideFlag(400...499 ~= status.rawValue)
    case .encoding, .configuration:
      return HTTPErrorClientSideFlag(rawValue: true)
    default:
      return HTTPErrorClientSideFlag(rawValue: false)
    }
  }

  public var isServerError: HTTPErrorServerSideFlag {
    switch category {
    case .http(let status):
      return HTTPErrorServerSideFlag(500...599 ~= status.rawValue)
    case .network:
      return HTTPErrorServerSideFlag(rawValue: true)
    default:
      return HTTPErrorServerSideFlag(rawValue: false)
    }
  }

  public var isTransientError: HTTPErrorTransientFlag {
    HTTPErrorTransientFlag(
      recoveryCategory == .retryable || recoveryCategory == .retryableWithDelay
    )
  }

  public var debugSummary: TechnicalSummaryText {
    var parts = [
      "HTTPError:",
      "Category: \(category)",
      "Severity: \(severity)",
      "Recovery: \(recoveryCategory)",
    ]

    if let request = request {
      parts.append("Request: \(request.method.rawValue) \(request.url)")
    }

    if let response = response {
      parts.append("Response: \(response.status.rawValue)")
    }

    if let underlyingError = underlyingError {
      parts.append("Underlying: \(underlyingError.localizedDescription)")
    }

    return TechnicalSummaryText(parts.joined(separator: ", "))
  }

  public var debugDescription: String {
    debugSummary.rawValue
  }
}
