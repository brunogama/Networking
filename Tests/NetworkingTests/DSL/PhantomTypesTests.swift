import Foundation
import Testing

@testable import Networking

@Suite("Phantom Types Tests")
struct PhantomTypesTests {

  // MARK: - withJSONBody Tests

  @Test("POST request can add JSON body")
  func postRequest_canAddJSONBody() throws {
    struct User: Codable, Sendable {
      let name: String
      let email: String
    }

    let user = User(name: "Alice", email: "alice@example.com")

    let request = TypedHTTPRequest<POSTMethod, AnyEnvironment>(path: "/users")
    let requestWithBody = try request.withJSONBody(user)

    #expect(requestWithBody.body != nil)
    #expect(requestWithBody.headers["Content-Type"] == "application/json")

    // Verify body decodes correctly
    let decoded = try JSONDecoder().decode(User.self, from: requestWithBody.body!)
    #expect(decoded.name == "Alice")
    #expect(decoded.email == "alice@example.com")
  }

  @Test("PUT request can add JSON body")
  func putRequest_canAddJSONBody() throws {
    struct UpdateData: Codable, Sendable {
      let status: String
    }

    let data = UpdateData(status: "active")

    let request = TypedHTTPRequest<PUTMethod, AnyEnvironment>(path: "/status")
    let requestWithBody = try request.withJSONBody(data)

    #expect(requestWithBody.body != nil)
    #expect(requestWithBody.headers["Content-Type"] == "application/json")

    let decoded = try JSONDecoder().decode(UpdateData.self, from: requestWithBody.body!)
    #expect(decoded.status == "active")
  }

  @Test("PATCH request can add JSON body")
  func patchRequest_canAddJSONBody() throws {
    struct PatchData: Codable, Sendable {
      let field: String
      let value: Int
    }

    let data = PatchData(field: "count", value: 42)

    let request = TypedHTTPRequest<PATCHMethod, AnyEnvironment>(path: "/resource")
    let requestWithBody = try request.withJSONBody(data)

    #expect(requestWithBody.body != nil)
    #expect(requestWithBody.headers["Content-Type"] == "application/json")

    let decoded = try JSONDecoder().decode(PatchData.self, from: requestWithBody.body!)
    #expect(decoded.field == "count")
    #expect(decoded.value == 42)
  }

  @Test("withJSONBody sets Content-Type header")
  func withJSONBody_setsContentTypeHeader() throws {
    struct SimpleData: Codable, Sendable {
      let value: String
    }

    let data = SimpleData(value: "test")

    let request = TypedHTTPRequest<POSTMethod, AnyEnvironment>(path: "/test")
    let requestWithBody = try request.withJSONBody(data)

    #expect(requestWithBody.headers["Content-Type"] == "application/json")
  }

  @Test("withJSONBody preserves existing headers")
  func withJSONBody_preservesExistingHeaders() throws {
    struct SimpleData: Codable, Sendable {
      let value: String
    }

    let data = SimpleData(value: "test")

    let request = TypedHTTPRequest<POSTMethod, AnyEnvironment>(
      path: "/test",
      headers: ["Authorization": "Bearer token", "Accept": "application/json"]
    )
    let requestWithBody = try request.withJSONBody(data)

    #expect(requestWithBody.headers["Authorization"] == "Bearer token")
    #expect(requestWithBody.headers["Accept"] == "application/json")
    #expect(requestWithBody.headers["Content-Type"] == "application/json")
  }

  @Test("withJSONBody uses custom encoder when provided")
  func withJSONBody_usesCustomEncoder() throws {
    struct DateData: Codable, Sendable {
      let timestamp: Date
    }

    let date = Date(timeIntervalSince1970: 1_609_459_200)  // 2021-01-01 00:00:00 UTC
    let data = DateData(timestamp: date)

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .secondsSince1970

    let request = TypedHTTPRequest<POSTMethod, AnyEnvironment>(path: "/events")
    let requestWithBody = try request.withJSONBody(data, encoder: encoder)

    #expect(requestWithBody.body != nil)

    // Verify encoding used seconds since 1970
    let json = try JSONSerialization.jsonObject(with: requestWithBody.body!) as? [String: Any]
    let timestamp = json?["timestamp"] as? Double
    #expect(timestamp == 1_609_459_200.0)
  }

  // MARK: - TypedHTTPRequest Conversion Tests

  @Test("typed request converts to HTTPRequest correctly")
  func typedRequest_convertsToHTTPRequest() {
    let typed = TypedHTTPRequest<GETMethod, ProductionEnvironment>(
      path: "/users/1",
      headers: ["Authorization": "Bearer token"],
      timeout: 45.0
    )

    let http = typed.toHTTPRequest()

    #expect(http.method == .get)
    #expect(http.url.absoluteString.contains("/users/1"))
    #expect(http.headers["Authorization"] == "Bearer token")
    #expect(http.timeout == 45.0)
  }

  @Test("typed POST request with body converts correctly")
  func typedPostWithBody_convertsToHTTPRequest() throws {
    struct User: Codable, Sendable {
      let name: String
    }

    let user = User(name: "Bob")
    let typed = try TypedHTTPRequest<POSTMethod, StagingEnvironment>(path: "/users")
      .withJSONBody(user)

    let http = typed.toHTTPRequest()

    #expect(http.method == .post)
    #expect(http.body != nil)
    #expect(http.headers["Content-Type"] == "application/json")

    let decoded = try JSONDecoder().decode(User.self, from: http.body!)
    #expect(decoded.name == "Bob")
  }

  // MARK: - Compile-Time Safety Documentation

  // Note: The following compile-time safety cannot be tested at runtime,
  // but is enforced by the Swift compiler due to the BodyAllowedMethod constraint:
  //
  // ❌ This will NOT compile:
  // let getRequest = TypedHTTPRequest<GETMethod, AnyEnvironment>(path: "/users")
  // let withBody = try getRequest.withJSONBody(someData)
  // // Error: Instance method 'withJSONBody' requires that 'GETMethod' conform to 'BodyAllowedMethod'
  //
  // ✅ This WILL compile:
  // let postRequest = TypedHTTPRequest<POSTMethod, AnyEnvironment>(path: "/users")
  // let withBody = try postRequest.withJSONBody(someData)
  //
  // The constraint is: extension TypedHTTPRequest where Method: BodyAllowedMethod
  // Only POST, PUT, and PATCH conform to BodyAllowedMethod.
}
