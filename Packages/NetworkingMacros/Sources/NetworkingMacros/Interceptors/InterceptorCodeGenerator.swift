import SwiftSyntax
import SwiftSyntaxBuilder
import Foundation
import MacroTemplateKit

/// Code generation utilities for interceptor integration in HTTP method macros.
///
/// This generator creates the boilerplate code needed to integrate interceptors
/// into macro-generated API methods, including context creation, interceptor
/// chain execution, and short-circuit handling.
///
/// All code generation uses MacroTemplateKit's Template ADT with zero string interpolation.
enum InterceptorCodeGenerator {
  // MARK: - Context Creation

  /// Generates Statement for InterceptorContext creation.
  ///
  /// - Parameters:
  ///   - path: The path variable name (e.g., "path")
  ///   - method: The HTTP method string (e.g., "GET")
  /// - Returns: Statement for context initialization
  static func generateContextCreationStatement(path: String, method: String) -> Statement<Void> {
    .letBinding(
      name: "context",
      type: nil,
      initializer: .functionCall(
        function: "InterceptorContext",
        arguments: [
          (label: "path", value: .variable(path, payload: ())),
          (label: "method", value: .propertyAccess(
            base: .literal(.nil),
            property: method
          )),
          (label: "attemptCount", value: .literal(.integer(0)))
        ]
      )
    )
  }

  /// Generates code string for InterceptorContext creation (backward compatibility).
  static func generateContextCreation(path: String, method: String) -> String {
    let statement = generateContextCreationStatement(path: path, method: method)
    let codeBlock = Renderer.render(statement)
    return codeBlock.description.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  // MARK: - Request Interceptor Hook

  /// Generates Statements for request interceptor execution and short-circuit handling.
  static func generateRequestInterceptorHookStatements(
    requestVar: String = "request",
    returnType: String
  ) -> [Statement<Void>] {
    [
      buildRequestResultBinding(requestVar: requestVar),
      buildRequestGuard(returnType: returnType)
    ]
  }

  /// Generates code string for request interceptor hook (backward compatibility).
  static func generateRequestInterceptorHook(
    requestVar: String = "request",
    returnType: String
  ) -> String {
    let statements = generateRequestInterceptorHookStatements(
      requestVar: requestVar,
      returnType: returnType
    )
    let codeBlocks = statements.map { Renderer.render($0).description }
    return codeBlocks.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
  }

  // MARK: - Response Interceptor Hook

  /// Generates Statements for response interceptor execution and retry handling.
  static func generateResponseInterceptorHookStatements(
    responseVar: String = "response"
  ) -> [Statement<Void>] {
    [
      buildResponseResultBinding(responseVar: responseVar),
      buildResponseGuard()
    ]
  }

  /// Generates code string for response interceptor hook (backward compatibility).
  static func generateResponseInterceptorHook(responseVar: String = "response") -> String {
    let statements = generateResponseInterceptorHookStatements(responseVar: responseVar)
    let codeBlocks = statements.map { Renderer.render($0).description }
    return codeBlocks.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
  }

  // MARK: - Complete Method Generation

  /// Generates complete method implementation with interceptor hooks.
  static func generateMethodImplementation(
    config: InterceptorMethodBuilder.MethodConfig,
    hasInterceptors: Bool
  ) -> DeclSyntax {
    let body = hasInterceptors ?
      InterceptorMethodBuilder.buildMethodBodyWithInterceptors(config: config) :
      InterceptorMethodBuilder.buildMethodBodyWithoutInterceptors(config: config)

    return InterceptorMethodBuilder.buildFunctionDeclaration(config: config, body: body)
  }

  /// Legacy API: Generates complete method implementation (backward compatibility).
  static func generateMethodImplementation(
    functionName: String,
    parameters: String,
    returnType: String,
    pathCode: String,
    method: String,
    additionalRequestCode: String,
    hasInterceptors: Bool
  ) -> DeclSyntax {
    let config = InterceptorMethodBuilder.MethodConfig(
      functionName: functionName,
      parameters: parameters,
      returnType: returnType,
      pathCode: pathCode,
      method: method,
      additionalRequestCode: additionalRequestCode
    )

    return generateMethodImplementation(config: config, hasInterceptors: hasInterceptors)
  }

  // MARK: - Private Statement Builders

  private static func buildRequestResultBinding(requestVar: String) -> Statement<Void> {
    .letBinding(
      name: "requestResult",
      type: nil,
      initializer: .functionCall(
        function: "interceptors.executeRequestInterceptors",
        arguments: [
          (label: "request", value: .functionCall(
            function: "&",
            arguments: [(label: nil, value: .variable(requestVar, payload: ()))]
          )),
          (label: "context", value: .variable("context", payload: ()))
        ]
      )
    )
  }

  private static func buildRequestGuard(returnType: String) -> Statement<Void> {
    .guardStatement(
      condition: .binaryOperation(
        left: .propertyAccess(base: .literal(.nil), property: "proceed"),
        operator: "~=",
        right: .variable("requestResult", payload: ())
      ),
      elseBody: [
        buildShortCircuitIf(returnType: returnType),
        buildInvalidResultThrow(reason: "Unexpected interceptor result")
      ]
    )
  }

  private static func buildShortCircuitIf(returnType: String) -> Statement<Void> {
    .ifStatement(
      condition: .binaryOperation(
        left: .functionCall(
          function: ".shortCircuit",
          arguments: [(label: nil, value: .variable("cachedResponse", payload: ()))]
        ),
        operator: "~=",
        right: .variable("requestResult", payload: ())
      ),
      thenBody: [
        .returnStatement(
          .functionCall(
            function: "JSONDecoder().decode",
            arguments: [
              (label: nil, value: .propertyAccess(
                base: .variable(returnType, payload: ()),
                property: "self"
              )),
              (label: "from", value: .propertyAccess(
                base: .variable("cachedResponse", payload: ()),
                property: "data"
              ))
            ]
          )
        )
      ],
      elseBody: nil
    )
  }

  private static func buildInvalidResultThrow(reason: String) -> Statement<Void> {
    .throwStatement(
      .functionCall(
        function: "InterceptorError.invalidResult",
        arguments: [
          (label: "reason", value: .literal(.string(reason)))
        ]
      )
    )
  }

  private static func buildResponseResultBinding(responseVar: String) -> Statement<Void> {
    .letBinding(
      name: "responseResult",
      type: nil,
      initializer: .functionCall(
        function: "interceptors.executeResponseInterceptors",
        arguments: [
          (label: "response", value: .variable(responseVar, payload: ())),
          (label: "context", value: .variable("context", payload: ()))
        ]
      )
    )
  }

  private static func buildResponseGuard() -> Statement<Void> {
    .guardStatement(
      condition: .binaryOperation(
        left: .propertyAccess(base: .literal(.nil), property: "proceed"),
        operator: "~=",
        right: .variable("responseResult", payload: ())
      ),
      elseBody: [
        buildInvalidResultThrow(reason: "Retry not yet implemented")
      ]
    )
  }
}
