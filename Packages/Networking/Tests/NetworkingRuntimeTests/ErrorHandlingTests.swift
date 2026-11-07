import Foundation
import NetworkingCore
import Testing

struct ErrorHandlingTests {
  @Test func preservesFailureContext() throws {
    let url = HTTPRequestURL(try #require(URL(string: "https://api.example.com/test")))
    let request = HTTPRequest(method: .get, url: url)
    let response = HTTPResponse(request: request, status: .notFound, body: HTTPBody?.none)
    let error = HTTPError.http(status: .notFound, request: request, response: response)
    #expect(error.category == .http(.notFound))
    #expect(error.request?.id == request.id)
    #expect(error.request?.url == request.url)
    #expect(error.response?.status == .notFound)
    #expect(error.underlyingError == nil)
  }

  @Test func factoryMethodsKeepTheirCategories() throws {
    let url = HTTPRequestURL(try #require(URL(string: "https://api.example.com/test")))
    let request = HTTPRequest(method: .get, url: url)
    #expect(HTTPError.network(.dnsFailure, request: request).category == .network(.dnsFailure))
    #expect(HTTPError.timeout(request: request).category == .timeout)
    #expect(HTTPError.cancelled(request: request).category == .cancelled)
  }

  @Test func absentRequestRemainsAbsent() {
    let error = HTTPError(category: .network(.noConnection))
    #expect(error.request == nil)
    #expect(error.response == nil)
  }
}
