import Foundation
import NetworkingCore
infix operator |> : AdditionPrecedence

// MARK: - HTTPRequest Builder Extension

extension HTTPRequest {
  /// Creates an HTTPRequest using the result builder pattern.
  /// - Parameter content: A closure that returns request components
  /// - Returns: A configured HTTPRequest
  /// - Throws: HTTPError if the request cannot be built
  public init(@RequestBuilder _ content: () -> [any RequestComponent]) throws {
    let request = try RequestBuilder.build(content)
    self = request
  }
}

// MARK: - Request Composition Operators

// swiftlint:disable static_operator
/// Combines a request with additional components.
/// - Parameters:
///   - lhs: The base HTTPRequest
///   - rhs: Additional request component to apply
/// - Returns: A new HTTPRequest with the combined configuration
public func + (lhs: HTTPRequest, rhs: any RequestComponent) throws -> HTTPRequest {
  try lhs.with { rhs }
}

/// Combines a request with multiple components.
/// - Parameters:
///   - lhs: The base HTTPRequest
///   - rhs: Array of request components to apply
/// - Returns: A new HTTPRequest with the combined configuration
public func + (lhs: HTTPRequest, rhs: [any RequestComponent]) throws -> HTTPRequest {
  try lhs.with { CompositeComponent(rhs) }
}

/// Pipe operator for fluent request building.
/// - Parameters:
///   - lhs: The base HTTPRequest
///   - rhs: Request component to apply
/// - Returns: A new HTTPRequest with the applied component
public func |> (lhs: HTTPRequest, rhs: any RequestComponent) throws -> HTTPRequest {
  try lhs + rhs
}
// swiftlint:enable static_operator

extension HTTPRequest {
  /// Creates an HTTPRequest by combining this request with additional components.
  /// - Parameter content: A closure that returns additional request components
  /// - Returns: A new HTTPRequest with the combined configuration
  public func with(@RequestBuilder _ content: () -> [any RequestComponent]) throws -> HTTPRequest {
    let newComponents = content()
    var partial = RequestBuilder.PartialRequest()

    // Apply current request properties first
    partial.method = self.method
    partial.url = self.url
    partial.headers = self.headers
    partial.body = self.body
    partial.timeout = self.timeout

    // Apply new components
    for component in newComponents {
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

// MARK: - Environment-Aware Components

/// Component that applies different configurations based on environment.
public struct EnvironmentAware: RequestComponent {
  public enum Environment: Hashable, Sendable {
    case development
    case staging
    case production
    case custom(HTTPEnvironmentName)
  }

  private let environment: Environment
  private let configurations: [Environment: any RequestComponent]

  public init(environment: Environment, configurations: [Environment: any RequestComponent]) {
    self.environment = environment
    self.configurations = configurations
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    if let component = configurations[environment] {
      try component.apply(to: &request)
    }
  }
}

// MARK: - Advanced Conditional Components

/// Component that applies different configurations based on a switch statement.
public struct SwitchComponent<T: Hashable & Sendable>: RequestComponent {
  private let value: T
  private let cases: [T: any RequestComponent]
  private let defaultCase: (any RequestComponent)?

  public init(
    value: T,
    cases: [T: any RequestComponent],
    default defaultCase: (any RequestComponent)? = nil
  ) {
    self.value = value
    self.cases = cases
    self.defaultCase = defaultCase
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    if let component = cases[value] {
      try component.apply(to: &request)
    } else if let defaultComponent = defaultCase {
      try defaultComponent.apply(to: &request)
    }
  }
}

// MARK: - Request Caching Components

/// Component that adds cache control headers.
public struct CacheControl: RequestComponent {
  public enum Directive: Sendable {
    case noCache
    case noStore
    case maxAge(CacheMaxAge)
    case mustRevalidate
    case custom(CacheDirectiveText)
  }

  private let directives: [Directive]

  public init(_ directives: Directive...) {
    self.directives = directives
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    let directiveStrings = directives.map(directiveString(for:))
    request.headers["Cache-Control"] = directiveStrings.joined(separator: ", ")
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func directiveString(for directive: Directive) -> String {
    switch directive {
    case .noCache: return "no-cache"
    case .noStore: return "no-store"
    case .maxAge(let seconds): return "max-age=\(seconds.rawValue)"
    case .mustRevalidate: return "must-revalidate"
    case .custom(let value): return value.rawValue
    }
  }
}

/// Component that adds ETags for conditional requests.
public struct IfNoneMatch: RequestComponent {
  private let etag: HTTPHeaderValue

  public init(_ etag: HTTPHeaderValue) {
    self.etag = etag
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    request.headers["If-None-Match"] = etag
  }
}

/// Component that adds last-modified conditional headers.
public struct IfModifiedSince: RequestComponent {
  private let date: Date

  public init(_ date: Date) {
    self.date = date
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
    formatter.timeZone = TimeZone(abbreviation: "GMT")
    formatter.locale = Locale(identifier: "en_US")
    request.headers["If-Modified-Since"] = formatter.string(from: date)
  }
}

// MARK: - Usage Examples in Documentation

/*
 Example usage of the enhanced request builder DSL:

 ```swift
 let client = NetworkClient()

 // Simple GET request
 let response = try await client.execute {
     BaseURL("https://api.example.com")
     GET("/users/123")
     BearerAuth(token)
 }

 // Conditional request building
 let searchRequest = try HTTPRequest {
     BaseURL("https://api.example.com")
     GET("/search")
     QueryParam("q", searchTerm)
     if isAuthenticated {
         BearerAuth(userToken)
     }
     if enableCaching {
         CacheControl(.maxAge(300))
     }
 }

 // Request composition with operators
 let baseRequest = try HTTPRequest {
     BaseURL("https://api.example.com")
     GET("/users")
 }
 let authenticatedRequest = try baseRequest + BearerAuth(token)
 let finalRequest = try authenticatedRequest |> QueryParam("limit", "10")
 ```
 */
