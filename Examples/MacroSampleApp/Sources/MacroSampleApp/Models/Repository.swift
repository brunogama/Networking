import Foundation

/// GitHub Repository model
struct Repository: Codable, Sendable {
  let id: Int
  let name: String
  let fullName: String
  let description: String?
  let stargazersCount: Int
  let forksCount: Int
  let language: String?
  let htmlUrl: String

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case description
    case language
    case fullName = "full_name"
    case stargazersCount = "stargazers_count"
    case forksCount = "forks_count"
    case htmlUrl = "html_url"
  }
}
