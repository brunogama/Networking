import Foundation
import NetworkingCore

// MARK: - URL and Base Configuration Components

public struct RequestBaseURL: RequestComponent {
  private let url: HTTPRequestURL

  public init(_ urlString: BaseURLText) throws {
    guard let url = URL(string: urlString) else {
      throw HTTPError(category: .configuration("Invalid base URL: \(urlString)"))
    }
    self.url = HTTPRequestURL(url)
  }

  public init(_ url: HTTPRequestURL) {
    self.url = url
  }

  package init(_ url: URL) {
    self.url = HTTPRequestURL(url)
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    if let existingURL = request.url {
      // Append the existing path to the base URL
      var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
      if let path = existingURL.path.isEmpty ? nil : existingURL.path {
        let currentPath = components?.path ?? ""
        components?.path = currentPath + path
      }
      if let combinedURL = components?.url {
        request.url = HTTPRequestURL(combinedURL)
      } else {
        request.url = url
      }
    } else {
      request.url = url
    }
  }
}

// MARK: - Header Components

public struct Header: RequestComponent {
  private let name: HTTPHeaderName
  private let value: HTTPHeaderValue

  public init(_ name: HTTPHeaderName, _ value: HTTPHeaderValue) {
    self.name = name
    self.value = value
  }

  package init(_ name: String, _ value: String) {
    self.init(HTTPHeaderName(name), HTTPHeaderValue(value))
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    request.headers[name] = value
  }
}
public struct ContentType: RequestComponent {
  private let value: HTTPMediaType

  public init(_ value: HTTPMediaType) {
    self.value = value
  }

  package init(_ value: String) {
    self.init(HTTPMediaType(value))
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    request.headers[HTTPHeaderName("Content-Type")] = HTTPHeaderValue(value.rawValue)
  }

  public static let json = Self("application/json")
  public static let xml = Self("application/xml")
  public static let formURLEncoded = Self("application/x-www-form-urlencoded")
  public static let plainText = Self("text/plain")
}

// MARK: - Authentication Components

public struct BearerAuth: RequestComponent {
  private let token: BearerTokenValue

  public init(_ token: BearerTokenValue) {
    self.token = token
  }

  package init(_ token: String) {
    self.init(BearerTokenValue(token))
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    request.headers["Authorization"] = "Bearer \(token)"
  }
}

public struct RequestBasicAuth: RequestComponent {
  private let username: BasicAuthUsername
  private let password: BasicAuthPassword

  public init(username: BasicAuthUsername, password: BasicAuthPassword) {
    self.username = username
    self.password = password
  }

  package init(username: String, password: String) {
    self.init(username: BasicAuthUsername(username), password: BasicAuthPassword(password))
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
  private let key: HTTPHeaderValue
  private let headerName: HTTPHeaderName

  public init(
    _ key: HTTPHeaderValue,
    headerName: HTTPHeaderName = HTTPHeaderName(rawValue: "X-API-Key")
  ) {
    self.key = key
    self.headerName = headerName
  }

  package init(
    _ key: String,
    headerName: HTTPHeaderName = HTTPHeaderName(rawValue: "X-API-Key")
  ) {
    self.init(HTTPHeaderValue(key), headerName: headerName)
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    request.headers[headerName] = key
  }
}

// MARK: - Query Parameter Components

public struct RequestQueryParam: RequestComponent {
  private let name: QueryParameterName
  private let value: QueryParameterValue

  public init(_ name: QueryParameterName, _ value: QueryParameterValue) {
    self.name = name
    self.value = value
  }

  public init<T: CustomStringConvertible>(_ name: QueryParameterName, _ value: T) {
    self.name = name
    self.value = QueryParameterValue(value.description)
  }

  package init(_ name: String, _ value: String) {
    self.init(QueryParameterName(name), QueryParameterValue(value))
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    guard let url = request.url else {
      throw HTTPError(category: .configuration("URL must be set before adding query parameters"))
    }

    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      throw HTTPError(category: .configuration("Invalid URL for query parameters"))
    }

    var queryItems = components.queryItems ?? []
    queryItems.append(URLQueryItem(name: name.rawValue, value: value.rawValue))
    components.queryItems = queryItems

    guard let newURL = components.url else {
      throw HTTPError(category: .configuration("Failed to construct URL with query parameters"))
    }

    request.url = HTTPRequestURL(newURL)
  }
}

public struct QueryParams: RequestComponent {
  private let params: [QueryParameterName: QueryParameterValue]

  public init(_ params: [QueryParameterName: QueryParameterValue]) {
    self.params = params
  }

  public init<T: CustomStringConvertible>(_ params: [QueryParameterName: T]) {
    self.params = params.mapValues { QueryParameterValue($0.description) }
  }

  package init(_ params: [String: String]) {
    self.init(
      Dictionary(
        uniqueKeysWithValues: params.map {
          (QueryParameterName($0.key), QueryParameterValue($0.value))
        }
      )
    )
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
      queryItems.append(URLQueryItem(name: name.rawValue, value: value.rawValue))
    }
    components.queryItems = queryItems

    guard let newURL = components.url else {
      throw HTTPError(category: .configuration("Failed to construct URL with query parameters"))
    }

    request.url = HTTPRequestURL(newURL)
  }
}
