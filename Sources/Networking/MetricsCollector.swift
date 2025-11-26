#if canImport(OSLog)
import Foundation
import OSLog

/// Protocol for collecting and aggregating network metrics and observability events.
/// This is the core interface for all metrics collection implementations.
public protocol MetricsCollector: Sendable {
  /// Records an observability event
  /// - Parameter event: The event to record
  func recordEvent(_ event: NetworkObservabilityMiddleware.ObservabilityEvent) async

  /// Records performance metrics snapshot
  /// - Parameter metrics: The performance metrics to record
  func recordPerformanceMetrics(_ metrics: NetworkObservabilityMiddleware.PerformanceMetrics) async
}

// MARK: - Advanced Metrics Storage and Analysis

/// Comprehensive metrics collector that provides advanced analytics, persistence, and real-time monitoring
public actor ComprehensiveMetricsCollector: MetricsCollector {
  // MARK: - Event Storage and Analysis

  /// Detailed event record with context and timing information
  public struct EventRecord: Sendable {
    public let event: NetworkObservabilityMiddleware.ObservabilityEvent
    public let timestamp: Date
    public let eventId: UUID
    public let sessionId: String?
    public let userId: String?

    init(
      event: NetworkObservabilityMiddleware.ObservabilityEvent,
      sessionId: String? = nil,
      userId: String? = nil
    ) {
      self.event = event
      self.timestamp = Date()
      self.eventId = UUID()
      self.sessionId = sessionId
      self.userId = userId
    }
  }

  /// Aggregated metrics for a specific time window
  public struct MetricsWindow: Sendable {
    public let windowStart: Date
    public let windowEnd: Date
    public let totalRequests: Int
    public let successfulRequests: Int
    public let failedRequests: Int
    public let averageResponseTime: TimeInterval
    public let p50ResponseTime: TimeInterval
    public let p95ResponseTime: TimeInterval
    public let p99ResponseTime: TimeInterval
    public let errorRate: Double
    public let throughput: Double
    public let topErrors: [String: Int]
    public let endpointStats: [String: EndpointMetrics]

    public struct EndpointMetrics: Sendable {
      public let endpoint: String
      public let requestCount: Int
      public let averageResponseTime: TimeInterval
      public let p95ResponseTime: TimeInterval
      public let errorRate: Double
      public let lastRequestTime: Date
    }
  }

  /// Business metrics and KPI tracking
  public struct BusinessMetrics: Sendable {
    public let timestamp: Date
    public let dailyActiveUsers: Int
    public let totalSessions: Int
    public let averageSessionDuration: TimeInterval
    public let conversionRate: Double
    public let errorsByFeature: [String: Int]
    public let performanceByFeature: [String: TimeInterval]
    public let userRetentionRate: Double
    public let apiUsageByEndpoint: [String: Int]

    public init(
      dailyActiveUsers: Int = 0,
      totalSessions: Int = 0,
      averageSessionDuration: TimeInterval = 0,
      conversionRate: Double = 0,
      errorsByFeature: [String: Int] = [:],
      performanceByFeature: [String: TimeInterval] = [:],
      userRetentionRate: Double = 0,
      apiUsageByEndpoint: [String: Int] = [:]
    ) {
      self.timestamp = Date()
      self.dailyActiveUsers = dailyActiveUsers
      self.totalSessions = totalSessions
      self.averageSessionDuration = averageSessionDuration
      self.conversionRate = conversionRate
      self.errorsByFeature = errorsByFeature
      self.performanceByFeature = performanceByFeature
      self.userRetentionRate = userRetentionRate
      self.apiUsageByEndpoint = apiUsageByEndpoint
    }
  }

  // MARK: - Configuration

  public struct Configuration: Sendable {
    /// Maximum number of events to keep in memory
    public let maxEventsInMemory: Int

    /// How long to keep events in memory
    public let eventRetentionDuration: TimeInterval

    /// Size of time windows for aggregated metrics (in seconds)
    public let metricsWindowSize: TimeInterval

    /// Whether to enable persistence to disk
    public let enablePersistence: Bool

    /// Directory for persistent storage (if enabled)
    public let persistenceDirectory: URL?

    /// Whether to enable real-time alerts
    public let enableAlerting: Bool

    /// Thresholds for triggering alerts
    public let alertThresholds: AlertThresholds

    /// Whether to calculate business metrics
    public let enableBusinessMetrics: Bool

    /// Custom event processors for specific event types
    public let eventProcessors: [String: @Sendable (EventRecord) async -> Void]

    public init(
      maxEventsInMemory: Int = 10_000,
      eventRetentionDuration: TimeInterval = 3600,  // 1 hour
      metricsWindowSize: TimeInterval = 300,  // 5 minutes
      enablePersistence: Bool = false,
      persistenceDirectory: URL? = nil,
      enableAlerting: Bool = true,
      alertThresholds: AlertThresholds = AlertThresholds(),
      enableBusinessMetrics: Bool = true,
      eventProcessors: [String: @Sendable (EventRecord) async -> Void] = [:]
    ) {
      self.maxEventsInMemory = maxEventsInMemory
      self.eventRetentionDuration = eventRetentionDuration
      self.metricsWindowSize = metricsWindowSize
      self.enablePersistence = enablePersistence
      self.persistenceDirectory = persistenceDirectory
      self.enableAlerting = enableAlerting
      self.alertThresholds = alertThresholds
      self.enableBusinessMetrics = enableBusinessMetrics
      self.eventProcessors = eventProcessors
    }
  }

  public struct AlertThresholds: Sendable {
    /// Error rate threshold (percentage) to trigger alerts
    public let errorRateThreshold: Double

    /// Response time threshold (seconds) to trigger alerts
    public let responseTimeThreshold: TimeInterval

    /// Minimum requests per second before considering low throughput
    public let throughputThreshold: Double

    /// Maximum number of active connections before alerting
    public let maxActiveConnections: Int

    public init(
      errorRateThreshold: Double = 5.0,  // 5%
      responseTimeThreshold: TimeInterval = 2.0,  // 2 seconds
      throughputThreshold: Double = 0.1,  // 0.1 requests per second
      maxActiveConnections: Int = 1000
    ) {
      self.errorRateThreshold = errorRateThreshold
      self.responseTimeThreshold = responseTimeThreshold
      self.throughputThreshold = throughputThreshold
      self.maxActiveConnections = maxActiveConnections
    }
  }

  // MARK: - Alert System

  public enum AlertLevel: String, Sendable, Codable {
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
  }

  public struct Alert: Sendable, Identifiable {
    public let id: UUID
    public let level: AlertLevel
    public let title: String
    public let message: String
    public let timestamp: Date
    public let metric: String?
    public let value: Double?
    public let threshold: Double?

    public init(
      level: AlertLevel,
      title: String,
      message: String,
      metric: String? = nil,
      value: Double? = nil,
      threshold: Double? = nil
    ) {
      self.id = UUID()
      self.level = level
      self.title = title
      self.message = message
      self.timestamp = Date()
      self.metric = metric
      self.value = value
      self.threshold = threshold
    }
  }

  // MARK: - Storage

  private let configuration: Configuration
  private let logger: Logger

  // Event storage
  private var events: [EventRecord] = []
  private var performanceSnapshots: [NetworkObservabilityMiddleware.PerformanceMetrics] = []
  private var businessMetricsHistory: [BusinessMetrics] = []
  private var metricsWindows: [MetricsWindow] = []
  private var activeAlerts: [Alert] = []

  // Real-time tracking
  private var dailyUsers: Set<String> = []
  private var activeSessions: Set<String> = []
  private var sessionStartTimes: [String: Date] = [:]
  private var lastCleanup = Date()

  // MARK: - Initialization

  public init(configuration: Configuration = Configuration()) {
    self.configuration = configuration
    self.logger = Logger(
      subsystem: "ModernNetworking",
      category: "MetricsCollector"
    )

    // Create persistence directory if needed
    if configuration.enablePersistence, let directory = configuration.persistenceDirectory {
      try? FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true,
        attributes: nil
      )
    }
  }

  // MARK: - MetricsCollector Protocol

  public func recordEvent(_ event: NetworkObservabilityMiddleware.ObservabilityEvent) async {
    // Extract session and user information
    var sessionId: String?
    var userId: String?

    switch event {
    case .requestStarted(let context):
      sessionId = context.sessionId
      userId = context.userId

    case .requestCompleted(let context, _):
      sessionId = context.sessionId
      userId = context.userId

    case .requestFailed(let context, _):
      sessionId = context.sessionId
      userId = context.userId

    default:
      break
    }

    // Create event record
    let eventRecord = EventRecord(
      event: event,
      sessionId: sessionId,
      userId: userId
    )

    // Store event
    events.append(eventRecord)

    // Update business metrics tracking
    if configuration.enableBusinessMetrics {
      await updateBusinessTracking(for: eventRecord)
    }

    // Process custom event processors
    if let processor = configuration.eventProcessors[String(describing: type(of: event))] {
      await processor(eventRecord)
    }

    // Check for alerts
    if configuration.enableAlerting {
      await checkForAlerts(event: event)
    }

    // Periodic cleanup
    await performPeriodicMaintenance()

    logger.debug("Recorded event: \(eventRecord.eventId)")
  }

  public func recordPerformanceMetrics(
    _ metrics: NetworkObservabilityMiddleware.PerformanceMetrics
  ) async {
    // Store performance snapshot
    performanceSnapshots.append(metrics)

    // Check for performance-based alerts
    if configuration.enableAlerting {
      await checkPerformanceAlerts(metrics)
    }

    // Update metrics windows
    await updateMetricsWindows(with: metrics)

    // Persist if configured
    if configuration.enablePersistence {
      await persistMetrics(metrics)
    }

    logger.info(
      "Performance metrics recorded: \(metrics.throughput) req/sec, \(String(format: "%.1f", metrics.errorRate * 100))% errors"
    )
  }

  // MARK: - Business Metrics Tracking

  private func updateBusinessTracking(for eventRecord: EventRecord) async {
    switch eventRecord.event {
    case .requestStarted(let context):
      // Track daily active users
      if let userId = context.userId {
        dailyUsers.insert(userId)
      }

      // Track active sessions
      if let sessionId = context.sessionId {
        activeSessions.insert(sessionId)
        if sessionStartTimes[sessionId] == nil {
          sessionStartTimes[sessionId] = eventRecord.timestamp
        }
      }

    case .requestCompleted:
      // Track API usage by endpoint
      // This would be expanded based on business needs
      break

    default:
      break
    }
  }

  // MARK: - Alert System

  private func checkForAlerts(event: NetworkObservabilityMiddleware.ObservabilityEvent) async {
    switch event {
    case .requestFailed(_, let errorContext):
      // Check for error rate alerts
      if errorContext.errorType == "network" {
        let alert = Alert(
          level: .warning,
          title: "Network Error Detected",
          message: "Network connectivity issue: \(errorContext.errorMessage)"
        )
        await recordAlert(alert)
      }

    case .circuitBreakerTripped(let endpoint, let reason):
      let alert = Alert(
        level: .error,
        title: "Circuit Breaker Tripped",
        message: "Circuit breaker activated for endpoint \(endpoint): \(reason)"
      )
      await recordAlert(alert)

    case .rateLimitHit(_, let limit, _):
      let alert = Alert(
        level: .warning,
        title: "Rate Limit Exceeded",
        message: "Rate limit of \(limit) requests exceeded"
      )
      await recordAlert(alert)

    default:
      break
    }
  }

  private func checkPerformanceAlerts(
    _ metrics: NetworkObservabilityMiddleware.PerformanceMetrics
  ) async {
    // Error rate alert
    if metrics.errorRate * 100 > configuration.alertThresholds.errorRateThreshold {
      let alert = Alert(
        level: .error,
        title: "High Error Rate",
        message: "Error rate is \(String(format: "%.1f", metrics.errorRate * 100))%",
        metric: "error_rate",
        value: metrics.errorRate * 100,
        threshold: configuration.alertThresholds.errorRateThreshold
      )
      await recordAlert(alert)
    }

    // Response time alert
    if metrics.averageResponseTime > configuration.alertThresholds.responseTimeThreshold {
      let alert = Alert(
        level: .warning,
        title: "High Response Time",
        message: "Average response time is \(Int(metrics.averageResponseTime * 1000))ms",
        metric: "response_time",
        value: metrics.averageResponseTime,
        threshold: configuration.alertThresholds.responseTimeThreshold
      )
      await recordAlert(alert)
    }

    // Low throughput alert
    if metrics.throughput < configuration.alertThresholds.throughputThreshold {
      let alert = Alert(
        level: .info,
        title: "Low Throughput",
        message: "Throughput is \(String(format: "%.2f", metrics.throughput)) req/sec",
        metric: "throughput",
        value: metrics.throughput,
        threshold: configuration.alertThresholds.throughputThreshold
      )
      await recordAlert(alert)
    }

    // High active connections alert
    if metrics.activeConnections > configuration.alertThresholds.maxActiveConnections {
      let alert = Alert(
        level: .critical,
        title: "High Connection Count",
        message: "\(metrics.activeConnections) active connections",
        metric: "active_connections",
        value: Double(metrics.activeConnections),
        threshold: Double(configuration.alertThresholds.maxActiveConnections)
      )
      await recordAlert(alert)
    }
  }

  private func recordAlert(_ alert: Alert) async {
    activeAlerts.append(alert)

    // Keep only recent alerts
    let cutoffTime = Date().addingTimeInterval(-3600)  // Last hour
    activeAlerts.removeAll { $0.timestamp < cutoffTime }

    logger.log(
      level: logLevelForAlert(alert.level),
      "\(alert.level.rawValue): \(alert.title) - \(alert.message)"
    )
  }

  private func logLevelForAlert(_ level: AlertLevel) -> OSLogType {
    switch level {
    case .info: return .info
    case .warning: return .error
    case .error: return .error
    case .critical: return .fault
    }
  }

  // MARK: - Metrics Windows

  private func updateMetricsWindows(
    with metrics: NetworkObservabilityMiddleware.PerformanceMetrics
  ) async {
    // Implementation for creating time-based metrics windows
    // This would aggregate metrics into fixed time windows for trend analysis

    let windowStart = Date().addingTimeInterval(-configuration.metricsWindowSize)
    let windowEnd = Date()

    // Create metrics window from recent events and performance data
    // This is a simplified version - full implementation would aggregate all metrics
    let window = MetricsWindow(
      windowStart: windowStart,
      windowEnd: windowEnd,
      totalRequests: metrics.totalRequests,
      successfulRequests: metrics.successfulRequests,
      failedRequests: metrics.failedRequests,
      averageResponseTime: metrics.averageResponseTime,
      p50ResponseTime: metrics.p50ResponseTime,
      p95ResponseTime: metrics.p95ResponseTime,
      p99ResponseTime: metrics.p99ResponseTime,
      errorRate: metrics.errorRate,
      throughput: metrics.throughput,
      topErrors: metrics.topErrors,
      endpointStats: [:]  // Would be calculated from recent events
    )

    metricsWindows.append(window)

    // Keep only recent windows
    let cutoffTime = Date().addingTimeInterval(-configuration.eventRetentionDuration)
    metricsWindows.removeAll { $0.windowEnd < cutoffTime }
  }

  // MARK: - Persistence

  private func persistMetrics(_ metrics: NetworkObservabilityMiddleware.PerformanceMetrics) async {
    guard let directory = configuration.persistenceDirectory else { return }

    let filename = "metrics-\(Int(metrics.timestamp.timeIntervalSince1970)).json"
    let fileURL = directory.appendingPathComponent(filename)

    do {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601

      // Create a simplified version for persistence
      let persistableMetrics = PersistableMetrics(from: metrics)
      let data = try encoder.encode(persistableMetrics)
      try data.write(to: fileURL)
    } catch {
      logger.error("Failed to persist metrics: \(error.localizedDescription)")
    }
  }

  private struct PersistableMetrics: Codable {
    let timestamp: Date
    let totalRequests: Int
    let successfulRequests: Int
    let failedRequests: Int
    let averageResponseTime: TimeInterval
    let errorRate: Double
    let throughput: Double

    init(from metrics: NetworkObservabilityMiddleware.PerformanceMetrics) {
      self.timestamp = metrics.timestamp
      self.totalRequests = metrics.totalRequests
      self.successfulRequests = metrics.successfulRequests
      self.failedRequests = metrics.failedRequests
      self.averageResponseTime = metrics.averageResponseTime
      self.errorRate = metrics.errorRate
      self.throughput = metrics.throughput
    }
  }

  // MARK: - Maintenance

  private func performPeriodicMaintenance() async {
    let now = Date()

    // Run maintenance every 5 minutes
    guard now.timeIntervalSince(lastCleanup) >= 300 else { return }
    lastCleanup = now

    let cutoffTime = now.addingTimeInterval(-configuration.eventRetentionDuration)

    // Clean up old events
    events.removeAll { $0.timestamp < cutoffTime }
    if events.count > configuration.maxEventsInMemory {
      events = Array(events.suffix(configuration.maxEventsInMemory))
    }

    // Clean up old performance snapshots
    performanceSnapshots.removeAll { $0.timestamp < cutoffTime }

    // Clean up session tracking
    for (sessionId, startTime) in sessionStartTimes {
      if now.timeIntervalSince(startTime) > 86_400 {  // 24 hours
        sessionStartTimes.removeValue(forKey: sessionId)
        activeSessions.remove(sessionId)
      }
    }

    // Reset daily users at midnight (simplified)
    let calendar = Calendar.current
    if calendar.component(.hour, from: now) == 0 && calendar.component(.minute, from: now) < 5 {
      dailyUsers.removeAll()
    }

    logger.debug(
      "Maintenance completed: \(self.events.count) events, \(self.performanceSnapshots.count) snapshots"
    )
  }

  // MARK: - Public Analytics API

  /// Returns all events within the specified time range
  public func getEvents(from startDate: Date, to endDate: Date) async -> [EventRecord] {
    events.filter { event in
      event.timestamp >= startDate && event.timestamp <= endDate
    }
  }

  /// Returns performance metrics within the specified time range
  public func getPerformanceSnapshots(
    from startDate: Date,
    to endDate: Date
  ) async -> [NetworkObservabilityMiddleware.PerformanceMetrics] {
    performanceSnapshots.filter { snapshot in
      snapshot.timestamp >= startDate && snapshot.timestamp <= endDate
    }
  }

  /// Returns all active alerts
  public var currentAlerts: [Alert] {
    get async {
      activeAlerts.filter { Date().timeIntervalSince($0.timestamp) < 3600 }
    }
  }

  /// Returns current business metrics
  public var currentBusinessMetrics: BusinessMetrics {
    get async {
      let sessionDurations = sessionStartTimes.compactMap { sessionId, startTime in
        activeSessions.contains(sessionId) ? Date().timeIntervalSince(startTime) : nil
      }

      let averageSessionDuration =
        sessionDurations.isEmpty
        ? 0 : sessionDurations.reduce(0, +) / Double(sessionDurations.count)

      return BusinessMetrics(
        dailyActiveUsers: dailyUsers.count,
        totalSessions: activeSessions.count,
        averageSessionDuration: averageSessionDuration
      )
    }
  }

  /// Returns metrics windows for trend analysis
  public var timeWindowMetrics: [MetricsWindow] {
    get async { metricsWindows }
  }

  /// Exports all metrics to JSON format
  public func exportMetrics(from startDate: Date, to endDate: Date) async -> Data? {
    struct ExportData: Codable {
      let exportTimestamp: Date
      let events: Int
      let performanceSnapshots: Int
      let businessMetrics: BusinessMetrics
      let alertCount: Int  // Changed from [Alert] to count for simplicity
    }

    let exportData = ExportData(
      exportTimestamp: Date(),
      events: await getEvents(from: startDate, to: endDate).count,
      performanceSnapshots: await getPerformanceSnapshots(from: startDate, to: endDate).count,
      businessMetrics: await currentBusinessMetrics,
      alertCount: await currentAlerts.count
    )

    do {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      return try encoder.encode(exportData)
    } catch {
      logger.error("Failed to export metrics: \(error.localizedDescription)")
      return nil
    }
  }

  /// Clears all stored metrics (useful for testing)
  public func clearAllMetrics() async {
    events.removeAll()
    performanceSnapshots.removeAll()
    businessMetricsHistory.removeAll()
    metricsWindows.removeAll()
    activeAlerts.removeAll()
    dailyUsers.removeAll()
    activeSessions.removeAll()
    sessionStartTimes.removeAll()

    logger.info("All metrics cleared")
  }
}

