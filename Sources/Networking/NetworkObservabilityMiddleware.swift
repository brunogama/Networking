import Foundation

#if canImport(OSLog)
  import OSLog
#endif

#if canImport(OSLog)

  /// Comprehensive observability middleware that provides detailed monitoring, tracing, and analytics
  /// for HTTP requests. This middleware extends beyond basic timing to provide deep insights into
  /// network behavior, performance patterns, and operational metrics.
  public actor NetworkObservabilityMiddleware: HTTPRequestMiddleware, HTTPResponseMiddleware,
    HTTPErrorMiddleware
  {
  // MARK: - Observability Event Types

  /// Represents different types of observability events that can be recorded
  public enum ObservabilityEvent: Sendable {
    case requestStarted(RequestContext)
    case requestCompleted(RequestContext, ResponseContext)
    case requestFailed(RequestContext, ErrorContext)
    case requestRetried(RequestContext, retryAttempt: Int)
    case circuitBreakerTripped(endpoint: String, reason: String)
    case cacheHit(RequestContext, cacheKey: String)
    case cacheMiss(RequestContext, cacheKey: String)
    case rateLimitHit(RequestContext, limit: Int, windowSeconds: TimeInterval)
    case authenticationsRefreshed(RequestContext)
    case middlewareError(RequestContext, middlewareName: String, error: String)
  }

  /// Context information captured when a request starts
  public struct RequestContext: Sendable, Identifiable {
    public let id: UUID
    public let method: String
    public let url: String
    public let host: String
    public let path: String
    public let timestamp: Date
    public let headers: [String: String]
    public let bodySize: Int
    public let userAgent: String?
    public let requestId: String
    public let correlationId: String?
    public let sessionId: String?
    public let userId: String?
    public let deviceId: String?
    public let appVersion: String?
    public let platform: String?
    public let networkType: String?
    public let customTags: [String: String]

    init(from request: HTTPRequest, customTags: [String: String] = [:]) {
      self.id = request.id
      self.method = request.method.rawValue
      self.url = request.url.absoluteString
      self.host = request.url.host ?? "unknown"
      self.path = request.url.path
      self.timestamp = Date()
      self.headers = request.headers
      self.bodySize = request.body?.count ?? 0
      self.userAgent = request.headers["User-Agent"]
      self.requestId = request.id.uuidString
      self.correlationId = request.headers["X-Correlation-ID"]
      self.sessionId = request.headers["X-Session-ID"]
      self.userId = request.headers["X-User-ID"]
      self.deviceId = request.headers["X-Device-ID"]
      self.appVersion = request.headers["X-App-Version"]
      self.platform = request.headers["X-Platform"]
      self.networkType = request.headers["X-Network-Type"]
      self.customTags = customTags
    }
  }

  /// Context information captured when a request completes successfully
  public struct ResponseContext: Sendable {
    public let statusCode: Int
    public let statusCategory: String
    public let responseSize: Int
    public let duration: TimeInterval
    public let headers: [String: String]
    public let contentType: String?
    public let cacheControl: String?
    public let serverProcessingTime: TimeInterval?
    public let retryCount: Int
    public let wasCached: Bool
    public let compressionRatio: Double?

    init(from response: HTTPResponse, startTime: Date, retryCount: Int = 0, wasCached: Bool = false)
    {
      self.statusCode = response.status.rawValue
      self.statusCategory = Self.categorizeStatus(response.status.rawValue)
      self.responseSize = response.body?.count ?? 0
      self.duration = Date().timeIntervalSince(startTime)
      self.headers = response.headers
      self.contentType = response.headers["Content-Type"]
      self.cacheControl = response.headers["Cache-Control"]
      self.retryCount = retryCount
      self.wasCached = wasCached

      // Extract server processing time if available
      if let serverTime = response.headers["X-Response-Time"] ?? response.headers["Server-Timing"] {
        self.serverProcessingTime = TimeInterval(
          serverTime.replacingOccurrences(of: "ms", with: "")
        )
        .flatMap { $0 / 1000.0 }
      } else {
        self.serverProcessingTime = nil
      }

      // Calculate compression ratio if both original and compressed sizes are available
      if let originalSize = response.headers["X-Original-Size"].flatMap(Int.init),
        originalSize > 0 && responseSize > 0
      {
        self.compressionRatio = Double(responseSize) / Double(originalSize)
      } else {
        self.compressionRatio = nil
      }
    }

    fileprivate static func categorizeStatus(_ code: Int) -> String {
      switch code {
      case 200..<300: return "success"
      case 300..<400: return "redirect"
      case 400..<500: return "client_error"
      case 500..<600: return "server_error"
      default: return "unknown"
      }
    }
  }

  /// Context information captured when a request fails
  public struct ErrorContext: Sendable {
    public let errorType: String
    public let errorCategory: String
    public let errorMessage: String
    public let duration: TimeInterval
    public let retryCount: Int
    public let isRetryable: Bool
    public let underlyingError: String?
    public let networkCondition: String?
    public let serverStatus: String?

    init(from error: HTTPError, startTime: Date, retryCount: Int = 0) {
      self.duration = Date().timeIntervalSince(startTime)
      self.retryCount = retryCount
      self.isRetryable = error.isTransientError
      self.underlyingError = error.underlyingError?.localizedDescription

      switch error.category {
      case .network(let networkError):
        self.errorType = "network"
        self.errorCategory = "connectivity"
        self.errorMessage = "Network error: \(networkError)"
        self.networkCondition = "\(networkError)"
        self.serverStatus = nil

      case .http(let status):
        self.errorType = "http"
        self.errorCategory = ResponseContext.categorizeStatus(status.rawValue)
        self.errorMessage = "HTTP \(status.rawValue)"
        self.networkCondition = nil
        self.serverStatus = "\(status.rawValue)"

      case .timeout:
        self.errorType = "timeout"
        self.errorCategory = "timeout"
        self.errorMessage = "Request timed out"
        self.networkCondition = "timeout"
        self.serverStatus = nil

      case .cancelled:
        self.errorType = "cancelled"
        self.errorCategory = "cancellation"
        self.errorMessage = "Request was cancelled"
        self.networkCondition = nil
        self.serverStatus = nil

      case .decoding(let message):
        self.errorType = "decoding"
        self.errorCategory = "data_processing"
        self.errorMessage = "Decoding error: \(message)"
        self.networkCondition = nil
        self.serverStatus = nil

      case .encoding(let message):
        self.errorType = "encoding"
        self.errorCategory = "data_processing"
        self.errorMessage = "Encoding error: \(message)"
        self.networkCondition = nil
        self.serverStatus = nil

      case .configuration(let message):
        self.errorType = "configuration"
        self.errorCategory = "configuration"
        self.errorMessage = "Configuration error: \(message)"
        self.networkCondition = nil
        self.serverStatus = nil

      case .custom(let type, let message):
        self.errorType = "custom"
        self.errorCategory = type.lowercased()
        self.errorMessage = "\(type) error: \(message)"
        self.networkCondition = nil
        self.serverStatus = nil
      }
    }
  }

  // MARK: - Performance Metrics

  /// Real-time performance and health metrics
  public struct PerformanceMetrics: Sendable {
    public let timestamp: Date
    public let totalRequests: Int
    public let successfulRequests: Int
    public let failedRequests: Int
    public let averageResponseTime: TimeInterval
    public let p50ResponseTime: TimeInterval
    public let p95ResponseTime: TimeInterval
    public let p99ResponseTime: TimeInterval
    public let errorRate: Double
    public let throughput: Double  // requests per second
    public let activeConnections: Int
    public let cacheHitRate: Double
    public let retryRate: Double
    public let topErrors: [String: Int]
    public let topSlowEndpoints: [(String, TimeInterval)]
    public let networkHealth: NetworkHealth

    public struct NetworkHealth: Sendable {
      public let status: HealthStatus
      public let latencyGrade: Grade
      public let reliabilityGrade: Grade
      public let throughputGrade: Grade
      public let overallGrade: Grade

      public enum HealthStatus: String, Sendable {
        case excellent = "excellent"
        case good = "good"
        case fair = "fair"
        case poor = "poor"
        case critical = "critical"
      }

      public enum Grade: String, Sendable {
        case a = "A"
        case b = "B"
        case c = "C"
        case d = "D"
        case f = "F"
      }
    }
  }

  // MARK: - Configuration

  /// Configuration options for observability middleware
  public struct Configuration: Sendable {
    /// Whether to collect detailed request/response headers
    public let collectHeaders: Bool

    /// Whether to collect request/response body information (size, content-type)
    public let collectBodyInfo: Bool

    /// Whether to enable distributed tracing
    public let enableTracing: Bool

    /// Whether to collect custom business metrics
    public let collectBusinessMetrics: Bool

    /// Sampling rate for detailed tracing (0.0 to 1.0)
    public let tracingSampleRate: Double

    /// Maximum number of active traces to keep in memory
    public let maxActiveTraces: Int

    /// How often to calculate and report performance metrics
    public let metricsReportingInterval: TimeInterval

    /// Custom tags to add to all observability events
    public let globalTags: [String: String]

    /// Predicate to determine if a request should be observed
    public let shouldObserve: @Sendable (HTTPRequest) -> Bool

    /// Function to extract custom tags from a request
    public let customTagExtractor: @Sendable (HTTPRequest) -> [String: String]

    /// List of header names to redact in logs (for security)
    public let redactedHeaders: Set<String>

    /// Whether to enable real-time performance monitoring
    public let enableRealTimeMetrics: Bool

    /// Maximum duration to keep metrics in memory
    public let metricsRetentionDuration: TimeInterval

    public init(
      collectHeaders: Bool = true,
      collectBodyInfo: Bool = true,
      enableTracing: Bool = true,
      collectBusinessMetrics: Bool = true,
      tracingSampleRate: Double = 1.0,
      maxActiveTraces: Int = 1000,
      metricsReportingInterval: TimeInterval = 60.0,
      globalTags: [String: String] = [:],
      shouldObserve: @escaping @Sendable (HTTPRequest) -> Bool = { _ in true },
      customTagExtractor: @escaping @Sendable (HTTPRequest) -> [String: String] = { _ in [:] },
      redactedHeaders: Set<String> = ["Authorization", "Cookie", "X-API-Key"],
      enableRealTimeMetrics: Bool = true,
      metricsRetentionDuration: TimeInterval = 3600.0
    ) {
      self.collectHeaders = collectHeaders
      self.collectBodyInfo = collectBodyInfo
      self.enableTracing = enableTracing
      self.collectBusinessMetrics = collectBusinessMetrics
      self.tracingSampleRate = max(0.0, min(1.0, tracingSampleRate))
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

  // MARK: - Trace Management

  private struct ActiveTrace: Sendable {
    let context: RequestContext
    let startTime: Date
    let traceId: String
    let spanId: String
    var retryCount: Int
    let customTags: [String: String]

    init(
      context: RequestContext,
      traceId: String = UUID().uuidString,
      spanId: String = UUID().uuidString
    ) {
      self.context = context
      self.startTime = Date()
      self.traceId = traceId
      self.spanId = spanId
      self.retryCount = 0
      self.customTags = context.customTags
    }
  }

  // MARK: - Properties

  private let configuration: Configuration
  private let metricsCollector: any MetricsCollector
  private let logger: Logger

  // Active trace tracking
  private var activeTraces: [UUID: ActiveTrace] = [:]
  private var lastMetricsReport = Date()

  // Performance tracking
  private var requestHistory: [(Date, TimeInterval, Bool)] = []  // timestamp, duration, success
  private var errorCounts: [String: Int] = [:]
  private var endpointPerformance: [String: [TimeInterval]] = [:]

  // MARK: - Initialization

  /// Creates a new network observability middleware
  /// - Parameters:
  ///   - configuration: Observability configuration
  ///   - metricsCollector: The metrics collector to use
  public init(
    configuration: Configuration,
    metricsCollector: any MetricsCollector
  ) {
    self.configuration = configuration
    self.metricsCollector = metricsCollector
    self.logger = Logger(
      subsystem: "Networking",
      category: "NetworkObservability"
    )
  }

  // MARK: - HTTPRequestMiddleware

  public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    guard configuration.shouldObserve(request) else {
      return request
    }

    // Create request context with custom tags
    let customTags = configuration.customTagExtractor(request)
    let allTags = configuration.globalTags.merging(customTags) { _, new in new }
    let context = RequestContext(from: request, customTags: allTags)

    // Determine if this request should be traced based on sampling
    let shouldTrace =
      configuration.enableTracing
      && (configuration.tracingSampleRate >= 1.0
        || Double.random(in: 0...1) <= configuration.tracingSampleRate)

    if shouldTrace {
      // Ensure we don't exceed max active traces
      if activeTraces.count >= configuration.maxActiveTraces {
        // Remove oldest traces
        let sortedTraces = activeTraces.sorted { $0.value.startTime < $1.value.startTime }
        let tracesToRemove = sortedTraces.prefix(
          activeTraces.count - configuration.maxActiveTraces + 1
        )
        for (requestId, _) in tracesToRemove {
          activeTraces.removeValue(forKey: requestId)
        }
      }

      // Start new trace
      activeTraces[request.id] = ActiveTrace(context: context)
    }

    // Record observability event
    let event = ObservabilityEvent.requestStarted(context)
    await metricsCollector.recordEvent(event)

    logger.debug("Request started: \(request.method.rawValue) \(request.url.absoluteString)")

    return request
  }

  // MARK: - HTTPResponseMiddleware

  public func processResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    // Find and remove the active trace
    if let trace = activeTraces.removeValue(forKey: request.id) {
      let responseContext = ResponseContext(
        from: response,
        startTime: trace.startTime,
        retryCount: trace.retryCount
      )

      // Record completion event
      let event = ObservabilityEvent.requestCompleted(trace.context, responseContext)
      await metricsCollector.recordEvent(event)

      // Update performance tracking
      await updatePerformanceMetrics(
        duration: responseContext.duration,
        success: true,
        endpoint: trace.context.path,
        error: nil
      )

      logger.debug(
        "Request completed: \(response.status.rawValue) \(request.method.rawValue) \(request.url.absoluteString) in \(Int(responseContext.duration * 1000))ms"
      )
    }

    // Check if we should report metrics
    if configuration.enableRealTimeMetrics
      && Date().timeIntervalSince(lastMetricsReport) >= configuration.metricsReportingInterval
    {
      await reportPerformanceMetrics()
      lastMetricsReport = Date()
    }

    return response
  }

  // MARK: - HTTPErrorMiddleware

  public func handleError(
    _ error: HTTPError,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    // Find and remove the active trace
    if let trace = activeTraces.removeValue(forKey: request.id) {
      let errorContext = ErrorContext(
        from: error,
        startTime: trace.startTime,
        retryCount: trace.retryCount
      )

      // Record error event
      let event = ObservabilityEvent.requestFailed(trace.context, errorContext)
      await metricsCollector.recordEvent(event)

      // Update performance tracking
      await updatePerformanceMetrics(
        duration: errorContext.duration,
        success: false,
        endpoint: trace.context.path,
        error: errorContext.errorType
      )

      logger.error(
        "Request failed: \(request.method.rawValue) \(request.url.absoluteString) - \(error.localizedDescription)"
      )
    }

    // Always rethrow the error
    throw error
  }

  // MARK: - Performance Metrics Management

  private func updatePerformanceMetrics(
    duration: TimeInterval,
    success: Bool,
    endpoint: String,
    error: String?
  ) async {
    // Add to request history with cleanup
    let now = Date()
    requestHistory.append((now, duration, success))

    // Keep only recent history within retention duration
    let cutoffTime = now.addingTimeInterval(-configuration.metricsRetentionDuration)
    requestHistory.removeAll { $0.0 < cutoffTime }

    // Update endpoint performance
    if endpointPerformance[endpoint] == nil {
      endpointPerformance[endpoint] = []
    }
    endpointPerformance[endpoint]?.append(duration)

    // Keep only recent measurements
    if let measurements = endpointPerformance[endpoint], measurements.count > 1000 {
      endpointPerformance[endpoint] = Array(measurements.suffix(1000))
    }

    // Update error counts
    if let error = error {
      errorCounts[error] = (errorCounts[error] ?? 0) + 1
    }
  }

  private func reportPerformanceMetrics() async {
    let metrics = await calculatePerformanceMetrics()
    await metricsCollector.recordPerformanceMetrics(metrics)

    logger.info(
      "Performance metrics: \(metrics.throughput) req/sec, \(Int(metrics.averageResponseTime * 1000))ms avg, \(String(format: "%.1f", metrics.errorRate * 100))% error rate"
    )
  }

  private func calculatePerformanceMetrics() async -> PerformanceMetrics {
    let now = Date()
    let recentRequests = requestHistory.filter { now.timeIntervalSince($0.0) <= 300 }  // Last 5 minutes

    let totalRequests = recentRequests.count
    let successfulRequests = recentRequests.filter { $0.2 }.count
    let failedRequests = totalRequests - successfulRequests

    let durations = recentRequests.map { $0.1 }.sorted()
    let averageResponseTime =
      durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)

    let p50Index = Int(Double(durations.count) * 0.5)
    let p95Index = Int(Double(durations.count) * 0.95)
    let p99Index = Int(Double(durations.count) * 0.99)

    let p50ResponseTime = durations.isEmpty ? 0 : durations[min(p50Index, durations.count - 1)]
    let p95ResponseTime = durations.isEmpty ? 0 : durations[min(p95Index, durations.count - 1)]
    let p99ResponseTime = durations.isEmpty ? 0 : durations[min(p99Index, durations.count - 1)]

    let errorRate = totalRequests == 0 ? 0 : Double(failedRequests) / Double(totalRequests)
    let throughput = totalRequests == 0 ? 0 : Double(totalRequests) / 300.0  // Per second over 5 minutes

    // Calculate top errors (limited to top 10)
    let topErrors = Dictionary(
      errorCounts.sorted { $0.value > $1.value }.prefix(10).map { $0 },
      uniquingKeysWith: { first, _ in first }
    )

    // Calculate top slow endpoints (limited to top 10)
    let topSlowEndpoints = endpointPerformance.compactMap {
      endpoint,
      times -> (String, TimeInterval)? in
      guard !times.isEmpty else { return nil }
      let avgTime = times.reduce(0, +) / Double(times.count)
      return (endpoint, avgTime)
    }
    .sorted { $0.1 > $1.1 }
    .prefix(10)
    .map { $0 }

    // Calculate network health
    let networkHealth = calculateNetworkHealth(
      errorRate: errorRate,
      averageLatency: averageResponseTime,
      p95Latency: p95ResponseTime,
      throughput: throughput
    )

    return PerformanceMetrics(
      timestamp: now,
      totalRequests: totalRequests,
      successfulRequests: successfulRequests,
      failedRequests: failedRequests,
      averageResponseTime: averageResponseTime,
      p50ResponseTime: p50ResponseTime,
      p95ResponseTime: p95ResponseTime,
      p99ResponseTime: p99ResponseTime,
      errorRate: errorRate,
      throughput: throughput,
      activeConnections: activeTraces.count,
      cacheHitRate: 0.0,  // Would be calculated from cache middleware events
      retryRate: 0.0,  // Would be calculated from retry middleware events
      topErrors: topErrors,
      topSlowEndpoints: topSlowEndpoints,
      networkHealth: networkHealth
    )
  }

  private func calculateNetworkHealth(
    errorRate: Double,
    averageLatency: TimeInterval,
    p95Latency: TimeInterval,
    throughput: Double
  ) -> PerformanceMetrics.NetworkHealth {
    // Calculate individual grades
    let latencyGrade = gradeLatency(averageLatency, p95Latency)
    let reliabilityGrade = gradeReliability(errorRate)
    let throughputGrade = gradeThroughput(throughput)

    // Calculate overall grade (weighted average)
    let overallScore =
      (gradeToScore(reliabilityGrade) * 0.4  // Reliability is most important
        + gradeToScore(latencyGrade) * 0.35  // Latency is critical
        + gradeToScore(throughputGrade) * 0.25  // Throughput is good to have
        )
    let overallGrade = scoreToGrade(overallScore)

    // Determine health status
    let status: PerformanceMetrics.NetworkHealth.HealthStatus
    switch overallGrade {
    case .a: status = .excellent
    case .b: status = .good
    case .c: status = .fair
    case .d: status = .poor
    case .f: status = .critical
    }

    return PerformanceMetrics.NetworkHealth(
      status: status,
      latencyGrade: latencyGrade,
      reliabilityGrade: reliabilityGrade,
      throughputGrade: throughputGrade,
      overallGrade: overallGrade
    )
  }

  private func gradeLatency(
    _ avg: TimeInterval,
    _ p95: TimeInterval
  ) -> PerformanceMetrics.NetworkHealth.Grade {
    let score = avg * 1000  // Convert to milliseconds
    switch score {
    case 0..<100: return .a  // Under 100ms is excellent
    case 100..<250: return .b  // Under 250ms is good
    case 250..<500: return .c  // Under 500ms is fair
    case 500..<1000: return .d  // Under 1s is poor
    default: return .f  // Over 1s is critical
    }
  }

  private func gradeReliability(_ errorRate: Double) -> PerformanceMetrics.NetworkHealth.Grade {
    let percentage = errorRate * 100
    switch percentage {
    case 0..<1: return .a  // Under 1% error rate
    case 1..<2.5: return .b  // Under 2.5% error rate
    case 2.5..<5: return .c  // Under 5% error rate
    case 5..<10: return .d  // Under 10% error rate
    default: return .f  // Over 10% error rate
    }
  }

  private func gradeThroughput(_ throughput: Double) -> PerformanceMetrics.NetworkHealth.Grade {
    switch throughput {
    case 10...: return .a  // 10+ requests per second
    case 5..<10: return .b  // 5-10 requests per second
    case 1..<5: return .c  // 1-5 requests per second
    case 0.1..<1: return .d  // 0.1-1 requests per second
    default: return .f  // Under 0.1 requests per second
    }
  }

  private func gradeToScore(_ grade: PerformanceMetrics.NetworkHealth.Grade) -> Double {
    switch grade {
    case .a: return 4.0
    case .b: return 3.0
    case .c: return 2.0
    case .d: return 1.0
    case .f: return 0.0
    }
  }

  private func scoreToGrade(_ score: Double) -> PerformanceMetrics.NetworkHealth.Grade {
    switch score {
    case 3.5...: return .a
    case 2.5..<3.5: return .b
    case 1.5..<2.5: return .c
    case 0.5..<1.5: return .d
    default: return .f
    }
  }

  // MARK: - Public Observability Access

  /// Returns current performance metrics
  public var currentMetrics: PerformanceMetrics {
    get async {
      await calculatePerformanceMetrics()
    }
  }

  /// Returns the number of currently active traces
  public var activeTraceCount: Int {
    get async { activeTraces.count }
  }

  /// Records a custom business metric event
  public func recordCustomEvent(_ event: ObservabilityEvent) async {
    await metricsCollector.recordEvent(event)
  }

  /// Records a retry attempt for a request
  public func recordRetryAttempt(for requestId: UUID, attempt: Int) async {
    if var trace = activeTraces[requestId] {
      trace.retryCount = attempt
      activeTraces[requestId] = trace

      let event = ObservabilityEvent.requestRetried(trace.context, retryAttempt: attempt)
      await metricsCollector.recordEvent(event)
    }
  }

  /// Records a cache event (hit or miss)
  public func recordCacheEvent(for requestId: UUID, hit: Bool, cacheKey: String) async {
    if let trace = activeTraces[requestId] {
      let event =
        hit
        ? ObservabilityEvent.cacheHit(trace.context, cacheKey: cacheKey)
        : ObservabilityEvent.cacheMiss(trace.context, cacheKey: cacheKey)
      await metricsCollector.recordEvent(event)
    }
  }

  /// Clears all tracking data (useful for cleanup/testing)
  public func clearObservabilityData() async {
    activeTraces.removeAll()
    requestHistory.removeAll()
    errorCounts.removeAll()
    endpointPerformance.removeAll()
  }
}

