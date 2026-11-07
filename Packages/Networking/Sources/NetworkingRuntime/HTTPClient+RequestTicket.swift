import NetworkingCore

extension HTTPClient {

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
