import Foundation
import NetworkingCore

package func cachePatternRegex(_ pattern: CacheInvalidationPattern) -> NSRegularExpression? {
  let components = pattern.rawValue.map { character in
    switch character {
    case "*": return ".*"
    case "?": return "."
    default: return NSRegularExpression.escapedPattern(for: String(character))
    }
  }
  return try? NSRegularExpression(pattern: "\\A" + components.joined() + "\\z")
}
