import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension NetworkClient {
  package func upload(
    _ request: HTTPRequest,
    fromFile fileURL: URL,
    progress: (@Sendable (HTTPFileTransferProgress) -> Void)?
  ) async throws -> HTTPResponse {
    let preparedRequest = try await applyRequestMiddlewares(request)
    var urlRequest = try buildURLRequest(from: preparedRequest)
    urlRequest.httpBody = nil
    let exchange = HTTPExchange<ExchangePrepared>(diagnostics: configuration.diagnostics)
      .start(preparedRequest)
    let result: HTTPResponse
    do {
      let (data, response) = try await session.upload(
        for: urlRequest,
        fromFile: fileURL,
        delegate: HTTPTaskDelegate(
          progress: progress,
          diagnostics: configuration.diagnostics,
          traceID: exchange.id
        )
      )
      guard let httpResponse = response as? HTTPURLResponse else {
        throw HTTPError.network(.serverUnreachable, request: preparedRequest)
      }
      result = HTTPResponse(
        request: preparedRequest,
        httpURLResponse: httpResponse,
        body: HTTPBody(data)
      )
      exchange.finish(result)
    } catch {
      exchange.fail(error)
      throw transportError(error, for: preparedRequest)
    }
    return try await finishResponse(result, for: preparedRequest)
  }

  package func download(
    _ request: HTTPRequest,
    progress: (@Sendable (HTTPFileTransferProgress) -> Void)?
  ) async throws -> HTTPFileDownload {
    let preparedRequest = try await applyRequestMiddlewares(request)
    let urlRequest = try buildURLRequest(from: preparedRequest)
    if let limit = configuration.maximumResponseBytes, limit < 0 { throw responseLimitError() }
    let exchange = HTTPExchange<ExchangePrepared>(diagnostics: configuration.diagnostics)
      .start(preparedRequest)
    let delegate = HTTPTaskDelegate(
      progress: progress,
      diagnostics: configuration.diagnostics,
      traceID: exchange.id,
      maximumDownloadBytes: configuration.maximumResponseBytes.map(Int64.init)
    )
    do {
      let downloaded = try await session.download(for: urlRequest, delegate: delegate)
      let result = try await completedDownload(downloaded, for: preparedRequest)
      exchange.finish(result.response)
      return result
    } catch {
      let failure =
        delegate.exceededDownloadLimit
        ? responseLimitError() : transportError(error, for: preparedRequest)
      exchange.fail(failure)
      throw failure
    }
  }

  private func completedDownload(
    _ downloaded: (URL, URLResponse),
    for request: HTTPRequest
  ) async throws -> HTTPFileDownload {
    do {
      guard let httpResponse = downloaded.1 as? HTTPURLResponse else {
        throw HTTPError.network(.serverUnreachable, request: request)
      }
      try validateDownloadedFile(downloaded.0)
      try Task.checkCancellation()
      let metadata = HTTPResponse(request: request, httpURLResponse: httpResponse, body: nil)
      let response = try await processDownloadedResponse(metadata, for: request)
      try Task.checkCancellation()
      return HTTPFileDownload(temporaryFileURL: downloaded.0, response: response)
    } catch {
      try? FileManager.default.removeItem(at: downloaded.0)
      throw error
    }
  }

  private func validateDownloadedFile(_ fileURL: URL) throws {
    guard let limit = configuration.maximumResponseBytes else { return }
    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    guard let bytes = attributes[.size] as? NSNumber else {
      throw CocoaError(.fileReadCorruptFile)
    }
    guard bytes.int64Value <= Int64(limit) else { throw responseLimitError() }
  }

  private func processDownloadedResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    try validateResponseSize(response)
    var result = response
    for middleware in responseMiddlewares where !(middleware is any CachedResponseProviding) {
      result = try await middleware.processResponse(result, for: request)
    }
    try validateResponseSize(result)
    if result.status.isClientError.rawValue || result.status.isServerError.rawValue {
      throw HTTPError.http(status: result.status, request: request, response: result)
    }
    return result
  }

}
