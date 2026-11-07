import Networking
import NetworkingMacros

@API(baseURL: .absolute("https://example.com")) protocol ConsumerAPI {
  @GET(.path("/users/{id}"))
  func user(id: Int) async throws -> ConsumerUser
}
