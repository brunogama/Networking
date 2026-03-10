import NetworkingRuntime
import Foundation

/// Middleware that collects performance metrics and timing information for HTTP requests.
public actor RequestTimingMiddleware: HTTPRequestMiddleware, HTTPResponseMiddleware,
  HTTPErrorMiddleware
{
  // MARK: - Timing Metrics

  /// Comprehensive timing and performance metrics for an HTTP request
  public struct RequestMetrics: Sendable {
    /// Unique identifier for this request
    public let requestId: UUID

    /// The original HTTP request
    public let request: HTTPRequest

    /// When the request started processing
    public let startTime: Date

    /// When the request completed (successfully or with error)
    public let endTime: Date

    /// Total duration of the request
    public let duration: TimeInterval

    /// Size of the request body in bytes
    public let requestBodySize: Int

    /// Size of the response body in bytes (if successful)
    public let responseBodySize: Int?

    /// HTTP status code (if successful)
    public let statusCode: Int?

    /// Whether the request succeeded or failed
    public let isSuccess: Bool

    /// Error category if the request failed
    public let errorCategory: HTTPError.Category?

    /// Additional metadata
    public let metadata: [String: String]

    public init(
      requestId: UUID,
      request: HTTPRequest,
      startTime: Date,
      endTime: Date,
      responseBodySize: Int? = nil,
      statusCode: Int? = nil,
      isSuccess: Bool,
      errorCategory: HTTPError.Category? = nil,
      metadata: [String: String] = [:]
    ) {
      self.requestId = requestId
      self.request = request
      self.startTime = startTime
      self.endTime = endTime
      self.duration = endTime.timeIntervalSince(startTime)
      self.requestBodySize = request.body?.count ?? 0
      self.responseBodySize = responseBodySize
      self.statusCode = statusCode
      self.isSuccess = isSuccess
      self.errorCategory = errorCategory
      self.metadata = metadata
    }
  }

  // MARK: - Metrics Collector Protocol

  /// Protocol for collecting and storing request metrics
  public protocol MetricsCollector: Sendable {
    /// Records metrics for a completed request
    func recordMetrics(_ metrics: RequestMetrics) async
  }

  // MARK: - Configuration

  /// Configuration for timing and metrics collection
  public struct Configuration: Sendable {
    /// Whether to collect detailed timing information
    public let collectDetailedMetrics: Bool

    /// Whether to include request/response body sizes in metrics
    public let includeBodySizes: Bool

    /// Predicate to determine if metrics should be collected for a request
    public let shouldCollectMetrics: @Sendable (HTTPRequest) -> Bool

    /// Function to generate additional metadata for metrics
    public let metadataGenerator: @Sendable (HTTPRequest) -> [String: String]

    /// Maximum number of concurrent timing operations to track
    public let maxConcurrentTimings: Int

    public init(
      collectDetailedMetrics: Bool = true,
      includeBodySizes: Bool = true,
      shouldCollectMetrics: @escaping @Sendable (HTTPRequest) -> Bool = { _ in true },
      metadataGenerator: @escaping @Sendable (HTTPRequest) -> [String: String] = { _ in [:] },
      maxConcurrentTimings: Int = 1000
    ) {
      self.collectDetailedMetrics = collectDetailedMetrics
      self.includeBodySizes = includeBodySizes
      self.shouldCollectMetrics = shouldCollectMetrics
      self.metadataGenerator = metadataGenerator
      self.maxConcurrentTimings = maxConcurrentTimings
    }
  }

  // MARK: - Active Timing Entry

  private struct TimingEntry {
    let startTime: Date
    let metadata: [String: String]
  }

  // MARK: - Properties

  private let configuration: Configuration
  private let metricsCollector: any MetricsCollector

  // Active timing tracking
  private var activeTimings: [UUID: TimingEntry] = [:]

  // MARK: - Initialization

  /// Creates a new request timing middleware
  /// - Parameters:
  ///   - configuration: The timing configuration
  ///   - metricsCollector: The metrics collector implementation
  public init(
    configuration: Configuration,
    metricsCollector: any MetricsCollector
  ) {
    self.configuration = configuration
    self.metricsCollector = metricsCollector
  }

  // MARK: - HTTPRequestMiddleware

  public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    guard configuration.shouldCollectMetrics(request) else {
      return request
    }

    // Ensure we don't exceed the maximum concurrent timings
    if activeTimings.count >= configuration.maxConcurrentTimings {
      // Clean up oldest entries
      let sortedEntries = activeTimings.sorted { $0.value.startTime < $1.value.startTime }
      let entriesToRemove = sortedEntries.prefix(
        activeTimings.count - configuration.maxConcurrentTimings + 1
      )
      for (requestId, _) in entriesToRemove {
        activeTimings.removeValue(forKey: requestId)
      }
    }

    // Start timing for this request
    let metadata = configuration.metadataGenerator(request)
    activeTimings[request.id] = TimingEntry(
      startTime: Date(),
      metadata: metadata
    )

    return request
  }

  // MARK: - HTTPResponseMiddleware

  public func processResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    guard let timingEntry = activeTimings.removeValue(forKey: request.id) else {
      return response
    }

    let metrics = RequestMetrics(
      requestId: request.id,
      request: request,
      startTime: timingEntry.startTime,
      endTime: Date(),
      responseBodySize: configuration.includeBodySizes ? response.body?.count : nil,
      statusCode: response.status.rawValue,
      isSuccess: true,
      metadata: timingEntry.metadata
    )

    await metricsCollector.recordMetrics(metrics)
    return response
  }

  // MARK: - HTTPErrorMiddleware

  public func handleError(
    _ error: HTTPError,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    if let timingEntry = activeTimings.removeValue(forKey: request.id) {
      let metrics = RequestMetrics(
        requestId: request.id,
        request: request,
        startTime: timingEntry.startTime,
        endTime: Date(),
        isSuccess: false,
        errorCategory: error.category,
        metadata: timingEntry.metadata
      )

      await metricsCollector.recordMetrics(metrics)
    }

    // Always rethrow the error
    throw error
  }

  // MARK: - Public Metrics Access

  /// Returns the number of currently active timings
  public var activeTimingCount: Int {
    get async { activeTimings.count }
  }

  /// Clears all active timings (useful for cleanup)
  public func clearActiveTimings() async {
    activeTimings.removeAll()
  }
}

