import Foundation
import NetworkingCore

extension SSEClient {
  func runConnectionLoop(
    for request: HTTPRequest,
    configuration: SSEConfiguration,
    continuation: SSEContinuation
  ) async throws {
    var state = SSEConnectionState(configuration: configuration)

    while !Task.isCancelled {
      guard
        try await continueConnectionLoop(
          for: request,
          configuration: configuration,
          continuation: continuation,
          state: &state
        )
      else {
        return
      }
    }
  }

  private func continueConnectionLoop(
    for request: HTTPRequest,
    configuration: SSEConfiguration,
    continuation: SSEContinuation,
    state: inout SSEConnectionState
  ) async throws -> Bool {
    do {
      try await consumeConnectionAttempt(
        for: request,
        configuration: configuration,
        state: &state,
        continuation: continuation
      )
      return try await reconnectAfterCompletion(
        for: request,
        configuration: configuration,
        continuation: continuation,
        state: &state
      )
    } catch let failure as SSEAttemptFailure {
      return try await handleAttemptFailure(
        failure,
        configuration: configuration,
        continuation: continuation,
        state: &state
      )
    }
  }

  private func reconnectAfterCompletion(
    for request: HTTPRequest,
    configuration: SSEConfiguration,
    continuation: SSEContinuation,
    state: inout SSEConnectionState
  ) async throws -> Bool {
    guard
      let decision = reconnectDecision(
        for: HTTPError.network(.connectionLost, request: request),
        configuration: configuration,
        state: state
      )
    else {
      continuation.yield(.closed)
      return false
    }

    try await performReconnect(
      using: decision,
      continuation: continuation,
      state: &state
    )
    return true
  }

  private func handleAttemptFailure(
    _ failure: SSEAttemptFailure,
    configuration: SSEConfiguration,
    continuation: SSEContinuation,
    state: inout SSEConnectionState
  ) async throws -> Bool {
    if let decision = reconnectDecision(
      for: failure.error,
      configuration: configuration,
      state: state
    ) {
      try await performReconnect(
        using: decision,
        continuation: continuation,
        state: &state
      )
      return true
    }

    if failure.openedConnection {
      continuation.yield(.closed)
      return false
    }

    throw failure.error
  }

  private func performReconnect(
    using decision: SSEReconnectDecision,
    continuation: SSEContinuation,
    state: inout SSEConnectionState
  ) async throws {
    state.reconnectAttempts = decision.attempt
    continuation.yield(.reconnecting(attempt: decision.attempt, delay: decision.delay))
    try await Task.sleep(for: .seconds(decision.delay.rawValue))
  }
}
