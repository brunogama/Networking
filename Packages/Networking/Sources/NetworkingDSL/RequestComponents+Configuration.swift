import Foundation
import NetworkingCore

// MARK: - Configuration Components

public struct RequestTimeout: RequestComponent {
  private let interval: NetworkingCore.RequestTimeout

  public init(_ interval: NetworkingCore.RequestTimeout) {
    self.interval = interval
  }

  package init(_ interval: TimeInterval) {
    self.init(NetworkingCore.RequestTimeout(interval))
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    request.timeout = interval
  }
}

public struct AcceptHeader: RequestComponent {
  private let mediaType: HTTPMediaType

  public init(_ mediaType: HTTPMediaType) {
    self.mediaType = mediaType
  }

  package init(_ mediaType: String) {
    self.init(HTTPMediaType(mediaType))
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    request.headers[HTTPHeaderName("Accept")] = HTTPHeaderValue(mediaType.rawValue)
  }

  public static let json = Self("application/json")
  public static let xml = Self("application/xml")
  public static let any = Self("*/*")
  public static let html = Self("text/html")
}

public struct UserAgent: RequestComponent {
  private let userAgent: HTTPUserAgentValue

  public init(_ userAgent: HTTPUserAgentValue) {
    self.userAgent = userAgent
  }

  package init(_ userAgent: String) {
    self.init(HTTPUserAgentValue(userAgent))
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    request.headers[HTTPHeaderName("User-Agent")] = HTTPHeaderValue(userAgent.rawValue)
  }
}

// MARK: - Conditional Components

public struct ConditionalComponent: RequestComponent {
  private let condition: ConditionalRequestUsage
  private let component: any RequestComponent

  public init(_ condition: ConditionalRequestUsage, _ component: any RequestComponent) {
    self.condition = condition
    self.component = component
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    if condition.rawValue {
      try component.apply(to: &request)
    }
  }
}

// MARK: - Helper Functions

public func `if`(
  _ condition: ConditionalRequestUsage,
  _ component: any RequestComponent
) -> any RequestComponent {
  ConditionalComponent(condition, component)
}

public func `if`(
  _ condition: ConditionalRequestUsage,
  @RequestBuilder _ content: () -> [any RequestComponent]
) -> any RequestComponent {
  if condition.rawValue {
    return CompositeComponent(content())
  }

  return EmptyComponent()
}

// MARK: - Supporting Types

public struct EmptyComponent: RequestComponent {
  public init() {}

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    // No-op
  }
}

public struct CompositeComponent: RequestComponent {
  private let components: [any RequestComponent]

  public init(_ components: [any RequestComponent]) {
    self.components = components
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    for component in components {
      try component.apply(to: &request)
    }
  }
}
