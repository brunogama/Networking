import Foundation
import NetworkingCore
import NetworkingRuntime

extension MockURLProtocol {

  public static func getCapturedRequests(
    contextID: MockContextIdentifier? = nil
  ) async -> [URLRequest] {
    mockState.getCapturedRequests(contextID: contextID)
  }

  public static func getRequestCount(
    for url: HTTPRequestURL,
    contextID: MockContextIdentifier? = nil
  ) async -> MockVerificationCount {
    mockState.getRequestCount(for: url, contextID: contextID)
  }

  public static func verifyRequest(
    url: HTTPRequestURL,
    method: HTTPMethod? = nil,
    count: MockVerificationCount = 1,
    contextID: MockContextIdentifier? = nil
  ) async -> MockPredicateMatchFlag {
    let requests = await getCapturedRequests(contextID: contextID)
    let matchingRequests = requests.filter { request in
      let urlMatches = request.url == url.rawValue
      let methodMatches =
        method.map { request.httpMethod?.uppercased() == $0.rawValue.rawValue.uppercased() } ?? true
      return urlMatches && methodMatches
    }
    return MockPredicateMatchFlag(matchingRequests.count >= count.rawValue)
  }

  public static func clearAll(contextID: MockContextIdentifier? = nil) {
    mockState.clearAll(contextID: contextID)
  }

  public static func getStubCount() async -> MockVerificationCount {
    mockState.getStubCount()
  }

  // MARK: - Convenience Methods

  public static func createMockConfiguration(
    contextID: MockContextIdentifier? = nil
  ) -> URLSessionConfiguration {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    if let contextID {
      var headers = config.httpAdditionalHeaders ?? [:]
      headers[contextHeader] = contextID.rawValue.uuidString
      config.httpAdditionalHeaders = headers
    }
    // Disable caching to ensure fresh responses for each request
    config.urlCache = nil
    config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    return config
  }

  public static func createMockHTTPClient(contextID: MockContextIdentifier? = nil) -> HTTPClient {
    let config = createMockConfiguration(contextID: contextID)
    return NetworkClient(session: URLSession(configuration: config))
  }
}
