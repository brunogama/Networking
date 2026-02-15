import SwiftSyntax
import SwiftSyntaxBuilder
import Foundation

/// Code generation utilities for interceptor integration in HTTP method macros.
///
/// This generator creates the boilerplate code needed to integrate interceptors
/// into macro-generated API methods, including context creation, interceptor
/// chain execution, and short-circuit handling.
enum InterceptorCodeGenerator {
  // MARK: - Context Creation

  /// Generates code to create an InterceptorContext.
  ///
  /// - Parameters:
  ///   - path: The path variable name (e.g., "path")
  ///   - method: The HTTP method string (e.g., ".GET")
  /// - Returns: Swift code string for context initialization
  ///
  /// Example output:
  /// ```swift
  /// let context = InterceptorContext(path: path, method: .GET, attemptCount: 0)
  /// ```
  static func generateContextCreation(path: String, method: String) -> String {
    """
    let context = InterceptorContext(path: \(path), method: \(method), attemptCount: 0)
    """
  }

  // MARK: - Request Interceptor Hook

  /// Generates code to execute request interceptors and handle short-circuit.
  ///
  /// - Parameter requestVar: The request variable name (default: "request")
  /// - Returns: Swift code string for request interceptor execution
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
  static func generateRequestInterceptorHook(
    requestVar: String = "request",
    returnType: String
  ) -> String {
    """
    let requestResult = try await interceptors.executeRequestInterceptors(
      request: &\(requestVar), context: context
    )
    guard case .proceed = requestResult else {
      if case .shortCircuit(let cachedResponse) = requestResult {
        return try JSONDecoder().decode(\(returnType).self, from: cachedResponse.data)
      }
      throw InterceptorError.invalidResult(reason: "Unexpected interceptor result")
    }
    """
  }

  // MARK: - Response Interceptor Hook

  /// Generates code to execute response interceptors and handle retry.
  ///
  /// - Parameter responseVar: The response variable name (default: "response")
  /// - Returns: Swift code string for response interceptor execution
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
  static func generateResponseInterceptorHook(responseVar: String = "response") -> String {
    """
    let responseResult = try await interceptors.executeResponseInterceptors(
      response: \(responseVar), context: context
    )
    guard case .proceed = responseResult else {
      throw InterceptorError.invalidResult(reason: "Retry not yet implemented")
    }
    """
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
  /// - Returns: Complete function implementation as string
  static func generateMethodImplementation(
    functionName: String,
    parameters: String,
    returnType: String,
    pathCode: String,
    method: String,
    additionalRequestCode: String,
    hasInterceptors: Bool
  ) -> String {
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
  ) -> String {
    let contextCreation = generateContextCreation(path: "path", method: ".\(method)")
    let requestHook = generateRequestInterceptorHook(returnType: returnType)
    let responseHook = generateResponseInterceptorHook()

    return """
      func \(functionName)(\(parameters)) async throws -> \(returnType) {
        let path = \(pathCode)
        var request = HTTPRequest(method: .\(method), path: path, baseURL: baseURL)\(additionalRequestCode)
        \(contextCreation)

        \(requestHook)

        let response = try await client.execute(request)

        \(responseHook)

        return try JSONDecoder().decode(\(returnType).self, from: response.data)
      }
      """
  }

  /// Generates method implementation without interceptors (Phase 5.2 compatibility).
  private static func generateMethodWithoutInterceptors(
    functionName: String,
    parameters: String,
    returnType: String,
    pathCode: String,
    method: String,
    additionalRequestCode: String
  ) -> String {
    """
    func \(functionName)(\(parameters)) async throws -> \(returnType) {
      let path = \(pathCode)
      var request = HTTPRequest(method: .\(method), path: path, baseURL: baseURL)\(additionalRequestCode)
      let response = try await client.execute(request)
      return try JSONDecoder().decode(\(returnType).self, from: response.data)
    }
    """
  }
}
