import Testing

@testable import NetworkingTesting
@Suite("MockVerifiable Protocol Tests")
struct MockVerifiableTests {
  // MARK: - verifyCalledOnce() Tests

  @Test("verifyCalledOnce succeeds when called exactly once")
  func acceptsOneCall() async throws {
    let mock = CountingMock()
    await mock.recordCall()

    try await mock.verifyCalledOnce()
  }

  @Test("verifyCalledOnce throws when called twice")
  func rejectsTwoCalls() async {
    let mock = CountingMock()
    await mock.recordCall()
    await mock.recordCall()

    await #expect(throws: MockError.self) {
      try await mock.verifyCalledOnce()
    }
  }

  @Test("verifyCalledOnce throws when never called")
  func rejectsMissingCall() async {
    let mock = CountingMock()

    await #expect(throws: MockError.self) {
      try await mock.verifyCalledOnce()
    }
  }

  // MARK: - verifyCalledExactly() Tests

  @Test("verifyCalledExactly succeeds when count matches")
  func acceptsExactCount() async throws {
    let mock = CountingMock()
    await mock.recordCall()
    await mock.recordCall()
    await mock.recordCall()

    try await mock.verifyCalledExactly(3)
  }

  @Test("verifyCalledExactly throws when count differs")
  func rejectsWrongCount() async {
    let mock = CountingMock()
    await mock.recordCall()

    await #expect(throws: MockError.self) {
      try await mock.verifyCalledExactly(2)
    }
  }

  // MARK: - verifyNeverCalled() Tests

  @Test("verifyNeverCalled succeeds when never called")
  func acceptsNoCalls() async throws {
    let mock = CountingMock()

    try await mock.verifyNeverCalled()
  }

  @Test("verifyNeverCalled throws when called once")
  func verifyNeverCalled_throws_whenCalled() async {
    let mock = CountingMock()
    await mock.recordCall()

    await #expect(throws: MockError.self) {
      try await mock.verifyNeverCalled()
    }
  }

  // MARK: - verifyCalledAtLeast() Tests

  @Test("verifyCalledAtLeast succeeds when called enough times")
  func acceptsMinimumCount() async throws {
    let mock = CountingMock()
    await mock.recordCall()
    await mock.recordCall()
    await mock.recordCall()

    try await mock.verifyCalledAtLeast(2)
  }

  @Test("verifyCalledAtLeast throws when not called enough")
  func rejectsInsufficientCount() async {
    let mock = CountingMock()
    await mock.recordCall()

    await #expect(throws: MockError.self) {
      try await mock.verifyCalledAtLeast(3)
    }
  }

  // MARK: - MockError Tests

  @Test("MockError.notStubbed has descriptive message")
  func describesMissingStub() {
    let error = MockError.notStubbed("getCurrentToken")

    #expect(error.description.contains("Not stubbed"))
    #expect(error.description.contains("getCurrentToken"))
  }

  @Test("MockError.unexpectedCallCount shows expected and actual")
  func describesUnexpectedCount() {
    let error = MockError.unexpectedCallCount(expected: 3, actual: 1)

    #expect(error.description.contains("Expected 3"))
    #expect(error.description.contains("got 1"))
  }

  @Test("MockError.unexpectedArgument has descriptive message")
  func describesUnexpectedArgument() {
    let error = MockError.unexpectedArgument(description: "invalid URL")

    #expect(error.description.contains("Unexpected argument"))
    #expect(error.description.contains("invalid URL"))
  }
}
