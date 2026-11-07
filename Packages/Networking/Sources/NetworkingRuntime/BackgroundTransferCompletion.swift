import Foundation

enum BackgroundTransferCompletion: Sendable {
  case success(URL)
  case failure(any Error, downloadedFileURL: URL?)

  var downloadedFileURL: URL? {
    switch self {
    case .success(let fileURL):
      return fileURL
    case .failure(_, let fileURL):
      return fileURL
    }
  }
}
