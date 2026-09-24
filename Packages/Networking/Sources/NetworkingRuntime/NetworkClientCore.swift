import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Modern HTTP client implementation using URLSession and structured concurrency.
///
/// `NetworkClient` is the primary implementation of ``HTTPClient`` that provides a comprehensive
/// networking solution built on top of URLSession. It supports a middleware pipeline for request
/// and response processing, automatic error recovery, and is fully compatible with Swift's
/// structured concurrency model.
///
/// ## Usage
///
/// ### Basic Client Creation
///
/// ```swift
/// let client = NetworkClient()
/// let response = try await client.execute(request)
/// ```
///
/// ### Client with Middleware
///
/// ```swift
/// let client = NetworkClient(
///     requestMiddlewares: [AuthenticationMiddleware()],
///     responseMiddlewares: [CachingMiddleware()],
///     errorMiddlewares: [RetryMiddleware()]
/// )
/// ```
///
/// ### Configuration-Based Client
///
/// ```swift
/// let client = NetworkClient {
///     BaseURL("https://api.example.com")
///     EnableLogging()
///     EnableRetry()
///     Authentication {
///         BearerToken(tokenProvider)
///     }
/// }
/// ```
///
/// ## Architecture
///
/// The client processes requests through a three-stage middleware pipeline:
///
/// 1. **Request Middleware**: Modifies requests before execution (authentication, logging, etc.)
/// 2. **Network Execution**: Performs the actual HTTP request using URLSession
/// 3. **Response Middleware**: Processes responses after execution (caching, validation, etc.)
/// 4. **Error Middleware**: Handles errors and provides recovery strategies (retry, fallback, etc.)
///
/// ## Thread Safety
///
/// `NetworkClient` is fully thread-safe and `Sendable`. All middleware operations are executed
/// in a controlled manner that ensures safe concurrent access. The client can be safely shared
/// across multiple tasks and actors.
///
/// ## Related Documentation
///
/// - <doc:Client-Configuration>: Complete configuration guide
/// - <doc:Middleware-System>: Creating custom middleware
/// - <doc:Core-Networking>: Understanding HTTP primitives
public final class NetworkClient: HTTPFileTransferClient {
  // MARK: - Properties

  let session: URLSession
  private let requestMiddlewares: [any HTTPRequestMiddleware]
  let responseMiddlewares: [any HTTPResponseMiddleware]
  private let errorMiddlewares: [any HTTPErrorMiddleware]
  private let defaultTimeout: RequestTimeout?
  private let trafficRecorder: NetworkTrafficRecorder?

  package var canPerformNativeFileTransfer: Bool {
    errorMiddlewares.isEmpty
  }

  package var canPerformNativeDownload: Bool {
    canPerformNativeFileTransfer && responseMiddlewares.isEmpty
  }

  // MARK: - Initialization

  /// Creates a client with a URL session and optional middleware.
  public init(
    session: URLSession = .shared,
    requestMiddlewares: [any HTTPRequestMiddleware] = [],
    responseMiddlewares: [any HTTPResponseMiddleware] = [],
    errorMiddlewares: [any HTTPErrorMiddleware] = [],
    defaultTimeout: RequestTimeout? = nil,
    trafficRecorder: NetworkTrafficRecorder? = nil
  ) {
    self.session = session
    self.requestMiddlewares = requestMiddlewares
    self.responseMiddlewares = responseMiddlewares
    self.errorMiddlewares = errorMiddlewares
    self.defaultTimeout = defaultTimeout
    self.trafficRecorder = trafficRecorder
  }

  // MARK: - HTTPClient

