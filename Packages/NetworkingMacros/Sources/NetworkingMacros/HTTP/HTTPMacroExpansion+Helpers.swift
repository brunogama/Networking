import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxMacros

struct HTTPMacroEndpointInput {
  let function: FunctionDeclSyntax
  let node: AttributeSyntax
  let path: String
  let usesOldSyntax: Bool
  let bodyParameter: String?
  let headers: [ParsedHeader]
  let accessLevel: String?
}

private struct HTTPMacroEndpointComponents {
  let bodyParameter: String?
  let queryParameters: [String]
  let headers: [ParsedHeader]
  let returnType: String
}

extension HTTPMacroExpansion {
  static func expandWithHelpers(
    _ input: HTTPMacroEndpointInput,
    context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    let bodyParameter = try extractBodyIfRequired(input, context: context)
    if config.requiresBody && bodyParameter == nil {
      return []
    }

    let queryParameters = ArgumentExtractors.extractQueryParameters(
      from: input.node,
      context: context
    )
    let headers = extractHeaders(input, context: context)
    try validateParameters(input, queryParameters: queryParameters, context: context)

    guard let returnType = extractReturnType(input.function, context: context) else {
      return []
    }
    let components = HTTPMacroEndpointComponents(
      bodyParameter: bodyParameter,
      queryParameters: queryParameters,
      headers: headers,
      returnType: returnType
    )
    return [generateImplementation(input, components: components)]
  }

  private static func extractBodyIfRequired(
    _ input: HTTPMacroEndpointInput,
    context: some MacroExpansionContext
  ) throws -> String? {
    if let bodyParameter = input.bodyParameter {
      return bodyParameter
    }
    if input.usesOldSyntax {
      return ArgumentExtractors.extractBodyParameter(from: input.node, context: context)
    }
    if config.requiresBody {
      MacroHelpers.emitError(
        "@\(config.method) requires a body parameter. Use @Body(\"paramName\") macro.",
        node: input.node,
        context: context
      )
    }
    return nil
  }

  private static func extractHeaders(
    _ input: HTTPMacroEndpointInput,
    context: some MacroExpansionContext
  ) -> [ParsedHeader] {
    if !input.headers.isEmpty {
      return input.headers
    }
    if input.usesOldSyntax {
      return ArgumentExtractors.extractHeaders(from: input.node, context: context)
        .map { ParsedHeader(name: $0.key, valueSource: .literal($0.value)) }
    }
    return []
  }

  private static func validateParameters(
    _ input: HTTPMacroEndpointInput,
    queryParameters: [String],
    context: some MacroExpansionContext
  ) throws {
    let functionParameters = MacroHelpers.extractParameterNames(from: input.function)
    try MacroHelpers.validatePathParameters(
      path: input.path,
      functionParameters: functionParameters,
      context: context
    )
    if !queryParameters.isEmpty {
      try MacroHelpers.validateQueryParameters(
        queryParameters,
        functionParameters: functionParameters,
        context: context
      )
    }
  }

  private static func extractReturnType(
    _ function: FunctionDeclSyntax,
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

  private static func generateImplementation(
    _ input: HTTPMacroEndpointInput,
    components: HTTPMacroEndpointComponents
  ) -> DeclSyntax {
    let pathCode = PathTemplateParser(template: input.path).generatePathSubstitution()
    let hasInterceptors =
      findParentProtocol(input.function)
      .map { InterceptorsMacro.hasInterceptors(from: $0) } ?? false
    return HTTPMethodImplementationBuilder.generate(
      HTTPMethodImplementationBuilder.Input(
        function: input.function,
        returnType: components.returnType,
        pathCode: pathCode,
        method: config.method,
        bodyParameter: components.bodyParameter,
        queryParameters: components.queryParameters,
        headers: components.headers,
        accessLevel: input.accessLevel,
        hasInterceptors: hasInterceptors
      )
    )
  }

  private static func findParentProtocol(_ function: FunctionDeclSyntax) -> ProtocolDeclSyntax? {
    var currentNode: Syntax? = Syntax(function)
    while let node = currentNode {
      if let protocolDeclaration = node.as(ProtocolDeclSyntax.self) {
        return protocolDeclaration
      }
      currentNode = node.parent
    }
    return nil
  }
}
