import XCTest
import SwiftSyntax
import MacroTemplateKit
@testable import NetworkingMacros

final class HTTPPhantomTypeTests: XCTestCase {

  // MARK: - HTTP Method Names

  func testHTTPMethodNames() {
    XCTAssertEqual(HTTPMethod.GET.methodName, "GET")
    XCTAssertEqual(HTTPMethod.POST.methodName, "POST")
    XCTAssertEqual(HTTPMethod.PUT.methodName, "PUT")
    XCTAssertEqual(HTTPMethod.PATCH.methodName, "PATCH")
    XCTAssertEqual(HTTPMethod.DELETE.methodName, "DELETE")
    XCTAssertEqual(HTTPMethod.HEAD.methodName, "HEAD")
    XCTAssertEqual(HTTPMethod.OPTIONS.methodName, "OPTIONS")
  }

  // MARK: - TypedHTTPTemplate Method Name

  func testTypedHTTPTemplateMethodName() {
    XCTAssertEqual(TypedHTTPTemplate<HTTPMethod.GET>.methodName, "GET")
    XCTAssertEqual(TypedHTTPTemplate<HTTPMethod.POST>.methodName, "POST")
    XCTAssertEqual(TypedHTTPTemplate<HTTPMethod.PUT>.methodName, "PUT")
    XCTAssertEqual(TypedHTTPTemplate<HTTPMethod.PATCH>.methodName, "PATCH")
    XCTAssertEqual(TypedHTTPTemplate<HTTPMethod.DELETE>.methodName, "DELETE")
  }

  // MARK: - Body Allowed Methods

  func testPOSTAllowsBody() {
    let template = TypedHTTPTemplate<HTTPMethod.POST>()
      .withURL("https://api.example.com")
      .withBody(.literal(.string("data")))

    // Should compile and produce valid template
    XCTAssertNotNil(template.template)
  }

  func testPUTAllowsBody() {
    let template = TypedHTTPTemplate<HTTPMethod.PUT>()
      .withURL("https://api.example.com")
      .withBody(.literal(.string("data")))

    XCTAssertNotNil(template.template)
  }

  func testPATCHAllowsBody() {
    let template = TypedHTTPTemplate<HTTPMethod.PATCH>()
      .withURL("https://api.example.com")
      .withBody(.literal(.string("data")))

    XCTAssertNotNil(template.template)
  }

  // MARK: - No Body Methods

  func testGETDoesNotExposeBodyMethod() {
    let template = TypedHTTPTemplate<HTTPMethod.GET>()
      .withURL("https://api.example.com")
      .withHeader(name: "Accept", value: "application/json")

    // Note: .withBody() is NOT available here (compile-time constraint)
    // This test verifies the template still works without body
    XCTAssertNotNil(template.template)
  }

  func testDELETEDoesNotExposeBodyMethod() {
    let template = TypedHTTPTemplate<HTTPMethod.DELETE>()
      .withURL("https://api.example.com")

    // .withBody() not available
    XCTAssertNotNil(template.template)
  }

  // MARK: - URL and Headers (All Methods)

  func testAllMethodsSupportURL() {
    let get = TypedHTTPTemplate<HTTPMethod.GET>().withURL("https://get.example.com")
    let post = TypedHTTPTemplate<HTTPMethod.POST>().withURL("https://post.example.com")
    let delete = TypedHTTPTemplate<HTTPMethod.DELETE>().withURL("https://delete.example.com")

    XCTAssertNotNil(get.template)
    XCTAssertNotNil(post.template)
    XCTAssertNotNil(delete.template)
  }

  func testAllMethodsSupportHeaders() {
    let get = TypedHTTPTemplate<HTTPMethod.GET>()
      .withHeader(name: "Authorization", value: "Bearer token")

    let post = TypedHTTPTemplate<HTTPMethod.POST>()
      .withHeader(name: "Content-Type", value: "application/json")

    XCTAssertNotNil(get.template)
    XCTAssertNotNil(post.template)
  }

  // MARK: - Query Parameters

  func testQueryParametersAllMethods() {
    let get = TypedHTTPTemplate<HTTPMethod.GET>()
      .withQuery(name: "page", value: .literal(.integer(1)))
      .withQuery(name: "limit", value: .literal(.integer(10)))

    let post = TypedHTTPTemplate<HTTPMethod.POST>()
      .withQuery(name: "debug", value: .literal(.boolean(true)))

    XCTAssertNotNil(get.template)
    XCTAssertNotNil(post.template)
  }

  // MARK: - Fluent Chaining

  func testFluentChaining() {
    let template = TypedHTTPTemplate<HTTPMethod.POST>()
      .withURL("https://api.example.com/users")
      .withHeader(name: "Content-Type", value: "application/json")
      .withHeader(name: "Authorization", value: .variable("token", payload: ()))
      .withBody(
        .functionCall(
          function: "encode",
          arguments: [(label: nil, value: .variable("user", payload: ()))]
        )
      )
      .withQuery(name: "notify", value: .literal(.boolean(true)))

    // Verify template structure
    if case .arrayLiteral(let elements) = template.template {
      XCTAssertEqual(elements.count, 5)  // url, 2 headers, body, query
    } else {
      XCTFail("Expected arrayLiteral with chained elements")
    }
  }

  // MARK: - Rendering

  func testRenderTypedHTTPTemplate() {
    let template = TypedHTTPTemplate<HTTPMethod.GET>()
      .withURL("https://api.example.com")

    let rendered = template.render()
    XCTAssertNotNil(rendered)
    // Rendered output should be valid SwiftSyntax
  }

  // MARK: - Builder Initialization

  func testTypedHTTPTemplateWithBuilder() {
    let template = TypedHTTPTemplate<HTTPMethod.POST> {
      Template.functionCall(
        function: "setupRequest",
        arguments: [(label: nil, value: .literal(.string("initial")))]
      )
    }

    XCTAssertNotNil(template.template)
  }

  // MARK: - Body Constraint Type Verification

  func testBodyConstraintTypes() {
    // Verify type relationships at compile time
    func requiresBodyAllowed<M: HTTPMethodWithBodyConstraint>(_: M.Type)
      where M.Body: BodyAllowedProtocol {}

    func requiresNoBody<M: HTTPMethodWithBodyConstraint>(_: M.Type)
      where M.Body: NoBodyProtocol {}

    // These should compile
    requiresBodyAllowed(HTTPMethod.POST.self)
    requiresBodyAllowed(HTTPMethod.PUT.self)
    requiresBodyAllowed(HTTPMethod.PATCH.self)

    requiresNoBody(HTTPMethod.GET.self)
    requiresNoBody(HTTPMethod.DELETE.self)
    requiresNoBody(HTTPMethod.HEAD.self)
    requiresNoBody(HTTPMethod.OPTIONS.self)
  }
}
