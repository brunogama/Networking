import Foundation
import NetworkingCore

/// Comprehensive error handling middleware system with Swift 6 compliance
public struct ErrorMiddleware: Sendable {
  /// Protocol for error transformation components in the pipeline.
  public protocol ErrorProcessor: Sendable {
    /// Processes and potentially transforms an error.
    func process(
      error: HTTPError,
      for request: HTTPRequest,
      context: ErrorContext
    ) async -> HTTPError
  }

  /// Context information for error processing.
  public struct ErrorContext: Sendable {
    public let timestamp: Date
    public let attemptNumber: RetryAttemptCount
    public let userAgent: HTTPUserAgentValue?
    public let sessionId: SessionIdentifier?
    public let additionalMetadata: [ErrorContextMetadataKey: ErrorContextMetadataValue]

    public init(
      timestamp: Date = Date(),
      attemptNumber: RetryAttemptCount = 1,
      userAgent: HTTPUserAgentValue? = nil,
      sessionId: SessionIdentifier? = nil,
      additionalMetadata: [ErrorContextMetadataKey: ErrorContextMetadataValue] = [:]
    ) {
      self.timestamp = timestamp
      self.attemptNumber = attemptNumber
      self.userAgent = userAgent
      self.sessionId = sessionId
      self.additionalMetadata = additionalMetadata
    }
  }

  /// Manages the error processing pipeline.
  public struct ErrorPipeline: Sendable {
    fileprivate let processors: [any ErrorProcessor]

    public init(processors: [any ErrorProcessor]) {
      self.processors = processors
    }

    /// Processes an error through the pipeline.
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

    /// Creates a standard error processing pipeline.
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

    /// Creates a development error processing pipeline with minimal sanitization.
    public static func development(httpClient: any HTTPClient) -> Self {
      Self(processors: [
        ErrorEnrichmentProcessor(),
        ErrorClassificationProcessor(),
      ])
    }

    /// Creates a production error processing pipeline with full sanitization.
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

  /// Main error middleware that integrates with the HTTP client.
  public struct HTTPErrorMiddleware {
    private let pipeline: ErrorPipeline

    public init(pipeline: ErrorPipeline) {
      self.pipeline = pipeline
    }

    public func handleError(
      _ error: HTTPError,
      for request: HTTPRequest
    ) async throws -> HTTPResponse {
      let processedError = await pipeline.process(
        error: error,
        for: request,
        context: ErrorContext()
      )

      throw processedError
    }
  }
}

extension ErrorMiddleware.ErrorPipeline {
  /// Creates a pipeline with custom processors.
  public static func custom(
    processors: [any ErrorMiddleware.ErrorProcessor]
  ) -> ErrorMiddleware.ErrorPipeline {
    ErrorMiddleware.ErrorPipeline(processors: processors)
  }

  /// Adds a processor to an existing pipeline.
  public func adding(
    _ processor: any ErrorMiddleware.ErrorProcessor
  ) -> ErrorMiddleware.ErrorPipeline {
    ErrorMiddleware.ErrorPipeline(processors: processors + [processor])
  }
}
