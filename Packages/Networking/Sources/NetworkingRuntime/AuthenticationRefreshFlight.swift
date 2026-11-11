import NetworkingCore

struct AuthenticationRefreshFlight: Sendable {
  private final class Token: Sendable {}

  private let token: Token
  let task: Task<BearerTokenValue, any Error>

  init(task: Task<BearerTokenValue, any Error>) {
    self.token = Token()
    self.task = task
  }

  func isSame(as other: borrowing Self) -> Bool {
    token === other.token
  }

  func cancel() {
    task.cancel()
  }
}
