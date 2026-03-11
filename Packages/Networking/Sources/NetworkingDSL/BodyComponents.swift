import Foundation
import NetworkingCore

// MARK: - Body Components

public struct JSONBody<T: Encodable & Sendable>: RequestComponent {
  private let value: T
  private let encoder: JSONEncoder

  public init(_ value: T, encoder: JSONEncoder = JSONEncoder()) {
    self.value = value
    self.encoder = encoder
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    do {
      request.body = HTTPBody(try encoder.encode(value))
      request.headers[HTTPHeaderName("Content-Type")] = HTTPHeaderValue("application/json")
    } catch {
      throw HTTPError(
        category: .encoding("Failed to encode JSON body: \(error.localizedDescription)")
      )
    }
  }
}

public struct DataBody: RequestComponent {
  private let data: HTTPBody
  private let contentType: HTTPMediaType?

  public init(_ data: HTTPBody, contentType: HTTPMediaType? = nil) {
    self.data = data
    self.contentType = contentType
  }

  package init(_ data: Data, contentType: HTTPMediaType? = nil) {
    self.init(HTTPBody(data), contentType: contentType)
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    request.body = data
    if let contentType = contentType {
      request.headers[HTTPHeaderName("Content-Type")] = HTTPHeaderValue(contentType.rawValue)
    }
  }
}

public struct FormBody: RequestComponent {
  private let parameters: [QueryParameterName: QueryParameterValue]

  public init(_ parameters: [QueryParameterName: QueryParameterValue]) {
    self.parameters = parameters
  }

  package init(_ parameters: [String: String]) {
    self.init(
      Dictionary(
        uniqueKeysWithValues: parameters.map {
          (QueryParameterName($0.key), QueryParameterValue($0.value))
        }
      )
    )
  }
  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    let formString =
      parameters
      .map { key, value in
        let encodedKey =
          key.rawValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
          ?? key.rawValue
        let encodedValue =
          value.rawValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
          ?? value.rawValue
        return "\(encodedKey)=\(encodedValue)"
      }
      .joined(separator: "&")

    guard let data = formString.data(using: .utf8) else {
      throw HTTPError(category: .encoding("Failed to encode form data"))
    }

    request.body = HTTPBody(data)
    request.headers["Content-Type"] = "application/x-www-form-urlencoded"
  }
}

// MARK: - Configuration Components

public struct Timeout: RequestComponent {
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

// MARK: - Query Parameters

public struct QueryParam: RequestComponent {
  private let name: QueryParameterName
  private let value: QueryParameterValue

  public init(_ name: QueryParameterName, _ value: QueryParameterValue) {
    self.name = name
    self.value = value
  }

  package init(_ name: String, _ value: String) {
    self.init(QueryParameterName(name), QueryParameterValue(value))
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    guard let url = request.url else {
      throw HTTPError(category: .configuration("URL must be set before adding query parameters"))
    }

    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    var queryItems = components?.queryItems ?? []
    queryItems.append(URLQueryItem(name: name.rawValue, value: value.rawValue))
    components?.queryItems = queryItems
    if let combinedURL = components?.url {
      request.url = HTTPRequestURL(combinedURL)
    } else {
      request.url = url
    }
  }
}