// MARK: - Default Metrics Collectors

/// A metrics collector that stores metrics in memory
public actor MemoryMetricsCollector: RequestTimingMiddleware.MetricsCollector {
  private var metrics: [RequestTimingMiddleware.RequestMetrics] = []
  private let maxMetricsCount: Int

  /// Creates a new memory metrics collector
  /// - Parameter maxMetricsCount: Maximum number of metrics to store
  public init(maxMetricsCount: Int = 1000) {
    self.maxMetricsCount = maxMetricsCount
  }

  public func recordMetrics(_ metrics: RequestTimingMiddleware.RequestMetrics) async {
    // Remove oldest metrics if we exceed the limit
    if self.metrics.count >= maxMetricsCount {
      let metricsToRemove = self.metrics.count - maxMetricsCount + 1
      self.metrics.removeFirst(metricsToRemove)
    }

    self.metrics.append(metrics)
  }

  /// Returns all recorded metrics
  public var allMetrics: [RequestTimingMiddleware.RequestMetrics] {
    get async { metrics }
  }

  /// Returns metrics for successful requests only
  public var successfulRequests: [RequestTimingMiddleware.RequestMetrics] {
    get async { metrics.filter { $0.isSuccess } }
  }

  /// Returns metrics for failed requests only
  public var failedRequests: [RequestTimingMiddleware.RequestMetrics] {
    get async { metrics.filter { !$0.isSuccess } }
  }

  /// Returns average response time for successful requests
  public var averageResponseTime: TimeInterval {
    get async {
      let successfulMetrics = metrics.filter { $0.isSuccess }
      guard !successfulMetrics.isEmpty else { return 0 }

      let totalDuration = successfulMetrics.reduce(0) { $0 + $1.duration }
      return totalDuration / Double(successfulMetrics.count)
    }
  }

  /// Returns the 95th percentile response time
  public var p95ResponseTime: TimeInterval {
    get async {
      let successfulMetrics = metrics.filter { $0.isSuccess }
      guard !successfulMetrics.isEmpty else { return 0 }

      let sortedDurations = successfulMetrics.map { $0.duration }.sorted()
      let index = Int(Double(sortedDurations.count) * 0.95)
      return sortedDurations[min(index, sortedDurations.count - 1)]
    }
  }

  /// Clears all recorded metrics
  public func clearMetrics() async {
    metrics.removeAll()
  }
}

/// A metrics collector that logs metrics to the console
public struct LoggingMetricsCollector: RequestTimingMiddleware.MetricsCollector {
  private let logLevel: LogLevel
  private let formatter: @Sendable (RequestTimingMiddleware.RequestMetrics) -> String

