enum TransferProgressBenchmarkFailure: Error {
  case noProgressCallbacks
  case backpressureNotObserved
}

enum TransferProgressWorkload {
  static let uploadBytes = 8 * 1_024 * 1_024
  static let uploadCount = 8
  static let sampleCount = 3
  static let sseBufferSize = 32
  static let consumerDelay = Duration.milliseconds(2)
  static let totalUploadBytes = Int64(uploadBytes * uploadCount)

  static func uploadExpectation(operation: String) -> TransferExpectation {
    TransferExpectation(
      count: uploadCount,
      bytes: Int64(uploadBytes),
      operation: operation
    )
  }
}
