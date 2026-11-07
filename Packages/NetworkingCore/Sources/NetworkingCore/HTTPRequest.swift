import Foundation

/// A structure representing an HTTP request with Swift 6 concurrency compliance.
public struct HTTPRequest: Sendable, Identifiable {
  // MARK: - Properties

  public let id: HTTPRequestID

  public let method: HTTPMethod

  public let url: HTTPRequestURL

  public let headers: HTTPHeaders

  public let body: HTTPBody?

  public let timeout: RequestTimeout

  public let timeoutOverride: RequestTimeout?

  // MARK: - Initialization

  public init(
    method: HTTPMethod,
    url: HTTPRequestURL,
    headers: HTTPHeaders = [:],
    body: HTTPBody? = nil,
    timeout: RequestTimeout? = nil,
    id: HTTPRequestID = .init()
  ) {
    self.id = id
    self.method = method
    self.url = url
    self.headers = headers
    self.body = body
    self.timeout = timeout ?? RequestTimeout(rawValue: 30.0)
    self.timeoutOverride = timeout
  }

  public init(
    method: HTTPMethod,
    url: URL,
    headers: [String: String] = [:],
    body: Data? = nil,
    timeout: TimeInterval? = nil,
    id: UUID = UUID()
  ) {
    self.init(
      method: method,
      url: HTTPRequestURL(url),
      headers: HTTPHeaders(headers),
      body: body.map { HTTPBody($0) },
      timeout: timeout.map { RequestTimeout($0) },
      id: HTTPRequestID(id)
    )
  }

}
