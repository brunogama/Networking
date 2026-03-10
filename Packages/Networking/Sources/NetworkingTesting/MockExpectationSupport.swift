import Foundation
import NetworkingRuntime

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Shared call-count semantics used by test doubles that verify request usage.
public enum MockCallCountExpectation: Sendable {
  case never
  case once
  case exactly(RequestCount)
  case atLeast(RequestCount)
  case atMost(RequestCount)
  case atLeastOnce
  case between(min: RequestCount, max: RequestCount)

  // The exhaustive enum switch is the clearest representation of call-count semantics.
  // swiftlint:disable:next cyclomatic_complexity
  func matches(_ count: Int) -> Bool {
    switch self {
    case .never: return count == 0
    case .once: return count == 1
    case .exactly(let expected): return count == expected.rawValue
    case .atLeast(let minimum): return count >= minimum.rawValue
    case .atMost(let maximum): return count <= maximum.rawValue
    case .atLeastOnce: return count >= 1
    case .between(let minimum, let maximum):
      return count >= minimum.rawValue && count <= maximum.rawValue
    }
  }

  var description: String {
    switch self {
    case .never: return "never"
    case .once: return "once"
    case .exactly(let count): return "exactly \(count.rawValue) time(s)"
    case .atLeast(let minimum): return "at least \(minimum.rawValue) time(s)"
    case .atMost(let maximum): return "at most \(maximum.rawValue) time(s)"
    case .atLeastOnce: return "at least once"
    case .between(let minimum, let maximum):
      return "between \(minimum.rawValue) and \(maximum.rawValue) time(s)"
    }
  }
}

enum MockURLRequestMatcherSupport {
  static func matches(_ request: URLRequest, method: HTTPMethod) -> Bool {
    request.httpMethod?.uppercased() == method.rawValue.uppercased()
  }

  static func matches(_ request: URLRequest, url: HTTPRequestURL) -> Bool {
    request.url == url.rawValue
  }

  static func matches(_ request: URLRequest, regex: NSRegularExpression) -> Bool {
    guard let url = request.url?.absoluteString else { return false }
    return regex.firstMatch(in: url, range: NSRange(location: 0, length: url.count)) != nil
  }

  static func matches(_ request: URLRequest, pattern: RequestPathPattern) -> Bool {
    guard let url = request.url?.absoluteString else { return false }
    return url.range(of: pattern.rawValue, options: .regularExpression) != nil
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
    "url(\(url.absoluteString))"
  }

  static func describe(pattern: RequestPathPattern) -> String {
    "urlPattern(\(pattern.rawValue))"
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
