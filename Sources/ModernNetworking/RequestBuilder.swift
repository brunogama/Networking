import Foundation

// MARK: - Request Builder Components

/// Base protocol for request builder components.
public protocol RequestComponent: Sendable {
  func apply(to request: inout RequestBuilder.PartialRequest) throws
}

/// Result builder for constructing HTTP requests with a fluent API.
@resultBuilder
public struct RequestBuilder {
  /// Internal structure for building requests.
  public struct PartialRequest: Sendable {
    public var method: HTTPMethod = .get
    public var url: URL?
    public var headers: [String: String] = [:]
    public var body: Data?
    public var timeout: TimeInterval = 30.0

    public init() {}
  }

  public static func buildBlock(_ components: any RequestComponent...) -> [any RequestComponent] {
    components
  }

  public static func buildOptional(_ component: [any RequestComponent]?) -> [any RequestComponent] {
    component ?? []
  }

  public static func buildEither(first component: [any RequestComponent]) -> [any RequestComponent]
  {
    component
  }

  public static func buildEither(second component: [any RequestComponent]) -> [any RequestComponent]
  {
    component
  }
  public static func buildArray(_ components: [[any RequestComponent]]) -> [any RequestComponent] {
    components.flatMap { $0 }
  }

  public static func buildLimitedAvailability(
    _ component: [any RequestComponent]
  ) -> [any RequestComponent] {
    component
  }

  public static func buildPartialBlock(first: any RequestComponent) -> [any RequestComponent] {
    [first]
  }

  public static func buildPartialBlock(
    accumulated: [any RequestComponent],
    next: any RequestComponent
  ) -> [any RequestComponent] {
    accumulated + [next]
  }

  /// Creates an HTTPRequest from the built components.
  public static func build(_ content: () -> [any RequestComponent]) throws -> HTTPRequest {
    var partial = PartialRequest()
    let components = content()

    for component in components {
      try component.apply(to: &partial)
    }

    guard let url = partial.url else {
      throw HTTPError(category: .configuration("URL is required"))
    }

    return HTTPRequest(
      method: partial.method,
      url: url,
      headers: partial.headers,
      body: partial.body,
      timeout: partial.timeout
    )
  }
}

// MARK: - HTTP Method Components

public struct GET: RequestComponent {
  private let path: String

  public init(_ path: String) {
    self.path = path
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    request.method = .get
    if let existingURL = request.url {
      request.url = existingURL.appendingPathComponent(path)
    } else {
      request.url = URL(string: path)
    }
  }
}
public struct POST: RequestComponent {
  private let path: String

  public init(_ path: String) {
    self.path = path
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    request.method = .post
    if let existingURL = request.url {
      request.url = existingURL.appendingPathComponent(path)
    } else {
      request.url = URL(string: path)
    }
  }
}

public struct PUT: RequestComponent {
  private let path: String

  public init(_ path: String) {
    self.path = path
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    request.method = .put
    if let existingURL = request.url {
      request.url = existingURL.appendingPathComponent(path)
    } else {
      request.url = URL(string: path)
    }
  }
}

public struct DELETE: RequestComponent {
  private let path: String

  public init(_ path: String) {
    self.path = path
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    request.method = .delete
    if let existingURL = request.url {
      request.url = existingURL.appendingPathComponent(path)
    } else {
      request.url = URL(string: path)
    }
  }
}
