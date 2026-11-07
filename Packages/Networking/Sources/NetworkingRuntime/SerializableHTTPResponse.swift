import Foundation
import NetworkingCore

/// Serializable version of HTTPResponse for disk storage.
struct SerializableHTTPResponse: Codable {
  let statusCode: Int
  let headers: [String: String]
  let body: Data?
  let requestURL: String

  init(from response: HTTPResponse) {
    self.statusCode = response.status.rawValue.rawValue
    self.headers = response.headers.rawValue
    self.body = response.body?.rawValue
    self.requestURL = response.request.url.rawValue.absoluteString
  }

  func toHTTPResponse() -> HTTPResponse? {
    guard let url = URL(string: requestURL) else {
      return nil
    }

    let request = HTTPRequest(
      method: .get,
      url: HTTPRequestURL(url),
      headers: [:],
      body: nil,
      timeout: 30.0
    )

    return HTTPResponse(
      request: request,
      status: HTTPStatus(rawValue: HTTPStatusCode(statusCode)),
      headers: HTTPHeaders(rawValue: headers),
      body: body.map { HTTPBody($0) }
    )
  }
}