// MARK: - Convenience Factories

extension NetworkObservabilityMiddleware {
  /// Creates observability middleware with standard configuration
  /// - Parameters:
  ///   - metricsCollector: The metrics collector to use
  ///   - enableRealTimeMetrics: Whether to enable real-time performance monitoring
  /// - Returns: Configured observability middleware
  public static func standard(
    metricsCollector: any MetricsCollector,
    enableRealTimeMetrics: Bool = true
  ) -> NetworkObservabilityMiddleware {
    let configuration = Configuration(enableRealTimeMetrics: enableRealTimeMetrics)
    return NetworkObservabilityMiddleware(
      configuration: configuration,
      metricsCollector: metricsCollector
    )
  }

  /// Creates observability middleware with production configuration
  /// - Parameters:
  ///   - metricsCollector: The metrics collector to use
  ///   - samplingRate: Tracing sampling rate (0.0 to 1.0)
  /// - Returns: Configured observability middleware
  public static func production(
    metricsCollector: any MetricsCollector,
    samplingRate: Double = 0.1
  ) -> NetworkObservabilityMiddleware {
    let configuration = Configuration(
      tracingSampleRate: samplingRate,
      metricsReportingInterval: 300.0,  // 5 minutes
      enableRealTimeMetrics: true
    )
    return NetworkObservabilityMiddleware(
      configuration: configuration,
      metricsCollector: metricsCollector
    )
  }

  /// Creates observability middleware for development/debugging
  /// - Parameter metricsCollector: The metrics collector to use
  /// - Returns: Configured observability middleware with full tracing
  public static func development(
    metricsCollector: any MetricsCollector
  ) -> NetworkObservabilityMiddleware {
    let configuration = Configuration(
      tracingSampleRate: 1.0,
      metricsReportingInterval: 30.0,
      redactedHeaders: [],  // Don't redact headers in development
      enableRealTimeMetrics: true
    )
    return NetworkObservabilityMiddleware(
      configuration: configuration,
      metricsCollector: metricsCollector
    )
  }
}

#endif  // canImport(OSLog)
