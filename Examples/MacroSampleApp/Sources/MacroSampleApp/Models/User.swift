import Foundation

/// GitHub User model
struct User: Codable, Sendable {
  let id: Int
  let login: String
  let avatarUrl: String
  let name: String?
  let bio: String?
  let publicRepos: Int?
  let followers: Int?
  let following: Int?

  enum CodingKeys: String, CodingKey {
    case id
    case login
    case name
    case bio
    case avatarUrl = "avatar_url"
    case publicRepos = "public_repos"
    case followers
    case following
  }
}
