import Testing

@testable import NetworkingSSE

@Suite("SSEParser")
struct SSEParserTests {
  @Test("Parses event, id, multiline data, and retry metadata")
  func parsesEventMetadataAndMultilineData() {
    var parser = SSEParser()

    _ = parser.process(line: "id: 42")
    _ = parser.process(line: "event: update")
    _ = parser.process(line: "retry: 1500")
    _ = parser.process(line: "data: first")
    _ = parser.process(line: "data: second")
    let result = parser.process(line: "")

    guard let event = result.event else {
      Issue.record("Expected an SSE event to be dispatched")
      return
    }

    #expect(event.id == "42")
    #expect(event.event == "update")
    #expect(event.data == "first\nsecond")
    #expect(abs((event.retry?.rawValue ?? 0) - 1.5) < 0.000_1)
    #expect(abs((result.retryHint?.rawValue ?? 0) - 1.5) < 0.000_1)
  }

  @Test("Ignores comments and unknown fields while still dispatching final data")
  func ignoresCommentsAndUnknownFields() {
    var parser = SSEParser()

    _ = parser.process(line: ": keep-alive")
    _ = parser.process(line: "unknown: ignored")
    _ = parser.process(line: "retry: not-a-number")
    _ = parser.process(line: "data: tail")
    let result = parser.finish()

    guard let event = result.event else {
      Issue.record("Expected finish() to dispatch the final SSE event")
      return
    }

    #expect(event.data == "tail")
    #expect(result.retryHint == nil)
  }

  @Test("Returns retry hints even when there is no dispatchable event")
  func returnsRetryHintsWithoutDispatchingAnEvent() {
    var parser = SSEParser()

    _ = parser.process(line: "retry: 250")
    let result = parser.process(line: "")

    #expect(result.event == nil)
    #expect(abs((result.retryHint?.rawValue ?? 0) - 0.25) < 0.000_1)
  }
}
