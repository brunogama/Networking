import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation

/// Macro implementation for @Interceptors.
///
/// Generates interceptor chain initialization in the API implementation struct.
/// Interceptors execute before/after HTTP requests to handle cross-cutting concerns
/// like authentication, logging, retry logic, and caching.
///
/// Example:
/// ```swift
/// @API(baseURL: "https://api.example.com")
/// @Interceptors([
///   AuthenticationInterceptor(tokenProvider: .shared),
///   LoggingInterceptor(),
///   RetryInterceptor(maxAttempts: 3)
/// ])
/// protocol UserAPI {
///   @GET("/users")
///   func getUsers() async throws -> [User]
/// }
/// ```
///
/// The @Interceptors macro works in conjunction with @API to inject interceptor
/// chain initialization into the generated implementation struct.
public struct InterceptorsMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Validate this is applied to a protocol
    guard declaration.is(ProtocolDeclSyntax.self) else {
      MacroHelpers.emitError(
        "@Interceptors can only be applied to protocols",
        node: node,
        context: context
      )
      return []
    }

    // Extract interceptor expressions from macro arguments
    guard let interceptors = extractInterceptors(from: node, context: context) else {
      return []
    }

    // Validate interceptors array is not empty
    guard !interceptors.isEmpty else {
      MacroHelpers.emitError(
        "@Interceptors requires a non-empty interceptor array",
        node: node,
        context: context
      )
      return []
    }

    // Note: The actual interceptor chain initialization is handled by APIMacro
    // This macro just validates the syntax and makes the information available
    // to other macros via the attribute syntax

    return []
  }

  // MARK: - Interceptor Extraction

  /// Extracts interceptor expressions from macro arguments.
  private static func extractInterceptors(
    from node: AttributeSyntax,
    context: some MacroExpansionContext
  ) -> [ExprSyntax]? {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
      let firstArg = arguments.first,
      let arrayExpr = firstArg.expression.as(ArrayExprSyntax.self)
    else {
      MacroHelpers.emitError(
        "@Interceptors requires an array argument",
        node: node,
        context: context
      )
      return nil
    }

    var interceptors: [ExprSyntax] = []

    for element in arrayExpr.elements {
      interceptors.append(element.expression)
    }

    return interceptors
  }

  // MARK: - Helper Methods

  /// Extracts interceptor expressions from protocol attributes.
  ///
  /// This is used by APIMacro and HTTP method macros to find the interceptor
  /// configuration on the protocol.
  ///
  /// - Parameter declaration: The protocol declaration to search
  /// - Returns: Array of interceptor expressions, or empty array if no @Interceptors attribute found
  public static func extractInterceptorExpressions(
    from declaration: some WithAttributesSyntax
  ) -> [ExprSyntax] {
    for attribute in declaration.attributes {
      guard case .attribute(let attr) = attribute else { continue }
      let attrName = attr.attributeName.description
        .trimmingCharacters(in: CharacterSet.whitespaces)

      if attrName == "Interceptors" {
        // Extract interceptors from this attribute
        if let arguments = attr.arguments?.as(LabeledExprListSyntax.self),
          let firstArg = arguments.first,
          let arrayExpr = firstArg.expression.as(ArrayExprSyntax.self)
        {
          var interceptors: [ExprSyntax] = []

          for element in arrayExpr.elements {
            interceptors.append(element.expression)
          }

          return interceptors
        }
      }
    }

    return []
  }

  /// Checks if the protocol has @Interceptors attribute.
  ///
  /// This is a convenience method for macros that need to check if interceptors
  /// are present without extracting their expressions.
  ///
  /// - Parameter declaration: The protocol declaration to check
  /// - Returns: True if @Interceptors attribute is present, false otherwise
  public static func hasInterceptors(from declaration: some WithAttributesSyntax) -> Bool {
    for attribute in declaration.attributes {
      guard case .attribute(let attr) = attribute else { continue }
      let attrName = attr.attributeName.description
        .trimmingCharacters(in: CharacterSet.whitespaces)

      if attrName == "Interceptors" {
        return true
      }
    }

    return false
  }
}
