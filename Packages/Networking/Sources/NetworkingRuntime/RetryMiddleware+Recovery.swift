import NetworkingCore

extension RetryMiddleware {
  /// Configuration that includes recovery strategy integration.
  public struct RecoveryConfiguration: Sendable {
    public let retryConfig: Configuration
    public let recoveryStrategies: [any ErrorRecoveryStrategies.RecoveryStrategy]
    public let prioritizeRecovery: RetryDecision

    public init(
      retryConfig: Configuration = Configuration(),
      recoveryStrategies: [any ErrorRecoveryStrategies.RecoveryStrategy] = [],
      prioritizeRecovery: RetryDecision = true
    ) {
      self.retryConfig = retryConfig
      self.recoveryStrategies = recoveryStrategies
      self.prioritizeRecovery = prioritizeRecovery
    }
  }

  /// Enhanced retry middleware with recovery strategy integration.
  public struct WithRecoveryStrategies: HTTPErrorMiddleware {
    private let recoveryConfig: RecoveryConfiguration
    private let baseMiddleware: RetryMiddleware

    public init(configuration: RecoveryConfiguration, client: any HTTPClient) {
      self.recoveryConfig = configuration
      self.baseMiddleware = RetryMiddleware(
        configuration: configuration.retryConfig,
        client: client
      )
    }

    public func handleError(
      _ error: HTTPError,
      for request: HTTPRequest
    ) async throws -> HTTPResponse {
      if recoveryConfig.prioritizeRecovery.rawValue {
        if let recoveredResponse = await tryRecoveryStrategies(error, request: request) {
          return recoveredResponse
        }

        return try await baseMiddleware.handleError(error, for: request)
      }

      do {
        return try await baseMiddleware.handleError(error, for: request)
      } catch let finalError as HTTPError {
        if let recoveredResponse = await tryRecoveryStrategies(finalError, request: request) {
          return recoveredResponse
        }

        throw finalError
      }
    }

    private func tryRecoveryStrategies(
      _ error: HTTPError,
      request: HTTPRequest
    ) async -> HTTPResponse? {
      for strategy in recoveryConfig.recoveryStrategies
      where strategy.canRecover(from: error).rawValue {
        do {
          return try await strategy.recover(
            from: error,
            request: request,
            using: baseMiddleware.client
          )
        } catch {
          continue
        }
      }

      return nil
    }
  }
}
