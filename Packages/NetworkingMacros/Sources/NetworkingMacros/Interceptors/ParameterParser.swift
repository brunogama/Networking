import Foundation
import MacroTemplateKit

/// Parameter string parsing utilities.
///
/// Parses parameter strings into ParameterSignature arrays for function declarations.
enum ParameterParser {
  /// Parses parameter string into ParameterSignature array.
  ///
  /// Simple parser for common parameter patterns. Supports:
  /// - "name: Type" (unlabeled parameter)
  /// - "label name: Type" (labeled parameter)
  ///
  /// - Parameter parametersString: Comma-separated parameter list
  /// - Returns: Array of parameter signatures
  static func parse(_ parametersString: String) -> [ParameterSignature] {
    guard !parametersString.isEmpty else { return [] }

    return parametersString.split(separator: ",").map { paramStr in
      parseParameter(String(paramStr))
    }
  }

  // MARK: - Private Helpers

  private static func parseParameter(_ parameterString: String) -> ParameterSignature {
    let trimmed = parameterString.trimmingCharacters(in: .whitespaces)
    let components = trimmed.split(separator: ":")

    guard components.count >= 2 else {
      return ParameterSignature(name: trimmed, type: "Any")
    }

    let nameComponent = components[0].trimmingCharacters(in: .whitespaces)
    let typeComponent = components[1].trimmingCharacters(in: .whitespaces)

    let nameParts = nameComponent.split(separator: " ")
    if nameParts.count == 2 {
      return ParameterSignature(
        label: String(nameParts[0]),
        name: String(nameParts[1]),
        type: typeComponent
      )
    } else {
      return ParameterSignature(name: nameComponent, type: typeComponent)
    }
  }
}
