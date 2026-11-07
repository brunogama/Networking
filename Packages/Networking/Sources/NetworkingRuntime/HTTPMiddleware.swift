import NetworkingCore

/// The ordered request, response, and recovery stages of an HTTP client.
public struct HTTPMiddleware: Sendable {
  /// Middleware applied before transport execution.
  public var request: [any HTTPRequestMiddleware]
  /// Middleware applied to responses, in order.
  public var response: [any HTTPResponseMiddleware]
  /// Middleware consulted for error recovery, in order.
  public var error: [any HTTPErrorMiddleware]

  /// Creates a pipeline from its independent stages.
  public init(
    request: [any HTTPRequestMiddleware] = [],
    response: [any HTTPResponseMiddleware] = [],
    error: [any HTTPErrorMiddleware] = []
  ) {
    self.request = request
    self.response = response
    self.error = error
  }
}
