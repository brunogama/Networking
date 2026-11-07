extension HTTPError {
  // MARK: - Error Categories

  /// The failure category used for exhaustive handling at client boundaries.
  public enum Category: Sendable, Hashable {
    case network(NetworkError)
    case http(HTTPStatus)
    case decoding(HTTPErrorDetail)
    case encoding(HTTPErrorDetail)
    case timeout
    case cancelled
    case configuration(HTTPErrorDetail)
    case custom(HTTPErrorTypeName, HTTPErrorDetail)  // (type, message)
  }
}