// MARK: - Simple In-Memory Collector

/// Simple, lightweight metrics collector for basic use cases
public actor SimpleMetricsCollector: MetricsCollector {
  private var events: [NetworkObservabilityMiddleware.ObservabilityEvent] = []
  private var performanceHistory: [NetworkObservabilityMiddleware.PerformanceMetrics] = []
  private let maxEvents: Int
  private let logger: Logger

  public init(maxEvents: Int = 1000) {
    self.maxEvents = maxEvents
    self.logger = Logger(
      subsystem: "ModernNetworking",
      category: "SimpleMetricsCollector"
    )
  }

  public func recordEvent(_ event: NetworkObservabilityMiddleware.ObservabilityEvent) async {
    events.append(event)

    // Keep only recent events
    if events.count > maxEvents {
      events.removeFirst(events.count - maxEvents)
    }

    logger.debug("Event recorded: \(String(describing: event))")
  }

  public func recordPerformanceMetrics(
    _ metrics: NetworkObservabilityMiddleware.PerformanceMetrics
  ) async {
    performanceHistory.append(metrics)

    // Keep only recent metrics
    if performanceHistory.count > maxEvents {
      performanceHistory.removeFirst(performanceHistory.count - maxEvents)
    }

    logger.info(
      "Performance: \(metrics.throughput) req/sec, \(String(format: "%.1f", metrics.errorRate * 100))% errors"
    )
  }

  /// Returns all recorded events
  public var allEvents: [NetworkObservabilityMiddleware.ObservabilityEvent] {
    get async { events }
  }

  /// Returns all performance metrics
  public var allPerformanceMetrics: [NetworkObservabilityMiddleware.PerformanceMetrics] {
    get async { performanceHistory }
  }

  /// Returns the latest performance metrics
  public var latestMetrics: NetworkObservabilityMiddleware.PerformanceMetrics? {
    get async { performanceHistory.last }
  }

  /// Clears all recorded data
  public func clearAll() async {
    events.removeAll()
    performanceHistory.removeAll()
  }
}

