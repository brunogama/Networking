import Networking
import NetworkingMacros

@API(baseURL: .absolute("https://api.example.com"))
protocol MacroCompileUsersAPI {
  @GET(.path("/users/{id}"))
  func user(id: Int) async throws -> MacroCompileUser

  @GET(.path(#"/files/a"b\c/{id}"#))
  func escapedPath(id: Int) async throws -> MacroCompileUser

  @POST(.path("/users"), queryParameters: [.parameter("notify")])
  @Body(.parameter("user"))
  func create(user: MacroCompileUser, notify: Bool) async throws -> MacroCompileUser

  @PUT(.path("/users/{id}"))
  @Body(.parameter("user"))
  func replace(id: Int, with user: MacroCompileUser) async throws -> MacroCompileUser

  @PATCH(.path("/users/{id}"))
  @Body(.parameter("user"))
  func update(id: Int, with user: MacroCompileUser) async throws -> MacroCompileUser

  @DELETE(.path("/users/{id}"))
  func delete(id: Int) async throws
}
