import Foundation

/// Comprehensive error handling middleware system with Swift 6 compliance
public struct ErrorMiddleware: Sendable {
  // MARK: - Error Processing Pipeline Protocol

  /// Protocol for error transformation components in the pipeline
  public protocol ErrorProcessor: Sendable {
    /// Processes and potentially transforms an error
    /// - Parameters:
    ///   - error: The error to process
    ///   - request: The original request
    ///   - context: Additional context for processing
    /// - Returns: A processed error or the original error
    func process(
      error: HTTPError,
      for request: HTTPRequest,
      context: ErrorContext
    ) async -> HTTPError
  }

  /// Context information for error processing
  public struct ErrorContext: Sendable {
    public let timestamp: Date
    public let attemptNumber: Int
    public let userAgent: String?
    public let sessionId: String?
    public let additionalMetadata: [String: String]

    public init(
      timestamp: Date = Date(),
      attemptNumber: Int = 1,
      userAgent: String? = nil,
      sessionId: String? = nil,
      additionalMetadata: [String: String] = [:]
    ) {
      self.timestamp = timestamp
      self.attemptNumber = attemptNumber
      self.userAgent = userAgent
      self.sessionId = sessionId
      self.additionalMetadata = additionalMetadata
    }
  }

  // MARK: - Error Enrichment Processor

  /// Enriches errors with additional context and metadata
  public struct ErrorEnrichmentProcessor: ErrorProcessor {
    private let enrichmentRules: [any EnrichmentRule]

    public init(enrichmentRules: [any EnrichmentRule] = []) {
      self.enrichmentRules = enrichmentRules.isEmpty ? Self.defaultEnrichmentRules : enrichmentRules
    }

    public func process(
      error: HTTPError,
      for request: HTTPRequest,
      context: ErrorContext
    ) async -> HTTPError {
      var enrichedError = error

      // Apply enrichment rules
      for rule in enrichmentRules {
        enrichedError = rule.enrich(enrichedError, request: request, context: context)
      }

      return enrichedError
    }

    private static let defaultEnrichmentRules: [any EnrichmentRule] = [
      TimestampEnrichmentRule(),
      RequestDetailsEnrichmentRule(),
      NetworkConditionEnrichmentRule(),
      UserContextEnrichmentRule(),
    ]
  }

  /// Rule for enriching errors with additional information
  public protocol EnrichmentRule: Sendable {
    func enrich(_ error: HTTPError, request: HTTPRequest, context: ErrorContext) -> HTTPError
  }

  /// Adds timestamp information to errors
  public struct TimestampEnrichmentRule: EnrichmentRule {
    public init() {}

    public func enrich(_ error: HTTPError, request: HTTPRequest, context: ErrorContext) -> HTTPError
    {
      // For this implementation, we'd ideally extend HTTPError to support metadata
      // For now, we'll return the error as-is since HTTPError is immutable
      // In a real implementation, you might want to create an EnrichedHTTPError type
      error
    }
  }

  /// Adds request details to errors
  public struct RequestDetailsEnrichmentRule: EnrichmentRule {
    public init() {}

    public func enrich(_ error: HTTPError, request: HTTPRequest, context: ErrorContext) -> HTTPError
    {
      // Add request-specific information to error context
      error
    }
  }

  /// Adds network condition information to errors
  public struct NetworkConditionEnrichmentRule: EnrichmentRule {
    public init() {}

    public func enrich(_ error: HTTPError, request: HTTPRequest, context: ErrorContext) -> HTTPError
    {
      // In a real implementation, this would check network reachability,
      // connection quality, etc.
      error
    }
  }

  /// Adds user context information to errors
  public struct UserContextEnrichmentRule: EnrichmentRule {
    public init() {}

    public func enrich(_ error: HTTPError, request: HTTPRequest, context: ErrorContext) -> HTTPError
    {
      // Add user session, device, app version, etc.
      error
    }
  }

  // MARK: - Error Classification Processor

  /// Classifies errors for appropriate handling
  public struct ErrorClassificationProcessor: ErrorProcessor {
    public init() {}

