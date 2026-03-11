import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Configuration builder for NetworkClient using result builders.
@resultBuilder
public struct NetworkClientBuilder {
  /// Intermediate configuration storage.
  public struct Configuration: Sendable {
    public var session: URLSession = .shared
    public var requestMiddlewares: [any HTTPRequestMiddleware] = []
    public var responseMiddlewares: [any HTTPResponseMiddleware] = []
    public var errorMiddlewares: [any HTTPErrorMiddleware] = []
    public var baseURL: HTTPRequestURL?
    public var defaultHeaders: HTTPHeaders = [:]
    public var timeout = RequestTimeout(rawValue: 30.0)

    // Configuration components storage
    public var authenticationConfiguration: AuthenticationConfiguration?
    public var retryConfiguration: RetryConfiguration?
    public var cachingConfiguration: CachingConfiguration?
    public var sessionConfiguration: SessionConfiguration?
    public var securityConfiguration: SecurityConfiguration?

    public init() {}
  }

  public static func buildBlock(
    _ components: any ConfigurationComponent...
  ) -> [any ConfigurationComponent] {
    components
  }

  public static func buildExpression(
    _ expression: any ConfigurationComponent
  ) -> any ConfigurationComponent {
    expression
  }

  public static func buildOptional(
    _ component: [any ConfigurationComponent]?
  ) -> [any ConfigurationComponent] {
    component ?? []
  }

  public static func buildEither(
    first component: [any ConfigurationComponent]
  ) -> [any ConfigurationComponent] {
    component
  }

  public static func buildEither(
    second component: [any ConfigurationComponent]
  ) -> [any ConfigurationComponent] {
    component
  }

  public static func buildArray(
    _ components: [[any ConfigurationComponent]]
  ) -> [any ConfigurationComponent] {
    components.flatMap { $0 }
  }
}
