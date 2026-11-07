enum AuthenticationRefreshState: Sendable {
  case idle
  case refreshing(AuthenticationRefreshFlight)
}
