import NetworkingCore

/// Actor to manage jitter state in a thread-safe way.
actor JitterState {
  private(set) var lastDelay: RetryDelay = 0

  func setLastDelay(_ delay: RetryDelay) {
    lastDelay = delay
  }
}
