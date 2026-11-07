import Foundation
import NetworkingCore

/// Controls diagnostic retention and explicit opt-in body capture.
public struct HTTPTracePrivacy: Sendable {

  public var redactedHeaders: Set<String> = [
    "authorization", "proxy-authorization", "cookie", "set-cookie", "x-api-key",
  ]

  public var capturesBodies = false

  public var maximumBodyBytes = 4096

  public init() {}

  func request(_ request: HTTPRequest) -> HTTPTrace.Message {
    HTTPTrace.Message(
      method: request.method.rawValue.rawValue,
      url: sanitizedURL(request.url.rawValue),
      statusCode: nil,
      headers: sanitizedHeaders(request.headers.rawValue),
      body: capturedBody(request.body?.rawValue)
    )
  }

  func response(_ response: HTTPResponse) -> HTTPTrace.Message {
    HTTPTrace.Message(
      method: nil,
      url: response.url.flatMap { sanitizedURL($0.rawValue) },
      statusCode: response.status.rawValue.rawValue,
      headers: sanitizedHeaders(response.headers.rawValue),
      body: capturedBody(response.body?.rawValue)
    )
  }

  private func capturedBody(_ body: Data?) -> Data? {
    guard capturesBodies, maximumBodyBytes > 0 else { return nil }
    return body.map { Data($0.prefix(maximumBodyBytes)) }
  }

  private func sanitizedHeaders(_ headers: [String: String]) -> [String: String] {
    let redacted = Set(redactedHeaders.map { $0.lowercased() })
    return headers.reduce(into: [:]) { result, header in
      result[header.key] = redacted.contains(header.key.lowercased()) ? "<redacted>" : header.value
    }
  }

  private func sanitizedURL(_ url: URL) -> URL? {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
      return nil
    }
    components.user = nil
    components.password = nil
    components.fragment = nil
    components.queryItems = components.queryItems?.map {
      URLQueryItem(name: $0.name, value: "<redacted>")
    }
    return components.url
  }
}
