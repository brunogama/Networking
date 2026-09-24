import NetworkingCore

package protocol CachedResponseProviding: AnyObject, Sendable {
  func cachedResponse(for request: HTTPRequest) async -> HTTPResponse?
}
