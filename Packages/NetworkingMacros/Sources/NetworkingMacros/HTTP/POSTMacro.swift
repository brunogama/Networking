import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation

/// Macro implementation for @POST HTTP method.
///
/// Generates code for POST requests with request body support.
///
/// Example:
/// ```swift
/// @POST("/users", body: "user")
/// func createUser(user: User) async throws -> User
/// ```
///
/// Expands to:
/// ```swift
/// func createUser(user: User) async throws -> User {
///   let path = "/users"
///   var request = HTTPRequest(method: .POST, path: path)
///   request.setBody(try JSONEncoder().encode(user))
///   request.addHeader(name: "Content-Type", value: "application/json")
///   let response = try await client.execute(request)
///   return try JSONDecoder().decode(User.self, from: response.data)
/// }
/// ```
public struct POSTMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Validate this is a function declaration
    guard let function = declaration.as(FunctionDeclSyntax.self) else {
      MacroHelpers.emitError(
        "@POST can only be applied to function declarations",
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

    // Detect syntax style (old vs new)
    let usesOldSyntax = function.usesOldMacroSyntax()
    let newBodyParam = function.detectBodyMacro()
    let newHeaders = function.detectHeadersMacro()

    // Check for mixing old and new syntax
    if usesOldSyntax && (newBodyParam != nil || !newHeaders.isEmpty) {
      MacroHelpers.emitError(
        """
        Cannot mix old and new syntax. Use either:
        - Old: @POST("/path", body: "param", headers: [...])
        - New: @POST("/path") with @Body("param") and @Headers { ... }
        """,
        node: node,
        context: context
      )
      return []
    }

    // Emit deprecation warning for old syntax
    if usesOldSyntax {
      MacroHelpers.emitWarning(
        """
        Old syntax is deprecated. Use @Body and @Headers attached macros instead:
        @POST("/path")
        @Body("paramName")
        @Headers { H("name", "value") }
        func myMethod(...)
        """,
        node: Syntax(node),
        context: context
      )
    }

    // Extract body parameter (try new syntax first, then old)
    let bodyParam: String?
    if let newBody = newBodyParam {
      bodyParam = newBody
    } else if let oldBody = extractBodyParameter(from: node, context: context) {
      bodyParam = oldBody
    } else {
      MacroHelpers.emitError(
        "@POST requires a body parameter. Use @Body(\"paramName\") or body: argument",
        node: node,
        context: context
      )
      return []
    }

    guard let body = bodyParam else {
      return []
    }

    // Extract query parameters (if any)
    let queryParams = extractQueryParameters(from: node, context: context)

    // Extract headers (new syntax takes precedence)
    let headers: [(name: String, value: String, isParameter: Bool)]
    if !newHeaders.isEmpty {
      headers = newHeaders
    } else {
      let oldHeaders = extractHeaders(from: node, context: context)
      headers = oldHeaders.map { (name: $0.key, value: $0.value, isParameter: false) }
    }

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

    // Extract return type
    guard let returnType = MacroHelpers.extractReturnType(from: function) else {
      MacroHelpers.emitError(
        "@POST methods must have an explicit return type",
        node: function,
        context: context
      )
      return []
    }

    // Generate implementation
    let implementation = generateImplementation(
      function: function,
      path: path,
      bodyParameter: body,
      queryParameters: queryParams,
      headers: headers,
      returnType: returnType
    )

    return [implementation]
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
        "@POST requires a path argument",
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
        "@POST requires a 'body' argument",
        node: node,
        context: context
      )
      return nil
    }

    // Find argument labeled "body"
    for argument in arguments {
      if argument.label?.text == "body",
        let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
        let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
      {
        return segment.content.text
      }
    }

    MacroHelpers.emitError(
      "@POST requires a 'body' argument",
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
        let dictExpr = argument.expression.as(DictionaryExprSyntax.self)
      {
        var headers: [String: String] = [:]

        for element in dictExpr.content.as(DictionaryElementListSyntax.self) ?? [] {
          if let keyString = element.key.as(StringLiteralExprSyntax.self),
            let keySegment = keyString.segments.first?.as(StringSegmentSyntax.self),
            let valueString = element.value.as(StringLiteralExprSyntax.self),
            let valueSegment = valueString.segments.first?.as(StringSegmentSyntax.self)
          {
            headers[keySegment.content.text] = valueSegment.content.text
          }
        }

        return headers
      }
    }

    return [:]
  }

  // MARK: - Code Generation

  /// Generates the implementation code for the POST request.
  private static func generateImplementation(
    function: FunctionDeclSyntax,
    path: String,
    bodyParameter: String,
    queryParameters: [String],
    headers: [(name: String, value: String, isParameter: Bool)],
    returnType: String
  ) -> DeclSyntax {
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

    // Generate body encoding code
    let bodyCode = """

        request.setBody(try JSONEncoder().encode(\(bodyParameter)))
        request.addHeader(name: "Content-Type", value: "application/json")
      """

    // Combine additional request code (body + headers + query params)
    let additionalRequestCode = bodyCode + headerCode + queryParamCode

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
      method: "POST",
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
  private static func generateHeaderCode(
    _ headers: [(name: String, value: String, isParameter: Bool)]
  ) -> String {
    guard !headers.isEmpty else { return "" }

    let headerCode = headers.map { header in
      if header.isParameter {
        // Parameter reference: interpolate the parameter value
        """
          request.addHeader(name: "\(header.name)", value: \\(\(header.value)))
        """
      } else {
        // Literal value: use as-is
        """
          request.addHeader(name: "\(header.name)", value: "\(header.value)")
        """
      }
    }.joined(separator: "\n")

    return "\n\(headerCode)"
  }
}
