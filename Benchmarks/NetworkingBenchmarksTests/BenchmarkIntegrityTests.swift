import Foundation
import Networking
import Testing
@testable import NetworkingBenchmarksCore

struct BenchmarkIntegrityTests {
  @Test("Accepts an exact fixture payload")
  func acceptsExactPayload() throws {
    let expected = Data(repeating: 0x72, count: 1_024)

    try BenchmarkIntegrity.validatePayload(
      Data(repeating: 0x72, count: 1_024),
      matches: expected,
      operation: "request"
    )
  }

  @Test("Rejects a missing response payload")
  func rejectsMissingPayload() {
    #expect(throws: BenchmarkIntegrity.Failure.self) {
      try BenchmarkIntegrity.validatePayload(
        nil,
        matches: Data([0x72]),
        operation: "request"
      )
    }
  }

  @Test("Rejects a modified text payload")
  func rejectsChangedTextPayload() {
    #expect(throws: BenchmarkIntegrity.Failure.self) {
      try BenchmarkIntegrity.validatePayload(
        "other",
        matches: "event",
        operation: "SSE"
      )
    }
  }

  @Test("Rejects a truncated fixture payload")
  func rejectsTruncatedPayload() {
    #expect(throws: BenchmarkIntegrity.Failure.self) {
      try BenchmarkIntegrity.validatePayload(
        Data(repeating: 0x72, count: 1_023),
        matches: Data(repeating: 0x72, count: 1_024),
        operation: "request"
      )
    }
  }

  @Test("Rejects a same-sized payload with different contents")
  func rejectsChangedPayload() {
    #expect(throws: BenchmarkIntegrity.Failure.self) {
      try BenchmarkIntegrity.validatePayload(
        Data(repeating: 0x64, count: 1_024),
        matches: Data(repeating: 0x72, count: 1_024),
        operation: "request"
      )
    }
  }

  @Test("Accepts a successful transfer with the expected byte count")
  func acceptsCompleteTransfer() throws {
    let result = FileTransferResult(
      transferId: TransferIdentifier(),
      bytesTransferred: 65_536,
      duration: 1,
      averageSpeed: 65_536,
      isSuccessful: true
    )

    try BenchmarkIntegrity.validateTransfer(
      result,
      expectedBytes: 65_536,
      operation: "upload"
    )
  }

  @Test("Rejects a result count that differs from the requested workload")
  func rejectsUnexpectedCount() {
    #expect(throws: BenchmarkIntegrity.Failure.self) {
      try BenchmarkIntegrity.validateCount(
        7,
        matches: 8,
        operation: "batch upload"
      )
    }
  }

  @Test("Rejects a transfer marked unsuccessful")
  func rejectsUnsuccessfulTransfer() {
    let result = FileTransferResult(
      transferId: TransferIdentifier(),
      bytesTransferred: 65_536,
      duration: 1,
      averageSpeed: 65_536,
      isSuccessful: false
    )

    #expect(throws: BenchmarkIntegrity.Failure.self) {
      try BenchmarkIntegrity.validateTransfer(
        result,
        expectedBytes: 65_536,
        operation: "upload"
      )
    }
  }

  @Test("Rejects an incomplete transfer")
  func rejectsIncompleteTransfer() {
    let result = FileTransferResult(
      transferId: TransferIdentifier(),
      bytesTransferred: 65_535,
      duration: 1,
      averageSpeed: 65_535,
      isSuccessful: true
    )

    #expect(throws: BenchmarkIntegrity.Failure.self) {
      try BenchmarkIntegrity.validateTransfer(
        result,
        expectedBytes: 65_536,
        operation: "upload"
      )
    }
  }
}
