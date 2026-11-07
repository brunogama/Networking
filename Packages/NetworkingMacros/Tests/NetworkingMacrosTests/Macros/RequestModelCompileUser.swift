import Networking
import NetworkingMacros

struct RequestModelCompileUser: Codable, Equatable, Sendable {
  let name: String
}

@RequestModel(method: .post, path: "/request-models")
struct RequestModelCreateUser: Request {
  typealias Response = RequestModelCompileUser

  @Header("Authorization") var token: String
  @Body("data") var payload: RequestModelCompileUser
}