  public enum LogLevel: String, Sendable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
  }

  /// Creates a new logging metrics collector
  /// - Parameters:
  ///   - logLevel: The log level to use
  ///   - formatter: Custom formatter for log messages
  public init(
    logLevel: LogLevel = .info,
    formatter: @escaping @Sendable (RequestTimingMiddleware.RequestMetrics) -> String = Self
      .defaultFormatter
  ) {
    self.logLevel = logLevel
    self.formatter = formatter
  }

  public func recordMetrics(_ metrics: RequestTimingMiddleware.RequestMetrics) async {
    let message = formatter(metrics)
    print("[\(logLevel.rawValue)] \(message)")
  }

  public static func defaultFormatter(_ metrics: RequestTimingMiddleware.RequestMetrics) -> String {
    let status = metrics.isSuccess ? "SUCCESS" : "FAILED"
    let durationMs = Int(metrics.duration * 1000)

    var parts = [
      "\(metrics.request.method.rawValue) \(metrics.request.url.absoluteString)",
      "\(status) in \(durationMs)ms",
    ]

    if let statusCode = metrics.statusCode {
      parts.append("status: \(statusCode)")
    }

    if let bodySize = metrics.responseBodySize {
      parts.append("size: \(bodySize) bytes")
    }

    return parts.joined(separator: " | ")
  }
}

/// A composite metrics collector that forwards to multiple collectors
public struct CompositeMetricsCollector: RequestTimingMiddleware.MetricsCollector {
  private let collectors: [any RequestTimingMiddleware.MetricsCollector]

  /// Creates a composite metrics collector
  /// - Parameter collectors: The collectors to forward metrics to
  public init(collectors: [any RequestTimingMiddleware.MetricsCollector]) {
    self.collectors = collectors
  }

  public func recordMetrics(_ metrics: RequestTimingMiddleware.RequestMetrics) async {
    // Record metrics in all collectors concurrently
    await withTaskGroup(of: Void.self) { group in
      for collector in collectors {
        group.addTask {
          await collector.recordMetrics(metrics)
        }
      }
    }
  }
}

// MARK: - Convenience Factory

extension RequestTimingMiddleware {
  /// Creates a timing middleware with memory-based metrics collection
  /// - Parameters:
  ///   - maxMetricsCount: Maximum number of metrics to store in memory
  ///   - configuration: Optional custom configuration
  /// - Returns: A configured timing middleware and its metrics collector
  public static func withMemoryCollector(
    maxMetricsCount: Int = 1000,
    configuration: Configuration = Configuration()
  ) -> (middleware: RequestTimingMiddleware, collector: MemoryMetricsCollector) {
    let collector = MemoryMetricsCollector(maxMetricsCount: maxMetricsCount)
    let middleware = RequestTimingMiddleware(
      configuration: configuration,
      metricsCollector: collector
    )
    return (middleware, collector)
  }

  /// Creates a timing middleware with console logging
  /// - Parameters:
  ///   - logLevel: The log level to use
  ///   - configuration: Optional custom configuration
  /// - Returns: A configured timing middleware
  public static func withLogging(
    logLevel: LoggingMetricsCollector.LogLevel = .info,
    configuration: Configuration = Configuration()
  ) -> RequestTimingMiddleware {
    let collector = LoggingMetricsCollector(logLevel: logLevel)
    return RequestTimingMiddleware(
      configuration: configuration,
      metricsCollector: collector
    )
  }

  /// Creates a timing middleware with both memory and logging collectors
  /// - Parameters:
  ///   - maxMetricsCount: Maximum number of metrics to store in memory
  ///   - logLevel: The log level to use for console output
  ///   - configuration: Optional custom configuration
  /// - Returns: A configured timing middleware and its memory collector
  public static func withMemoryAndLogging(
    maxMetricsCount: Int = 1000,
    logLevel: LoggingMetricsCollector.LogLevel = .info,
    configuration: Configuration = Configuration()
  ) -> (middleware: RequestTimingMiddleware, collector: MemoryMetricsCollector) {
    let memoryCollector = MemoryMetricsCollector(maxMetricsCount: maxMetricsCount)
    let loggingCollector = LoggingMetricsCollector(logLevel: logLevel)
    let compositeCollector = CompositeMetricsCollector(
      collectors: [memoryCollector, loggingCollector]
    )

    let middleware = RequestTimingMiddleware(
      configuration: configuration,
      metricsCollector: compositeCollector
    )

    return (middleware, memoryCollector)
  }
}
