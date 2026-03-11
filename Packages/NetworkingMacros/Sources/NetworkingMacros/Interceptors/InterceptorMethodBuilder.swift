import SwiftSyntax
import MacroTemplateKit

/// Method implementation builder for interceptor-integrated functions.
///
/// Extracts method body construction logic to maintain code organization
/// and complexity budgets.
enum InterceptorMethodBuilder {
  /// Configuration for method generation.
  struct MethodConfig {
    let functionName: String
    let parameters: String
    let returnType: String
    let pathCode: String
    let method: String
    let additionalRequestCode: String
  }

  // MARK: - Method with Interceptors

  /// Builds complete method body with interceptor hooks.
  static func buildMethodBodyWithInterceptors(
    config: MethodConfig
  ) -> [Statement<Void>] {
    let contextCreation = InterceptorCodeGenerator.generateContextCreationStatement(
      path: "path",
      method: config.method
    )
    let requestHook = InterceptorCodeGenerator.generateRequestInterceptorHookStatements(
      returnType: config.returnType
    )
    let responseHook = InterceptorCodeGenerator.generateResponseInterceptorHookStatements()

    var statements: [Statement<Void>] = []

    statements.append(InterceptorStatementBuilder.buildPathBinding(pathCode: config.pathCode))
    statements.append(InterceptorStatementBuilder.buildRequestInitialization(method: config.method))

    if let additionalCode = InterceptorStatementBuilder.buildAdditionalRequestCode(
      config.additionalRequestCode
    ) {
      statements.append(additionalCode)
    }

    statements.append(contextCreation)
    statements.append(contentsOf: requestHook)
    statements.append(InterceptorStatementBuilder.buildExecuteCall())
    statements.append(contentsOf: responseHook)
    statements.append(InterceptorStatementBuilder.buildDecodeReturn(returnType: config.returnType))

    return statements
  }

  // MARK: - Method without Interceptors

  /// Builds complete method body without interceptors.
  static func buildMethodBodyWithoutInterceptors(
    config: MethodConfig
  ) -> [Statement<Void>] {
    var statements: [Statement<Void>] = []

    statements.append(InterceptorStatementBuilder.buildPathBinding(pathCode: config.pathCode))
    statements.append(InterceptorStatementBuilder.buildRequestInitialization(method: config.method))

    if let additionalCode = InterceptorStatementBuilder.buildAdditionalRequestCode(
      config.additionalRequestCode
    ) {
      statements.append(additionalCode)
    }

    statements.append(InterceptorStatementBuilder.buildExecuteCall())
    statements.append(InterceptorStatementBuilder.buildDecodeReturn(returnType: config.returnType))

    return statements
  }

  // MARK: - Declaration Generation

  /// Builds function declaration from config and body.
  static func buildFunctionDeclaration(
    config: MethodConfig,
    body: [Statement<Void>]
  ) -> DeclSyntax {
    let signature = FunctionSignature<Void>(
      name: config.functionName,
      parameters: ParameterParser.parse(config.parameters),
      isAsync: true,
      canThrow: true,
      returnType: config.returnType,
      body: body
    )

    return Renderer.render(.function(signature))
  }
}
