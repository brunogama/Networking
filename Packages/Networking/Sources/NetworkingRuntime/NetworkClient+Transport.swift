import Foundation
import NetworkingCore

extension NetworkClient {
  func performRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
    let urlRequest = try buildURLRequest(from: request)
    let exchange = HTTPExchange<ExchangePrepared>(diagnostics: configuration.diagnostics)
      .start(request)
    let delegate = HTTPTaskDelegate(diagnostics: configuration.diagnostics, traceID: exchange.id)
    do {
      let (data, response) = try await responseData(for: urlRequest, delegate: delegate)
      guard let response = response as? HTTPURLResponse else {
        throw HTTPError.network(.serverUnreachable, request: request)
      }
      let result = HTTPResponse(request: request, httpURLResponse: response, body: HTTPBody(data))
      exchange.finish(result)
      return result
    } catch {
      exchange.fail(error)
      throw transportError(error, for: request)
    }
  }

  func transportError(_ error: any Error, for request: HTTPRequest) -> HTTPError {
    if let error = error as? URLError { return mapURLError(error, for: request) }
    if let error = error as? HTTPError { return error }
    if error is CancellationError { return HTTPError.cancelled(request: request) }
    return HTTPError(
      category: .custom("Transport", "URLSession execution failed"),
      request: request,
      underlyingError: error
    )
  }

  private func responseData(
    for request: URLRequest,
    delegate: HTTPTaskDelegate
  ) async throws -> (Data, URLResponse) {
    guard let limit = configuration.maximumResponseBytes else {
      return try await session.data(for: request, delegate: delegate)
    }
    guard limit >= 0 else { throw responseLimitError() }
    let (bytes, response) = try await session.bytes(for: request, delegate: delegate)
    var data = Data()
    for try await byte in bytes {
      guard data.count < limit else {
        bytes.task.cancel()
        throw responseLimitError()
      }
      data.append(byte)
    }
    return (data, response)
  }

  func validateResponseSize(_ response: HTTPResponse) throws {
    guard let limit = configuration.maximumResponseBytes else { return }
    guard limit >= 0, (response.body?.count.rawValue ?? 0) <= limit else {
      throw responseLimitError()
    }
  }

  func responseLimitError() -> HTTPError {
    HTTPError(category: .configuration("Response exceeds the configured size limit"))
  }

  func buildURLRequest(from request: HTTPRequest) throws -> URLRequest {
    var result = URLRequest(url: request.url.rawValue)
    result.httpMethod = request.method.rawValue.rawValue
    result.timeoutInterval =
      (request.timeoutOverride ?? configuration.timeout)?.rawValue
      ?? session.configuration.timeoutIntervalForRequest
    result.cachePolicy = session.configuration.requestCachePolicy
    for (key, value) in request.headers {
      result.setValue(value.rawValue, forHTTPHeaderField: key.rawValue)
    }
    result.httpBody = request.body?.rawValue
    return result
  }

  func mapURLError(_ error: URLError, for request: HTTPRequest) -> HTTPError {
    if error.code == .timedOut {
      return HTTPError(category: .timeout, request: request, underlyingError: error)
    }
    if error.code == .cancelled {
      return HTTPError(category: .cancelled, request: request, underlyingError: error)
    }
    let categories: [URLError.Code: HTTPError.NetworkError] = [
      .notConnectedToInternet: .noConnection,
      .networkConnectionLost: .connectionLost,
      .cannotFindHost: .dnsFailure,
      .dnsLookupFailed: .dnsFailure,
      .cannotConnectToHost: .serverUnreachable,
      .secureConnectionFailed: .sslError,
      .serverCertificateUntrusted: .sslError,
    ]
    return HTTPError(
      category: .network(categories[error.code, default: .serverUnreachable]),
      request: request,
      underlyingError: error
    )
  }
}
