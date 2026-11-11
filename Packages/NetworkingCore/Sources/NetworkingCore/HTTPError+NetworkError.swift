extension HTTPError {
  /// Transport failures that are independent of HTTP response status.
  public enum NetworkError: Sendable, Hashable {
    case noConnection
    case dnsFailure
    case connectionLost
    case serverUnreachable
    case sslError
  }
}
