// swiftlint:disable file_length
import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Retry Configuration Components

/// Retry configuration block using result builders.
public struct Retry: ConfigurationComponent {
  private let components: [any RetryComponent]

  public init(@RetryBuilder _ content: () -> [any RetryComponent]) {
    self.components = content()
  }

  public func apply(to configuration: inout NetworkClientBuilder.Configuration) {
    var retryConfig = RetryConfiguration()

    // Apply retry components to build the configuration
    for component in components {
      component.apply(to: &retryConfig)
    }

    configuration.retryConfiguration = retryConfig
  }
}

/// Result builder for retry configuration.
@resultBuilder
public struct RetryBuilder {
  public static func buildBlock(_ components: any RetryComponent...) -> [any RetryComponent] {
    components
  }

  public static func buildOptional(_ component: [any RetryComponent]?) -> [any RetryComponent] {
    component ?? []
  }

  public static func buildEither(first component: [any RetryComponent]) -> [any RetryComponent] {
    component
  }

  public static func buildEither(second component: [any RetryComponent]) -> [any RetryComponent] {
    component
  }

  public static func buildArray(_ components: [[any RetryComponent]]) -> [any RetryComponent] {
    components.flatMap { $0 }
  }
}

/// Base protocol for retry configuration components.
public protocol RetryComponent: Sendable {
  func apply(to configuration: inout RetryConfiguration)
}

/// Maximum retry attempts configuration component.
public struct MaxAttempts: RetryComponent {
  private let attempts: RetryAttemptCount

  public init(_ attempts: RetryAttemptCount) {
    self.attempts = RetryAttemptCount(max(0, attempts.rawValue))
  }

  public func apply(to configuration: inout RetryConfiguration) {
    configuration = RetryConfiguration(
      maxAttempts: attempts,
      backoffStrategy: configuration.backoffStrategy,
      delay: configuration.delay,
      retryCondition: configuration.retryCondition
    )
  }
}

/// Backoff strategy configuration component.
public struct BackoffStrategyComponent: RetryComponent {
  private let strategy: RetryBackoffStrategy

  public init(_ strategy: RetryBackoffStrategy) {
    self.strategy = strategy
  }

  public static func fixed() -> Self {
    Self(RetryBackoffStrategy.fixed)
  }

  public static func linear() -> Self {
    Self(RetryBackoffStrategy.linear)
  }

  public static func exponential() -> Self {
    Self(RetryBackoffStrategy.exponential)
  }

  public static func custom(
    _ calculator: @escaping @Sendable (RetryAttemptCount) -> RetryDelay
  ) -> Self {
    Self(
      RetryBackoffStrategy.custom(calculator)
    )
  }

  public func apply(to configuration: inout RetryConfiguration) {
    configuration = RetryConfiguration(
      maxAttempts: configuration.maxAttempts,
      backoffStrategy: strategy,
      delay: configuration.delay,
      retryCondition: configuration.retryCondition
    )
  }
}

/// Initial delay configuration component.
public struct InitialDelay: RetryComponent {
  private let delay: RetryDelay

  public init(_ delay: RetryDelay) {
    self.delay = RetryDelay(max(0, delay.rawValue))
  }

  public func apply(to configuration: inout RetryConfiguration) {
    configuration = RetryConfiguration(
      maxAttempts: configuration.maxAttempts,
      backoffStrategy: configuration.backoffStrategy,
      delay: delay,
      retryCondition: configuration.retryCondition
    )
  }
}

/// Retry condition configuration component.
public struct RetryWhen: RetryComponent {
  private let condition: @Sendable (HTTPError) -> RetryDecision

  public init(_ condition: @escaping @Sendable (HTTPError) -> RetryDecision) {
    self.condition = condition
  }

  public static func networkErrors() -> Self {
    Self { error in
      switch error.category {
      case .network: return true
      case .timeout: return true
      default: return false
      }
    }
  }

  public static func serverErrors() -> Self {
    Self { error in
      if case .http(let status) = error.category {
        return RetryDecision(status.rawValue >= 500)
      }
      return false
    }
  }

  public static func statusCodes(_ codes: Set<HTTPStatusCode>) -> Self {
    Self { error in
      if case .http(let status) = error.category {
        return RetryDecision(codes.contains(status.rawValue))
      }
      return false
    }
  }

  public func apply(to configuration: inout RetryConfiguration) {
    configuration = RetryConfiguration(
      maxAttempts: configuration.maxAttempts,
      backoffStrategy: configuration.backoffStrategy,
      delay: configuration.delay,
      retryCondition: condition
    )
  }
}
