import Foundation
import Networking
import Testing

struct NetworkClientTests {
  @Test(arguments: 100...599)
  func statusCategories(code: Int) {
    let status = HTTPStatus(rawValue: HTTPStatusCode(code))
    #expect(status.rawValue.rawValue == code)
    #expect(status.isInformational.rawValue == (100...199).contains(code))
    #expect(status.isSuccess.rawValue == (200...299).contains(code))
    #expect(status.isRedirection.rawValue == (300...399).contains(code))
    #expect(status.isClientError.rawValue == (400...499).contains(code))
    #expect(status.isServerError.rawValue == (500...599).contains(code))
    #expect(status == HTTPStatus(rawValue: HTTPStatusCode(code)))
    #expect(status.hashValue == HTTPStatus(rawValue: HTTPStatusCode(code)).hashValue)
  }

  @Test(arguments: ["get", "POST", "patch", "CuStOm"])
  func methodsNormalize(name: String) throws {
    let method = HTTPMethod(rawValue: HTTPMethodName(name))
    #expect(method.rawValue.rawValue == name.uppercased())
    #expect(method == HTTPMethod(rawValue: method.rawValue))
    #expect(method.hashValue == HTTPMethod(rawValue: method.rawValue).hashValue)
    let request = HTTPRequest(
      method: method,
      url: try #require(URL(string: "https://example.com/users")),
      headers: ["Authorization": "Bearer test"],
      body: Data("body".utf8)
    )
    let error = HTTPError.timeout(request: request)
    #expect(error.request?.id == request.id)
    #expect(error.request?.headers == request.headers)
    #expect(error.request?.body == request.body)
  }

  @Test(arguments: ["a&admin=true+b", "", "日本語", "a#b?c", "\"quoted\"", "a\r\nb"])
  func queryAndJSONRoundTrip(value: String) throws {
    var request = HTTPRequest(
      method: .post,
      url: try #require(URL(string: "https://example.com/users?existing=1"))
    )
    let identifier = request.id
    let codec = JSONCodec()
    let body = try codec.encode(["value": value])
    try request.addQueryParameter(name: "value", value: value)
    request.setBody(HTTPBody(body))
    request.addHeader(name: "Content-Type", value: "application/json")
    let components = try #require(
      URLComponents(url: request.url.rawValue, resolvingAgainstBaseURL: true)
    )
    #expect(
      components.queryItems == [
        URLQueryItem(name: "existing", value: "1"), URLQueryItem(name: "value", value: value),
      ]
    )
    #expect(request.id == identifier)
    #expect(try codec.decode([String: String].self, from: body) == ["value": value])
  }
}
