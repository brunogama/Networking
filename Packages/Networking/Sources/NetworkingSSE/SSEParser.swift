import Foundation

struct SSEDispatchResult {
  let event: SSEEvent?
  let retryHint: SSEReconnectDelay?

  static let none = Self(event: nil, retryHint: nil)
}

struct SSEParser {
  private enum Field: String {
    case data
    case event
    case id
    case retry
  }

  private var dataLines: [String] = []
  private var eventName: SSEEventName?
  private var eventID: SSEEventID?
  private var retry: SSEReconnectDelay?

  mutating func process(line: String) -> SSEDispatchResult {
    if line.isEmpty {
      return dispatchEvent()
    }

    if line.first == ":" {
      return .none
    }

    let parsedField = parse(line: line)
    guard let field = Field(rawValue: parsedField.field) else {
      return .none
    }

    apply(field: field, value: parsedField.value)
    return .none
  }

  mutating func finish() -> SSEDispatchResult {
    dispatchEvent()
  }

  private mutating func dispatchEvent() -> SSEDispatchResult {
    let retryHint = retry
    defer { resetCurrentEvent() }

    guard !dataLines.isEmpty else {
      return SSEDispatchResult(event: nil, retryHint: retryHint)
    }

    return SSEDispatchResult(
      event: SSEEvent(
        id: eventID,
        event: eventName,
        data: SSEEventPayload(dataLines.joined(separator: "\n")),
        retry: retryHint
      ),
      retryHint: retryHint
    )
  }

  private func parse(line: String) -> (field: String, value: String) {
    let components = line.split(
      separator: ":",
      maxSplits: 1,
      omittingEmptySubsequences: false
    )

    guard let field = components.first else {
      return ("", "")
    }

    guard components.count == 2 else {
      return (String(field), "")
    }

    var value = String(components[1])
    if value.first == " " {
      value.removeFirst()
    }

    return (String(field), value)
  }

  private mutating func apply(field: Field, value: String) {
    switch field {
    case .data:
      dataLines.append(value)

    case .event:
      eventName = value.isEmpty ? nil : SSEEventName(value)

    case .id:
      updateEventID(value)

    case .retry:
      updateRetry(value)
    }
  }

  private mutating func updateEventID(_ value: String) {
    guard !value.unicodeScalars.contains(where: { $0.value == 0 }) else {
      return
    }

    eventID = SSEEventID(value)
  }

  private mutating func updateRetry(_ value: String) {
    guard let milliseconds = Int(value), milliseconds >= 0 else {
      return
    }

    retry = SSEReconnectDelay(TimeInterval(milliseconds) / 1000.0)
  }

  private mutating func resetCurrentEvent() {
    dataLines.removeAll(keepingCapacity: true)
    eventName = nil
    eventID = nil
    retry = nil
  }
}
