import Foundation

#if !os(Linux)
extension BackgroundTransferDelegate {
  enum Event: Sendable {
    case progress(URLSessionDownloadTask, Int64, Int64)
    case completion(URLSessionTask, BackgroundTransferCompletion)
  }
}
#endif
