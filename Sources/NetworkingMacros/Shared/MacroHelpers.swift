import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation

/// Validation and utility functions for macro expansion.
enum MacroHelpers {
  // MARK: - Function Signature Validation

  /// Validates that a function has the `async` keyword.
  static func validateAsync(
    function: FunctionDeclSyntax,
    context: some MacroExpansionContext
  ) throws {
    guard function.signature.effectSpecifiers?.asyncSpecifier != nil else {
      throw MacroExpansionError.missingAsyncKeyword(function.name.text)
    }
  }

  /// Validates that a function has the `throws` keyword.
  static func validateThrows(
    function: FunctionDeclSyntax,
    context: some MacroExpansionContext
  ) throws {
    guard function.signature.effectSpecifiers?.throwsClause?.throwsSpecifier != nil else {
      throw MacroExpansionError.missingThrowsKeyword(function.name.text)
    }
  }

  /// Validates that a function is both async and throws.
  static func validateAsyncThrows(
    function: FunctionDeclSyntax,
    context: some MacroExpansionContext
  ) throws {
    try validateAsync(function: function, context: context)
    try validateThrows(function: function, context: context)
  }

  // MARK: - Parameter Extraction

  /// Extracts all parameter names from a function signature.
  static func extractParameterNames(
    from function: FunctionDeclSyntax
  ) -> [String] {
    function.signature.parameterClause.parameters.map { param in
      param.secondName?.text ?? param.firstName.text
    }
  }

  /// Extracts parameter information including names and types.
  static func extractParameters(
    from function: FunctionDeclSyntax
  ) -> [(name: String, type: String)] {
    function.signature.parameterClause.parameters.map { param in
      let name = param.secondName?.text ?? param.firstName.text
      let type = param.type.description.trimmingCharacters(in: .whitespaces)
      return (name: name, type: type)
    }
  }

  // MARK: - Path Template Validation

  /// Validates that all path parameters exist in function parameters.
  static func validatePathParameters(
    path: String,
    functionParameters: [String],
    context: some MacroExpansionContext
  ) throws {
    let pathParams = extractPathParameters(from: path)

    for pathParam in pathParams {
      guard functionParameters.contains(pathParam) else {
        throw MacroExpansionError.parameterMismatch(
          path: path,
          declared: functionParameters,
          required: pathParams
        )
      }
    }
  }

  /// Extracts parameter names from path template (e.g., "{id}" -> "id").
  static func extractPathParameters(from path: String) -> [String] {
    let pattern = #"\{(\w+)\}"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return []
    }

    let nsString = path as NSString
    let matches = regex.matches(
      in: path,
      range: NSRange(location: 0, length: nsString.length)
    )

