import Foundation
import Testing

@testable import Networking

/// Tests for MockVerifiable protocol default implementations
///
/// Verifies that all mock verification methods work correctly across
/// different call counts and error conditions.
@Suite("MockVerifiable Protocol Tests")
struct MockVerifiableTests {

  // MARK: - Helper Mock

  /// Simple mock implementation for testing MockVerifiable protocol
  private final class SimpleMock: MockVerifiable, @unchecked Sendable {
    private let queue = DispatchQueue(label: "test.mock", attributes: .concurrent)
    private var _callCount: Int = 0

    var callCount: Int {
      queue.sync { _callCount }
    }

    func recordCall() {
      queue.sync(flags: .barrier) { _callCount += 1 }
    }

    func reset() {
      queue.sync(flags: .barrier) { _callCount = 0 }
    }
  }

  // MARK: - verifyCalledOnce() Tests

  @Test("verifyCalledOnce succeeds when called exactly once")
  func verifyCalledOnce_succeeds_whenCalledOnce() async throws {
    let mock = SimpleMock()
    mock.recordCall()

    try await mock.verifyCalledOnce()
  }

  @Test("verifyCalledOnce throws when called twice")
  func verifyCalledOnce_throws_whenCalledTwice() async {
    let mock = SimpleMock()
    mock.recordCall()
    mock.recordCall()

    await #expect(throws: MockError.self) {
      try await mock.verifyCalledOnce()
    }
  }

  @Test("verifyCalledOnce throws when never called")
  func verifyCalledOnce_throws_whenNeverCalled() async {
    let mock = SimpleMock()

    await #expect(throws: MockError.self) {
      try await mock.verifyCalledOnce()
    }
  }

  // MARK: - verifyCalledExactly() Tests

  @Test("verifyCalledExactly succeeds when count matches")
  func verifyCalledExactly_succeeds_whenCountMatches() async throws {
    let mock = SimpleMock()
    mock.recordCall()
    mock.recordCall()
    mock.recordCall()

    try await mock.verifyCalledExactly(3)
  }

  @Test("verifyCalledExactly throws when count differs")
  func verifyCalledExactly_throws_whenCountDiffers() async {
    let mock = SimpleMock()
    mock.recordCall()

    await #expect(throws: MockError.self) {
      try await mock.verifyCalledExactly(2)
    }
  }

  // MARK: - verifyNeverCalled() Tests

  @Test("verifyNeverCalled succeeds when never called")
  func verifyNeverCalled_succeeds_whenNeverCalled() async throws {
    let mock = SimpleMock()

    try await mock.verifyNeverCalled()
  }

  @Test("verifyNeverCalled throws when called once")
  func verifyNeverCalled_throws_whenCalled() async {
    let mock = SimpleMock()
    mock.recordCall()

    await #expect(throws: MockError.self) {
      try await mock.verifyNeverCalled()
    }
  }

  // MARK: - verifyCalledAtLeast() Tests

  @Test("verifyCalledAtLeast succeeds when called enough times")
  func verifyCalledAtLeast_succeeds_whenCalledEnough() async throws {
    let mock = SimpleMock()
    mock.recordCall()
    mock.recordCall()
    mock.recordCall()

    try await mock.verifyCalledAtLeast(2)
  }

  @Test("verifyCalledAtLeast throws when not called enough")
  func verifyCalledAtLeast_throws_whenNotEnough() async {
    let mock = SimpleMock()
    mock.recordCall()

    await #expect(throws: MockError.self) {
      try await mock.verifyCalledAtLeast(3)
    }
  }

  // MARK: - MockError Tests

  @Test("MockError.notStubbed has descriptive message")
  func mockError_notStubbed_hasDescriptiveMessage() {
    let error = MockError.notStubbed("getCurrentToken")

    #expect(error.description.contains("Not stubbed"))
    #expect(error.description.contains("getCurrentToken"))
  }

  @Test("MockError.unexpectedCallCount shows expected and actual")
  func mockError_unexpectedCallCount_showsExpectedAndActual() {
    let error = MockError.unexpectedCallCount(expected: 3, actual: 1)

    #expect(error.description.contains("Expected 3"))
    #expect(error.description.contains("got 1"))
  }

  @Test("MockError.unexpectedArgument has descriptive message")
  func mockError_unexpectedArgument_hasDescriptiveMessage() {
    let error = MockError.unexpectedArgument(description: "invalid URL")

    #expect(error.description.contains("Unexpected argument"))
    #expect(error.description.contains("invalid URL"))
  }
}
