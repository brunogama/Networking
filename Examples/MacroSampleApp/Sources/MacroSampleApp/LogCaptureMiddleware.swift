import Foundation
import Networking

/// Middleware that captures HTTP requests and responses in HTTPie format for display.
final class LogCaptureMiddleware: HTTPRequestMiddleware, HTTPResponseMiddleware, @unchecked Sendable
{
  private let lock = NSLock()
  private var _log: String = ""

  var log: String {
    lock.lock()
    defer { lock.unlock() }
    return _log
  }

  func clear() {
    lock.lock()
    defer { lock.unlock() }
    _log = ""
  }

  private func append(_ text: String) {
    lock.lock()
    defer { lock.unlock() }
    _log += text
  }

  // MARK: - HTTPRequestMiddleware

  func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    let method = request.method.rawValue
    let url = request.url.absoluteString
    append("http \(method) \(url)\n")
    return request
  }

  // MARK: - HTTPResponseMiddleware

  func processResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    let statusCode = response.status.rawValue
    let statusDesc = httpStatusDescription(statusCode)
    append("HTTP/1.1 \(statusCode) \(statusDesc)\n")

    if let body = response.body,
      let json = try? JSONSerialization.jsonObject(with: body),
      let pretty = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
      let str = String(data: pretty, encoding: .utf8)
    {
      let truncated = str.count > 300 ? String(str.prefix(300)) + "..." : str
      append("\(truncated)\n")
    }

    return response
  }

  private func httpStatusDescription(_ code: Int) -> String {
    switch code {
    case 200: return "OK"
    case 201: return "Created"
    case 404: return "Not Found"
    case 500: return "Internal Server Error"
    default: return "Unknown"
    }
  }
}
