import NetworkingCore

extension HTTPClient {
  /// Runs a request and its ticket consumer in one structured task scope.
  ///
  /// Returning or throwing from `operation` cancels unfinished work and waits for it to end.
  /// Retain `ticket.cancellation` when another task or a UI action needs cancellation authority.
  /// A retained cancellation capability becomes inert once a terminal result is published.
  /// - Throws: Errors thrown by `operation`, including the ticket's `HTTPError` response failures.
  public func withRequest<Output: Sendable>(
    _ request: HTTPRequest,
    operation: @Sendable (consuming RequestTicket<RequestRunning>) async throws -> Output
  ) async rethrows -> Output {
    let control = RequestCancellation(request: request)
    return try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask { await control.run(using: self) }
      defer {
        control.cancel()
        group.cancelAll()
      }
      let ticket = RequestTicket<RequestPending>(control: control).start()
      return try await operation(ticket)
    }
  }
}
