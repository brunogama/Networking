import Foundation
import Testing

@testable import Networking

@Suite("Request Operators Tests")
struct RequestOperatorsTests {

  @Test("+ operator merges headers with rhs taking precedence")
  func plusOperator_mergesHeaders_rhsTakesPrecedence() {
    let base = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com")!,
      headers: ["Accept": "application/json", "User-Agent": "BaseAgent"]
    )

    let override = HTTPRequest(
      method: .post,
      url: URL(string: "/users")!,
      headers: ["User-Agent": "OverrideAgent", "Authorization": "Bearer token"]
    )

    let result = base + override

    #expect(result.headers["Accept"] == "application/json")
    #expect(result.headers["User-Agent"] == "OverrideAgent")
    #expect(result.headers["Authorization"] == "Bearer token")
  }

  @Test("+ operator combines relative paths")
  func plusOperator_combinesRelativePaths() {
    let base = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/v1")!
    )

    let path = HTTPRequest(
      method: .get,
      url: URL(string: "/users/1")!
    )

    let result = base + path

    #expect(result.url.absoluteString == "https://api.example.com/v1/users/1")
  }

  @Test("+ operator handles trailing slashes in path composition")
  func plusOperator_handlesTrailingSlashes() {
    let base = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/")!
    )

    let path = HTTPRequest(
      method: .get,
      url: URL(string: "/users")!
    )

    let result = base + path

    #expect(result.url.absoluteString == "https://api.example.com/users")
  }

  @Test("+ operator rhs absolute URL wins completely")
  func plusOperator_rhsAbsoluteURLWins() {
    let base = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com")!,
      headers: ["Accept": "application/json"]
    )

    let override = HTTPRequest(
      method: .post,
      url: URL(string: "https://other-api.com/data")!
    )

    let result = base + override

    #expect(result.url.absoluteString == "https://other-api.com/data")
    #expect(result.method == .post)
  }

  @Test("+ operator rhs method wins")
  func plusOperator_rhsMethodWins() {
    let base = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com")!
    )

    let override = HTTPRequest(
      method: .post,
      url: URL(string: "/users")!
    )

    let result = base + override

    #expect(result.method == .post)
  }

  @Test("+ operator rhs body wins if present")
  func plusOperator_rhsBodyWinsIfPresent() {
    let baseBody = Data("base".utf8)
    let overrideBody = Data("override".utf8)

    let base = HTTPRequest(
      method: .post,
      url: URL(string: "https://api.example.com")!,
      body: baseBody
    )

    let override = HTTPRequest(
      method: .post,
      url: URL(string: "/users")!,
      body: overrideBody
    )

    let result = base + override

    #expect(result.body == overrideBody)
  }

  @Test("+ operator lhs body used when rhs has no body")
  func plusOperator_lhsBodyUsedWhenRhsNil() {
    let baseBody = Data("base".utf8)

    let base = HTTPRequest(
      method: .post,
      url: URL(string: "https://api.example.com")!,
      body: baseBody
    )

    let override = HTTPRequest(
      method: .post,
      url: URL(string: "/users")!,
      body: nil
    )

    let result = base + override

    #expect(result.body == baseBody)
  }

  @Test("merged(with:) is equivalent to + operator")
  func mergedWith_equivalentToPlusOperator() {
    let base = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com")!,
      headers: ["Accept": "application/json"]
    )

    let override = HTTPRequest(
      method: .post,
      url: URL(string: "/users")!,
      headers: ["Authorization": "Bearer token"]
    )

    let operatorResult = base + override
    let methodResult = base.merged(with: override)

    #expect(operatorResult.method == methodResult.method)
    #expect(operatorResult.url == methodResult.url)
    #expect(operatorResult.headers == methodResult.headers)
    #expect(operatorResult.body == methodResult.body)
    #expect(operatorResult.timeout == methodResult.timeout)
  }

  @Test("+ operator rhs timeout wins")
  func plusOperator_rhsTimeoutWins() {
    let base = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com")!,
      timeout: 30.0
    )

    let override = HTTPRequest(
      method: .get,
      url: URL(string: "/users")!,
      timeout: 60.0
    )

    let result = base + override

    #expect(result.timeout == 60.0)
  }
}
