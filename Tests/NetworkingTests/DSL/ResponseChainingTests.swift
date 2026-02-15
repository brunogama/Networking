import Testing
import Foundation
@testable import Networking

// Test fixture
struct TestUser: Codable, Sendable, Equatable {
  let id: Int
  let name: String
}

@Suite("Response Chaining Tests")
struct ResponseChainingTests {

  // MARK: - Decode Tests

  @Test("decode() returns DecodedResponse with value")
  func decodeReturnsDecodedResponse() throws {
    let userData = try JSONEncoder().encode(TestUser(id: 1, name: "Alice"))
    let request = HTTPRequest(method: .get, url: URL(string: "https://api.test.com/user")!)
    let response = HTTPResponse(request: request, status: .ok, body: userData)

    let decoded = try response.decode(TestUser.self)

    #expect(decoded.value.id == 1)
    #expect(decoded.value.name == "Alice")
  }

  @Test("decode() preserves original response metadata")
  func decodePreservesResponseMetadata() throws {
    let userData = try JSONEncoder().encode(TestUser(id: 1, name: "Test"))
    let request = HTTPRequest(method: .get, url: URL(string: "https://api.test.com/user")!)
    let response = HTTPResponse(
      request: request,
      status: .ok,
      headers: ["X-Custom": "value"],
      body: userData
    )

    let decoded = try response.decode(TestUser.self)

    #expect(decoded.status == .ok)
    #expect(decoded.headers["X-Custom"] == "value")
    #expect(decoded.requestURL.absoluteString == "https://api.test.com/user")
  }

  @Test("decode() throws on empty body")
  func decodeThrowsOnEmptyBody() throws {
    let request = HTTPRequest(method: .get, url: URL(string: "https://api.test.com/user")!)
    let response = HTTPResponse(request: request, status: .ok, body: nil)

    #expect(throws: HTTPError.self) {
      try response.decode(TestUser.self)
    }
  }

  @Test("decodeIfPresent() returns nil on failure")
  func decodeIfPresentReturnsNilOnFailure() {
    let request = HTTPRequest(method: .get, url: URL(string: "https://api.test.com/user")!)
    let response = HTTPResponse(request: request, status: .ok, body: nil)

    let decoded = response.decodeIfPresent(TestUser.self)

    #expect(decoded == nil)
  }

  // MARK: - Chain Tests

  @Test("cacheable() attaches TTL configuration")
  func cacheableAttachesTTL() throws {
    let userData = try JSONEncoder().encode(TestUser(id: 1, name: "Test"))
    let request = HTTPRequest(method: .get, url: URL(string: "https://api.test.com/user")!)
    let response = HTTPResponse(request: request, status: .ok, body: userData)

    let cached = try response.decode(TestUser.self).cacheable(ttl: 600)

    #expect(cached.ttl == 600)
    #expect(cached.value.id == 1)
  }

  @Test("retryable() attaches maxAttempts configuration")
  func retryableAttachesMaxAttempts() throws {
    let userData = try JSONEncoder().encode(TestUser(id: 1, name: "Test"))
    let request = HTTPRequest(method: .get, url: URL(string: "https://api.test.com/user")!)
    let response = HTTPResponse(request: request, status: .ok, body: userData)

    let retryable = try response.decode(TestUser.self).retryable(maxAttempts: 5)

    #expect(retryable.maxAttempts == 5)
    #expect(retryable.value.id == 1)
  }

  @Test("full chain preserves all configuration")
  func fullChainPreservesConfiguration() throws {
    let userData = try JSONEncoder().encode(TestUser(id: 1, name: "Test"))
    let request = HTTPRequest(method: .get, url: URL(string: "https://api.test.com/user")!)
    let response = HTTPResponse(request: request, status: .ok, body: userData)

    let result =
      try response
      .decode(TestUser.self)
      .cacheable(ttl: 300)
      .retryable(maxAttempts: 3)

    #expect(result.value.id == 1)
    #expect(result.ttl == 300)
    #expect(result.maxAttempts == 3)
    #expect(result.status == .ok)
  }

  @Test("map() transforms decoded value")
  func mapTransformsValue() throws {
    let userData = try JSONEncoder().encode(TestUser(id: 1, name: "Alice"))
    let request = HTTPRequest(method: .get, url: URL(string: "https://api.test.com/user")!)
    let response = HTTPResponse(request: request, status: .ok, body: userData)

    let mapped = try response.decode(TestUser.self).map { $0.name }

    #expect(mapped.value == "Alice")
    #expect(mapped.status == .ok)
  }

  @Test("validated() passes on valid data")
  func validatedPassesOnValidData() throws {
    let userData = try JSONEncoder().encode(TestUser(id: 1, name: "Alice"))
    let request = HTTPRequest(method: .get, url: URL(string: "https://api.test.com/user")!)
    let response = HTTPResponse(request: request, status: .ok, body: userData)

    let validated = try response.decode(TestUser.self).validated { user in
      guard user.id > 0 else { throw ValidationError.invalidId }
    }

    #expect(validated.value.id == 1)
  }
}

enum ValidationError: Error {
  case invalidId
}
