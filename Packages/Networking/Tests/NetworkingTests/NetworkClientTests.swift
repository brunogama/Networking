import Foundation
@testable import Networking
import NetworkingTesting
import Testing

struct NetworkClientTests {
  @Test("NetworkClient can be created with default configuration")
  func defaultClient() async throws {
    let client = NetworkClient()
    #expect(client != nil)
  }

  @Test("NetworkClient can be created with builder pattern")
  func clientBuilder() async throws {
    let client = try NetworkClient {
      BaseURL(HTTPRequestURL(URL(string: "https://api.example.com")!))
      DefaultTimeout(15.0)
      DefaultHeader("User-Agent", "TestApp/1.0")
    }
    #expect(client != nil)
  }

  @Test("HTTP request can be built with DSL")
  func requestBuilder() async throws {
    let request = try HTTPRequest {
      GET("/users/123")
      Header("Authorization", "Bearer token")
      Timeout(30.0)
    }

    #expect(request.method == .get)
    #expect(request.url.path == "/users/123")
    #expect(request.headers["Authorization"] == "Bearer token")
    #expect(request.timeout == 30.0)
  }

  @Test("HTTPStatus provides correct category information")
  func hTTPStatus() async throws {
    #expect(HTTPStatus.ok.isSuccess.rawValue)
    #expect(HTTPStatus.notFound.isClientError.rawValue)
    #expect(HTTPStatus.internalServerError.isServerError.rawValue)
    #expect(HTTPStatus.ok.isClientError.rawValue == false)
  }

  @Test("HTTPError can be created with different categories")
  func hTTPError() async throws {
    let request = try HTTPRequest {
      GET("/test")
    }

    let networkError = HTTPError.network(.noConnection, request: request)
    #expect(networkError.request?.id == request.id)

    let timeoutError = HTTPError.timeout(request: request)
    if case .timeout = timeoutError.category {
      // Expected
    } else {
      Issue.record("Expected timeout category")
    }
  }
}
