struct SSEConnectionState: ~Copyable {
  var lastEventID: SSELastEventID?
  var serverRetryHint: SSEReconnectDelay?
  var reconnectAttempts: SSEReconnectAttempt = 0

  init(configuration: SSEConfiguration) {
    lastEventID = configuration.lastEventID
  }
}
