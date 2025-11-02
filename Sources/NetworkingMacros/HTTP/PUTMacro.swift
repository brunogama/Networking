import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation

/// Macro implementation for @PUT HTTP method.
///
/// Generates code for PUT requests with request body support.
///
/// Example:
/// ```swift
/// @PUT("/users/{id}", body: "user")
/// func updateUser(id: String, user: User) async throws -> User
/// ```
///
/// Expands to:
/// ```swift
/// func updateUser(id: String, user: User) async throws -> User {
///   let path = "/users/\(id)"
///   var request = HTTPRequest(method: .PUT, path: path)
///   request.setBody(try JSONEncoder().encode(user))
///   request.addHeader(name: "Content-Type", value: "application/json")
///   let response = try await client.execute(request)
///   return try JSONDecoder().decode(User.self, from: response.data)
/// }
/// ```
public struct PUTMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Validate this is a function declaration
    guard let function = declaration.as(FunctionDeclSyntax.self) else {
      MacroHelpers.emitError(
        "@PUT can only be applied to function declarations",
        node: node,
        context: context
      )
      return []
    }

    // Validate function is async throws
    try MacroHelpers.validateAsyncThrows(function: function, context: context)

    // Extract path from first argument
    guard let path = extractPath(from: node, context: context) else {
      return []
    }

    // Validate path template syntax
    try MacroHelpers.validatePathTemplate(path, context: context)

    // Extract body parameter name from macro arguments
    guard let bodyParam = extractBodyParameter(from: node, context: context) else {
      return []
    }

    // Extract query parameters (if any)
    let queryParams = extractQueryParameters(from: node, context: context)

    // Extract headers (if any)
    let headers = extractHeaders(from: node, context: context)

    // Extract function parameters
    let functionParams = MacroHelpers.extractParameterNames(from: function)

    // Validate path parameters exist in function signature
    try MacroHelpers.validatePathParameters(
      path: path,
      functionParameters: functionParams,
      context: context
    )

    // Validate query parameters exist in function signature
    if !queryParams.isEmpty {
      try MacroHelpers.validateQueryParameters(
        queryParams,
        functionParameters: functionParams,
        context: context
      )
    }

    // Validate body parameter exists in function signature
    try MacroHelpers.validateBodyParameter(
      bodyParam,
      functionParameters: functionParams,
      context: context
    )

    // Extract return type
    guard let returnType = MacroHelpers.extractReturnType(from: function) else {
      MacroHelpers.emitError(
        "@PUT methods must have an explicit return type",
        node: function,
        context: context
      )
      return []
    }

    // Generate implementation
    let implementation = generateImplementation(
      function: function,
      path: path,
      bodyParameter: bodyParam,
      queryParameters: queryParams,
      headers: headers,
      returnType: returnType
    )

    return [DeclSyntax(stringLiteral: implementation)]
  }

  // MARK: - Argument Extraction

  /// Extracts the path from the first macro argument.
  private static func extractPath(
    from node: AttributeSyntax,
    context: some MacroExpansionContext
  ) -> String? {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
      let firstArg = arguments.first,
      let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
      let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
    else {
      MacroHelpers.emitError(
        "@PUT requires a path argument",
        node: node,
        context: context
      )
      return nil
    }

    return segment.content.text
  }

  /// Extracts the body parameter name from macro arguments.
  private static func extractBodyParameter(
    from node: AttributeSyntax,
    context: some MacroExpansionContext
  ) -> String? {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
      MacroHelpers.emitError(
        "@PUT requires a 'body' argument",
        node: node,
        context: context
      )
      return nil
    }

    // Find argument labeled "body"
    for argument in arguments {
      if argument.label?.text == "body",
        let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
        let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
        return segment.content.text
      }
    }

    MacroHelpers.emitError(
      "@PUT requires a 'body' argument",
      node: node,
      context: context
    )
    return nil
  }

  /// Extracts query parameters from macro arguments.
  private static func extractQueryParameters(
    from node: AttributeSyntax,
    context: some MacroExpansionContext
  ) -> [String] {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
      return []
    }

    for argument in arguments {
      if argument.label?.text == "queryParameters",
        let arrayExpr = argument.expression.as(ArrayExprSyntax.self) {
        return arrayExpr.elements.compactMap { element in
          if let stringLiteral = element.expression.as(StringLiteralExprSyntax.self),
            let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
            return segment.content.text
          }
          return nil
        }
      }
    }

    return []
  }

  /// Extracts headers from macro arguments.
  private static func extractHeaders(
    from node: AttributeSyntax,
    context: some MacroExpansionContext
  ) -> [String: String] {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
      return [:]
    }

    for argument in arguments {
      if argument.label?.text == "headers",
        let dictExpr = argument.expression.as(DictionaryExprSyntax.self) {
        var headers: [String: String] = [:]

        for element in dictExpr.content.as(DictionaryElementListSyntax.self) ?? [] {
          if let keyString = element.key.as(StringLiteralExprSyntax.self),
            let keySegment = keyString.segments.first?.as(StringSegmentSyntax.self),
            let valueString = element.value.as(StringLiteralExprSyntax.self),
            let valueSegment = valueString.segments.first?.as(StringSegmentSyntax.self) {
            headers[keySegment.content.text] = valueSegment.content.text
          }
        }

        return headers
      }
    }

    return [:]
  }

  // MARK: - Code Generation

  /// Generates the implementation code for the PUT request.
  private static func generateImplementation(
    function: FunctionDeclSyntax,
    path: String,
    bodyParameter: String,
    queryParameters: [String],
    headers: [String: String],
    returnType: String
  ) -> String {
    let functionName = function.name.text
    let parameters = MacroHelpers.extractParameters(from: function)
    let paramList = parameters.map { "\($0.name): \($0.type)" }.joined(separator: ", ")

    // Generate path substitution code
    let parser = PathTemplateParser(template: path)
    let pathCode = parser.generatePathSubstitution()

    // Generate query parameter code
    let queryParamCode = generateQueryParameterCode(queryParameters)

    // Generate header code
    let headerCode = generateHeaderCode(headers)

    return """
      func \(functionName)(\(paramList)) async throws -> \(returnType) {
        let path = \(pathCode)
        var request = HTTPRequest(method: .PUT, path: path)
        request.setBody(try JSONEncoder().encode(\(bodyParameter)))
        request.addHeader(name: "Content-Type", value: "application/json")\(headerCode)\(queryParamCode)
        let response = try await client.execute(request)
        return try JSONDecoder().decode(\(returnType).self, from: response.data)
      }
      """
  }

  /// Generates code for adding query parameters.
  private static func generateQueryParameterCode(_ queryParameters: [String]) -> String {
    guard !queryParameters.isEmpty else { return "" }

    let paramCode = queryParameters.map { param in
      """
        request.addQueryParameter(name: "\(param)", value: \\(\(param)))
      """
    }.joined(separator: "\n")

    return "\n\(paramCode)"
  }

  /// Generates code for adding custom headers.
  private static func generateHeaderCode(_ headers: [String: String]) -> String {
    guard !headers.isEmpty else { return "" }

    let headerCode = headers.map { name, value in
      """
        request.addHeader(name: "\(name)", value: "\(value)")
      """
    }.joined(separator: "\n")

    return "\n\(headerCode)"
  }
}
