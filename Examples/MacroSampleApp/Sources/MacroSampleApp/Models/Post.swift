import Foundation

/// JSONPlaceholder Post model
struct Post: Codable, Sendable {
  let id: Int?
  let userId: Int
  let title: String
  let body: String

  enum CodingKeys: String, CodingKey {
    case id
    case userId
    case title
    case body
  }
}
