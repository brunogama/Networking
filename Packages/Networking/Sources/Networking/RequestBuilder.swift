import Foundation

// MARK: - Request Builder Components

/// Base protocol for request builder components.
///
/// `RequestComponent` defines the interface for all components that can be used in the
/// request builder DSL. Components encapsulate specific aspects of HTTP request construction
/// such as methods, headers, body content, and query parameters.
///
/// ## Implementation
///
/// To create a custom request component, implement this protocol:
///
/// ```swift
/// struct CustomHeader: RequestComponent {
///     let name: String
///     let value: String
///
///     func apply(to request: inout RequestBuilder.PartialRequest) throws {
///         request.headers[name] = value
///     }
/// }
/// ```
///
/// ## Related Types
///
/// - ``RequestBuilder``: The result builder that processes components
/// - ``HTTPRequest``: The final request type created from components
/// - <doc:Request-Building>: Complete guide to request building
public protocol RequestComponent: Sendable {
  /// Applies this component's configuration to a partial request.
  ///
  /// - Parameter request: The partial request being built
  /// - Throws: ``HTTPError`` if the component configuration is invalid
  func apply(to request: inout RequestBuilder.PartialRequest) throws
}

/// Result builder for constructing HTTP requests with a fluent API.
///
/// `RequestBuilder` enables declarative construction of HTTP requests using Swift's
/// result builder syntax. It processes ``RequestComponent`` instances to build
/// complete ``HTTPRequest`` objects.
///
/// ## Usage
///
/// Use the builder syntax to create requests:
///
/// ```swift
/// let request = try RequestBuilder.build {
///     GET("/api/users")
///     BearerAuth(token)
///     QueryParam("limit", "10")
///     ContentType("application/json")
/// }
/// ```
///
/// ## Builder Features
///
/// The builder supports all Swift result builder features:
/// - Conditional components (`if` statements)
/// - Optional components
/// - Arrays of components
/// - Either/or logic
///
/// ```swift
/// let request = try RequestBuilder.build {
///     GET("/api/data")
///
///     if needsAuth {
///         BearerAuth(token)
///     }
///
///     for (key, value) in queryParams {
///         QueryParam(key, value)
///     }
/// }
/// ```
///
/// ## Error Handling
///
/// Building requests can throw ``HTTPError`` if:
/// - No URL is specified
/// - Component configuration is invalid
/// - Required parameters are missing
///
/// ## Related Documentation
///
/// - <doc:Request-Building>: Complete request building guide
/// - ``RequestComponent``: Individual component protocol
/// - ``HTTPRequest``: The final request type
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

  public static func buildEither(first component: [any RequestComponent]) -> [any RequestComponent] {
    component
  }

  public static func buildEither(second component: [any RequestComponent]) -> [any RequestComponent] {
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
