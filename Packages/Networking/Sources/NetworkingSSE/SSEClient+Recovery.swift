import Foundation
import NetworkingCore

private let sseRetryableErrors: [URLError.Code: HTTPError.NetworkError] = [
  .notConnectedToInternet: .noConnection,
  .networkConnectionLost: .connectionLost,
  .cannotFindHost: .dnsFailure,
  .dnsLookupFailed: .dnsFailure,
  .cannotConnectToHost: .serverUnreachable,
  .timedOut: .serverUnreachable,
  .secureConnectionFailed: .sslError,
  .serverCertificateUntrusted: .sslError,
]

struct SSEAttemptFailure: Error {
  let error: HTTPError
  let openedConnection: Bool
}

struct SSEReconnectDecision {
  let attempt: SSEReconnectAttempt
  let delay: SSEReconnectDelay
}

extension SSEClient {
  func reconnectDecision(
    for error: HTTPError,
    configuration: SSEConfiguration,
    state: SSEConnectionState
  ) -> SSEReconnectDecision? {
    guard shouldReconnect(for: error) else {
      return nil
    }

    guard case .automatic(let policy) = configuration.reconnectMode else {
      return nil
    }

    let attempt = SSEReconnectAttempt(state.reconnectAttempts.rawValue + 1)
    guard policy.maxAttempts.map({ attempt <= $0.rawValue }) ?? true else {
      return nil
    }

    return SSEReconnectDecision(
      attempt: attempt,
      delay: reconnectDelay(
        using: policy,
        configuration: configuration,
        attempt: attempt,
        serverRetryHint: state.serverRetryHint
      )
    )
  }

  func mapURLError(
    _ error: URLError,
    for request: HTTPRequest
  ) -> HTTPError {
    guard error.code != .cancelled else {
      return HTTPError.cancelled(request: request)
    }

    let networkError = sseRetryableErrors[error.code] ?? .serverUnreachable
    return HTTPError(
      category: .network(networkError),
      request: request,
      underlyingError: error
    )
  }

  func wrapUnexpectedError(
    _ error: Error,
    for request: HTTPRequest
  ) -> HTTPError {
    if let httpError = error as? HTTPError {
      return httpError
    }

    return HTTPError(
      category: .network(.serverUnreachable),
      request: request,
      underlyingError: error
    )
  }

  private func reconnectDelay(
    using policy: SSEReconnectPolicy,
    configuration: SSEConfiguration,
    attempt: SSEReconnectAttempt,
    serverRetryHint: SSEReconnectDelay?
  ) -> SSEReconnectDelay {
    if configuration.respectServerRetry.rawValue, let serverRetryHint {
      return SSEReconnectDelay(min(max(serverRetryHint.rawValue, 0), policy.maxDelay.rawValue))
    }

    let delay = policy.initialDelay.rawValue * pow(2, Double(attempt.rawValue - 1))
    return SSEReconnectDelay(min(max(delay, 0), policy.maxDelay.rawValue))
  }

  private func shouldReconnect(for error: HTTPError) -> Bool {
    switch error.category {
    case .cancelled, .configuration:
      return false

    case .custom(let type, _):
      return type.rawValue.caseInsensitiveCompare("SSE") != .orderedSame && isRetryable(error)

    default:
      return isRetryable(error)
    }
  }

  private func isRetryable(_ error: HTTPError) -> Bool {
    error.recoveryCategory == .retryable || error.recoveryCategory == .retryableWithDelay
  }
}
