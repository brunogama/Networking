import Foundation
import Networking

struct TransferExpectation: Sendable {
  let count: Int
  let bytes: Int64
  let operation: String
}

enum BenchmarkIntegrity {
  enum Failure: LocalizedError {
    case missingPayload(operation: String)
    case unexpectedPayloadSize(operation: String, expected: Int, actual: Int)
    case unexpectedPayloadContents(operation: String)
    case incompleteTransfer(
      operation: String,
      expected: Int64,
      actual: Int64,
      wasSuccessful: Bool
    )
    case unexpectedCount(operation: String, expected: Int, actual: Int)

    var errorDescription: String? {
      switch self {
      case .missingPayload(let operation):
        "\(operation) returned no payload."
      case .unexpectedPayloadSize(let operation, let expected, let actual):
        "\(operation) returned \(actual) bytes; expected \(expected)."
      case .unexpectedPayloadContents(let operation):
        "\(operation) payload did not match the fixture."
      case .incompleteTransfer(
        let operation,
        let expected,
        let actual,
        let wasSuccessful
      ):
        "\(operation) transferred \(actual) of \(expected) bytes "
          + "(successful: \(wasSuccessful))."
      case .unexpectedCount(let operation, let expected, let actual):
        "\(operation) returned \(actual) items; expected \(expected)."
      }
    }
  }

  static func validatePayload(
    _ actual: String?,
    matches expected: String,
    operation: String
  ) throws {
    guard let actual else { throw Failure.missingPayload(operation: operation) }
    guard actual.utf8.count == expected.utf8.count else {
      throw Failure.unexpectedPayloadSize(
        operation: operation,
        expected: expected.utf8.count,
        actual: actual.utf8.count
      )
    }
    guard actual == expected else {
      throw Failure.unexpectedPayloadContents(operation: operation)
    }
  }

  static func validatePayload(
    _ actual: Data?,
    matches expected: Data,
    operation: String
  ) throws {
    guard let actual else { throw Failure.missingPayload(operation: operation) }
    guard actual.count == expected.count else {
      throw Failure.unexpectedPayloadSize(
        operation: operation,
        expected: expected.count,
        actual: actual.count
      )
    }
    guard actual == expected else {
      throw Failure.unexpectedPayloadContents(operation: operation)
    }
  }

  static func validateTransfer(
    _ result: FileTransferResult,
    expectedBytes: Int64,
    operation: String
  ) throws {
    let actualBytes = result.bytesTransferred.rawValue
    let wasSuccessful = result.isSuccessful.rawValue
    guard wasSuccessful, actualBytes == expectedBytes else {
      throw Failure.incompleteTransfer(
        operation: operation,
        expected: expectedBytes,
        actual: actualBytes,
        wasSuccessful: wasSuccessful
      )
    }
  }

  static func validateTransfers(
    _ results: [FileTransferResult],
    expecting expectation: TransferExpectation
  ) throws {
    try validateCount(
      results.count,
      matches: expectation.count,
      operation: expectation.operation
    )
    for result in results {
      try validateTransfer(
        result,
        expectedBytes: expectation.bytes,
        operation: expectation.operation
      )
    }
  }

  static func validateCount(
    _ actual: Int,
    matches expected: Int,
    operation: String
  ) throws {
    guard actual == expected else {
      throw Failure.unexpectedCount(
        operation: operation,
        expected: expected,
        actual: actual
      )
    }
  }

  static func validateFile(
    at fileURL: URL,
    matches expected: Data,
    operation: String
  ) throws {
    let actual = try Data(contentsOf: fileURL)
    try validatePayload(actual, matches: expected, operation: operation)
  }
}
