import Foundation

enum MacroPathTemplateValidator {
  static func validateBalancedBraces(in path: String) throws {
    let openBraces = path.filter { $0 == "{" }.count
    let closeBraces = path.filter { $0 == "}" }.count

    guard openBraces == closeBraces else {
      let suggestion =
        openBraces > closeBraces
        ? "Missing closing brace '}'"
        : "Missing opening brace '{'"
      throw MacroExpansionError.invalidPathTemplate(
        EndpointPath(path),
        suggestion: MacroDiagnosticText(suggestion)
      )
    }
  }

  static func validatePathParameterNames(in path: String) throws {
    let pattern = #"\{([^}]*)\}"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return
    }

    let nsString = path as NSString
    let matches = regex.matches(
      in: path,
      range: NSRange(location: 0, length: nsString.length)
    )

    for match in matches {
      guard match.numberOfRanges > 1 else { continue }
      let range = match.range(at: 1)
      let paramName = nsString.substring(with: range)
      try validatePathParameterName(paramName, in: path)
    }
  }

  private static func validatePathParameterName(
    _ paramName: String,
    in path: String
  ) throws {
    guard !paramName.isEmpty else {
      throw MacroExpansionError.invalidPathTemplate(
        EndpointPath(path),
        suggestion: MacroDiagnosticText("Empty parameter name in {}")
      )
    }

    guard paramName.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
      throw MacroExpansionError.invalidPathTemplate(
        EndpointPath(path),
        suggestion: MacroDiagnosticText("Parameter '\(paramName)' contains invalid characters")
      )
    }
  }
}
