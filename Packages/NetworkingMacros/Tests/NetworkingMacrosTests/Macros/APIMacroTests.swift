import SwiftSyntax
import Testing
@testable import NetworkingMacrosPlugin

struct APIMacroTests {
  @Test(arguments: ["UserAPI", "ComplexAPIService"])
  func generatesInjectedFactory(name: String) throws {
    let expansion = try expandPeer(
      APIMacro.self,
      source: """
        @API(baseURL: .absolute("https://api.example.com"))
        protocol \(name) {}
        """
    )
    #expect(expansion.messages.isEmpty)
    #expect(expansion.declarations.count == 2)
    let implementation = try #require(expansion.declarations.first?.as(StructDeclSyntax.self))
    #expect(implementation.name.text == "\(name)Implementation")
    #expect(implementation.modifiers.map(\.name.text) == ["private"])
    #expect(
      implementation.inheritanceClause?.inheritedTypes.map(\.type.trimmedDescription)
        == [name, "Sendable"]
    )
    #expect(expansion.source.contains("private let codec: JSONCodec"))
    #expect(expansion.source.contains("self.codec = codec"))
    #expect(expansion.source.contains("codec: JSONCodec = JSONCodec()"))
    #expect(expansion.source.contains("\(name)Implementation(client: client, codec: codec)"))
  }

  @Test(arguments: ["public", "package", "internal", "private"])
  func preservesFactoryAccess(access: String) throws {
    let expansion = try expandPeer(
      APIMacro.self,
      source: """
        @API(baseURL: .absolute("https://api.example.com"))
        \(access) protocol UserAPI {}
        """
    )
    #expect(expansion.messages.isEmpty)
    #expect(expansion.source.contains("\(access) enum UserAPIFactory"))
  }

  @Test func generatesMethodsWithConfiguration() throws {
    let expansion = try expandPeer(
      APIMacro.self,
      source: """
        @API(baseURL: .absolute("https://api.example.com"))
        @DefaultHeaders([.named("Accept"): .literal("application/json")])
        @Timeout(.milliseconds(250))
        protocol UserAPI {
          @GET(.path("/users/{id}"))
          func user(id: Int) async throws -> User
          @POST(.path("/users"))
          @Body(.parameter("user"))
          func create(user: User) async throws -> User
          @DELETE(.path("/users/{id}"))
          func remove(id: Int) async throws
        }
        """
    )
    #expect(expansion.messages.isEmpty)
    #expect(expansion.source.contains("RequestTimeout(rawValue: 0.25)"))
    #expect(expansion.source.contains(#"["Accept": "application/json"]"#))
    #expect(expansion.source.contains("codec.encode(user)"))
    #expect(expansion.source.contains("codec.decode(User.self"))
    #expect(!expansion.source.contains("JSONDecoder()"))
    #expect(!expansion.source.contains("JSONEncoder()"))
  }

  @Test(arguments: [
    ("@API protocol UserAPI {}", "@API requires a baseURL argument"),
    (#"@API(baseURL: .absolute("")) protocol UserAPI {}"#, "Base URL cannot be empty"),
    (
      #"@API(baseURL: .absolute("https://example.com")) struct UserAPI {}"#,
      "@API can only be applied to protocols"
    ),
  ])
  func rejectsInvalidDeclarations(source: String, message: String) throws {
    let expansion = try expandPeer(APIMacro.self, source: source)
    #expect(expansion.messages == [message])
  }

  @Test(arguments: [
    ("@API protocol UserAPI {}", "apiRequiresBaseURL"),
    (#"@API(baseURL: .absolute("")) protocol UserAPI {}"#, "emptyBaseURL"),
  ])
  func reportsStableDiagnosticIDs(source: String, identifier: String) throws {
    let expansion = try expandPeer(APIMacro.self, source: source)
    #expect(expansion.diagnosticIDs == [identifier])
  }

  @Test(arguments: [
    ("var count: Int { get }", "@API protocols may only contain endpoint methods"),
    ("func user() async throws -> User", "Method 'user' requires an HTTP method macro"),
  ])
  func rejectsNonEndpoints(member: String, message: String) throws {
    let expansion = try expandPeer(
      APIMacro.self,
      source: """
        @API(baseURL: .absolute("https://example.com"))
        protocol UserAPI { \(member) }
        """
    )
    #expect(expansion.messages == [message])
  }

  @Test func rejectsConflictingHTTPMethods() throws {
    let expansion = try expandPeer(
      APIMacro.self,
      source: """
        @API(baseURL: .absolute("https://example.com"))
        protocol UserAPI {
          @GET(.path("/users"))
          @DELETE(.path("/users"))
          func users() async throws -> [User]
        }
        """
    )
    #expect(expansion.messages.first?.contains("multiple HTTP method macros") == true)
  }
}