// MARK: - Console Logging Collector

/// Metrics collector that outputs all events and metrics to the console
public struct ConsoleMetricsCollector: MetricsCollector {
  private let logger: Logger
  private let formatter: @Sendable (NetworkObservabilityMiddleware.ObservabilityEvent) -> String

  public init(
    formatter: @escaping @Sendable (NetworkObservabilityMiddleware.ObservabilityEvent) -> String =
      Self.defaultFormatter
  ) {
    self.logger = Logger(
      subsystem: "ModernNetworking",
      category: "ConsoleMetricsCollector"
    )
    self.formatter = formatter
  }

  public func recordEvent(_ event: NetworkObservabilityMiddleware.ObservabilityEvent) async {
    let message = formatter(event)
    logger.info("EVENT: \(message)")
  }

  public func recordPerformanceMetrics(
    _ metrics: NetworkObservabilityMiddleware.PerformanceMetrics
  ) async {
    logger.info(
      "METRICS: \(metrics.throughput) req/sec | \(Int(metrics.averageResponseTime * 1000))ms avg | \(String(format: "%.1f", metrics.errorRate * 100))% errors | Health: \(metrics.networkHealth.status.rawValue)"
    )
  }

  public static func defaultFormatter(
    _ event: NetworkObservabilityMiddleware.ObservabilityEvent
  ) -> String {
    switch event {
    case .requestStarted(let context):
      return "REQUEST_STARTED: \(context.method) \(context.path)"

    case .requestCompleted(let context, let response):
      return
        "REQUEST_COMPLETED: \(context.method) \(context.path) [\(response.statusCode)] in \(Int(response.duration * 1000))ms"

    case .requestFailed(let context, let error):
      return
        "REQUEST_FAILED: \(context.method) \(context.path) - \(error.errorType): \(error.errorMessage)"

    case .requestRetried(let context, let attempt):
      return "REQUEST_RETRIED: \(context.method) \(context.path) (attempt \(attempt))"

    case .circuitBreakerTripped(let endpoint, let reason):
      return "CIRCUIT_BREAKER_TRIPPED: \(endpoint) - \(reason)"

    case .cacheHit(let context, let cacheKey):
      return "CACHE_HIT: \(context.path) [\(cacheKey)]"

    case .cacheMiss(let context, let cacheKey):
      return "CACHE_MISS: \(context.path) [\(cacheKey)]"

    case .rateLimitHit(let context, let limit, let window):
      return "RATE_LIMIT_HIT: \(context.path) [\(limit) requests per \(window)s]"

    case .authenticationsRefreshed(let context):
      return "AUTH_REFRESHED: \(context.path)"

    case .middlewareError(let context, let middlewareName, let error):
      return "MIDDLEWARE_ERROR: \(middlewareName) on \(context.path) - \(error)"
    }
  }
}