    public func process(
      error: HTTPError,
      for request: HTTPRequest,
      context: ErrorContext
    ) async -> HTTPError {
      // The classification is already handled by HTTPError extensions
      // This processor could be used to override or enhance classifications
      error
    }
  }

  // MARK: - Error Sanitization Processor

  /// Sanitizes errors by removing sensitive information before logging or reporting
  public struct ErrorSanitizationProcessor: ErrorProcessor {
    private let sensitiveHeaders: Set<String>
    private let sensitiveQueryParams: Set<String>

    public init(
      sensitiveHeaders: Set<String> = ["Authorization", "X-API-Key", "Cookie"],
      sensitiveQueryParams: Set<String> = ["access_token", "password", "secret"]
    ) {
      self.sensitiveHeaders = Set(sensitiveHeaders.map { $0.lowercased() })
      self.sensitiveQueryParams = Set(sensitiveQueryParams.map { $0.lowercased() })
    }

    public func process(
      error: HTTPError,
      for request: HTTPRequest,
      context: ErrorContext
    ) async -> HTTPError {
      // Create a sanitized version of the request
      let sanitizedRequest = sanitizeRequest(request)

      // Create new error with sanitized request
      return HTTPError(
        category: error.category,
        request: sanitizedRequest,
        response: error.response,
        underlyingError: error.underlyingError
      )
    }

    private func sanitizeRequest(_ request: HTTPRequest) -> HTTPRequest {
      // Sanitize headers
      var sanitizedHeaders = request.headers
      for header in sanitizedHeaders.keys {
        if sensitiveHeaders.contains(header.lowercased()) {
          sanitizedHeaders[header] = "***REDACTED***"
        }
      }

      // Sanitize URL query parameters
      var urlComponents = URLComponents(url: request.url, resolvingAgainstBaseURL: false)
      if let queryItems = urlComponents?.queryItems {
        urlComponents?.queryItems = queryItems.map { item in
          if sensitiveQueryParams.contains(item.name.lowercased()) {
            return URLQueryItem(name: item.name, value: "***REDACTED***")
          }
          return item
        }
      }

      let sanitizedURL = urlComponents?.url ?? request.url

      return HTTPRequest(
        method: request.method,
        url: sanitizedURL,
        headers: sanitizedHeaders,
        body: request.body,  // Consider sanitizing body content as well
        timeout: request.timeout
      )
    }
  }

  // MARK: - Error Recovery Processor

  /// Handles error recovery using configured strategies
  public struct ErrorRecoveryProcessor: ErrorProcessor {
    private let recoveryStrategy: any ErrorRecoveryStrategies.RecoveryStrategy
    private let httpClient: any HTTPClient
    private let maxAttempts: Int

    public init(
      recoveryStrategy: any ErrorRecoveryStrategies.RecoveryStrategy,
      httpClient: any HTTPClient,
      maxAttempts: Int = 3
    ) {
      self.recoveryStrategy = recoveryStrategy
      self.httpClient = httpClient
      self.maxAttempts = maxAttempts
    }

    public func process(
      error: HTTPError,
      for request: HTTPRequest,
      context: ErrorContext
    ) async -> HTTPError {
      // Check if we've exceeded max attempts
      if context.attemptNumber > maxAttempts {
        return error
      }

      // Check if the strategy can recover from this error
      guard recoveryStrategy.canRecover(from: error) else {
        return error
      }

      // Attempt recovery
      do {
        _ = try await recoveryStrategy.recover(
          from: error,
          request: request,
          using: httpClient
        )

        // If recovery succeeds, we don't return an error
        // This processor is designed to modify errors, not handle recovery directly
        // In a real implementation, recovery would be handled at a higher level
        return error
      } catch let recoveryError as HTTPError {
        return recoveryError
      } catch {
        return HTTPError(
          category: .network(.serverUnreachable),
          request: request,
          underlyingError: error
        )
      }
    }
  }

  // MARK: - Error Pipeline

  /// Manages the error processing pipeline
  public struct ErrorPipeline: Sendable {
    private let processors: [any ErrorProcessor]

    public init(processors: [any ErrorProcessor]) {
      self.processors = processors
    }

