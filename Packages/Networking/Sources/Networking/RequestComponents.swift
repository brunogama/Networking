import Foundation

// MARK: - URL and Base Configuration Components

public struct RequestBaseURL: RequestComponent {
  private let url: URL

  public init(_ urlString: String) throws {
    guard let url = URL(string: urlString) else {
      throw HTTPError(category: .configuration("Invalid base URL: \(urlString)"))
    }
    self.url = url
  }

  public init(_ url: URL) {
    self.url = url
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    if let existingURL = request.url {
      // Append the existing path to the base URL
      var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
      if let path = existingURL.path.isEmpty ? nil : existingURL.path {
        let currentPath = components?.path ?? ""
        components?.path = currentPath + path
      }
      request.url = components?.url ?? url
    } else {
      request.url = url
    }
  }
}

// MARK: - Header Components

public struct Header: RequestComponent {
  private let name: String
  private let value: String

  public init(_ name: String, _ value: String) {
    self.name = name
    self.value = value
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    request.headers[name] = value
  }
}
public struct ContentType: RequestComponent {
  private let value: String

  public init(_ value: String) {
    self.value = value
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    request.headers["Content-Type"] = value
  }

  public static let json = Self("application/json")
  public static let xml = Self("application/xml")
  public static let formURLEncoded = Self("application/x-www-form-urlencoded")
  public static let plainText = Self("text/plain")
}

// MARK: - Authentication Components

public struct BearerAuth: RequestComponent {
  private let token: String

  public init(_ token: String) {
    self.token = token
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    request.headers["Authorization"] = "Bearer \(token)"
  }
}

public struct RequestBasicAuth: RequestComponent {
  private let username: String
  private let password: String

  public init(username: String, password: String) {
    self.username = username
    self.password = password
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    let credentials = "\(username):\(password)"
    guard let data = credentials.data(using: .utf8) else {
      throw HTTPError(category: .encoding("Failed to encode basic auth credentials"))
    }
    let base64 = data.base64EncodedString()
    request.headers["Authorization"] = "Basic \(base64)"
  }
}

public struct APIKey: RequestComponent {
  private let key: String
  private let headerName: String

  public init(_ key: String, headerName: String = "X-API-Key") {
    self.key = key
    self.headerName = headerName
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    request.headers[headerName] = key
  }
}

// MARK: - Query Parameter Components

public struct RequestQueryParam: RequestComponent {
  private let name: String
  private let value: String

  public init(_ name: String, _ value: String) {
    self.name = name
    self.value = value
  }

  public init<T: CustomStringConvertible>(_ name: String, _ value: T) {
    self.name = name
    self.value = value.description
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    guard let url = request.url else {
      throw HTTPError(category: .configuration("URL must be set before adding query parameters"))
    }

    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      throw HTTPError(category: .configuration("Invalid URL for query parameters"))
    }

    var queryItems = components.queryItems ?? []
    queryItems.append(URLQueryItem(name: name, value: value))
    components.queryItems = queryItems

    guard let newURL = components.url else {
      throw HTTPError(category: .configuration("Failed to construct URL with query parameters"))
    }

    request.url = newURL
  }
}

public struct QueryParams: RequestComponent {
  private let params: [String: String]

  public init(_ params: [String: String]) {
    self.params = params
  }

  public init<T: CustomStringConvertible>(_ params: [String: T]) {
    self.params = params.mapValues { $0.description }
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    guard let url = request.url else {
      throw HTTPError(category: .configuration("URL must be set before adding query parameters"))
    }

    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      throw HTTPError(category: .configuration("Invalid URL for query parameters"))
    }

    var queryItems = components.queryItems ?? []
    for (name, value) in params {
      queryItems.append(URLQueryItem(name: name, value: value))
    }
    components.queryItems = queryItems

    guard let newURL = components.url else {
      throw HTTPError(category: .configuration("Failed to construct URL with query parameters"))
    }

    request.url = newURL
  }
}

// MARK: - Configuration Components

public struct RequestTimeout: RequestComponent {
  private let interval: TimeInterval

  public init(_ interval: TimeInterval) {
    self.interval = interval
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    request.timeout = interval
  }
}

public struct AcceptHeader: RequestComponent {
  private let mediaType: String

  public init(_ mediaType: String) {
    self.mediaType = mediaType
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    request.headers["Accept"] = mediaType
  }

  public static let json = Self("application/json")
  public static let xml = Self("application/xml")
  public static let any = Self("*/*")
  public static let html = Self("text/html")
}

public struct UserAgent: RequestComponent {
  private let userAgent: String

  public init(_ userAgent: String) {
    self.userAgent = userAgent
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    request.headers["User-Agent"] = userAgent
  }
}

// MARK: - Conditional Components

public struct ConditionalComponent: RequestComponent {
  private let condition: Bool
  private let component: any RequestComponent

  public init(_ condition: Bool, _ component: any RequestComponent) {
    self.condition = condition
    self.component = component
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    if condition {
      try component.apply(to: &request)
    }
  }
}

// MARK: - Helper Functions

public func `if`(_ condition: Bool, _ component: any RequestComponent) -> any RequestComponent {
  ConditionalComponent(condition, component)
}

public func `if`(
  _ condition: Bool,
  @RequestBuilder _ content: () -> [any RequestComponent]
) -> any RequestComponent {
  if condition {
    return CompositeComponent(content())
  } else {
    return EmptyComponent()
  }
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
