import Foundation
import NetworkingCore

/// Controls diagnostic retention and explicit opt-in body capture.
public struct HTTPTracePrivacy: Sendable {
  /// Header names whose values must never appear in diagnostics.
  public var redactedHeaders: Set<String> = [
    "authorization", "proxy-authorization", "cookie", "set-cookie", "x-api-key",
  ]
  /// Whether to capture body prefixes, which may contain sensitive application data.
  public var capturesBodies = false
  /// Maximum retained bytes per body; nonpositive values disable body capture.
  public var maximumBodyBytes = 4096

  /// Creates a policy with secret headers redacted and body capture disabled.
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
