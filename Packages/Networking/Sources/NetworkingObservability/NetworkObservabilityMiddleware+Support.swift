import NetworkingRuntime
import Foundation

#if canImport(OSLog)
import OSLog

extension NetworkObservabilityMiddleware {
  public enum ObservabilityEvent: Sendable {
    case requestStarted(RequestContext)
    case requestCompleted(RequestContext, ResponseContext)
    case requestFailed(RequestContext, ErrorContext)
    case requestRetried(RequestContext, retryAttempt: RetryAttemptCount)
    case circuitBreakerTripped(endpoint: EndpointIdentifier, reason: CircuitBreakerReason)
    case cacheHit(RequestContext, cacheKey: CacheKey)
    case cacheMiss(RequestContext, cacheKey: CacheKey)
    case rateLimitHit(RequestContext, limit: RequestCount, windowSeconds: MeasurementDuration)
    case authenticationsRefreshed(RequestContext)
    case middlewareError(RequestContext, middlewareName: MiddlewareName, error: HTTPErrorDetail)
  }

  public struct Configuration: Sendable {
    public let collectHeaders: CollectHeadersFlag
    public let collectBodyInfo: CollectBodyInfoFlag
    public let enableTracing: EnableTracingFlag
    public let collectBusinessMetrics: CollectBusinessMetricsFlag
    public let tracingSampleRate: TracingSampleRate
    public let maxActiveTraces: MaxActiveTraceCount
    public let metricsReportingInterval: MetricsReportingInterval
    public let globalTags: [ObservabilityTagName: ObservabilityTagValue]
    public let shouldObserve: @Sendable (HTTPRequest) -> ObservationDecision
    public let customTagExtractor:
      @Sendable (HTTPRequest) -> [ObservabilityTagName: ObservabilityTagValue]
    public let redactedHeaders: Set<RedactedHeaderName>
    public let enableRealTimeMetrics: EnableRealtimeMetricsFlag
    public let metricsRetentionDuration: MetricsRetentionDuration

    public init(
      collectHeaders: CollectHeadersFlag = true,
      collectBodyInfo: CollectBodyInfoFlag = true,
      enableTracing: EnableTracingFlag = true,
      collectBusinessMetrics: CollectBusinessMetricsFlag = true,
      tracingSampleRate: TracingSampleRate = 1.0,
      maxActiveTraces: MaxActiveTraceCount = 1000,
      metricsReportingInterval: MetricsReportingInterval = 60.0,
      globalTags: [ObservabilityTagName: ObservabilityTagValue] = [:],
      shouldObserve: @escaping @Sendable (HTTPRequest) -> ObservationDecision = { _ in true },
      customTagExtractor:
        @escaping @Sendable (HTTPRequest) -> [ObservabilityTagName: ObservabilityTagValue] = { _ in
          [:]
        },
      redactedHeaders: Set<RedactedHeaderName> = ["Authorization", "Cookie", "X-API-Key"],
      enableRealTimeMetrics: EnableRealtimeMetricsFlag = true,
      metricsRetentionDuration: MetricsRetentionDuration = 3600.0
    ) {
      self.collectHeaders = collectHeaders
      self.collectBodyInfo = collectBodyInfo
      self.enableTracing = enableTracing
      self.collectBusinessMetrics = collectBusinessMetrics
      self.tracingSampleRate = TracingSampleRate(max(0.0, min(1.0, tracingSampleRate.rawValue)))
      self.maxActiveTraces = maxActiveTraces
      self.metricsReportingInterval = metricsReportingInterval
      self.globalTags = globalTags
      self.shouldObserve = shouldObserve
      self.customTagExtractor = customTagExtractor
      self.redactedHeaders = redactedHeaders
      self.enableRealTimeMetrics = enableRealTimeMetrics
      self.metricsRetentionDuration = metricsRetentionDuration
    }
  }

  struct ActiveTrace: Sendable {
    let context: RequestContext
    let startTime: Date
    let traceId: TraceIdentifier
    let spanId: SpanIdentifier
    var retryCount: RetryAttemptCount
    let customTags: [ObservabilityTagName: ObservabilityTagValue]

    init(
      context: RequestContext,
      traceId: TraceIdentifier = TraceIdentifier(UUID().uuidString),
      spanId: SpanIdentifier = SpanIdentifier(UUID().uuidString)
    ) {
      self.context = context
      self.startTime = Date()
      self.traceId = traceId
      self.spanId = spanId
      self.retryCount = 0
      self.customTags = context.customTags
    }
  }

  struct RequestSample: Sendable {
    let timestamp: Date
    let duration: TimeInterval
    let wasSuccessful: Bool
  }
}

#endif  // canImport(OSLog)