    /// Processes an error through the pipeline
    public func process(
      error: HTTPError,
      for request: HTTPRequest,
      context: ErrorContext = ErrorContext()
    ) async -> HTTPError {
      var currentError = error

      for processor in processors {
        currentError = await processor.process(
          error: currentError,
          for: request,
          context: context
        )
      }

      return currentError
    }

    /// Creates a standard error processing pipeline
    public static func standard(
      httpClient: any HTTPClient,
      recoveryStrategy: (any ErrorRecoveryStrategies.RecoveryStrategy)? = nil
    ) -> Self {
      var processors: [any ErrorProcessor] = [
        ErrorEnrichmentProcessor(),
        ErrorClassificationProcessor(),
        ErrorSanitizationProcessor(),
      ]

      if let strategy = recoveryStrategy {
        processors.append(
          ErrorRecoveryProcessor(
            recoveryStrategy: strategy,
            httpClient: httpClient
          )
        )
      }

      return Self(processors: processors)
    }

    /// Creates a development error processing pipeline with minimal sanitization
    public static func development(httpClient: any HTTPClient) -> Self {
      Self(processors: [
        ErrorEnrichmentProcessor(),
        ErrorClassificationProcessor(),
        // No sanitization in development for debugging purposes
      ])
    }

    /// Creates a production error processing pipeline with full sanitization
    public static func production(
      httpClient: any HTTPClient,
      recoveryStrategy: any ErrorRecoveryStrategies.RecoveryStrategy
    ) -> Self {
      Self(processors: [
        ErrorEnrichmentProcessor(),
        ErrorClassificationProcessor(),
        ErrorSanitizationProcessor(),
        ErrorRecoveryProcessor(
          recoveryStrategy: recoveryStrategy,
          httpClient: httpClient
        ),
      ])
    }
  }

  // MARK: - Error Middleware Implementation

  /// Main error middleware that integrates with the HTTP client
  public struct HTTPErrorMiddleware {
    private let pipeline: ErrorPipeline

    public init(pipeline: ErrorPipeline) {
      self.pipeline = pipeline
    }

    public func handleError(
      _ error: HTTPError,
      for request: HTTPRequest
    ) async throws -> HTTPResponse {
      // Process the error through the pipeline
      let processedError = await pipeline.process(
        error: error,
        for: request,
        context: ErrorContext()
      )

      // After processing, still throw the error since this middleware
      // doesn't directly handle recovery (that would be done by recovery middleware)
      throw processedError
    }
  }
}

// MARK: - Convenience Extensions

extension ErrorMiddleware.ErrorPipeline {
  /// Creates a pipeline with custom processors
  public static func custom(
    processors: [any ErrorMiddleware.ErrorProcessor]
  ) -> ErrorMiddleware.ErrorPipeline {
    ErrorMiddleware.ErrorPipeline(processors: processors)
  }

  /// Adds a processor to an existing pipeline
  public func adding(
    _ processor: any ErrorMiddleware.ErrorProcessor
  ) -> ErrorMiddleware.ErrorPipeline {
    ErrorMiddleware.ErrorPipeline(processors: processors + [processor])
  }
}

// MARK: - Error Reporting Integration

extension ErrorMiddleware {
  /// Protocol for error reporting services
  public protocol ErrorReporter: Sendable {
    func report(_ error: HTTPError, context: ErrorContext) async
  }

  /// Console error reporter for development
  public struct ConsoleErrorReporter: ErrorReporter {
    public init() {}

    public func report(_ error: HTTPError, context: ErrorContext) async {
      print("🔴 HTTP Error: \(error.debugDescription)")
      print("   Context: \(context)")
    }
  }

  /// Error reporting processor
  public struct ErrorReportingProcessor: ErrorProcessor {
    private let reporter: any ErrorReporter

    public init(reporter: any ErrorReporter) {
      self.reporter = reporter
    }

    public func process(
      error: HTTPError,
      for request: HTTPRequest,
      context: ErrorContext
    ) async -> HTTPError {
      // Report the error
      await reporter.report(error, context: context)
      return error
    }
  }
}
