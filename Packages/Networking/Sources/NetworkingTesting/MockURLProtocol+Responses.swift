import Foundation
import NetworkingCore

extension MockURLProtocol {
  /// Mock response configuration.
  public enum MockResponse: Sendable {
    case success(statusCode: HTTPStatusCode, data: HTTPBody, headers: HTTPHeaders = [:])
    case failure(Error)
    case timeout
    case networkUnavailable
    case custom(
      statusCode: HTTPStatusCode,
      data: HTTPBody,
      headers: HTTPHeaders,
      delay: MockResponseDelay
    )

    var statusCode: HTTPStatusCode {
      switch self {
      case .success(let code, _, _): return code
      case .custom(let code, _, _, _): return code
      case .failure, .timeout, .networkUnavailable: return -1
      }
    }

    var data: HTTPBody {
      switch self {
      case .success(_, let data, _): return data
      case .custom(_, let data, _, _): return data
      case .failure, .timeout, .networkUnavailable: return HTTPBody(Data())
      }
    }

    var headers: HTTPHeaders {
      switch self {
      case .success(_, _, let headers): return headers
      case .custom(_, _, let headers, _): return headers
      case .failure, .timeout, .networkUnavailable: return [:]
      }
    }

    var delay: MockResponseDelay {
      switch self {
      case .custom(_, _, _, let delay): return delay
      case .timeout: return 0.0  // Fail immediately so timeout simulations do not stall test suites
      default: return 0.0
      }
    }

    var error: Error? {
      switch self {
      case .failure(let error): return error
      case .timeout: return URLError(.timedOut)
      case .networkUnavailable: return URLError(.notConnectedToInternet)
      default: return nil
      }
    }
  }

}

extension MockURLProtocol.MockResponse {
  /// Convert MockResponse to HTTPResponse for use with MockNetworkClient.
  /// - Parameter request: The original HTTP request
  /// - Returns: HTTPResponse based on the mock configuration
  /// - Throws: Configured HTTP and cancellation errors unchanged; other failures become HTTP errors.
  public func toHTTPResponse(for request: HTTPRequest) async throws -> HTTPResponse {
    if case .timeout = self {
      throw HTTPError(
        category: .timeout,
        request: request,
        underlyingError: URLError(.timedOut)
      )
    }

    if delay.rawValue > 0 {
      try await Task.sleep(for: .seconds(delay.rawValue))
    }

    if let responseError = error {
      throw executionError(responseError, for: request)
    }

    return HTTPResponse(
      request: request,
      status: HTTPStatus(rawValue: statusCode),
      headers: headers,
      body: data
    )
  }

  private func executionError(_ error: any Error, for request: HTTPRequest) -> any Error {
    switch error {
    case is HTTPError, is CancellationError:
      return error
    default:
      return HTTPError(
        category: .network(.connectionLost),
        request: request,
        underlyingError: error
      )
    }
  }
}
