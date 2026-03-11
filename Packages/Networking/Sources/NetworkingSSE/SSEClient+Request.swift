import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension SSEClient {
  func applyRequestMiddlewares(_ request: HTTPRequest) async throws -> HTTPRequest {
    var currentRequest = request

    for middleware in requestMiddlewares {
      currentRequest = try await middleware.modifyRequest(currentRequest)
    }

    return currentRequest
  }

  func buildURLRequest(
    from request: HTTPRequest,
    configuration: SSEConfiguration,
    state: SSEConnectionState
  ) throws -> URLRequest {
    try validateRequestMethod(request)

    var urlRequest = makeBaseRequest(from: request)
    applyHeaders(
      from: request,
      to: &urlRequest,
      configuration: configuration,
      lastEventID: state.lastEventID
    )
    return urlRequest
  }

  private func validateRequestMethod(_ request: HTTPRequest) throws {
    guard request.method == .get else {
      throw HTTPError(
        category: .configuration("SSE transport requires a GET request"),
        request: request
      )
    }
  }

  private func makeBaseRequest(from request: HTTPRequest) -> URLRequest {
    var urlRequest = URLRequest(url: request.urlValue)
    urlRequest.httpMethod = request.method.methodValue
    urlRequest.timeoutInterval = request.timeoutInterval
    urlRequest.cachePolicy = session.configuration.requestCachePolicy
    urlRequest.httpBody = request.bodyValue
    return urlRequest
  }

  private func applyHeaders(
    from request: HTTPRequest,
    to urlRequest: inout URLRequest,
    configuration: SSEConfiguration,
    lastEventID: SSELastEventID?
  ) {
    for (key, value) in request.headers {
      urlRequest.setValue(value.rawValue, forHTTPHeaderField: key.rawValue)
    }

    applyDefaultHeaders(to: &urlRequest, acceptHeader: configuration.acceptHeader)
    applyLastEventID(lastEventID, to: &urlRequest)
  }

  private func applyDefaultHeaders(
    to request: inout URLRequest,
    acceptHeader: SSEAcceptHeader
  ) {
    if request.value(forHTTPHeaderField: "Accept") == nil {
      request.setValue(acceptHeader.rawValue, forHTTPHeaderField: "Accept")
    }

    if request.value(forHTTPHeaderField: "Cache-Control") == nil {
      request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
    }
  }

  private func applyLastEventID(
    _ lastEventID: SSELastEventID?,
    to request: inout URLRequest
  ) {
    guard let lastEventID, !lastEventID.isEmpty else {
      return
    }

    request.setValue(lastEventID.rawValue, forHTTPHeaderField: "Last-Event-ID")
  }
}
