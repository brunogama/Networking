import NetworkingRuntime
import Foundation

#if canImport(OSLog)
import OSLog
#endif

#if canImport(OSLog)

// Comprehensive observability middleware that provides detailed monitoring, tracing, and analytics
// for HTTP requests. This middleware extends beyond basic timing to provide deep insights into
// network behavior, performance patterns, and operational metrics.
public actor NetworkObservabilityMiddleware: HTTPRequestMiddleware, HTTPResponseMiddleware,
  HTTPErrorMiddleware
{
  let configuration: Configuration
  let metricsCollector: any MetricsCollector
  let logger: Logger

  var activeTraces: [HTTPRequestID: ActiveTrace] = [:]
  var lastMetricsReport = Date()
  var requestHistory: [RequestSample] = []
  var errorCounts: [String: Int] = [:]
  var endpointPerformance: [String: [TimeInterval]] = [:]

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

  public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    guard configuration.shouldObserve(request).rawValue else {
      return request
    }

    let customTags = configuration.customTagExtractor(request)
    let allTags = configuration.globalTags.merging(customTags) { _, new in new }
    let context = RequestContext(from: request, customTags: allTags)

    let shouldTrace =
      configuration.enableTracing.rawValue
      && (configuration.tracingSampleRate >= 1.0
        || Double.random(in: 0...1) <= configuration.tracingSampleRate.rawValue)

    if shouldTrace {
      if activeTraces.count >= configuration.maxActiveTraces.rawValue {
        let sortedTraces = activeTraces.sorted { $0.value.startTime < $1.value.startTime }
        let tracesToRemove = sortedTraces.prefix(
          activeTraces.count - configuration.maxActiveTraces.rawValue + 1
        )
        for (requestId, _) in tracesToRemove {
          activeTraces.removeValue(forKey: requestId)
        }
      }

      activeTraces[request.id] = ActiveTrace(context: context)
    }

    let event = ObservabilityEvent.requestStarted(context)
    await metricsCollector.recordEvent(event)

    logger.debug("Request started: \(request.method.rawValue) \(request.url.absoluteString)")

    return request
  }

  public func processResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    if let trace = activeTraces.removeValue(forKey: request.id) {
      let responseContext = ResponseContext(
        from: response,
        startTime: trace.startTime,
        retryCount: trace.retryCount
      )

      let event = ObservabilityEvent.requestCompleted(trace.context, responseContext)
      await metricsCollector.recordEvent(event)

      await updatePerformanceMetrics(
        duration: responseContext.duration.rawValue,
        success: true,
        endpoint: trace.context.path.rawValue,
        error: nil
      )

      logger.debug(
        """
        Request completed: \(response.status.rawValue) \(request.method.rawValue) \
        \(request.url.absoluteString) in \(Int(responseContext.duration.rawValue * 1000))ms
        """
      )
    }

    if configuration.enableRealTimeMetrics.rawValue
      && Date().timeIntervalSince(lastMetricsReport)
        >= configuration.metricsReportingInterval.rawValue
    {
      await reportPerformanceMetrics()
      lastMetricsReport = Date()
    }

    return response
  }

  public func handleError(
    _ error: HTTPError,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    if let trace = activeTraces.removeValue(forKey: request.id) {
      let errorContext = ErrorContext(
        from: error,
        startTime: trace.startTime,
        retryCount: trace.retryCount
      )

      let event = ObservabilityEvent.requestFailed(trace.context, errorContext)
      await metricsCollector.recordEvent(event)

      await updatePerformanceMetrics(
        duration: errorContext.duration.rawValue,
        success: false,
        endpoint: trace.context.path.rawValue,
        error: errorContext.errorType.rawValue
      )

      logger.error(
        "Request failed: \(request.method.rawValue) \(request.url.absoluteString) - \(error.localizedDescription)"
      )
    }

    throw error
  }
}

#endif  // canImport(OSLog)
