import Networking
import NetworkingMacros

/// Exercises the generated public factory across module boundaries.
@API(baseURL: .absolute("https://example.com"))
public protocol PublicAPI {
  @GET(.path("/users/{id}"))
  func user(id: Int) async throws -> PublicUser
}
