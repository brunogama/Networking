import Foundation
import NetworkingCore

extension HTTPResponse {
  init(request: HTTPRequest, httpURLResponse: HTTPURLResponse, body: HTTPBody?) {
    self.init(
      request: request,
      status: HTTPStatus(rawValue: HTTPStatusCode(httpURLResponse.statusCode)),
      headers: HTTPHeaders(rawValue: responseHeaders(from: httpURLResponse)),
      body: body,
      url: httpURLResponse.url.map { HTTPResponseURL(rawValue: $0) }
    )
  }
}

private func responseHeaders(from response: HTTPURLResponse) -> [String: String] {
  Dictionary(
    uniqueKeysWithValues: response.allHeaderFields.compactMap { key, value in
      guard let name = key as? String, let headerValue = value as? String else { return nil }
      return (name, headerValue)
    }
  )
}
