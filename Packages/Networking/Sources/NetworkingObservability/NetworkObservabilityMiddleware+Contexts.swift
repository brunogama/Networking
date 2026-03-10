import NetworkingRuntime
import Foundation

#if canImport(OSLog)
import OSLog

extension NetworkObservabilityMiddleware {
  public struct RequestContext: Sendable, Identifiable {
    public let id: HTTPRequestID
    public let method: HTTPMethodName
    public let url: ObservabilityURLText
    public let host: ObservabilityHostName
    public let path: ObservabilityPathText
    public let timestamp: Date
    public let headers: HTTPHeaders
    public let bodySize: ObservabilityBodySize
    public let userAgent: ObservabilityUserAgent?
    public let requestId: HTTPRequestID
    public let correlationId: CorrelationIdentifier?
    public let sessionId: SessionIdentifier?
    public let userId: UserIdentifier?
    public let deviceId: DeviceIdentifier?
    public let appVersion: AppVersionText?
    public let platform: PlatformName?
    public let networkType: NetworkTypeName?
    public let customTags: [ObservabilityTagName: ObservabilityTagValue]

    init(
      from request: HTTPRequest,
      customTags: [ObservabilityTagName: ObservabilityTagValue] = [:]
    ) {
      self.id = request.id
      self.method = request.method.rawValue
      self.url = ObservabilityURLText(request.url.absoluteString)
      self.host = ObservabilityHostName(request.url.host ?? "unknown")
      self.path = ObservabilityPathText(request.url.path)
      self.timestamp = Date()
      self.headers = request.headers
      self.bodySize = ObservabilityBodySize((request.body?.count ?? 0).rawValue)
      self.userAgent = request.headers["User-Agent"].map { ObservabilityUserAgent($0) }
      self.requestId = request.id
      self.correlationId = request.headers["X-Correlation-ID"].map { CorrelationIdentifier($0) }
      self.sessionId = request.headers["X-Session-ID"].map { SessionIdentifier($0) }
      self.userId = request.headers["X-User-ID"].map { UserIdentifier($0) }
      self.deviceId = request.headers["X-Device-ID"].map { DeviceIdentifier($0) }
      self.appVersion = request.headers["X-App-Version"].map { AppVersionText($0) }
      self.platform = request.headers["X-Platform"].map { PlatformName($0) }
      self.networkType = request.headers["X-Network-Type"].map { NetworkTypeName($0) }
      self.customTags = customTags
    }
  }

  public struct ResponseContext: Sendable {
    public let statusCode: HTTPStatusCode
    public let statusCategory: StatusCategoryText
    public let responseSize: ResponseSize
    public let duration: MeasurementDuration
    public let headers: HTTPHeaders
    public let contentType: HTTPHeaderValue?
    public let cacheControl: HTTPHeaderValue?
    public let serverProcessingTime: MeasurementDuration?
    public let retryCount: RetryAttemptCount
    public let wasCached: CacheDecision
    public let compressionRatio: CompressionRatioValue?

    init(
      from response: HTTPResponse,
      startTime: Date,
      retryCount: RetryAttemptCount = 0,
      wasCached: CacheDecision = false
    ) {
      self.statusCode = response.status.rawValue
      self.statusCategory = Self.categorizeStatus(response.status.rawValue)
      self.responseSize = ResponseSize((response.body?.count ?? 0).rawValue)
      self.duration = MeasurementDuration(Date().timeIntervalSince(startTime))
      self.headers = response.headers
      self.contentType = response.headers["Content-Type"].map { HTTPHeaderValue($0) }
      self.cacheControl = response.headers["Cache-Control"].map { HTTPHeaderValue($0) }
      self.retryCount = retryCount
      self.wasCached = wasCached

      if let serverTime = response.headers["X-Response-Time"] ?? response.headers["Server-Timing"] {
        self.serverProcessingTime = TimeInterval(
          serverTime.replacingOccurrences(of: "ms", with: "")
        )
        .map { MeasurementDuration($0 / 1000.0) }
      } else {
        self.serverProcessingTime = nil
      }

      if let originalSize = response.headers["X-Original-Size"].flatMap(Int.init),
        originalSize > 0 && responseSize > 0
      {
        self.compressionRatio = CompressionRatioValue(
          Double(responseSize.rawValue) / Double(originalSize)
        )
      } else {
        self.compressionRatio = nil
      }
    }

    // swiftlint:disable:next cyclomatic_complexity
    fileprivate static func categorizeStatus(_ code: HTTPStatusCode) -> StatusCategoryText {
      switch code {
      case 200..<300: return "success"
      case 300..<400: return "redirect"
      case 400..<500: return "client_error"
      case 500..<600: return "server_error"
      default: return "unknown"
      }
    }
  }

  public struct ErrorContext: Sendable {
    public let errorType: ObservabilityErrorType
    public let errorCategory: ObservabilityErrorCategory
    public let errorMessage: HTTPErrorMessage
    public let duration: MeasurementDuration
    public let retryCount: RetryAttemptCount
    public let isRetryable: RetryDecision
    public let underlyingError: UnderlyingErrorText?
    public let networkCondition: NetworkConditionText?
    public let serverStatus: ServerStatusText?

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    init(from error: HTTPError, startTime: Date, retryCount: RetryAttemptCount = 0) {
      self.duration = MeasurementDuration(Date().timeIntervalSince(startTime))
      self.retryCount = retryCount
      self.isRetryable = RetryDecision(error.isTransientError.rawValue)
      if let underlyingError = error.underlyingError?.localizedDescription {
        self.underlyingError = UnderlyingErrorText(underlyingError)
      } else {
        self.underlyingError = nil
      }

      switch error.category {
      case .network(let networkError):
        self.errorType = "network"
        self.errorCategory = "connectivity"
        self.errorMessage = HTTPErrorMessage("Network error: \(networkError)")
        self.networkCondition = NetworkConditionText("\(networkError)")
        self.serverStatus = nil

      case .http(let status):
        self.errorType = "http"
        self.errorCategory = ObservabilityErrorCategory(
          ResponseContext.categorizeStatus(status.rawValue).rawValue
        )
        self.errorMessage = HTTPErrorMessage("HTTP \(status.rawValue.rawValue)")
        self.networkCondition = nil
        self.serverStatus = ServerStatusText("\(status.rawValue.rawValue)")

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
        self.errorMessage = HTTPErrorMessage("Decoding error: \(message)")
        self.networkCondition = nil
        self.serverStatus = nil

      case .encoding(let message):
        self.errorType = "encoding"
        self.errorCategory = "data_processing"
        self.errorMessage = HTTPErrorMessage("Encoding error: \(message)")
        self.networkCondition = nil
        self.serverStatus = nil

      case .configuration(let message):
        self.errorType = "configuration"
        self.errorCategory = "configuration"
        self.errorMessage = HTTPErrorMessage("Configuration error: \(message)")
        self.networkCondition = nil
        self.serverStatus = nil

      case .custom(let type, let message):
        self.errorType = "custom"
        self.errorCategory = ObservabilityErrorCategory(type.lowercased())
        self.errorMessage = HTTPErrorMessage("\(type) error: \(message)")
        self.networkCondition = nil
        self.serverStatus = nil
      }
    }
  }
}

#endif  // canImport(OSLog)
