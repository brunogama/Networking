import Foundation
import NetworkingCore

enum MockURLRequestMatcherSupport {
  static func matches(_ request: URLRequest, method: HTTPMethod) -> Bool {
    request.httpMethod?.uppercased() == method.rawValue.rawValue.uppercased()
  }

  static func matches(_ request: URLRequest, url: HTTPRequestURL) -> Bool {
    request.url == url.rawValue
  }

  static func matches(_ request: URLRequest, regex: NSRegularExpression) -> Bool {
    guard let url = request.url?.absoluteString else { return false }
    return regex.firstMatch(in: url, range: NSRange(location: 0, length: url.utf16.count)) != nil
  }

  static func matches(
    _ request: URLRequest,
    header name: HTTPHeaderName,
    value: HTTPHeaderValue?
  ) -> Bool {
    let headerValue = request.value(forHTTPHeaderField: name.rawValue)
    return value == nil ? headerValue != nil : headerValue == value?.rawValue
  }

  static func matches(_ request: URLRequest, body expectedBody: HTTPBody) -> Bool {
    request.httpBody == expectedBody.rawValue
  }

  static func describe(method: HTTPMethod) -> String {
    "method(\(method.rawValue.rawValue))"
  }

  static func describe(url: HTTPRequestURL) -> String {
    "url(\(url.rawValue.absoluteString))"
  }

  static func describe(path: MockRequestPath) -> String {
    "path(\(path.rawValue))"
  }

  static func describe(header name: HTTPHeaderName, value: HTTPHeaderValue?) -> String {
    "header(\(name.rawValue): \(value?.rawValue ?? "any"))"
  }

  static func describe(body _: HTTPBody) -> String {
    "body(data)"
  }
}
