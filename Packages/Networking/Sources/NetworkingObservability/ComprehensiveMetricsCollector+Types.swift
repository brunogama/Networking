import NetworkingRuntime
import Foundation

#if canImport(OSLog)
import OSLog

extension ComprehensiveMetricsCollector {
  public struct EventRecord: Sendable {
    public let event: NetworkObservabilityMiddleware.ObservabilityEvent
    public let timestamp: Date
    public let eventId: EventIdentifier
    public let sessionId: SessionIdentifier?
    public let userId: UserIdentifier?

    init(
      event: NetworkObservabilityMiddleware.ObservabilityEvent,
      sessionId: SessionIdentifier? = nil,
      userId: UserIdentifier? = nil
    ) {
      self.event = event
      self.timestamp = Date()
      self.eventId = EventIdentifier()
      self.sessionId = sessionId
      self.userId = userId
    }
  }

  public struct MetricsWindow: Sendable {
    public let windowStart: Date
    public let windowEnd: Date
    public let totalRequests: RequestCount
    public let successfulRequests: RequestCount
    public let failedRequests: RequestCount
    public let averageResponseTime: MeasurementDuration
    public let p50ResponseTime: MeasurementDuration
    public let p95ResponseTime: MeasurementDuration
    public let p99ResponseTime: MeasurementDuration
    public let errorRate: ErrorRateValue
    public let throughput: ThroughputValue
    public let topErrors: [ObservabilityErrorType: RequestCount]
    public let endpointStats: [EndpointIdentifier: EndpointMetrics]

    public struct EndpointMetrics: Sendable {
      public let endpoint: EndpointIdentifier
      public let requestCount: RequestCount
      public let averageResponseTime: MeasurementDuration
      public let p95ResponseTime: MeasurementDuration
      public let errorRate: ErrorRateValue
      public let lastRequestTime: Date
    }
  }

  public struct BusinessMetrics: Sendable, Codable {
    public let timestamp: Date
    public let dailyActiveUsers: DailyActiveUserCount
    public let totalSessions: SessionCount
    public let averageSessionDuration: MeasurementDuration
    public let conversionRate: ConversionRate
    public let errorsByFeature: [ObservabilityTagName: RequestCount]
    public let performanceByFeature: [ObservabilityTagName: MeasurementDuration]
    public let userRetentionRate: UserRetentionRate
    public let apiUsageByEndpoint: [EndpointIdentifier: RequestCount]

    public init(
      dailyActiveUsers: DailyActiveUserCount = 0,
      totalSessions: SessionCount = 0,
      averageSessionDuration: MeasurementDuration = 0,
      conversionRate: ConversionRate = 0,
      errorsByFeature: [ObservabilityTagName: RequestCount] = [:],
      performanceByFeature: [ObservabilityTagName: MeasurementDuration] = [:],
      userRetentionRate: UserRetentionRate = 0,
      apiUsageByEndpoint: [EndpointIdentifier: RequestCount] = [:]
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

  public struct Configuration: Sendable {
    public let maxEventsInMemory: MaxEventsInMemory
    public let eventRetentionDuration: EventRetentionDuration
    public let metricsWindowSize: MetricsWindowSize
    public let enablePersistence: EnablePersistenceFlag
    public let persistenceDirectory: PersistenceDirectory?
    public let enableAlerting: EnableAlertingFlag
    public let alertThresholds: AlertThresholds
    public let enableBusinessMetrics: CollectBusinessMetricsFlag
    public let eventProcessors: [ObservabilityTagName: @Sendable (EventRecord) async -> Void]

    public init(
      maxEventsInMemory: MaxEventsInMemory = 10_000,
      eventRetentionDuration: EventRetentionDuration = 3600,
      metricsWindowSize: MetricsWindowSize = 300,
      enablePersistence: EnablePersistenceFlag = false,
      persistenceDirectory: PersistenceDirectory? = nil,
      enableAlerting: EnableAlertingFlag = true,
      alertThresholds: AlertThresholds = AlertThresholds(),
      enableBusinessMetrics: CollectBusinessMetricsFlag = true,
      eventProcessors: [ObservabilityTagName: @Sendable (EventRecord) async -> Void] = [:]
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
    public let errorRateThreshold: AlertThresholdValue
    public let responseTimeThreshold: MeasurementDuration
    public let throughputThreshold: ThroughputValue
    public let maxActiveConnections: ActiveConnectionCount

    public init(
      errorRateThreshold: AlertThresholdValue = 5.0,
      responseTimeThreshold: MeasurementDuration = 2.0,
      throughputThreshold: ThroughputValue = 0.1,
      maxActiveConnections: ActiveConnectionCount = 1000
    ) {
      self.errorRateThreshold = errorRateThreshold
      self.responseTimeThreshold = responseTimeThreshold
      self.throughputThreshold = throughputThreshold
      self.maxActiveConnections = maxActiveConnections
    }
  }

  public enum AlertLevel: Sendable, Codable {
    case info
    case warning
    case error
    case critical

    public var label: UserMessageText {
      switch self {
      case .info: return "INFO"
      case .warning: return "WARNING"
      case .error: return "ERROR"
      case .critical: return "CRITICAL"
      }
    }
  }

  public struct Alert: Sendable, Identifiable, Codable {
    public let id: EventIdentifier
    public let level: AlertLevel
    public let title: AlertTitle
    public let message: AlertMessage
    public let timestamp: Date
    public let metric: AlertMetricName?
    public let value: AlertThresholdValue?
    public let threshold: AlertThresholdValue?

    public init(
      level: AlertLevel,
      title: AlertTitle,
      message: AlertMessage,
      metric: AlertMetricName? = nil,
      value: AlertThresholdValue? = nil,
      threshold: AlertThresholdValue? = nil
    ) {
      self.id = EventIdentifier()
      self.level = level
      self.title = title
      self.message = message
      self.timestamp = Date()
      self.metric = metric
      self.value = value
      self.threshold = threshold
    }
  }
}

#endif  // canImport(OSLog)
