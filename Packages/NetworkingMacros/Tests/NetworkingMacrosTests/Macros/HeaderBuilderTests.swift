import XCTest

@testable import Networking

/// Tests for HeaderBuilder result builder and HeaderComponent
final class HeaderBuilderTests: XCTestCase {

  // MARK: - HeaderBuilder Tests

  func testHeaderBuilderSingleComponent() {
    let components = buildHeaders {
      H("Authorization", "token")
    }

    XCTAssertEqual(components.count, 1)
    XCTAssertEqual(components[0].name, "Authorization")
  }

  func testHeaderBuilderMultipleComponents() {
    let components = buildHeaders {
      H("Authorization", "token")
      H("Accept", "application/json")
      H("X-Custom-Header", "value")
    }

    XCTAssertEqual(components.count, 3)
    XCTAssertEqual(components[0].name, "Authorization")
    XCTAssertEqual(components[1].name, "Accept")
    XCTAssertEqual(components[2].name, "X-Custom-Header")
  }

  func testHeaderBuilderEmptyBlock() {
    let components = buildHeaders {}

    XCTAssertEqual(components.count, 0)
  }

  func testHeaderBuilderOrderPreservation() {
    let components = buildHeaders {
      H("First", "value1")
      H("Second", "value2")
      H("Third", "value3")
    }

    XCTAssertEqual(components[0].name, "First")
    XCTAssertEqual(components[1].name, "Second")
    XCTAssertEqual(components[2].name, "Third")
  }

  // MARK: - HeaderComponent Tests

  func testHeaderComponentCreation() {
    let component = H("Content-Type", "application/json")

    XCTAssertEqual(component.name, "Content-Type")
    XCTAssertTrue(isParameter(component.valueSource, "application/json"))
  }

  func testHeaderComponentParameterSource() {
    let component = HeaderComponent(
      name: "Authorization",
      valueSource: .parameter("token")
    )

    XCTAssertEqual(component.name, "Authorization")
    XCTAssertTrue(isParameter(component.valueSource, "token"))
  }

  func testHeaderComponentLiteralSource() {
    let component = HeaderComponent(
      name: "Content-Type",
      valueSource: .literal("application/json")
    )

    XCTAssertEqual(component.name, "Content-Type")
    XCTAssertTrue(isLiteral(component.valueSource, "application/json"))
  }

  func testResultBuilderComposition() {
    // Test that @HeaderBuilder properly composes components
    let headers = buildHeaders {
      H("Header1", "value1")
      H("Header2", "value2")
    }

    XCTAssertEqual(headers.count, 2)
    XCTAssertEqual(headers.map(\.name), ["Header1", "Header2"])
  }

  func testHeaderBuilderInMacroContext() {
    // Simulate how it would be used in @Headers macro
    @HeaderBuilder
    func makeHeaders() -> [HeaderComponent] {
      H("Authorization", "token")
      H("Accept", "application/json")
    }

    let closureResult = makeHeaders()
    XCTAssertEqual(closureResult.count, 2)
  }

  func testHeaderBuilderSendableConformance() {
    // HeaderComponent should be Sendable for Swift 6 concurrency
    let component = H("Test", "value")

    // This compiles = Sendable conformance works
    Task {
      _ = component
    }
  }

  // MARK: - Helper Methods

  private func buildHeaders(@HeaderBuilder _ content: () -> [HeaderComponent]) -> [HeaderComponent]
  {
    content()
  }

  private func isParameter(_ valueSource: HeaderComponent.ValueSource, _ value: String) -> Bool {
    if case .parameter(let param) = valueSource {
      return param == value
    }
    return false
  }

  private func isLiteral(_ valueSource: HeaderComponent.ValueSource, _ value: String) -> Bool {
    if case .literal(let literal) = valueSource {
      return literal == value
    }
    return false
  }
}
