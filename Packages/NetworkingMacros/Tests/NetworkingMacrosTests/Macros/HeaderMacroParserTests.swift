import Testing
@testable import NetworkingMacrosPlugin

struct HeaderMacroParserTests {
  @Test func distinguishesLiteralAndParameterValues() throws {
    let input = try MacroTestInput(
      """
      @Headers([
        .named("Authorization"): .parameter("token"),
        .named("X-Literal"): .literal("token")
      ])
      func fetch(token: String) async throws -> User
      """
    )
    #expect(
      HeaderMacroParser.parseHeaders(from: input.attribute) == [
        ParsedHeader(name: "Authorization", valueSource: .parameter("token")),
        ParsedHeader(name: "X-Literal", valueSource: .literal("token")),
      ]
    )
    let expansion = try expandPeer(HeadersMacro.self, source: input.declaration.description)
    #expect(expansion.messages.isEmpty)
    #expect(expansion.declarations.isEmpty)
  }

  @Test func appliesHeadersInGeneratedMethod() throws {
    let expansion = try expandPeer(
      GETMacro.self,
      source: """
        @GET(.path("/users"))
        @Headers([
          .named("Authorization"): .parameter("token"),
          .named("X-Literal"): .literal("token")
        ])
        func fetch(token: String) async throws -> User
        """
    )
    #expect(expansion.messages.isEmpty)
    #expect(
      expansion.source.contains(#"request.addHeader(name: "Authorization", value: "\(token)")"#)
    )
    #expect(expansion.source.contains(#"request.addHeader(name: "X-Literal", value: "token")"#))
  }

  @Test(arguments: [
    ("@Headers func fetch() async throws -> User", "@Headers requires a dictionary"),
    ("@Headers struct User {}", "@Headers can only be applied to functions"),
    (
      #"@Headers([.named("Authorization"): .parameter("missing")]) func fetch()"#,
      "Header parameter 'missing' was not found"
    ),
    (
      #"@Headers([.named("X\r\nInjected"): .literal("value")]) func fetch()"#,
      "Header names must be nonempty and contain no CR or LF"
    ),
    (
      #"@Headers([.named("X-Test"): .literal("value\r\nInjected: true")]) func fetch()"#,
      "Header values must contain no CR or LF"
    ),
    (
      #"@Headers([.named("X-Test"): unknownValue]) func fetch()"#,
      "@Headers requires a dictionary"
    ),
  ])
  func diagnosesInvalidHeaders(source: String, message: String) throws {
    let expansion = try expandPeer(HeadersMacro.self, source: source)
    #expect(expansion.messages.count == 1)
    #expect(expansion.messages.first?.contains(message) == true)
  }
}