  /// Executes a request through the configured middleware pipeline.
  /// - Throws: A transport, middleware, or HTTP status error.
  public func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    var currentRequest = request
    do {
      currentRequest = try await applyRequestMiddlewares(currentRequest)
      if let cached = try await cachedResponse(for: currentRequest) {
        return cached
      }
      let response = try await performRequest(currentRequest)
      return try await finishResponse(response, for: currentRequest)
    } catch let error as HTTPError {
      let recovered = try await handleErrorWithMiddlewares(error, for: currentRequest)
      return try await finishResponse(recovered, for: currentRequest)
    } catch is CancellationError {
      throw HTTPError.cancelled(request: currentRequest)
    } catch {
      let httpError = HTTPError(
        category: .network(.serverUnreachable),
        request: currentRequest,
        underlyingError: error
      )
      let recovered = try await handleErrorWithMiddlewares(httpError, for: currentRequest)
      return try await finishResponse(recovered, for: currentRequest)
    }
  }

  // MARK: - Private Methods

  private func cachedResponse(for request: HTTPRequest) async throws -> HTTPResponse? {
    for middleware in requestMiddlewares {
      guard let provider = middleware as? any CachedResponseProviding,
        let response = await provider.cachedResponse(for: request)
      else {
        continue
      }
      return try await finishResponse(
        response,
        for: request,
        skipping: ObjectIdentifier(provider)
      )
    }
    return nil
  }

  func finishResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest,
    skipping skippedMiddleware: ObjectIdentifier? = nil
  ) async throws -> HTTPResponse {
    let processedResponse = try await applyResponseMiddlewares(
      response,
      for: request,
      skipping: skippedMiddleware
    )

    if processedResponse.status.isClientError.rawValue
      || processedResponse.status.isServerError.rawValue
    {
      throw HTTPError.http(
        status: processedResponse.status,
        request: request,
        response: processedResponse
      )
    }

    return processedResponse
  }

  func applyRequestMiddlewares(_ request: HTTPRequest) async throws -> HTTPRequest {
    var currentRequest = request
    for middleware in requestMiddlewares {
      currentRequest = try await middleware.modifyRequest(currentRequest)
    }
    return currentRequest
  }

  private func applyResponseMiddlewares(
    _ response: HTTPResponse,
    for request: HTTPRequest,
    skipping skippedMiddleware: ObjectIdentifier?
  ) async throws -> HTTPResponse {
    var currentResponse = response
    for middleware in responseMiddlewares {
      if let skippedMiddleware,
        let object = middleware as AnyObject?,
        ObjectIdentifier(object) == skippedMiddleware
      {
        continue
      }
      currentResponse = try await middleware.processResponse(currentResponse, for: request)
    }
    return currentResponse
  }
  private func handleErrorWithMiddlewares(
    _ error: HTTPError,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    var currentError = error
    for middleware in errorMiddlewares {
      do {
        return try await middleware.handleError(currentError, for: request)
      } catch let newError as HTTPError {
        currentError = newError
      } catch is CancellationError {
        throw HTTPError.cancelled(request: request)
      } catch {
        currentError = HTTPError(
          category: .network(.serverUnreachable),
          request: request,
          underlyingError: error
        )
      }
    }
    throw currentError
  }

  private func performRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
    let urlRequest = try buildURLRequest(from: request)

    if let trafficRecorder {
      return try await performRecordedRequest(
        urlRequest,
        for: request,
        recorder: trafficRecorder
      )
    }
    return try await performUnrecordedRequest(urlRequest, for: request)
  }
  func buildURLRequest(from httpRequest: HTTPRequest) throws -> URLRequest {
    var urlRequest = URLRequest(url: httpRequest.urlValue)
    urlRequest.httpMethod = httpRequest.method.methodValue
    urlRequest.timeoutInterval =
      (httpRequest.timeoutOverride ?? defaultTimeout)?.rawValue
      ?? session.configuration.timeoutIntervalForRequest
    // Use session's configuration cache policy if set, otherwise default
    urlRequest.cachePolicy = session.configuration.requestCachePolicy

    // Set headers
    for (key, value) in httpRequest.headers {
      urlRequest.setValue(value.rawValue, forHTTPHeaderField: key.rawValue)
    }

    // Set body
    urlRequest.httpBody = httpRequest.bodyValue

    return urlRequest
  }

  // swiftlint:disable:next cyclomatic_complexity
  func mapURLError(_ error: URLError, for request: HTTPRequest) -> HTTPError {
    let networkError: HTTPError.NetworkError

    switch error.code {
    case .notConnectedToInternet:
      networkError = .noConnection

    case .networkConnectionLost:
      networkError = .connectionLost

    case .cannotFindHost, .dnsLookupFailed:
      networkError = .dnsFailure

    case .cannotConnectToHost:
      networkError = .serverUnreachable

    case .timedOut:
      return HTTPError(category: .timeout, request: request, underlyingError: error)

    case .secureConnectionFailed, .serverCertificateUntrusted:
      networkError = .sslError

    case .cancelled:
      return HTTPError(category: .cancelled, request: request, underlyingError: error)

    default:
      networkError = .serverUnreachable
    }

    return HTTPError(
      category: .network(networkError),
      request: request,
      underlyingError: error
    )
  }
}
