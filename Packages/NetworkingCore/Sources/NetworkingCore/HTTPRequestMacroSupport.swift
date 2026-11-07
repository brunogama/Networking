import Foundation

extension HTTPRequest {

  public mutating func addQueryParameter<Value>(
    name: QueryParameterName,
    value: Value
  )
    throws(HTTPError)
  {
    guard var components = URLComponents(url: url.rawValue, resolvingAgainstBaseURL: true) else {
      throw HTTPError(category: .configuration("Invalid request URL"), request: self)
    }
    var items = components.queryItems ?? []
    items.append(URLQueryItem(name: name.rawValue, value: String(describing: value)))
    components.queryItems = items
    guard let url = components.url else {
      throw HTTPError(category: .configuration("Invalid query parameter"), request: self)
    }
    self = HTTPRequest(
      method: method,
      url: HTTPRequestURL(url),
      headers: headers,
      body: body,
      timeout: timeoutOverride,
      id: id
    )
  }

  public mutating func setBody(_ data: HTTPBody) {
    self = HTTPRequest(
      method: method,
      url: url,
      headers: headers,
      body: data,
      timeout: timeoutOverride,
      id: id
    )
  }

  public mutating func addHeader(name: HTTPHeaderName, value: HTTPHeaderValue) {
    setHeaders([name: value])
  }

  public mutating func setHeaders(_ values: HTTPHeaders) {
    var merged = headers
    for (name, value) in values { merged[name] = value }
    self = HTTPRequest(
      method: method,
      url: url,
      headers: merged,
      body: body,
      timeout: timeoutOverride,
      id: id
    )
  }
}
