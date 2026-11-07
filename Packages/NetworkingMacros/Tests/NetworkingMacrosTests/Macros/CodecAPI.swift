import Foundation
import Networking
import NetworkingMacros
import Testing

@API(baseURL: .absolute("https://api.example.com"))
@DefaultHeaders([.named("Accept"): .literal("application/json")])
@Timeout(.milliseconds(250)) protocol CodecAPI: Sendable {
  @POST(.path("/users"))
  @Body(.parameter("user"))
  @Headers([.named("Authorization"): .parameter("token")])
  func create(user: CodecUser, token: String) async throws -> CodecUser

  @GET(.path("/users"), queryParameters: [.parameter("page")])
  func user(page: Int?) async throws -> CodecUser
}
