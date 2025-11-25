import Foundation

/// GitHub Search Result wrapper
struct SearchResult<T: Codable & Sendable>: Codable, Sendable {
  let totalCount: Int
  let incompleteResults: Bool
  let items: [T]

  enum CodingKeys: String, CodingKey {
    case totalCount = "total_count"
    case incompleteResults = "incomplete_results"
    case items
  }
}
