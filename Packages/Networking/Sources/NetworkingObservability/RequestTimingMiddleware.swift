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
    public let requestId: HTTPRequestID

    /// The original HTTP request
    public let request: HTTPRequest

    /// When the request started processing
    public let startTime: Date

    /// When the request completed (successfully or with error)
    public let endTime: Date

    /// Total duration of the request
    public let duration: MeasurementDuration

    /// Size of the request body in bytes
    public let requestBodySize: RequestBodySize

    /// Size of the response body in bytes (if successful)
    public let responseBodySize: ResponseSize?

    /// HTTP status code (if successful)
    public let statusCode: HTTPStatusCode?

    /// Whether the request succeeded or failed
    public let isSuccess: RequestSuccessFlag

    /// Error category if the request failed
    public let errorCategory: HTTPError.Category?

    /// Additional metadata
    public let metadata: [TimingMetadataKey: TimingMetadataValue]

    public init(
      requestId: HTTPRequestID,
      request: HTTPRequest,
      startTime: Date,
      endTime: Date,
      responseBodySize: ResponseSize? = nil,
      statusCode: HTTPStatusCode? = nil,
      isSuccess: RequestSuccessFlag,
      errorCategory: HTTPError.Category? = nil,
      metadata: [TimingMetadataKey: TimingMetadataValue] = [:]
    ) {
      self.requestId = requestId
      self.request = request
      self.startTime = startTime
      self.endTime = endTime
      self.duration = MeasurementDuration(endTime.timeIntervalSince(startTime))
      self.requestBodySize = RequestBodySize((request.body?.count ?? 0).rawValue)
      self.responseBodySize = responseBodySize
      self.statusCode = statusCode
      self.isSuccess = isSuccess
      self.errorCategory = errorCategory
      self.metadata = metadata
    }

    package init(
      requestId: HTTPRequestID,
      request: HTTPRequest,
      startTime: Date,
      endTime: Date,
      responseBodySize: Int?,
      statusCode: HTTPStatusCode?,
      isSuccess: Bool,
      errorCategory: HTTPError.Category?,
      metadata: [String: String]
    ) {
      self.init(
        requestId: requestId,
        request: request,
        startTime: startTime,
        endTime: endTime,
        responseBodySize: responseBodySize.map { ResponseSize($0) },
        statusCode: statusCode,
        isSuccess: RequestSuccessFlag(isSuccess),
        errorCategory: errorCategory,
        metadata: Dictionary(
          uniqueKeysWithValues: metadata.map {
            (TimingMetadataKey($0.key), TimingMetadataValue($0.value))
          }
        )
      )
    }

    package init(
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
      self.init(
        requestId: HTTPRequestID(requestId),
        request: request,
        startTime: startTime,
        endTime: endTime,
        responseBodySize: responseBodySize,
        statusCode: statusCode.map { HTTPStatusCode($0) },
        isSuccess: isSuccess,
        errorCategory: errorCategory,
        metadata: metadata
      )
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
    public let collectDetailedMetrics: CollectDetailedMetricsFlag

    /// Whether to include request/response body sizes in metrics
    public let includeBodySizes: IncludeBodySizesFlag

    /// Predicate to determine if metrics should be collected for a request
    public let shouldCollectMetrics: @Sendable (HTTPRequest) -> MetricsCollectionDecision

    /// Function to generate additional metadata for metrics
    public let metadataGenerator:
      @Sendable (HTTPRequest) -> [TimingMetadataKey: TimingMetadataValue]

    /// Maximum number of concurrent timing operations to track
    public let maxConcurrentTimings: MaxConcurrentTimingCount

    public init(
      collectDetailedMetrics: CollectDetailedMetricsFlag = true,
      includeBodySizes: IncludeBodySizesFlag = true,
      shouldCollectMetrics: @escaping @Sendable (HTTPRequest) -> MetricsCollectionDecision = { _ in
        true
      },
      metadataGenerator:
        @escaping @Sendable (HTTPRequest) -> [TimingMetadataKey: TimingMetadataValue] = { _ in [:]
        },
      maxConcurrentTimings: MaxConcurrentTimingCount = 1000
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
    let metadata: [TimingMetadataKey: TimingMetadataValue]
  }

  // MARK: - Properties

  private let configuration: Configuration
  private let metricsCollector: any MetricsCollector

  // Active timing tracking
  private var activeTimings: [HTTPRequestID: TimingEntry] = [:]

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
    guard configuration.shouldCollectMetrics(request).rawValue else {
      return request
    }

    // Ensure we don't exceed the maximum concurrent timings
    if activeTimings.count >= configuration.maxConcurrentTimings.rawValue {
      // Clean up oldest entries
      let sortedEntries = activeTimings.sorted { $0.value.startTime < $1.value.startTime }
      let entriesToRemove = sortedEntries.prefix(
        activeTimings.count - configuration.maxConcurrentTimings.rawValue + 1
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
      responseBodySize: configuration.includeBodySizes.rawValue
        ? response.body.map { ResponseSize($0.count.rawValue) } : nil,
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
  public var activeTimingCount: ActiveTimingCount {
    get async { ActiveTimingCount(activeTimings.count) }
  }

  /// Clears all active timings (useful for cleanup)
  public func clearActiveTimings() async {
    activeTimings.removeAll()
  }
}
