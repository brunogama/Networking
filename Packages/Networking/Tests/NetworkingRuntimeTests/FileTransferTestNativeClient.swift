import Foundation
import XCTest
@testable import NetworkingRuntime
import NetworkingTesting

actor FileTransferTestNativeClient: HTTPFileTransferClient {

  private let downloadedData: Data
  private var storedCalls = Calls()
  nonisolated let canPerformNativeFileTransfer: Bool

  init(downloadedData: Data, canPerformNativeFileTransfer: Bool = true) {
    self.downloadedData = downloadedData
    self.canPerformNativeFileTransfer = canPerformNativeFileTransfer
  }

  var calls: Calls {
    storedCalls
  }

  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    storedCalls.execute += 1
    return HTTPResponse(request: request, status: .ok, body: HTTPBody(downloadedData))
  }

  func upload(
    _ request: HTTPRequest,
    fromFile fileURL: URL,
    progress: (@Sendable (HTTPFileTransferProgress) -> Void)?
  ) async throws -> HTTPResponse {
    storedCalls.upload += 1
    storedCalls.uploadedFileURL = fileURL
    storedCalls.uploadRequestHasBody = request.body != nil
    let fileSize = try Data(contentsOf: fileURL).count
    progress?(
      HTTPFileTransferProgress(transferredBytes: Int64(fileSize), totalBytes: Int64(fileSize))
    )
    return HTTPResponse(request: request, status: .ok, headers: HTTPHeaders())
  }

  func download(
    _ request: HTTPRequest,
    progress: (@Sendable (HTTPFileTransferProgress) -> Void)?
  ) async throws -> HTTPFileDownload {
    storedCalls.download += 1
    let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString
    )
    try downloadedData.write(to: temporaryURL)
    progress?(
      HTTPFileTransferProgress(
        transferredBytes: Int64(downloadedData.count),
        totalBytes: Int64(downloadedData.count)
      )
    )
    return HTTPFileDownload(
      temporaryFileURL: temporaryURL,
      response: HTTPResponse(request: request, status: .ok, headers: HTTPHeaders())
    )
  }
}
