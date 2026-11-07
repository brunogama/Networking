import Foundation

struct PathTemplateParser {
  let template: String

  func extractParameters() -> [String] {
    guard let regex = try? NSRegularExpression(pattern: #"\{(\w+)\}"#) else { return [] }
    let source = template as NSString
    return regex.matches(in: template, range: NSRange(location: 0, length: source.length))
      .compactMap { match in
        guard match.numberOfRanges > 1 else { return nil }
        return source.substring(with: match.range(at: 1))
      }
  }

  func generatePathSubstitution() -> String {
    var result = String(reflecting: template)
    for parameter in extractParameters() {
      result = result.replacingOccurrences(of: "{\(parameter)}", with: "\\(\(parameter))")
    }
    return result
  }
}
