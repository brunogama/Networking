import Testing
@testable import NetworkingMacrosPlugin

struct BodyMacroTests {
  @Test(arguments: [
    ("user", "user: User"),
    ("data", "id: Int, data: UserData"),
    ("requestBody", "for userID: String, body requestBody: PostData"),
  ])
  func acceptsLocalParameterName(name: String, parameters: String) throws {
    let expansion = try expandPeer(
      BodyMacro.self,
      source: """
        @Body(.parameter("\(name)"))
        func create(\(parameters)) async throws -> User
        """
    )
    #expect(expansion.messages.isEmpty)
    #expect(expansion.declarations.isEmpty)
  }

  @Test(arguments: [
    (
      #"@Body(.parameter("missing")) func create(user: User) async throws -> User"#,
      "Body parameter 'missing' not found"
    ),
    ("@Body func create(user: User) async throws -> User", "@Body requires parameter name"),
    (#"@Body(.parameter("user")) struct User {}"#, "@Body can only be applied to functions"),
    (
      #"@Body(.parameter("user")) @Body(.parameter("data")) func create(user: User, data: Data)"#,
      "Only one @Body macro allowed"
    ),
  ])
  func rejectsInvalidBody(source: String, message: String) throws {
    let expansion = try expandPeer(BodyMacro.self, source: source)
    #expect(expansion.messages.count == 1)
    #expect(expansion.messages.first?.contains(message) == true)
  }
}
