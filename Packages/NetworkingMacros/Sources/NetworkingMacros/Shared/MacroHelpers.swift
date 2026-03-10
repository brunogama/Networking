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
      throw MacroExpansionError.missingAsyncKeyword(MacroFunctionName(function.name.text))
    }
  }

  /// Validates that a function has the `throws` keyword.
  static func validateThrows(
    function: FunctionDeclSyntax,
    context: some MacroExpansionContext
  ) throws {
    guard function.signature.effectSpecifiers?.throwsClause?.throwsSpecifier != nil else {
      throw MacroExpansionError.missingThrowsKeyword(MacroFunctionName(function.name.text))
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
          path: EndpointPath(path),
          declared: functionParameters.map { ParameterReference($0) },
          required: pathParams.map { ParameterReference($0) }
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
    try MacroPathTemplateValidator.validateBalancedBraces(in: path)
    try MacroPathTemplateValidator.validatePathParameterNames(in: path)
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
          ParameterReference(queryParam),
          available: functionParameters.map { ParameterReference($0) }
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
        ParameterReference(bodyParam),
        available: functionParameters.map { ParameterReference($0) }
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
        MacroFunctionName(function.name.text),
        found: methods.map { HTTPMethodName($0) }
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

  // MARK: - Macro Argument Extraction

  /// Extracts a labeled argument from macro attribute syntax
  /// - Parameters:
  ///   - label: The argument label to extract
  ///   - node: The attribute syntax containing arguments
  /// - Returns: The labeled argument expression, or nil if not found
  static func extractArgument(
    labeled label: String,
    from node: AttributeSyntax
  ) -> LabeledExprSyntax? {
    node.macroArgument(labeled: label)
  }

  /// Extracts an integer literal value from a labeled argument
  /// - Parameters:
  ///   - label: The argument label to extract
  ///   - node: The attribute syntax containing arguments
  /// - Returns: String representation of the integer, or nil if not found
  static func extractIntegerValue(
    labeled label: String,
    from node: AttributeSyntax
  ) -> String? {
    node.macroIntegerValue(labeled: label)
  }

  /// Extracts a member access value (e.g., .standard) from a labeled argument
  /// - Parameters:
  ///   - label: The argument label to extract
  ///   - node: The attribute syntax containing arguments
  /// - Returns: The member name text, or nil if not found
  static func extractMemberValue(
    labeled label: String,
    from node: AttributeSyntax
  ) -> String? {
    node.macroMemberValue(labeled: label)
  }

  /// Extracts a string literal value from a labeled argument
  /// - Parameters:
  ///   - label: The argument label to extract
  ///   - node: The attribute syntax containing arguments
  /// - Returns: The string content, or nil if not found
  static func extractStringValue(
    labeled label: String,
    from node: AttributeSyntax
  ) -> String? {
    node.macroStringValue(labeled: label)
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

/// Diagnostic messages for configuration macros
enum ConfigurationMacroDiagnostic: String, DiagnosticMessage {
  case cacheableRequiresProtocol
  case measuredRequiresFunction

  var message: String {
    switch self {
    case .cacheableRequiresProtocol:
      return "@Cacheable can only be applied to protocols"
    case .measuredRequiresFunction:
      return "@Measured can only be applied to functions"
    }
  }

  var diagnosticID: MessageID {
    MessageID(domain: "NetworkingMacros.Configuration", id: rawValue)
  }

  var severity: DiagnosticSeverity { .error }
}

/// Errors that can occur during macro expansion.
public enum MacroExpansionError: Error, CustomStringConvertible, Sendable {
  case parameterMismatch(
    path: EndpointPath,
    declared: [ParameterReference],
    required: [ParameterReference]
  )
  case invalidPathTemplate(EndpointPath, suggestion: MacroDiagnosticText?)
  case bodyParameterNotFound(ParameterReference, available: [ParameterReference])
  case queryParameterNotFound(ParameterReference, available: [ParameterReference])
  case multipleHTTPMethods(MacroFunctionName, found: [HTTPMethodName])
  case missingAsyncKeyword(MacroFunctionName)
  case missingThrowsKeyword(MacroFunctionName)
  case nonDecodableReturnType(MacroTypeReference)
  case nonEncodableBodyType(MacroTypeReference)

  public var description: String {
    switch self {
    case .parameterMismatch(let path, let declared, let required):
      return """
        Path parameter mismatch in '\(path)': \
        function has parameters [\(declared.map(\.rawValue).joined(separator: ", "))], \
        but path requires [\(required.map(\.rawValue).joined(separator: ", "))]
        """

    case .invalidPathTemplate(let template, let suggestion):
      if let suggestion = suggestion {
        return "Invalid path template '\(template)': \(suggestion)"
      }
      return "Invalid path template '\(template)'"

    case .bodyParameterNotFound(let param, let available):
      return """
        Body parameter '\(param)' not found in function signature. \
        Available: [\(available.map(\.rawValue).joined(separator: ", "))]
        """

    case .queryParameterNotFound(let param, let available):
      return """
        Query parameter '\(param)' not found in function signature. \
        Available: [\(available.map(\.rawValue).joined(separator: ", "))]
        """

    case .multipleHTTPMethods(let function, let found):
      return """
        Function '\(function)' has multiple HTTP method macros: \
        [\(found.map(\.rawValue).joined(separator: ", "))]. Only one is allowed.
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

// MARK: - Attached Macro Detection

extension FunctionDeclSyntax {
  /// Detects @Body macro on this function and returns parameter name
  ///
  /// - Returns: The parameter name from @Body("paramName"), or nil if not found
  func detectBodyMacro() -> String? {
    for attribute in attributes {
      guard case .attribute(let attr) = attribute,
        let identType = attr.attributeName.as(IdentifierTypeSyntax.self),
        identType.name.text == "Body",
        case .argumentList(let arguments) = attr.arguments,
        let firstArg = arguments.first,
        let parameterName = BoundaryExpressionParser.string(from: firstArg.expression)
      else {
        continue
      }
      return parameterName
    }
    return nil
  }

  /// Detects @Headers macro on this function and returns parsed header configurations.
  func detectHeadersMacro() -> [ParsedHeader] {
    var headers: [ParsedHeader] = []

    for attribute in attributes {
      guard let closure = HeaderMacroParser.closure(from: attribute) else {
        continue
      }

      headers.append(contentsOf: HeaderMacroParser.parseHeaders(from: closure))
    }

    return headers
  }

  /// Checks if function uses old syntax (body/headers in macro arguments)
  ///
  /// - Returns: true if old syntax detected (body: or headers: labeled arguments)
  func usesOldMacroSyntax() -> Bool {
    for attribute in attributes {
      guard case .attribute(let attr) = attribute,
        case .argumentList(let arguments) = attr.arguments
      else {
        continue
      }

      // Check for 'body:' or 'headers:' labeled arguments
      for argument in arguments {
        if let label = argument.label?.text,
          label == "body" || label == "headers"
        {
          return true
        }
      }
    }
    return false
  }
}
