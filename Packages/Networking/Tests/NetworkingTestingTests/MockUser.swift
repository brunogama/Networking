struct MockUser: Codable, Equatable, Sendable {
  let id: Int
  let name: String
  var email: String?
}
