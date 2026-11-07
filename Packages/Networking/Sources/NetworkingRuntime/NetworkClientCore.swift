import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Executes HTTP requests with URLSession, ordered middleware, and optional traffic diagnostics.
///
/// Immutable configuration permits concurrent calls; mutable middleware owns its synchronization.
public final class NetworkClient: HTTPFileTransferClient {
  let session: URLSession
  let middleware: HTTPMiddleware
  let configuration: Configuration
  let codec: JSONCodec

  var responseMiddlewares: [any HTTPResponseMiddleware] { middleware.response }
  // File-backed downloads contain metadata only; body middleware requires the buffered pipeline.
  package var canPerformNativeFileTransfer: Bool {
    middleware.error.isEmpty && middleware.response.isEmpty
  }

  /// Creates a client with a session, an ordered pipeline, and transport options.
  public init(
    session: URLSession = .shared,
    middleware: HTTPMiddleware,
    configuration: Configuration = .init(),
    codec: JSONCodec = JSONCodec()
  ) {
    self.session = session
    self.middleware = middleware
    self.configuration = configuration
    self.codec = codec
  }

  /// Executes a request through middleware, transport, response validation, and error recovery.
  /// - Throws: A transport, middleware, or HTTP status error.
  public func execute(_ request: HTTPRequest) async throws(HTTPError) -> HTTPResponse {
    do {
      return try await executeWithRecovery(request)
    } catch let error as HTTPError {
      throw error
    } catch is CancellationError {
      throw HTTPError.cancelled(request: request)
    } catch {
      throw HTTPError(
        category: .custom("Middleware", "HTTP pipeline failed"),
        request: request,
        underlyingError: error
      )
    }
  }

  private func executeWithRecovery(_ request: HTTPRequest) async throws -> HTTPResponse {
    var currentRequest = request
    do {
      currentRequest = try await applyRequestMiddlewares(currentRequest)
      if let cached = try await cachedResponse(for: currentRequest) { return cached }
      let response = try await performRequest(currentRequest)
      return try await finishResponse(response, for: currentRequest)
    } catch let error as HTTPError {
      let recovered = try await handleErrorWithMiddlewares(error, for: currentRequest)
      return try await finishResponse(recovered, for: currentRequest)
    } catch is CancellationError {
      throw HTTPError.cancelled(request: currentRequest)
    } catch {
      let httpError = HTTPError(
        category: .custom("Middleware", "Request or response middleware failed"),
        request: currentRequest,
        underlyingError: error
      )
      let recovered = try await handleErrorWithMiddlewares(httpError, for: currentRequest)
      return try await finishResponse(recovered, for: currentRequest)
    }
  }

  private func cachedResponse(for request: HTTPRequest) async throws -> HTTPResponse? {
    for item in middleware.request {
      guard let provider = item as? any CachedResponseProviding,
        let response = await provider.cachedResponse(for: request)
      else { continue }
      return try await finishResponse(response, for: request, skipping: ObjectIdentifier(provider))
    }
    return nil
  }

  func finishResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest,
    skipping skippedMiddleware: ObjectIdentifier? = nil
  ) async throws -> HTTPResponse {
    try validateResponseSize(response)
    let processed = try await applyResponseMiddlewares(
      response,
      for: request,
      skipping: skippedMiddleware
    )
    try validateResponseSize(processed)
    if processed.status.isClientError.rawValue || processed.status.isServerError.rawValue {
      throw HTTPError.http(status: processed.status, request: request, response: processed)
    }
    return processed
  }

  func applyRequestMiddlewares(_ request: HTTPRequest) async throws -> HTTPRequest {
    var result = try prepare(request)
    for item in middleware.request { result = try await item.modifyRequest(result) }
    return result
  }

  private func applyResponseMiddlewares(
    _ response: HTTPResponse,
    for request: HTTPRequest,
    skipping skippedMiddleware: ObjectIdentifier?
  ) async throws -> HTTPResponse {
    var result = response
    for item in middleware.response {
      if let skippedMiddleware,
        let object = item as AnyObject?,
        ObjectIdentifier(object) == skippedMiddleware
      {
        continue
      }
      result = try await item.processResponse(result, for: request)
    }
    return result
  }

  private func handleErrorWithMiddlewares(
    _ error: HTTPError,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    var current = error
    for item in middleware.error {
      do {
        return try await item.handleError(current, for: request)
      } catch let failure as HTTPError {
        current = failure
      } catch is CancellationError {
        throw HTTPError.cancelled(request: request)
      } catch {
        current = HTTPError(
          category: .custom("Middleware", "Error recovery middleware failed"),
          request: request,
          underlyingError: error
        )
      }
    }
    throw current
  }
}
