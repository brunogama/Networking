/// Core protocol for executing HTTP requests with modern Swift concurrency.
public protocol HTTPClient: Sendable {

  func execute(_ request: HTTPRequest) async throws -> HTTPResponse
}
