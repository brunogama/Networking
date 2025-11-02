import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation

/// Macro implementation for @GET attached to protocol methods.
///
/// Generates method implementation that:
/// - Builds URL from base URL + path with parameter substitution
/// - Creates HTTPRequest with GET method
/// - Adds query parameters
/// - Executes request via NetworkClient
/// - Decodes response to return type
public struct GETMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Validate this is a function declaration
    guard let function = declaration.as(FunctionDeclSyntax.self) else {
      MacroHelpers.emitError(
        "@GET can only be applied to function declarations",
        node: node,
        context: context
      )
      return []
    }

    // Validate function signature requirements
    try MacroHelpers.validateAsyncThrows(function: function, context: context)

    // Extract path from macro arguments
    guard let path = extractPath(from: node, context: context) else {
      return []
    }

    // Validate path template syntax
    try MacroHelpers.validatePathTemplate(path, context: context)

    // Extract query parameters from macro arguments
    let queryParams = extractQueryParameters(from: node, context: context)

    // Extract custom headers from macro arguments
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
    try MacroHelpers.validateQueryParameters(
      queryParams,
      functionParameters: functionParams,
      context: context
    )

    // Extract return type
    guard let returnType = MacroHelpers.extractReturnType(from: function) else {
      MacroHelpers.emitError(
        "@GET methods must have an explicit return type",
        node: function,
        context: context
      )
      return []
    }

    // Generate method implementation
    let implementation = generateImplementation(
      function: function,
      path: path,
      queryParameters: queryParams,
      headers: headers,
      returnType: returnType
    )

    return [DeclSyntax(stringLiteral: implementation)]
  }

  // MARK: - Helper Methods

  /// Extracts the path string from the macro attribute.
  private static func extractPath(
    from attribute: AttributeSyntax,
    context: some MacroExpansionContext
  ) -> String? {
    guard let arguments = attribute.arguments,
      case .argumentList(let list) = arguments,
      let firstArg = list.first
    else {
      MacroHelpers.emitError(
        "@GET requires a path argument",
        node: attribute,
        context: context
      )
      return nil
    }

    // Extract string literal value
    if let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
      let segment = stringLiteral.segments.first,
      case .stringSegment(let stringSegment) = segment
    {
      return stringSegment.content.text
    }

    MacroHelpers.emitError(
      "Path must be a string literal",
      node: attribute,
      context: context
    )
    return nil
  }

  /// Extracts query parameter names from the macro attribute.
  private static func extractQueryParameters(
    from attribute: AttributeSyntax,
    context: some MacroExpansionContext
  ) -> [String] {
    guard let arguments = attribute.arguments,
      case .argumentList(let list) = arguments
    else {
      return []
    }

    // Look for queryParameters argument
    for argument in list {
      if let label = argument.label?.text,
        label == "queryParameters",
        let arrayExpr = argument.expression.as(ArrayExprSyntax.self)
      {
        return arrayExpr.elements.compactMap { element in
          if let stringLiteral = element.expression.as(StringLiteralExprSyntax.self),
            let segment = stringLiteral.segments.first,
            case .stringSegment(let stringSegment) = segment
          {
            return stringSegment.content.text
          }
          return nil
        }
      }
    }

    return []
  }

  /// Extracts custom headers from the macro attribute.
  private static func extractHeaders(
    from attribute: AttributeSyntax,
    context: some MacroExpansionContext
  ) -> [String: String] {
    guard let arguments = attribute.arguments,
      case .argumentList(let list) = arguments
    else {
      return [:]
    }

    // Look for headers argument
    for argument in list {
      if let label = argument.label?.text,
        label == "headers",
        let dictExpr = argument.expression.as(DictionaryExprSyntax.self)
      {
        var headers: [String: String] = [:]

        if case .elements(let elements) = dictExpr.content {
          for element in elements {
            if let keyString = element.key.as(StringLiteralExprSyntax.self),
              let keySegment = keyString.segments.first,
              case .stringSegment(let keyContent) = keySegment,
              let valueString = element.value.as(StringLiteralExprSyntax.self),
              let valueSegment = valueString.segments.first,
              case .stringSegment(let valueContent) = valueSegment
            {
              headers[keyContent.content.text] = valueContent.content.text
            }
          }
        }

        return headers
      }
    }

    return [:]
  }

  /// Generates the complete method implementation.
  private static func generateImplementation(
    function: FunctionDeclSyntax,
    path: String,
    queryParameters: [String],
    headers: [String: String],
    returnType: String
  ) -> String {
    let functionName = function.name.text
    let parameters = MacroHelpers.extractParameters(from: function)

    // Generate path substitution
    let parser = PathTemplateParser(template: path)
    let pathCode = parser.generatePathSubstitution()

    // Generate parameter list for function signature
    let paramList = parameters.map { "\($0.name): \($0.type)" }.joined(separator: ", ")

    // Generate query parameter code
    let queryParamCode = generateQueryParameterCode(queryParameters)

    // Generate header code
    let headerCode = generateHeaderCode(headers)

    // Combine additional request code (headers + query params)
    let additionalRequestCode = headerCode + queryParamCode

    // Check if parent protocol has @Interceptors
    let hasInterceptors =
      findParentProtocol(function)
      .map { InterceptorsMacro.hasInterceptors(from: $0) } ?? false

    // Generate implementation using InterceptorCodeGenerator
    return InterceptorCodeGenerator.generateMethodImplementation(
      functionName: functionName,
      parameters: paramList,
      returnType: returnType,
      pathCode: pathCode,
      method: "GET",
      additionalRequestCode: additionalRequestCode,
      hasInterceptors: hasInterceptors
    )
  }

  /// Finds the parent protocol declaration of a function.
  private static func findParentProtocol(_ function: FunctionDeclSyntax) -> ProtocolDeclSyntax? {
    var currentNode: Syntax? = Syntax(function)

    while let node = currentNode {
      if let protocolDecl = node.as(ProtocolDeclSyntax.self) {
        return protocolDecl
      }
      currentNode = node.parent
    }

    return nil
  }

  /// Generates code for adding custom headers to request.
  private static func generateHeaderCode(_ headers: [String: String]) -> String {
    guard !headers.isEmpty else { return "" }

    let headerLines = headers.sorted(by: { $0.key < $1.key }).map { name, value in
      "\n  request.addHeader(name: \"\(name)\", value: \"\(value)\")"
    }.joined()

    return headerLines
  }

  /// Generates code for adding query parameters to request.
  private static func generateQueryParameterCode(_ queryParams: [String]) -> String {
    guard !queryParams.isEmpty else { return "" }

    let queryLines = queryParams.map { param in
      "\n  request.addQueryParameter(name: \"\(param)\", value: \\(\(param)))"
    }.joined()

    return queryLines
  }
}
