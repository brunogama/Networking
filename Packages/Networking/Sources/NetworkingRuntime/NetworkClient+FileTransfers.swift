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
    do {
      let (data, response) = try await session.upload(
        for: urlRequest,
        fromFile: fileURL,
        delegate: FileTransferTaskDelegate(progress: progress)
      )
      guard let httpResponse = response as? HTTPURLResponse else {
        throw HTTPError.network(.serverUnreachable, request: preparedRequest)
      }
      return try await finishResponse(
        HTTPResponse(
          request: preparedRequest,
          httpURLResponse: httpResponse,
          body: HTTPBody(data)
        ),
        for: preparedRequest
      )
    } catch let error as URLError {
      throw mapURLError(error, for: preparedRequest)
    } catch is CancellationError {
      throw HTTPError.cancelled(request: preparedRequest)
    }
  }

  package func download(
    _ request: HTTPRequest,
    progress: (@Sendable (HTTPFileTransferProgress) -> Void)?
  ) async throws -> HTTPFileDownload {
    let preparedRequest = try await applyRequestMiddlewares(request)
    let urlRequest = try buildURLRequest(from: preparedRequest)
    do {
      let (fileURL, response) = try await session.download(
        for: urlRequest,
        delegate: FileTransferTaskDelegate(progress: progress)
      )
      do {
        guard let httpResponse = response as? HTTPURLResponse else {
          throw HTTPError.network(.serverUnreachable, request: preparedRequest)
        }
        let result = HTTPResponse(
          request: preparedRequest,
          httpURLResponse: httpResponse,
          body: HTTPBody(Data())
        )
        let processedResponse = try await processDownloadedResponse(result, for: preparedRequest)
        return HTTPFileDownload(temporaryFileURL: fileURL, response: processedResponse)
      } catch {
        try? FileManager.default.removeItem(at: fileURL)
        throw error
      }
    } catch let error as URLError {
      throw mapURLError(error, for: preparedRequest)
    } catch is CancellationError {
      throw HTTPError.cancelled(request: preparedRequest)
    }
  }

  private func processDownloadedResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    var result = response
    for middleware in responseMiddlewares where !(middleware is any CachedResponseProviding) {
      result = try await middleware.processResponse(result, for: request)
    }
    if result.status.isClientError.rawValue || result.status.isServerError.rawValue {
      throw HTTPError.http(status: result.status, request: request, response: result)
    }
    return result
  }

}
