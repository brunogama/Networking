import MacroTemplateKit
import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Macro implementation for @Timeout.
///
/// Configures default timeout for all HTTP requests in an API client.
///
/// Example:
/// ```swift
/// @API(baseURL: "https://api.example.com")
/// @Timeout(30.0)
/// protocol UserAPI {
///   @GET("/users")
///   func getUsers() async throws -> [User]
/// }
/// ```
///
/// The @Timeout macro works in conjunction with @API to inject timeout configuration
/// into the generated implementation struct.
public struct TimeoutMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Validate this is applied to a protocol
    guard declaration.is(ProtocolDeclSyntax.self) else {
      MacroHelpers.emitError(
        "@Timeout can only be applied to protocols",
        node: node,
        context: context
      )
      return []
    }

    // Extract timeout value from macro arguments
    guard let timeout = extractTimeout(from: node, context: context) else {
      return []
    }

    // Validate timeout is positive
    guard timeout > 0 else {
      MacroHelpers.emitError(
        "@Timeout requires a positive timeout value",
        node: node,
        context: context
      )
      return []
    }

    // Note: The actual timeout application is handled by APIMacro and HTTP method macros
    // This macro just validates the syntax and makes the information available
    // to other macros via the attribute syntax
    // Template algebra infrastructure available via MacroTemplateKit for future enhancement

    return []
  }

  // MARK: - Timeout Extraction

  /// Extracts timeout value from macro arguments.
  private static func extractTimeout(
    from node: AttributeSyntax,
    context: some MacroExpansionContext
  ) -> Double? {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
      let firstArg = arguments.first
    else {
      MacroHelpers.emitError(
        "@Timeout requires a timeout value in seconds",
        node: node,
        context: context
      )
      return nil
    }

    // Try to extract numeric literal (Int or Float)
    if let intLiteral = firstArg.expression.as(IntegerLiteralExprSyntax.self) {
      if let value = Double(intLiteral.literal.text) {
        return value
      }
    } else if let floatLiteral = firstArg.expression.as(FloatLiteralExprSyntax.self) {
      if let value = Double(floatLiteral.literal.text) {
        return value
      }
    }

    MacroHelpers.emitError(
      "@Timeout requires a numeric literal (e.g., 30.0 or 30)",
      node: node,
      context: context
    )
    return nil
  }

  // MARK: - Helper Methods

  /// Extracts default timeout from protocol attributes.
  ///
  /// This is used by APIMacro and HTTP method macros to find the default timeout
  /// configuration on the protocol.
  public static func extractDefaultTimeout(
    from declaration: some WithAttributesSyntax
  ) -> Double? {
    for attribute in declaration.attributes {
      guard case .attribute(let attr) = attribute else { continue }
      let attrName = attr.attributeName.description
        .trimmingCharacters(in: CharacterSet.whitespaces)

      if attrName == "Timeout" {
        // Extract timeout from this attribute
        if let arguments = attr.arguments?.as(LabeledExprListSyntax.self),
          let firstArg = arguments.first {
          // Try to extract numeric literal
          if let intLiteral = firstArg.expression.as(IntegerLiteralExprSyntax.self) {
            return Double(intLiteral.literal.text)
          } else if let floatLiteral = firstArg.expression.as(FloatLiteralExprSyntax.self) {
            return Double(floatLiteral.literal.text)
          }
        }
      }
    }

    return nil
  }
}
