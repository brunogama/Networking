// swiftlint:disable file_length
import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Caching Configuration Components

/// Caching configuration block using result builders.
public struct Caching: ConfigurationComponent {
  private let components: [any CachingComponent]

  public init(@CachingBuilder _ content: () -> [any CachingComponent]) {
    self.components = content()
  }

  public func apply(to configuration: inout NetworkClientBuilder.Configuration) {
    var cachingConfig = CachingConfiguration()

    // Apply caching components to build the configuration
    for component in components {
      component.apply(to: &cachingConfig)
    }

    configuration.cachingConfiguration = cachingConfig
  }
}

/// Result builder for caching configuration.
@resultBuilder
public struct CachingBuilder {
  public static func buildBlock(_ components: any CachingComponent...) -> [any CachingComponent] {
    components
  }

  public static func buildOptional(_ component: [any CachingComponent]?) -> [any CachingComponent] {
    component ?? []
  }

  public static func buildEither(
    first component: [any CachingComponent]
  ) -> [any CachingComponent] {
    component
  }

  public static func buildEither(
    second component: [any CachingComponent]
  ) -> [any CachingComponent] {
    component
  }

  public static func buildArray(_ components: [[any CachingComponent]]) -> [any CachingComponent] {
    components.flatMap { $0 }
  }
}

/// Base protocol for caching configuration components.
public protocol CachingComponent: Sendable {
  func apply(to configuration: inout CachingConfiguration)
}

/// Caching policy configuration component.
public struct Policy: CachingComponent {
  private let policy: CachingPolicy

  public init(_ policy: CachingPolicy) {
    self.policy = policy
  }

  public static func none() -> Self {
    Self(.none)
  }

  public static func standard() -> Self {
    Self(.standard)
  }

  public static func aggressive() -> Self {
    Self(.aggressive)
  }

  public static func custom(
    maxAge: CacheMaxAge,
    revalidate: CacheRevalidationFlag = true
  ) -> Self {
    Self(.custom(maxAge: maxAge, revalidate: revalidate))
  }

  public func apply(to configuration: inout CachingConfiguration) {
    configuration = CachingConfiguration(
      policy: policy,
      storage: configuration.storage,
      duration: configuration.duration,
      shouldCache: configuration.shouldCache
    )
  }
}

/// Cache storage configuration component.
public struct Storage: CachingComponent {
  private let storage: CacheStorage

  public init(_ storage: CacheStorage) {
    self.storage = storage
  }

  public static func memory(size: StorageSize) -> Self {
    Self(.memory(size: size))
  }

  public static func disk(size: StorageSize, path: CacheStoragePath? = nil) -> Self {
    Self(.disk(size: size, path: path))
  }

  public static func hybrid(
    memorySize: StorageSize,
    diskSize: StorageSize,
    path: CacheStoragePath? = nil
  ) -> Self {
    Self(.hybrid(memorySize: memorySize, diskSize: diskSize, path: path))
  }

  public func apply(to configuration: inout CachingConfiguration) {
    configuration = CachingConfiguration(
      policy: configuration.policy,
      storage: storage,
      duration: configuration.duration,
      shouldCache: configuration.shouldCache
    )
  }
}

/// Cache duration configuration component.
public struct Duration: CachingComponent {
  private let duration: CacheDuration

  public init(_ duration: CacheDuration) {
    self.duration = duration
  }

  public static func ttl(_ seconds: RequestTimeout) -> Self {
    Self(.ttl(seconds))
  }

  public static func until(_ date: Date) -> Self {
    Self(.until(date))
  }

  public static func session() -> Self {
    Self(.session)
  }

  public static func forever() -> Self {
    Self(.forever)
  }

  public func apply(to configuration: inout CachingConfiguration) {
    configuration = CachingConfiguration(
      policy: configuration.policy,
      storage: configuration.storage,
      duration: duration,
      shouldCache: configuration.shouldCache
    )
  }
}

/// Cache condition configuration component.
public struct CacheWhen: CachingComponent {
  private let condition: @Sendable (HTTPRequest, HTTPResponse) -> CacheDecision

  public init(_ condition: @escaping @Sendable (HTTPRequest, HTTPResponse) -> CacheDecision) {
    self.condition = condition
  }

  public static func always() -> Self {
    Self { _, _ in true }
  }

  public static func never() -> Self {
    Self { _, _ in false }
  }

  public static func getRequestsOnly() -> Self {
    Self { request, _ in CacheDecision(request.method == .get) }
  }

  public static func successfulResponses() -> Self {
    Self { _, response in CacheDecision(response.status.isSuccess.rawValue) }
  }

  public static func statusCodes(_ codes: Set<HTTPStatusCode>) -> Self {
    Self { _, response in CacheDecision(codes.contains(response.status.rawValue)) }
  }

  public func apply(to configuration: inout CachingConfiguration) {
    configuration = CachingConfiguration(
      policy: configuration.policy,
      storage: configuration.storage,
      duration: configuration.duration,
      shouldCache: condition
    )
  }
}