// MARK: - Composite Collector

/// Collector that forwards events to multiple collectors for observability
public struct ObservabilityCompositeMetricsCollector: MetricsCollector {
  private let collectors: [any MetricsCollector]

  public init(collectors: [any MetricsCollector]) {
    self.collectors = collectors
  }

  public func recordEvent(_ event: NetworkObservabilityMiddleware.ObservabilityEvent) async {
    // Record in all collectors concurrently
    await withTaskGroup(of: Void.self) { group in
      for collector in collectors {
        group.addTask {
          await collector.recordEvent(event)
        }
      }
    }
  }

  public func recordPerformanceMetrics(
    _ metrics: NetworkObservabilityMiddleware.PerformanceMetrics
  ) async {
    // Record in all collectors concurrently
    await withTaskGroup(of: Void.self) { group in
      for collector in collectors {
        group.addTask {
          await collector.recordPerformanceMetrics(metrics)
        }
      }
    }
  }
}

// MARK: - Convenience Extensions

extension ComprehensiveMetricsCollector.Alert: Codable {}

extension ComprehensiveMetricsCollector.BusinessMetrics: Codable {}

// MARK: - Convenience Factories

extension ComprehensiveMetricsCollector {
  /// Creates a collector with production configuration
  public static func production(persistenceDirectory: URL? = nil) -> ComprehensiveMetricsCollector {
    let config = Configuration(
      maxEventsInMemory: 50_000,
      eventRetentionDuration: 86_400,  // 24 hours
      enablePersistence: persistenceDirectory != nil,
      persistenceDirectory: persistenceDirectory,
      enableAlerting: true,
      enableBusinessMetrics: true
    )
    return ComprehensiveMetricsCollector(configuration: config)
  }

  /// Creates a collector for development/testing
  public static func development() -> ComprehensiveMetricsCollector {
    let config = Configuration(
      maxEventsInMemory: 1000,
      eventRetentionDuration: 3600,  // 1 hour
      enablePersistence: false,
      enableAlerting: false,
      enableBusinessMetrics: false
    )
    return ComprehensiveMetricsCollector(configuration: config)
  }

  /// Creates a collector with custom alert thresholds
  public static func withCustomAlerts(
    errorRateThreshold: Double = 5.0,
    responseTimeThreshold: TimeInterval = 2.0,
    throughputThreshold: Double = 0.1
  ) -> ComprehensiveMetricsCollector {
    let alertThresholds = AlertThresholds(
      errorRateThreshold: errorRateThreshold,
      responseTimeThreshold: responseTimeThreshold,
      throughputThreshold: throughputThreshold
    )

    let config = Configuration(
      enableAlerting: true,
      alertThresholds: alertThresholds
    )

    return ComprehensiveMetricsCollector(configuration: config)
  }
}
#endif
