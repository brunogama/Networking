/// Protocol for request modification middleware.
public protocol HTTPRequestMiddleware: Sendable {

  func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest
}
