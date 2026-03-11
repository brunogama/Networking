import NetworkingCore
import NetworkingDSL
import NetworkingRuntime

extension NetworkClient {
  /// Convenience method to execute a request built with the DSL.
  /// - Parameter content: A closure that returns request components
  /// - Returns: The HTTP response
  /// - Throws: HTTPError if the request fails
  public func execute(
    @RequestBuilder _ content: () -> [any RequestComponent]
  ) async throws -> HTTPResponse {
    let request = try HTTPRequest(content)
    return try await execute(request)
  }
}
