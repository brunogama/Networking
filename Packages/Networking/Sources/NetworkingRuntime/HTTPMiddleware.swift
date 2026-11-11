import NetworkingCore

/// The ordered request, response, and recovery stages of an HTTP client.
public struct HTTPMiddleware: Sendable {

  public var request: [any HTTPRequestMiddleware]

  public var response: [any HTTPResponseMiddleware]

  public var error: [any HTTPErrorMiddleware]

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
