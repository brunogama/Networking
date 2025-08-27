import Foundation

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
      request.body = try encoder.encode(value)
      request.headers["Content-Type"] = "application/json"
    } catch {
      throw HTTPError(
        category: .encoding("Failed to encode JSON body: \(error.localizedDescription)")
      )
    }
  }
}

public struct DataBody: RequestComponent {
  private let data: Data
  private let contentType: String?

  public init(_ data: Data, contentType: String? = nil) {
    self.data = data
    self.contentType = contentType
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    request.body = data
    if let contentType = contentType {
      request.headers["Content-Type"] = contentType
    }
  }
}

public struct FormBody: RequestComponent {
  private let parameters: [String: String]

  public init(_ parameters: [String: String]) {
    self.parameters = parameters
  }
  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    let formString =
      parameters
      .map { key, value in
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
        let encodedValue =
          value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
        return "\(encodedKey)=\(encodedValue)"
      }
      .joined(separator: "&")

    guard let data = formString.data(using: .utf8) else {
      throw HTTPError(category: .encoding("Failed to encode form data"))
    }

    request.body = data
    request.headers["Content-Type"] = "application/x-www-form-urlencoded"
  }
}

// MARK: - Configuration Components

public struct Timeout: RequestComponent {
  private let interval: TimeInterval

  public init(_ interval: TimeInterval) {
    self.interval = interval
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    request.timeout = interval
  }
}

// MARK: - Query Parameters

public struct QueryParam: RequestComponent {
  private let name: String
  private let value: String

  public init(_ name: String, _ value: String) {
    self.name = name
    self.value = value
  }

  public func apply(to request: inout RequestBuilder.PartialRequest) throws {
    guard let url = request.url else {
      throw HTTPError(category: .configuration("URL must be set before adding query parameters"))
    }

    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    var queryItems = components?.queryItems ?? []
    queryItems.append(URLQueryItem(name: name, value: value))
    components?.queryItems = queryItems
    request.url = components?.url ?? url
  }
}
