import Foundation
import Networking

/// Middleware that logs HTTP requests and responses in HTTPie format.
///
/// Outputs requests like:
/// ```
/// http GET https://api.github.com/users/apple Accept:application/json
/// ```
///
/// And responses like:
/// ```
/// HTTP/1.1 200 OK
/// Content-Type: application/json
///
/// {"login":"apple","id":10639145,...}
/// ```
struct HTTPieMiddleware: HTTPRequestMiddleware, HTTPResponseMiddleware {
  // MARK: - Configuration

  struct Configuration: Sendable {
    let printRequest: Bool
    let printResponse: Bool
    let printHeaders: Bool
    let printBody: Bool
    let maxBodyLength: Int
    let colorized: Bool

    init(
      printRequest: Bool = true,
      printResponse: Bool = true,
      printHeaders: Bool = true,
      printBody: Bool = true,
      maxBodyLength: Int = 2048,
      colorized: Bool = true
    ) {
      self.printRequest = printRequest
      self.printResponse = printResponse
      self.printHeaders = printHeaders
      self.printBody = printBody
      self.maxBodyLength = maxBodyLength
      self.colorized = colorized
    }
  }

  // MARK: - ANSI Colors

  private enum Color: String {
    case reset = "\u{001B}[0m"
    case cyan = "\u{001B}[36m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case blue = "\u{001B}[34m"
    case magenta = "\u{001B}[35m"
    case gray = "\u{001B}[90m"
  }

  // MARK: - Properties

  private let configuration: Configuration

  // MARK: - Initialization

  init(configuration: Configuration = Configuration()) {
    self.configuration = configuration
  }

  // MARK: - HTTPRequestMiddleware

  func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    guard configuration.printRequest else { return request }

    var output = "\n"
    output += formatRequestCommand(request)

    if configuration.printHeaders {
      output += formatRequestHeaders(request)
    }

    if configuration.printBody, let body = request.body {
      output += formatRequestBody(body)
    }

    print(output)
    return request
  }

  // MARK: - HTTPResponseMiddleware

  func processResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    guard configuration.printResponse else { return response }

    var output = "\n"
    output += formatResponseStatus(response)

    if configuration.printHeaders {
      output += formatResponseHeaders(response)
    }

    if configuration.printBody, let body = response.body {
      output += formatResponseBody(body)
    }

    print(output)
    return response
  }

  // MARK: - Request Formatting

  private func formatRequestCommand(_ request: HTTPRequest) -> String {
    let method = request.method.rawValue
    let url = request.url.absoluteString

    if configuration.colorized {
      return "\(Color.cyan.rawValue)http\(Color.reset.rawValue) "
        + "\(Color.green.rawValue)\(method)\(Color.reset.rawValue) "
        + "\(Color.yellow.rawValue)\(url)\(Color.reset.rawValue)"
    }
    return "http \(method) \(url)"
  }

  private func formatRequestHeaders(_ request: HTTPRequest) -> String {
    guard !request.headers.isEmpty else { return "" }

    var output = ""
    for (key, value) in request.headers.sorted(by: { $0.key < $1.key }) {
      if configuration.colorized {
        output += " \(Color.blue.rawValue)\(key)\(Color.reset.rawValue):\(value)"
      } else {
        output += " \(key):\(value)"
      }
    }
    return output
  }

  private func formatRequestBody(_ body: Data) -> String {
    guard let bodyString = formatBodyData(body) else { return "" }

    var output = "\n"
    if configuration.colorized {
      output += "\(Color.gray.rawValue)>>> Request Body:\(Color.reset.rawValue)\n"
      output += "\(Color.magenta.rawValue)\(bodyString)\(Color.reset.rawValue)"
    } else {
      output += ">>> Request Body:\n\(bodyString)"
    }
    return output
  }

  // MARK: - Response Formatting

  private func formatResponseStatus(_ response: HTTPResponse) -> String {
    let statusCode = response.status.rawValue
    let statusDescription = httpStatusDescription(statusCode)

    if configuration.colorized {
      let statusColor = statusCode < 400 ? Color.green : Color.yellow
      return
        "\(statusColor.rawValue)HTTP/1.1 \(statusCode) \(statusDescription)\(Color.reset.rawValue)\n"
    }
    return "HTTP/1.1 \(statusCode) \(statusDescription)\n"
  }

  private func formatResponseHeaders(_ response: HTTPResponse) -> String {
    guard !response.headers.isEmpty else { return "" }

    var output = ""
    for (key, value) in response.headers.sorted(by: { $0.key < $1.key }) {
      if configuration.colorized {
        output += "\(Color.blue.rawValue)\(key)\(Color.reset.rawValue): \(value)\n"
      } else {
        output += "\(key): \(value)\n"
      }
    }
    return output
  }

  private func formatResponseBody(_ body: Data) -> String {
    guard let bodyString = formatBodyData(body) else { return "" }

    var output = "\n"
    if configuration.colorized {
      output += "\(Color.magenta.rawValue)\(bodyString)\(Color.reset.rawValue)"
    } else {
      output += bodyString
    }
    return output
  }

  // MARK: - Helpers

  private func formatBodyData(_ data: Data) -> String? {
    guard let string = String(data: data, encoding: .utf8) else { return nil }

    if string.count > configuration.maxBodyLength {
      return String(string.prefix(configuration.maxBodyLength)) + "... (truncated)"
    }

    if let jsonData = try? JSONSerialization.jsonObject(with: data),
      let prettyData = try? JSONSerialization.data(
        withJSONObject: jsonData,
        options: [.prettyPrinted, .sortedKeys]
      ),
      let prettyString = String(data: prettyData, encoding: .utf8)
    {
      if prettyString.count > configuration.maxBodyLength {
        return String(prettyString.prefix(configuration.maxBodyLength)) + "... (truncated)"
      }
      return prettyString
    }

    return string
  }

  private func httpStatusDescription(_ code: Int) -> String {
    switch code {
    case 200: return "OK"
    case 201: return "Created"
    case 204: return "No Content"
    case 301: return "Moved Permanently"
    case 302: return "Found"
    case 304: return "Not Modified"
    case 400: return "Bad Request"
    case 401: return "Unauthorized"
    case 403: return "Forbidden"
    case 404: return "Not Found"
    case 405: return "Method Not Allowed"
    case 409: return "Conflict"
    case 422: return "Unprocessable Entity"
    case 429: return "Too Many Requests"
    case 500: return "Internal Server Error"
    case 502: return "Bad Gateway"
    case 503: return "Service Unavailable"
    case 504: return "Gateway Timeout"
    default: return "Unknown"
    }
  }
}
