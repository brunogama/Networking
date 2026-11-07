import SwiftSyntax
import Testing
@testable import NetworkingMacrosPlugin

struct ConfigurationMacroTests {
  @Test(arguments: [
    (".seconds(30)", 30.0),
    (".seconds(0.5)", 0.5),
    (".milliseconds(250)", 0.25),
    (".microseconds(250000)", 0.25),
    (".nanoseconds(250000000)", 0.25),
    ("Duration.milliseconds(250)", 0.25),
  ])
  func preservesDurationUnits(expression: String, seconds: Double) throws {
    let source = "@Timeout(\(expression)) protocol UserAPI {}"
    let expansion = try expandMember(TimeoutMacro.self, source: source)
    #expect(expansion.messages.isEmpty)
    #expect(expansion.declarations.isEmpty)
    let input = try MacroTestInput(source)
    let declaration = try #require(input.declaration.as(ProtocolDeclSyntax.self))
    #expect(TimeoutMacro.extractDefaultTimeout(from: declaration) == seconds)
  }

  @Test(arguments: [".seconds(0)", ".seconds(-1)", "someDuration", ".minutes(1)", "30"])
  func rejectsInvalidDuration(expression: String) throws {
    let expansion = try expandMember(
      TimeoutMacro.self,
      source: """
        @Timeout(\(expression)) protocol UserAPI {}
        """
    )
    #expect(expansion.messages.first?.contains("requires a positive Duration literal") == true)
  }

  @Test func timeoutRequiresProtocol() throws {
    let expansion = try expandMember(
      TimeoutMacro.self,
      source: """
        @Timeout(.seconds(30)) struct Service {}
        """
    )
    #expect(expansion.messages == ["@Timeout can only be applied to protocols"])
  }

  @Test func extractsDefaultHeaders() throws {
    let source = """
      @DefaultHeaders([
        .named("Accept"): .literal("application/json"),
        .named("X-Version"): .literal("v1")
      ])
      protocol UserAPI {}
      """
    let expansion = try expandMember(DefaultHeadersMacro.self, source: source)
    #expect(expansion.messages.isEmpty)
    let input = try MacroTestInput(source)
    let declaration = try #require(input.declaration.as(ProtocolDeclSyntax.self))
    #expect(
      DefaultHeadersMacro.extractDefaultHeaders(from: declaration) == [
        "Accept": "application/json", "X-Version": "v1",
      ]
    )
  }

  @Test(arguments: [
    ("@DefaultHeaders([:]) protocol UserAPI {}", "requires a non-empty headers dictionary"),
    ("@DefaultHeaders protocol UserAPI {}", "requires a dictionary argument"),
    ("@DefaultHeaders([:]) struct Service {}", "can only be applied to protocols"),
  ])
  func rejectsInvalidDefaultHeaders(source: String, message: String) throws {
    let expansion = try expandMember(DefaultHeadersMacro.self, source: source)
    #expect(expansion.messages.first?.contains(message) == true)
  }
}
