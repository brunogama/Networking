import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation

/// Macro implementation for @DELETE HTTP method.
///
/// Generates code for DELETE requests (typically for resource deletion).
///
/// Example:
/// ```swift
/// @DELETE("/users/{id}")
/// func deleteUser(id: String) async throws
/// ```
///
/// Expands to:
/// ```swift
/// func deleteUser(id: String) async throws {
///   let path = "/users/\(id)"
///   var request = HTTPRequest(method: .DELETE, path: path)
///   let _ = try await client.execute(request)
/// }
/// ```
public struct DELETEMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Validate this is a function declaration
    guard let function = declaration.as(FunctionDeclSyntax.self) else {
      MacroHelpers.emitError(
        "@DELETE can only be applied to function declarations",
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

    // Extract query parameters (if any)
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
    if !queryParams.isEmpty {
      try MacroHelpers.validateQueryParameters(
        queryParams,
        functionParameters: functionParams,
        context: context
      )
    }

    // Extract return type (DELETE can be Void or return a response)
    let returnType = MacroHelpers.extractReturnType(from: function)

    // Generate implementation
    let implementation = generateImplementation(
      function: function,
      path: path,
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
        "@DELETE requires a path argument",
        node: node,
        context: context
      )
      return nil
    }

    return segment.content.text
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
        let arrayExpr = argument.expression.as(ArrayExprSyntax.self)
      {
        return arrayExpr.elements.compactMap { element in
          if let stringLiteral = element.expression.as(StringLiteralExprSyntax.self),
            let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
          {
            return segment.content.text
          }
          return nil
        }
      }
    }

    return []
  }

  /// Extracts custom headers from the macro attribute.
  private static func extractHeaders(
    from node: AttributeSyntax,
    context: some MacroExpansionContext
  ) -> [String: String] {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
      return [:]
    }

    // Look for headers argument
    for argument in arguments {
      if argument.label?.text == "headers",
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

  // MARK: - Code Generation

  /// Generates the implementation code for the DELETE request.
  private static func generateImplementation(
    function: FunctionDeclSyntax,
    path: String,
    queryParameters: [String],
    headers: [String: String],
    returnType: String?
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

    // Combine additional request code (headers + query params)
    let additionalRequestCode = headerCode + queryParamCode

    // Check if parent protocol has @Interceptors
    let hasInterceptors =
      findParentProtocol(function)
      .map { InterceptorsMacro.hasInterceptors(from: $0) } ?? false

    // Build the function signature
    let signature: String
    if let returnType = returnType, returnType != "Void" && !returnType.isEmpty {
      signature = "func \(functionName)(\(paramList)) async throws -> \(returnType)"
    } else {
      signature = "func \(functionName)(\(paramList)) async throws"
    }

    // Generate implementation with or without interceptors
    if hasInterceptors {
      return generateWithInterceptors(
        signature: signature,
        pathCode: pathCode,
        additionalRequestCode: additionalRequestCode,
        returnType: returnType
      )
    } else {
      return generateWithoutInterceptors(
        signature: signature,
        pathCode: pathCode,
        additionalRequestCode: additionalRequestCode,
        returnType: returnType
      )
    }
  }

  /// Generates DELETE implementation with interceptors.
  private static func generateWithInterceptors(
    signature: String,
    pathCode: String,
    additionalRequestCode: String,
    returnType: String?
  ) -> String {
    let contextCreation = InterceptorCodeGenerator.generateContextCreation(
      path: "path",
      method: ".DELETE"
    )
    let requestHook: String
    let responseHook = InterceptorCodeGenerator.generateResponseInterceptorHook()

    if let returnType = returnType, returnType != "Void" && !returnType.isEmpty {
      requestHook = InterceptorCodeGenerator.generateRequestInterceptorHook(returnType: returnType)

      return """
        \(signature) {
          let path = \(pathCode)
          var request = HTTPRequest(method: .DELETE, path: path, baseURL: baseURL)\(additionalRequestCode)
          \(contextCreation)

          \(requestHook)

          let response = try await client.execute(request)

          \(responseHook)

          return try JSONDecoder().decode(\(returnType).self, from: response.data)
        }
        """
    } else {
      // Void return type with interceptors
      return """
        \(signature) {
          let path = \(pathCode)
          var request = HTTPRequest(method: .DELETE, path: path, baseURL: baseURL)\(additionalRequestCode)
          \(contextCreation)

          let requestResult = try await interceptors.executeRequestInterceptors(
            request: &request, context: context
          )
          guard case .proceed = requestResult else {
            throw InterceptorError.invalidResult(reason: "DELETE with Void return cannot short-circuit")
          }

          let _ = try await client.execute(request)
        }
        """
    }
  }

  /// Generates DELETE implementation without interceptors.
  private static func generateWithoutInterceptors(
    signature: String,
    pathCode: String,
    additionalRequestCode: String,
    returnType: String?
  ) -> String {
    let returnStatement: String
    if let returnType = returnType, returnType != "Void" && !returnType.isEmpty {
      returnStatement = """
        let response = try await client.execute(request)
        return try JSONDecoder().decode(\(returnType).self, from: response.data)
        """
    } else {
      returnStatement = "let _ = try await client.execute(request)"
    }

    return """
      \(signature) {
        let path = \(pathCode)
        var request = HTTPRequest(method: .DELETE, path: path, baseURL: baseURL)\(additionalRequestCode)
        \(returnStatement)
      }
      """
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

  /// Generates code for adding query parameters.
  private static func generateQueryParameterCode(_ queryParameters: [String]) -> String {
    guard !queryParameters.isEmpty else { return "" }

    let paramCode = queryParameters.map { param in
      "\n  request.addQueryParameter(name: \"\(param)\", value: \\(\(param)))"
    }.joined()

    return paramCode
  }
}
