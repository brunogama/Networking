import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

// MARK: - HTTPMacroExpansion Helper Methods

extension HTTPMacroExpansion {
  /// Internal expansion method that handles Steps 7-10 of the workflow.
  ///
  /// Called by sharedExpansion after validation steps complete.
  static func expandWithHelpers(
    function: FunctionDeclSyntax,
    node: AttributeSyntax,
    path: String,
    usesOldSyntax: Bool,
    newBodyParam: String?,
    newHeaders: [(name: String, value: String, isParameter: Bool)],
    context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Step 7: Extract body parameter (if required by config)
    let bodyParam = try extractBodyIfRequired(
      function: function,
      node: node,
      usesOldSyntax: usesOldSyntax,
      newBodyParam: newBodyParam,
      context: context
    )

    // Return empty if body required but not found
    if config.requiresBody && bodyParam == nil {
      return []
    }

    // Step 8: Extract query parameters and headers
    let queryParams = ArgumentExtractors.extractQueryParameters(from: node, context: context)
    let headers = extractHeaders(
      node: node,
      usesOldSyntax: usesOldSyntax,
      newHeaders: newHeaders,
      context: context
    )

    // Step 9: Validate parameters exist in function signature
    let functionParams = MacroHelpers.extractParameterNames(from: function)
    try MacroHelpers.validatePathParameters(
      path: path,
      functionParameters: functionParams,
      context: context
    )
    if !queryParams.isEmpty {
      try MacroHelpers.validateQueryParameters(
        queryParams,
        functionParameters: functionParams,
        context: context
      )
    }

    // Step 10: Extract return type and generate implementation
    guard
      let returnType = extractAndNormalizeReturnType(
        function: function,
        context: context
      )
    else {
      return []
    }

    return [
      generateImplementation(
        function: function,
        path: path,
        bodyParameter: bodyParam,
        queryParameters: queryParams,
        headers: headers,
        returnType: returnType
      )
    ]
  }

  // MARK: - Private Helpers

  /// Extracts body parameter based on syntax style and config.requiresBody.
  private static func extractBodyIfRequired(
    function: FunctionDeclSyntax,
    node: AttributeSyntax,
    usesOldSyntax: Bool,
    newBodyParam: String?,
    context: some MacroExpansionContext
  ) throws -> String? {
    // Use new syntax if available
    if let bodyParam = newBodyParam {
      return bodyParam
    }

    // Use old syntax if present
    if usesOldSyntax {
      return ArgumentExtractors.extractBodyParameter(from: node, context: context)
    }

    // If body required but not found, emit error
    if config.requiresBody {
      MacroHelpers.emitError(
        "@\(config.method) requires a body parameter. Use @Body(\"paramName\") macro.",
        node: node,
        context: context
      )
      return nil
    }

    return nil
  }

  /// Extracts headers from either old or new syntax.
  private static func extractHeaders(
    node: AttributeSyntax,
    usesOldSyntax: Bool,
    newHeaders: [(name: String, value: String, isParameter: Bool)],
    context: some MacroExpansionContext
  ) -> [(name: String, value: String, isParameter: Bool)] {
    if !newHeaders.isEmpty {
      return newHeaders
    }
    if usesOldSyntax {
      let oldHeaders = ArgumentExtractors.extractHeaders(from: node, context: context)
      return oldHeaders.map { (name: $0.key, value: $0.value, isParameter: false) }
    }
    return []
  }

  /// Extracts and normalizes return type, handling Void for DELETE.
  private static func extractAndNormalizeReturnType(
    function: FunctionDeclSyntax,
    context: some MacroExpansionContext
  ) -> String? {
    guard let returnClause = function.signature.returnClause else {
      if config.allowsVoidReturn {
        return "Void"
      }
      MacroHelpers.emitError(
        "@\(config.method) requires a return type",
        node: Syntax(function),
        context: context
      )
      return nil
    }
    return returnClause.type.trimmedDescription
  }

  /// Generates the implementation using InterceptorCodeGenerator.
  private static func generateImplementation(
    function: FunctionDeclSyntax,
    path: String,
    bodyParameter: String?,
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

    // Generate additional request code
    var additionalCode = ""
    additionalCode += generateBodyCode(bodyParameter)
    additionalCode += generateHeaderCode(headers)
    additionalCode += generateQueryParameterCode(queryParameters)

    // Check if parent protocol has @Interceptors
    let hasInterceptors =
      findParentProtocol(function)
      .map { InterceptorsMacro.hasInterceptors(from: $0) } ?? false

    // Delegate to InterceptorCodeGenerator
    return InterceptorCodeGenerator.generateMethodImplementation(
      functionName: functionName,
      parameters: paramList,
      returnType: returnType,
      pathCode: pathCode,
      method: config.method,
      additionalRequestCode: additionalCode,
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

  private static func generateBodyCode(_ bodyParameter: String?) -> String {
    guard let body = bodyParameter else { return "" }
    return "\n  request.setBody(try JSONEncoder().encode(\(body)))"
      + "\n  request.addHeader(name: \"Content-Type\", value: \"application/json\")"
  }

  private static func generateHeaderCode(
    _ headers: [(name: String, value: String, isParameter: Bool)]
  ) -> String {
    guard !headers.isEmpty else { return "" }

    let headerLines = headers.map { header in
      if header.isParameter {
        // Parameter reference: interpolate the parameter value
        "\n  request.addHeader(name: \"\(header.name)\", value: \\(\(header.value)))"
      } else {
        // Literal value: use as-is
        "\n  request.addHeader(name: \"\(header.name)\", value: \"\(header.value)\")"
      }
    }.joined()

    return headerLines
  }

  private static func generateQueryParameterCode(_ queryParameters: [String]) -> String {
    guard !queryParameters.isEmpty else { return "" }

    let paramCode = queryParameters.map { param in
      "\n  request.addQueryParameter(name: \"\(param)\", value: \\(\(param)))"
    }.joined()

    return paramCode
  }
}
