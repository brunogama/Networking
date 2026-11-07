struct SSEDispatchResult {
  let event: SSEEvent?
  let retryHint: SSEReconnectDelay?
  let idUpdate: SSEEventID?

  static let none = Self(event: nil, retryHint: nil, idUpdate: nil)
}
