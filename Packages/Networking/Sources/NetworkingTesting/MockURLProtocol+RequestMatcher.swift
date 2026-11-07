import Foundation
import NetworkingCore

extension MockURLProtocol {
  /// Request matching criteria for flexible stub configuration.
  public enum RequestMatcher: Sendable {
    case url(HTTPRequestURL)
    case urlPattern(NSRegularExpression)
    case method(HTTPMethod)
    case path(MockRequestPath)
    case header(name: HTTPHeaderName, value: HTTPHeaderValue?)
    case body(HTTPBody)
    case custom(MockURLRequestPredicate)

    func matches(_ request: URLRequest) -> Bool {
      switch self {
      case .url, .urlPattern, .path: return matchesLocation(request)
      case .method, .header: return matchesMetadata(request)
      case .body(let body): return MockURLRequestMatcherSupport.matches(request, body: body)
      case .custom(let predicate): return predicate.matches(request)
      }
    }

    private func matchesLocation(_ request: URLRequest) -> Bool {
      switch self {
      case .url(let url): return MockURLRequestMatcherSupport.matches(request, url: url)
      case .urlPattern(let regex):
        return MockURLRequestMatcherSupport.matches(request, regex: regex)
      case .path(let path): return request.url?.path == path.rawValue
      default: return false
      }
    }

    private func matchesMetadata(_ request: URLRequest) -> Bool {
      switch self {
      case .method(let method): return MockURLRequestMatcherSupport.matches(request, method: method)
      case .header(let name, let value):
        return MockURLRequestMatcherSupport.matches(request, header: name, value: value)
      default: return false
      }
    }

    var description: String {
      switch self {
      case .method(let method): return MockURLRequestMatcherSupport.describe(method: method)
      case .url(let url): return MockURLRequestMatcherSupport.describe(url: url)
      case .urlPattern:
        return "urlPattern(regex)"
      case .path(let path): return MockURLRequestMatcherSupport.describe(path: path)
      case .header(let name, let value):
        return MockURLRequestMatcherSupport.describe(header: name, value: value)
      case .body(let body): return MockURLRequestMatcherSupport.describe(body: body)
      case .custom: return "custom matcher"
      }
    }

    public static func urlPattern(_ pattern: RequestPathPattern) -> Self {
      do {
        return .urlPattern(try NSRegularExpression(pattern: pattern.rawValue, options: []))
      } catch {
        return .custom(MockURLRequestPredicate { _ in false })
      }
    }
  }

}
