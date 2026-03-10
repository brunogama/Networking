import Foundation
import NetworkingCore

extension ErrorMiddleware {
  /// Enriches errors with additional context and metadata.
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

  /// Rule for enriching errors with additional information.
  public protocol EnrichmentRule: Sendable {
    func enrich(_ error: HTTPError, request: HTTPRequest, context: ErrorContext) -> HTTPError
  }

  /// Adds timestamp information to errors.
  public struct TimestampEnrichmentRule: EnrichmentRule {
    public init() {}

    public func enrich(_ error: HTTPError, request: HTTPRequest, context: ErrorContext) -> HTTPError
    {
      error
    }
  }

  /// Adds request details to errors.
  public struct RequestDetailsEnrichmentRule: EnrichmentRule {
    public init() {}

    public func enrich(_ error: HTTPError, request: HTTPRequest, context: ErrorContext) -> HTTPError
    {
      error
    }
  }

  /// Adds network condition information to errors.
  public struct NetworkConditionEnrichmentRule: EnrichmentRule {
    public init() {}

    public func enrich(_ error: HTTPError, request: HTTPRequest, context: ErrorContext) -> HTTPError
    {
      error
    }
  }

  /// Adds user context information to errors.
  public struct UserContextEnrichmentRule: EnrichmentRule {
    public init() {}

    public func enrich(_ error: HTTPError, request: HTTPRequest, context: ErrorContext) -> HTTPError
    {
      error
    }
  }

  /// Classifies errors for appropriate handling.
  public struct ErrorClassificationProcessor: ErrorProcessor {
    public init() {}

    public func process(
      error: HTTPError,
      for request: HTTPRequest,
      context: ErrorContext
    ) async -> HTTPError {
      error
    }
  }

  /// Sanitizes errors by removing sensitive information before logging or reporting.
  public struct ErrorSanitizationProcessor: ErrorProcessor {
    private let sensitiveHeaders: Set<HTTPHeaderName>
    private let sensitiveQueryParams: Set<QueryParameterName>

    public init(
      sensitiveHeaders: Set<HTTPHeaderName> = ["authorization", "x-api-key", "cookie"],
      sensitiveQueryParams: Set<QueryParameterName> = ["access_token", "password", "secret"]
    ) {
      self.sensitiveHeaders = Set(sensitiveHeaders.map { HTTPHeaderName($0.lowercased()) })
      self.sensitiveQueryParams = Set(
        sensitiveQueryParams.map { QueryParameterName($0.lowercased()) }
      )
    }

    public func process(
      error: HTTPError,
      for request: HTTPRequest,
      context: ErrorContext
    ) async -> HTTPError {
      let sanitizedRequest = sanitizeRequest(request)

      return HTTPError(
        category: error.category,
        request: sanitizedRequest,
        response: error.response,
        underlyingError: error.underlyingError
      )
    }

    private func sanitizeRequest(_ request: HTTPRequest) -> HTTPRequest {
      var sanitizedHeaders = request.headers
      for header in sanitizedHeaders.keys
      where sensitiveHeaders.contains(HTTPHeaderName(header.lowercased())) {
        sanitizedHeaders[header] = "***REDACTED***"
      }

      var urlComponents = URLComponents(url: request.url, resolvingAgainstBaseURL: false)
      if let queryItems = urlComponents?.queryItems {
        urlComponents?.queryItems = queryItems.map { item in
          if sensitiveQueryParams.contains(QueryParameterName(item.name.lowercased())) {
            return URLQueryItem(name: item.name, value: "***REDACTED***")
          }
          return item
        }
      }

      let sanitizedURL = urlComponents?.url.map { HTTPRequestURL($0) } ?? request.url

      return HTTPRequest(
        method: request.method,
        url: sanitizedURL,
        headers: sanitizedHeaders,
        body: request.body,
        timeout: request.timeout
      )
    }
  }

  /// Handles error recovery using configured strategies.
  public struct ErrorRecoveryProcessor: ErrorProcessor {
    private let recoveryStrategy: any ErrorRecoveryStrategies.RecoveryStrategy
    private let httpClient: any HTTPClient
    private let maxAttempts: RetryAttemptCount

    public init(
      recoveryStrategy: any ErrorRecoveryStrategies.RecoveryStrategy,
      httpClient: any HTTPClient,
      maxAttempts: RetryAttemptCount = 3
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
      if context.attemptNumber.rawValue > maxAttempts {
        return error
      }

      guard recoveryStrategy.canRecover(from: error).rawValue else {
        return error
      }

      do {
        _ = try await recoveryStrategy.recover(
          from: error,
          request: request,
          using: httpClient
        )

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
}
