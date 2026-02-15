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
  ///
  /// Example output:
  /// ```swift
  /// let context = InterceptorContext(path: path, method: .GET, attemptCount: 0)
  /// ```
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
  ///
  /// - Parameters:
  ///   - path: The path variable name (e.g., "path")
  ///   - method: The HTTP method string (e.g., ".GET")
  /// - Returns: Swift code string for context initialization
  static func generateContextCreation(path: String, method: String) -> String {
    let statement = generateContextCreationStatement(path: path, method: method)
    let codeBlock = Renderer.render(statement)
    return codeBlock.description.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  // MARK: - Request Interceptor Hook

  /// Generates Statements for request interceptor execution and short-circuit handling.
  ///
  /// - Parameters:
  ///   - requestVar: The request variable name (default: "request")
  ///   - returnType: Return type for short-circuit decoding
  /// - Returns: Statements for request interceptor execution
  ///
  /// Example output:
  /// ```swift
  /// let requestResult = try await interceptors.executeRequestInterceptors(
  ///   request: &request, context: context
  /// )
  /// guard case .proceed = requestResult else {
  ///   if case .shortCircuit(let cachedResponse) = requestResult {
  ///     return try JSONDecoder().decode(ReturnType.self, from: cachedResponse.data)
  ///   }
  ///   throw InterceptorError.invalidResult(reason: "Unexpected interceptor result")
  /// }
  /// ```
  static func generateRequestInterceptorHookStatements(
    requestVar: String = "request",
    returnType: String
  ) -> [Statement<Void>] {
    [
      // let requestResult = try await interceptors.executeRequestInterceptors(request: &request, context: context)
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
      ),

      // guard case .proceed = requestResult else { ... }
      .guardStatement(
        condition: .binaryOperation(
          left: .propertyAccess(base: .literal(.nil), property: "proceed"),
          operator: "~=",
          right: .variable("requestResult", payload: ())
        ),
        elseBody: [
          // if case .shortCircuit(let cachedResponse) = requestResult { ... }
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
              // return try JSONDecoder().decode(ReturnType.self, from: cachedResponse.data)
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
          ),

          // throw InterceptorError.invalidResult(reason: "Unexpected interceptor result")
          .throwStatement(
            .functionCall(
              function: "InterceptorError.invalidResult",
              arguments: [
                (label: "reason", value: .literal(.string("Unexpected interceptor result")))
              ]
            )
          )
        ]
      )
    ]
  }

  /// Generates code string for request interceptor hook (backward compatibility).
  ///
  /// - Parameters:
  ///   - requestVar: The request variable name (default: "request")
  ///   - returnType: Return type for short-circuit decoding
  /// - Returns: Swift code string for request interceptor execution
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
  ///
  /// - Parameter responseVar: The response variable name (default: "response")
  /// - Returns: Statements for response interceptor execution
  ///
  /// Example output:
  /// ```swift
  /// let responseResult = try await interceptors.executeResponseInterceptors(
  ///   response: response, context: context
  /// )
  /// guard case .proceed = responseResult else {
  ///   throw InterceptorError.invalidResult(reason: "Retry not yet implemented")
  /// }
  /// ```
  static func generateResponseInterceptorHookStatements(responseVar: String = "response") -> [Statement<Void>] {
    [
      // let responseResult = try await interceptors.executeResponseInterceptors(response: response, context: context)
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
      ),

      // guard case .proceed = responseResult else { ... }
      .guardStatement(
        condition: .binaryOperation(
          left: .propertyAccess(base: .literal(.nil), property: "proceed"),
          operator: "~=",
          right: .variable("responseResult", payload: ())
        ),
        elseBody: [
          // throw InterceptorError.invalidResult(reason: "Retry not yet implemented")
          .throwStatement(
            .functionCall(
              function: "InterceptorError.invalidResult",
              arguments: [
                (label: "reason", value: .literal(.string("Retry not yet implemented")))
              ]
            )
          )
        ]
      )
    ]
  }

  /// Generates code string for response interceptor hook (backward compatibility).
  ///
  /// - Parameter responseVar: The response variable name (default: "response")
  /// - Returns: Swift code string for response interceptor execution
  static func generateResponseInterceptorHook(responseVar: String = "response") -> String {
    let statements = generateResponseInterceptorHookStatements(responseVar: responseVar)
    let codeBlocks = statements.map { Renderer.render($0).description }
    return codeBlocks.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
  }

  // MARK: - Complete Method Generation

  /// Generates complete method implementation with interceptor hooks.
  ///
  /// - Parameters:
  ///   - functionName: Name of the function
  ///   - parameters: Function parameter list
  ///   - returnType: Return type of the function
  ///   - pathCode: Code for path construction
  ///   - method: HTTP method (e.g., "GET", "POST")
  ///   - additionalRequestCode: Additional code to add to request (headers, query params, body)
  ///   - hasInterceptors: Whether interceptors are enabled
  /// - Returns: Complete function implementation as DeclSyntax
  static func generateMethodImplementation(
    functionName: String,
    parameters: String,
    returnType: String,
    pathCode: String,
    method: String,
    additionalRequestCode: String,
    hasInterceptors: Bool
  ) -> DeclSyntax {
    if hasInterceptors {
      return generateMethodWithInterceptors(
        functionName: functionName,
        parameters: parameters,
        returnType: returnType,
        pathCode: pathCode,
        method: method,
        additionalRequestCode: additionalRequestCode
      )
    } else {
      return generateMethodWithoutInterceptors(
        functionName: functionName,
        parameters: parameters,
        returnType: returnType,
        pathCode: pathCode,
        method: method,
        additionalRequestCode: additionalRequestCode
      )
    }
  }

  // MARK: - Private Helpers

  /// Generates method implementation with interceptor hooks (Phase 6).
  private static func generateMethodWithInterceptors(
    functionName: String,
    parameters: String,
    returnType: String,
    pathCode: String,
    method: String,
    additionalRequestCode: String
  ) -> DeclSyntax {
    let contextCreation = generateContextCreationStatement(path: "path", method: method)
    let requestHook = generateRequestInterceptorHookStatements(returnType: returnType)
    let responseHook = generateResponseInterceptorHookStatements()

    var bodyStatements: [Statement<Void>] = []

    // let path = pathCode
    bodyStatements.append(
      .letBinding(
        name: "path",
        type: nil,
        initializer: .variable(pathCode, payload: ())
      )
    )

    // var request = HTTPRequest(method: .METHOD, path: path, baseURL: baseURL)
    bodyStatements.append(
      .varBinding(
        name: "request",
        type: nil,
        initializer: .functionCall(
          function: "HTTPRequest",
          arguments: [
            (label: "method", value: .propertyAccess(
              base: .literal(.nil),
              property: method
            )),
            (label: "path", value: .variable("path", payload: ())),
            (label: "baseURL", value: .variable("baseURL", payload: ()))
          ]
        )
      )
    )

    // Additional request code (headers, body, etc.) - use string literal for now
    if !additionalRequestCode.isEmpty {
      bodyStatements.append(
        .expression(.variable(additionalRequestCode, payload: ()))
      )
    }

    // Context creation
    bodyStatements.append(contextCreation)

    // Request interceptor hook
    bodyStatements.append(contentsOf: requestHook)

    // let response = try await client.execute(request)
    bodyStatements.append(
      .letBinding(
        name: "response",
        type: nil,
        initializer: .functionCall(
          function: "client.execute",
          arguments: [
            (label: nil, value: .variable("request", payload: ()))
          ]
        )
      )
    )

    // Response interceptor hook
    bodyStatements.append(contentsOf: responseHook)

    // return try JSONDecoder().decode(ReturnType.self, from: response.data)
    bodyStatements.append(
      .returnStatement(
        .functionCall(
          function: "JSONDecoder().decode",
          arguments: [
            (label: nil, value: .propertyAccess(
              base: .variable(returnType, payload: ()),
              property: "self"
            )),
            (label: "from", value: .propertyAccess(
              base: .variable("response", payload: ()),
              property: "data"
            ))
          ]
        )
      )
    )

    // Build function signature
    let signature = FunctionSignature<Void>(
      name: functionName,
      parameters: parseParameters(parameters),
      isAsync: true,
      canThrow: true,
      returnType: returnType,
      body: bodyStatements
    )

    // Render to DeclSyntax
    return Renderer.render(.function(signature))
  }

  /// Generates method implementation without interceptors (Phase 5.2 compatibility).
  private static func generateMethodWithoutInterceptors(
    functionName: String,
    parameters: String,
    returnType: String,
    pathCode: String,
    method: String,
    additionalRequestCode: String
  ) -> DeclSyntax {
    var bodyStatements: [Statement<Void>] = []

    // let path = pathCode
    bodyStatements.append(
      .letBinding(
        name: "path",
        type: nil,
        initializer: .variable(pathCode, payload: ())
      )
    )

    // var request = HTTPRequest(method: .METHOD, path: path, baseURL: baseURL)
    bodyStatements.append(
      .varBinding(
        name: "request",
        type: nil,
        initializer: .functionCall(
          function: "HTTPRequest",
          arguments: [
            (label: "method", value: .propertyAccess(
              base: .literal(.nil),
              property: method
            )),
            (label: "path", value: .variable("path", payload: ())),
            (label: "baseURL", value: .variable("baseURL", payload: ()))
          ]
        )
      )
    )

    // Additional request code (headers, body, etc.)
    if !additionalRequestCode.isEmpty {
      bodyStatements.append(
        .expression(.variable(additionalRequestCode, payload: ()))
      )
    }

    // let response = try await client.execute(request)
    bodyStatements.append(
      .letBinding(
        name: "response",
        type: nil,
        initializer: .functionCall(
          function: "client.execute",
          arguments: [
            (label: nil, value: .variable("request", payload: ()))
          ]
        )
      )
    )

    // return try JSONDecoder().decode(ReturnType.self, from: response.data)
    bodyStatements.append(
      .returnStatement(
        .functionCall(
          function: "JSONDecoder().decode",
          arguments: [
            (label: nil, value: .propertyAccess(
              base: .variable(returnType, payload: ()),
              property: "self"
            )),
            (label: "from", value: .propertyAccess(
              base: .variable("response", payload: ()),
              property: "data"
            ))
          ]
        )
      )
    )

    // Build function signature
    let signature = FunctionSignature<Void>(
      name: functionName,
      parameters: parseParameters(parameters),
      isAsync: true,
      canThrow: true,
      returnType: returnType,
      body: bodyStatements
    )

    // Render to DeclSyntax
    return Renderer.render(.function(signature))
  }

  /// Parses parameter string into ParameterSignature array.
  ///
  /// Simple parser for common parameter patterns. For complex parameters,
  /// this may need enhancement.
  private static func parseParameters(_ parametersString: String) -> [ParameterSignature] {
    guard !parametersString.isEmpty else { return [] }

    return parametersString.split(separator: ",").map { paramStr in
      let trimmed = paramStr.trimmingCharacters(in: .whitespaces)
      let components = trimmed.split(separator: ":")

      guard components.count >= 2 else {
        // Fallback for malformed parameters
        return ParameterSignature(name: String(trimmed), type: "Any")
      }

      let nameComponent = components[0].trimmingCharacters(in: .whitespaces)
      let typeComponent = components[1].trimmingCharacters(in: .whitespaces)

      // Check if there's a label (space-separated)
      let nameParts = nameComponent.split(separator: " ")
      if nameParts.count == 2 {
        let label = String(nameParts[0])
        let name = String(nameParts[1])
        return ParameterSignature(label: label, name: name, type: typeComponent)
      } else {
        return ParameterSignature(name: nameComponent, type: typeComponent)
      }
    }
  }
}