    return matches.compactMap { match in
      guard match.numberOfRanges > 1 else { return nil }
      let range = match.range(at: 1)
      return nsString.substring(with: range)
    }
  }

  /// Validates path template syntax.
  static func validatePathTemplate(
    _ path: String,
    context: some MacroExpansionContext
  ) throws {
    // Check for unmatched braces
    let openBraces = path.filter { $0 == "{" }.count
    let closeBraces = path.filter { $0 == "}" }.count

    guard openBraces == closeBraces else {
      let suggestion =
        openBraces > closeBraces
        ? "Missing closing brace '}'"
        : "Missing opening brace '{'"
      throw MacroExpansionError.invalidPathTemplate(path, suggestion: suggestion)
    }

    // Validate parameter syntax
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

      // Validate parameter name (must be valid Swift identifier)
      if paramName.isEmpty {
        throw MacroExpansionError.invalidPathTemplate(
          path,
          suggestion: "Empty parameter name in {}"
        )
      }

      if !paramName.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
        throw MacroExpansionError.invalidPathTemplate(
          path,
          suggestion: "Parameter '\(paramName)' contains invalid characters"
        )
      }
    }
  }

  // MARK: - Query Parameter Validation

  /// Validates that query parameters exist in function signature.
  static func validateQueryParameters(
    _ queryParams: [String],
    functionParameters: [String],
    context: some MacroExpansionContext
  ) throws {
    for queryParam in queryParams {
      guard functionParameters.contains(queryParam) else {
        throw MacroExpansionError.queryParameterNotFound(
          queryParam,
          available: functionParameters
        )
      }
    }
  }

  // MARK: - Body Parameter Validation

  /// Validates that body parameter exists in function signature.
  static func validateBodyParameter(
    _ bodyParam: String,
    functionParameters: [String],
    context: some MacroExpansionContext
  ) throws {
    guard functionParameters.contains(bodyParam) else {
      throw MacroExpansionError.bodyParameterNotFound(
        bodyParam,
        available: functionParameters
      )
    }
  }

  // MARK: - Return Type Extraction

  /// Extracts return type from function signature.
  static func extractReturnType(from function: FunctionDeclSyntax) -> String? {
    function.signature.returnClause?.type.description
      .trimmingCharacters(in: .whitespaces)
  }

  // MARK: - HTTP Method Detection

  /// Detects HTTP method macros on a function.
  static func detectHTTPMethods(on declaration: some WithAttributesSyntax) -> [String] {
    let httpMethods = ["GET", "POST", "PUT", "PATCH", "DELETE"]
    var found: [String] = []

    for attribute in declaration.attributes {
      guard case .attribute(let attr) = attribute else { continue }
      let attrName = attr.attributeName.description
        .trimmingCharacters(in: CharacterSet.whitespaces)

      if httpMethods.contains(attrName) {
        found.append(attrName)
      }
    }

    return found
  }

  /// Validates that only one HTTP method macro is present.
  static func validateSingleHTTPMethod(
    on function: FunctionDeclSyntax,
    context: some MacroExpansionContext
  ) throws {
    let methods = detectHTTPMethods(on: function)

    guard methods.count <= 1 else {
      throw MacroExpansionError.multipleHTTPMethods(
        function.name.text,
        found: methods
      )
    }
  }

  // MARK: - Diagnostic Helpers

  /// Emits a diagnostic error at the macro location.
  static func emitError(
    _ message: String,
    node: some SyntaxProtocol,
    context: some MacroExpansionContext
  ) {
    context.diagnose(
      Diagnostic(
        node: Syntax(node),
        message: SimpleDiagnosticMessage(
          message: message,
          diagnosticID: MessageID(domain: "Networking", id: "error"),
          severity: .error
        )
      )
    )
  }

  /// Emits a diagnostic warning at the macro location.
  static func emitWarning(
    _ message: String,
    node: some SyntaxProtocol,
    context: some MacroExpansionContext
  ) {
    context.diagnose(
      Diagnostic(
        node: Syntax(node),
        message: SimpleDiagnosticMessage(
          message: message,
          diagnosticID: MessageID(domain: "Networking", id: "warning"),
          severity: .warning
        )
      )
    )
  }
}

// MARK: - Diagnostic Message

/// Simple diagnostic message for macro errors.
///
/// This type is used throughout the macro implementation to emit diagnostics.
internal struct SimpleDiagnosticMessage: DiagnosticMessage {
  let message: String
  let diagnosticID: MessageID
  let severity: DiagnosticSeverity
}

// MARK: - MacroExpansionError Extension

/// Errors that can occur during macro expansion.
public enum MacroExpansionError: Error, CustomStringConvertible {
  case parameterMismatch(path: String, declared: [String], required: [String])
  case invalidPathTemplate(String, suggestion: String?)
  case bodyParameterNotFound(String, available: [String])
  case queryParameterNotFound(String, available: [String])
  case multipleHTTPMethods(String, found: [String])
  case missingAsyncKeyword(String)
  case missingThrowsKeyword(String)
  case nonDecodableReturnType(String)
  case nonEncodableBodyType(String)

  public var description: String {
    switch self {
    case .parameterMismatch(let path, let declared, let required):
      return """
        Path parameter mismatch in '\(path)': \
        function has parameters [\(declared.joined(separator: ", "))], \
        but path requires [\(required.joined(separator: ", "))]
        """

    case .invalidPathTemplate(let template, let suggestion):
      if let suggestion = suggestion {
        return "Invalid path template '\(template)': \(suggestion)"
      }
      return "Invalid path template '\(template)'"

    case .bodyParameterNotFound(let param, let available):
      return """
        Body parameter '\(param)' not found in function signature. \
        Available: [\(available.joined(separator: ", "))]
        """

    case .queryParameterNotFound(let param, let available):
      return """
        Query parameter '\(param)' not found in function signature. \
        Available: [\(available.joined(separator: ", "))]
        """

    case .multipleHTTPMethods(let function, let found):
      return """
        Function '\(function)' has multiple HTTP method macros: \
        [\(found.joined(separator: ", "))]. Only one is allowed.
        """

    case .missingAsyncKeyword(let function):
      return "Function '\(function)' must be marked 'async'"

    case .missingThrowsKeyword(let function):
      return "Function '\(function)' must be marked 'throws'"

    case .nonDecodableReturnType(let type):
      return "Return type '\(type)' must conform to Decodable"

    case .nonEncodableBodyType(let type):
      return "Body parameter type '\(type)' must conform to Encodable"
    }
  }
}
