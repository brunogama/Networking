// swiftlint:disable file_length
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
public final class NetworkClient: HTTPClient {
  // MARK: - Properties

  private let session: URLSession
  private let requestMiddlewares: [any HTTPRequestMiddleware]
  private let responseMiddlewares: [any HTTPResponseMiddleware]
  private let errorMiddlewares: [any HTTPErrorMiddleware]

  // MARK: - Initialization

  public init(
    session: URLSession = .shared,
    requestMiddlewares: [any HTTPRequestMiddleware] = [],
    responseMiddlewares: [any HTTPResponseMiddleware] = [],
    errorMiddlewares: [any HTTPErrorMiddleware] = []
  ) {
    self.session = session
    self.requestMiddlewares = requestMiddlewares
    self.responseMiddlewares = responseMiddlewares
    self.errorMiddlewares = errorMiddlewares
  }

  // MARK: - HTTPClient

  public func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    do {
      // Apply request middlewares
      let processedRequest = try await applyRequestMiddlewares(request)

      // Execute the request
      let response = try await performRequest(processedRequest)
      // Apply response middlewares
      return try await applyResponseMiddlewares(response, for: processedRequest)
    } catch let error as HTTPError {
      // Try to handle error with middlewares
      return try await handleErrorWithMiddlewares(error, for: request)
    } catch {
      // Convert other errors to HTTPError
      let httpError = HTTPError(
        category: .network(.serverUnreachable),
        request: request,
        underlyingError: error
      )
      return try await handleErrorWithMiddlewares(httpError, for: request)
    }
  }

  // MARK: - Private Methods

  private func applyRequestMiddlewares(_ request: HTTPRequest) async throws -> HTTPRequest {
    var currentRequest = request
    for middleware in requestMiddlewares {
      currentRequest = try await middleware.modifyRequest(currentRequest)
    }
    return currentRequest
  }

  private func applyResponseMiddlewares(
    _ response: HTTPResponse,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    var currentResponse = response
    for middleware in responseMiddlewares {
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

    do {
      let (data, response) = try await session.data(for: urlRequest)

      guard let httpResponse = response as? HTTPURLResponse else {
        throw HTTPError(
          category: .network(.serverUnreachable),
          request: request
        )
      }

      return HTTPResponse(
        request: request,
        httpURLResponse: httpResponse,
        body: HTTPBody(data)
      )
    } catch let error as URLError {
      throw mapURLError(error, for: request)
    }
  }
  private func buildURLRequest(from httpRequest: HTTPRequest) throws -> URLRequest {
    var urlRequest = URLRequest(url: httpRequest.urlValue)
    urlRequest.httpMethod = httpRequest.method.methodValue
    urlRequest.timeoutInterval = httpRequest.timeoutInterval
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
  private func mapURLError(_ error: URLError, for request: HTTPRequest) -> HTTPError {
    let networkError: HTTPError.NetworkError

    switch error.code {
    case .notConnectedToInternet, .networkConnectionLost:
      networkError = .noConnection

    case .cannotFindHost, .dnsLookupFailed:
      networkError = .dnsFailure

    case .cannotConnectToHost, .timedOut:
      networkError = .serverUnreachable

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
