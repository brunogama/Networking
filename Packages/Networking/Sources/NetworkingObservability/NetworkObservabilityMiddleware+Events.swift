import NetworkingRuntime
import Foundation

#if canImport(OSLog)
import OSLog

extension NetworkObservabilityMiddleware {
  public func recordCustomEvent(_ event: ObservabilityEvent) async {
    await metricsCollector.recordEvent(event)
  }

  public func recordRetryAttempt(for requestId: HTTPRequestID, attempt: RetryAttemptCount) async {
    if var trace = activeTraces[requestId] {
      trace.retryCount = attempt
      activeTraces[requestId] = trace

      let event = ObservabilityEvent.requestRetried(trace.context, retryAttempt: attempt)
      await metricsCollector.recordEvent(event)
    }
  }

  public func recordCacheEvent(
    for requestId: HTTPRequestID,
    hit: CacheDecision,
    cacheKey: CacheKey
  ) async {
    if let trace = activeTraces[requestId] {
      let event =
        hit.rawValue
        ? ObservabilityEvent.cacheHit(trace.context, cacheKey: cacheKey)
        : ObservabilityEvent.cacheMiss(trace.context, cacheKey: cacheKey)
      await metricsCollector.recordEvent(event)
    }
  }
}

#endif  // canImport(OSLog)
