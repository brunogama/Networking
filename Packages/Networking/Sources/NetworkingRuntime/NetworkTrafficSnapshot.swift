import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

package enum NetworkTrafficSnapshot {
  package static func request(
    from request: URLRequest,
    policy: NetworkTrafficCapturePolicy
  ) -> NetworkTrafficRequest {
    let headerSnapshot = headers(from: request.allHTTPHeaderFields ?? [:], policy: policy)
    return NetworkTrafficRequest(
      method: request.httpMethod ?? "GET",
      url: request.url.flatMap { sanitizedURL($0, policy: policy) },
      headerNames: headerSnapshot.names,
      headers: headerSnapshot.values,
      body: body(from: request.httpBody, policy: policy)
    )
  }

  package static func response(
    from response: URLResponse,
    body data: Data,
    policy: NetworkTrafficCapturePolicy
  ) -> NetworkTrafficResponse {
    let httpResponse = response as? HTTPURLResponse
    var responseHeaders: [String: String] = [:]
    if let httpResponse {
      for (key, value) in httpResponse.allHeaderFields {
        guard let name = key as? String else {
          continue
        }
        responseHeaders[name] = String(describing: value)
      }
    }
    let headerSnapshot = headers(from: responseHeaders, policy: policy)
    return NetworkTrafficResponse(
      statusCode: httpResponse?.statusCode,
      url: response.url.flatMap { sanitizedURL($0, policy: policy) },
      headerNames: headerSnapshot.names,
      headers: headerSnapshot.values,
      body: body(from: data, policy: policy)
    )
  }

  package static func failure(from error: any Error) -> NetworkTrafficFailure {
    let nsError = error as NSError
    return NetworkTrafficFailure(domain: nsError.domain, code: nsError.code)
  }

  package static func redirect(
    response: HTTPURLResponse,
    request: URLRequest,
    policy: NetworkTrafficCapturePolicy,
    observedAt: Date = Date()
  ) -> NetworkTrafficRedirect {
    NetworkTrafficRedirect(
      observedAt: observedAt,
      statusCode: response.statusCode,
      fromURL: response.url.flatMap { sanitizedURL($0, policy: policy) },
      toURL: request.url.flatMap { sanitizedURL($0, policy: policy) }
    )
  }

  package static func transaction(
    from metrics: URLSessionTaskTransactionMetrics,
    policy: NetworkTrafficCapturePolicy
  ) -> NetworkTrafficTransaction {
    let response = metrics.response as? HTTPURLResponse
    return NetworkTrafficTransaction(
      requestURL: metrics.request.url.flatMap { sanitizedURL($0, policy: policy) },
      responseURL: metrics.response?.url.flatMap { sanitizedURL($0, policy: policy) },
      responseStatusCode: response?.statusCode,
      fetchStart: metrics.fetchStartDate,
      domainLookupStart: metrics.domainLookupStartDate,
      domainLookupEnd: metrics.domainLookupEndDate,
      connectStart: metrics.connectStartDate,
      secureConnectionStart: metrics.secureConnectionStartDate,
      secureConnectionEnd: metrics.secureConnectionEndDate,
      connectEnd: metrics.connectEndDate,
      requestStart: metrics.requestStartDate,
      requestEnd: metrics.requestEndDate,
      responseStart: metrics.responseStartDate,
      responseEnd: metrics.responseEndDate,
      networkProtocolName: metrics.networkProtocolName,
      isProxyConnection: metrics.isProxyConnection,
      isReusedConnection: metrics.isReusedConnection,
      resourceFetchType: resourceFetchType(from: metrics.resourceFetchType)
    )
  }

  private static func sanitizedURL(
    _ url: URL,
    policy: NetworkTrafficCapturePolicy
  ) -> URL? {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return nil
    }
    components.user = nil
    components.password = nil
    components.fragment = nil
    if !policy.includesQueryValues {
      components.queryItems = components.queryItems?.map { URLQueryItem(name: $0.name, value: nil) }
    }
    return components.url
  }

  private static func headers(
    from headers: [String: String],
    policy: NetworkTrafficCapturePolicy
  ) -> (names: [String], values: [String: String]) {
    let names = headers.keys.sorted {
      let left = $0.lowercased()
      let right = $1.lowercased()
      return left == right ? $0 < $1 : left < right
    }
    let values = headers.filter { key, _ in
      policy.capturedHeaderNames.contains(key.lowercased())
    }
    return (names, values)
  }

  private static func body(
    from data: Data?,
    policy: NetworkTrafficCapturePolicy
  ) -> NetworkTrafficBody? {
    guard let data, policy.bodyByteLimit > 0 else {
      return nil
    }
    return NetworkTrafficBody(
      data: Data(data.prefix(policy.bodyByteLimit)),
      originalByteCount: data.count,
      isTruncated: data.count > policy.bodyByteLimit
    )
  }

  // swiftlint:disable:next cyclomatic_complexity
  private static func resourceFetchType(
    from type: URLSessionTaskMetrics.ResourceFetchType
  ) -> NetworkTrafficResourceFetchType {
    switch type {
    case .networkLoad:
      return .networkLoad
    case .serverPush:
      return .serverPush
    case .localCache:
      return .localCache
    case .unknown:
      return .unknown
    @unknown default:
      return .unknown
    }
  }
}
