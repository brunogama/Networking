import Foundation
import NetworkingCore

/// Reports truthful completion progress for requests executed through the middleware pipeline.
///
/// URLSession task progress is exposed by ``FileTransferOperations``. Response middleware only
/// receives a response after its body has arrived, so this type does not synthesize intermediate
/// byte counts.
public actor ProgressTrackingMiddleware: HTTPRequestMiddleware, HTTPResponseMiddleware {
  private let configuration: ProgressTrackingConfiguration
  private var callbacks: [UUID: ProgressCallback]

  public init(configuration: ProgressTrackingConfiguration = .default) {
    self.configuration = configuration
    self.callbacks = [:]
  }

  private init(
    configuration: ProgressTrackingConfiguration,
    requestId: HTTPRequestID,
    callback: @escaping ProgressCallback
  ) {
    self.configuration = configuration
    self.callbacks = [requestId.rawValue: callback]
  }

  /// Registers a completion progress callback for a specific request.
  public func setProgressCallback(
    for requestId: HTTPRequestID,
    callback: @escaping ProgressCallback
  ) {
    callbacks[requestId.rawValue] = callback
  }

  public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    request
  }

  public func processResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    guard let callback = callbacks.removeValue(forKey: request.id.rawValue) else {
      return response
    }

    guard let transferredBytes = completedByteCount(for: response, request: request) else {
      return response
    }

    callback(
      TransferProgress(
        totalBytes: TransferByteCount(transferredBytes),
        transferredBytes: TransferByteCount(transferredBytes),
        phase: .completed
      )
    )
    return response
  }

  private func completedByteCount(for response: HTTPResponse, request: HTTPRequest) -> Int64? {
    if configuration.trackUploadProgress.rawValue,
      let body = request.body,
      Int64(body.count.rawValue) >= configuration.minimumBytesThreshold.rawValue
    {
      return Int64(body.count.rawValue)
    }

    guard configuration.trackDownloadProgress.rawValue,
      request.method == .get,
      let body = response.body,
      Int64(body.count.rawValue) >= configuration.minimumBytesThreshold.rawValue
    else {
      return nil
    }

    return Int64(body.count.rawValue)
  }
}

extension ProgressTrackingMiddleware {
  static func configured(
    for requestId: HTTPRequestID,
    callback: @escaping ProgressCallback,
    configuration: ProgressTrackingConfiguration
  ) -> ProgressTrackingMiddleware {
    ProgressTrackingMiddleware(
      configuration: configuration,
      requestId: requestId,
      callback: callback
    )
  }
}
