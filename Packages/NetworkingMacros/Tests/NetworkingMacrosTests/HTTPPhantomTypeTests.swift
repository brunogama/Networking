import XCTest
import SwiftSyntax
import MacroTemplateKit
@testable import NetworkingMacrosPlugin

final class HTTPPhantomTypeTests: XCTestCase {

  // MARK: - HTTP Method Names

  func testHTTPMethodNames() {
    XCTAssertEqual(HTTPMethod.GET.methodName, .named("GET"))
    XCTAssertEqual(HTTPMethod.POST.methodName, .named("POST"))
    XCTAssertEqual(HTTPMethod.PUT.methodName, .named("PUT"))
    XCTAssertEqual(HTTPMethod.PATCH.methodName, .named("PATCH"))
    XCTAssertEqual(HTTPMethod.DELETE.methodName, .named("DELETE"))
    XCTAssertEqual(HTTPMethod.HEAD.methodName, .named("HEAD"))
    XCTAssertEqual(HTTPMethod.OPTIONS.methodName, .named("OPTIONS"))
  }

  // MARK: - TypedHTTPTemplate Method Name

  func testTypedHTTPTemplateMethodName() {
    XCTAssertEqual(TypedHTTPTemplate<HTTPMethod.GET>.methodName, .named("GET"))
    XCTAssertEqual(TypedHTTPTemplate<HTTPMethod.POST>.methodName, .named("POST"))
    XCTAssertEqual(TypedHTTPTemplate<HTTPMethod.PUT>.methodName, .named("PUT"))
    XCTAssertEqual(TypedHTTPTemplate<HTTPMethod.PATCH>.methodName, .named("PATCH"))
    XCTAssertEqual(TypedHTTPTemplate<HTTPMethod.DELETE>.methodName, .named("DELETE"))
  }

  // MARK: - Body Allowed Methods

  func testPOSTAllowsBody() {
    let template = TypedHTTPTemplate<HTTPMethod.POST>()
      .withURL(.absolute("https://api.example.com"))
      .withBody(.literal(.string("data")))

    // Should compile and produce valid template
    XCTAssertNotNil(template.template)
  }

  func testPUTAllowsBody() {
    let template = TypedHTTPTemplate<HTTPMethod.PUT>()
      .withURL(.absolute("https://api.example.com"))
      .withBody(.literal(.string("data")))

    XCTAssertNotNil(template.template)
  }

  func testPATCHAllowsBody() {
    let template = TypedHTTPTemplate<HTTPMethod.PATCH>()
      .withURL(.absolute("https://api.example.com"))
      .withBody(.literal(.string("data")))

    XCTAssertNotNil(template.template)
  }

  // MARK: - No Body Methods

  func testGETDoesNotExposeBodyMethod() {
    let template = TypedHTTPTemplate<HTTPMethod.GET>()
      .withURL(.absolute("https://api.example.com"))
      .withHeader(name: .named("Accept"), value: HeaderValueReference.literal("application/json"))

    // Note: .withBody() is NOT available here (compile-time constraint)
    // This test verifies the template still works without body
    XCTAssertNotNil(template.template)
  }

  func testDELETEDoesNotExposeBodyMethod() {
    let template = TypedHTTPTemplate<HTTPMethod.DELETE>()
      .withURL(.absolute("https://api.example.com"))

    // .withBody() not available
    XCTAssertNotNil(template.template)
  }

  // MARK: - URL and Headers (All Methods)

  func testAllMethodsSupportURL() {
    let get = TypedHTTPTemplate<HTTPMethod.GET>().withURL(.absolute("https://get.example.com"))
    let post = TypedHTTPTemplate<HTTPMethod.POST>().withURL(.absolute("https://post.example.com"))
    let delete = TypedHTTPTemplate<HTTPMethod.DELETE>().withURL(
      .absolute("https://delete.example.com")
    )

    XCTAssertNotNil(get.template)
    XCTAssertNotNil(post.template)
    XCTAssertNotNil(delete.template)
  }

  func testAllMethodsSupportHeaders() {
    let get = TypedHTTPTemplate<HTTPMethod.GET>()
      .withHeader(
        name: .named("Authorization"),
        value: HeaderValueReference.literal("Bearer token")
      )

    let post = TypedHTTPTemplate<HTTPMethod.POST>()
      .withHeader(
        name: .named("Content-Type"),
        value: HeaderValueReference.literal("application/json")
      )

    XCTAssertNotNil(get.template)
    XCTAssertNotNil(post.template)
  }

  // MARK: - Query Parameters

  func testQueryParametersAllMethods() {
    let get = TypedHTTPTemplate<HTTPMethod.GET>()
      .withQuery(name: .named("page"), value: .literal(.integer(1)))
      .withQuery(name: .named("limit"), value: .literal(.integer(10)))

    let post = TypedHTTPTemplate<HTTPMethod.POST>()
      .withQuery(name: .named("debug"), value: .literal(.boolean(true)))

    XCTAssertNotNil(get.template)
    XCTAssertNotNil(post.template)
  }

  // MARK: - Fluent Chaining

  func testFluentChaining() {
    let template = TypedHTTPTemplate<HTTPMethod.POST>()
      .withURL(.absolute("https://api.example.com/users"))
      .withHeader(
        name: .named("Content-Type"),
        value: HeaderValueReference.literal("application/json")
      )
      .withHeader(name: .named("Authorization"), value: .variable("token", payload: ()))
      .withBody(
        .functionCall(
          function: "encode",
          arguments: [(label: nil, value: .variable("user", payload: ()))]
        )
      )
      .withQuery(name: .named("notify"), value: .literal(.boolean(true)))

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
      .withURL(.absolute("https://api.example.com"))

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
