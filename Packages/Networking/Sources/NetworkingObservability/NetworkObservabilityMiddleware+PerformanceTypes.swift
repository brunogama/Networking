import NetworkingRuntime
import Foundation

#if canImport(OSLog)
import OSLog

extension NetworkObservabilityMiddleware {
  public struct PerformanceMetrics: Sendable {
    public let timestamp: Date
    public let totalRequests: RequestCount
    public let successfulRequests: RequestCount
    public let failedRequests: RequestCount
    public let averageResponseTime: MeasurementDuration
    public let p50ResponseTime: MeasurementDuration
    public let p95ResponseTime: MeasurementDuration
    public let p99ResponseTime: MeasurementDuration
    public let errorRate: ErrorRateValue
    public let throughput: ThroughputValue
    public let activeConnections: ActiveConnectionCount
    public let cacheHitRate: CacheHitRateValue
    public let retryRate: RetryRateValue
    public let topErrors: [ObservabilityErrorType: RequestCount]
    public let topSlowEndpoints: [SlowEndpoint]
    public let networkHealth: NetworkHealth

    public struct SlowEndpoint: Sendable {
      public let endpoint: EndpointIdentifier
      public let averageResponseTime: MeasurementDuration
    }

    public struct NetworkHealth: Sendable {
      public let status: HealthStatus
      public let latencyGrade: Grade
      public let reliabilityGrade: Grade
      public let throughputGrade: Grade
      public let overallGrade: Grade

      // swiftlint:disable nesting
      public enum HealthStatus: Sendable {
        case excellent
        case good
        case fair
        case poor
        case critical

        public var label: StatusCategoryText {
          switch self {
          case .excellent: return "excellent"
          case .good: return "good"
          case .fair: return "fair"
          case .poor: return "poor"
          case .critical: return "critical"
          }
        }
      }

      // swiftlint:disable identifier_name
      public enum Grade: Int, Sendable {
        case f = 0
        case d = 1
        case c = 2
        case b = 3
        case a = 4

        public var label: UserMessageText {
          switch self {
          case .a: return "A"
          case .b: return "B"
          case .c: return "C"
          case .d: return "D"
          case .f: return "F"
          }
        }
      }
      // swiftlint:enable identifier_name
      // swiftlint:enable nesting
    }
  }
}

#endif  // canImport(OSLog)
