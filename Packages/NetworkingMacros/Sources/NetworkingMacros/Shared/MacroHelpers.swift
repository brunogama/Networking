import SwiftSyntax
import SwiftSyntaxMacros
import Foundation

/// Validation and utility functions for macro expansion.
enum MacroHelpers {
  // MARK: - Function Signature Validation

  static func validateAsync(
    function: FunctionDeclSyntax,
    context: some MacroExpansionContext
  ) throws {
    guard function.signature.effectSpecifiers?.asyncSpecifier != nil else {
      throw MacroExpansionError.missingAsyncKeyword(MacroFunctionName(function.name.text))
    }
  }

  static func validateThrows(
    function: FunctionDeclSyntax,
    context: some MacroExpansionContext
  ) throws {
    guard function.signature.effectSpecifiers?.throwsClause?.throwsSpecifier != nil else {
      throw MacroExpansionError.missingThrowsKeyword(MacroFunctionName(function.name.text))
    }
  }

  static func validateAsyncThrows(
    function: FunctionDeclSyntax,
    context: some MacroExpansionContext
  ) throws {
    try validateAsync(function: function, context: context)
    try validateThrows(function: function, context: context)
  }

  // MARK: - Parameter Extraction

  static func extractParameterNames(
    from function: FunctionDeclSyntax
  ) -> [String] {
    function.signature.parameterClause.parameters.map { param in
      param.secondName?.text ?? param.firstName.text
    }
  }

  // MARK: - Path Template Validation

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

  static func validatePathTemplate(
    _ path: String,
    context: some MacroExpansionContext
  ) throws {
    try MacroPathTemplateValidator.validateBalancedBraces(in: path)
    try MacroPathTemplateValidator.validatePathParameterNames(in: path)
  }

  // MARK: - Query Parameter Validation

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

  // MARK: - HTTP Method Detection

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

}
