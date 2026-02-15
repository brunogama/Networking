import MacroTemplateKit
import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Macro implementation for @DefaultHeaders.
///
/// Generates stored properties in the API implementation struct to hold default headers
/// that will be applied to all HTTP requests.
///
/// Example:
/// ```swift
/// @API(baseURL: "https://api.example.com")
/// @DefaultHeaders(["Accept": "application/json"])
/// protocol UserAPI {
///   @GET("/users")
///   func getUsers() async throws -> [User]
/// }
/// ```
///
/// The @DefaultHeaders macro works in conjunction with @API to inject header configuration
/// into the generated implementation struct.
public struct DefaultHeadersMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Validate this is applied to a protocol
    guard declaration.is(ProtocolDeclSyntax.self) else {
      MacroHelpers.emitError(
        "@DefaultHeaders can only be applied to protocols",
        node: node,
        context: context
      )
      return []
    }

    // Extract headers dictionary from macro arguments
    guard let headers = extractHeaders(from: node, context: context) else {
      return []
    }

    // Validate headers dictionary is not empty
    guard !headers.isEmpty else {
      MacroHelpers.emitError(
        "@DefaultHeaders requires a non-empty headers dictionary",
        node: node,
        context: context
      )
      return []
    }

    // Note: The actual header application is handled by APIMacro
    // This macro just validates the syntax and makes the information available
    // to other macros via the attribute syntax
    // Template algebra infrastructure available via MacroTemplateKit for future enhancement

    return []
  }

  // MARK: - Header Extraction

  /// Extracts headers dictionary from macro arguments.
  private static func extractHeaders(
    from node: AttributeSyntax,
    context: some MacroExpansionContext
  ) -> [String: String]? {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
      let firstArg = arguments.first,
      let dictExpr = firstArg.expression.as(DictionaryExprSyntax.self)
    else {
      MacroHelpers.emitError(
        "@DefaultHeaders requires a dictionary argument",
        node: node,
        context: context
      )
      return nil
    }

    var headers: [String: String] = [:]

    for element in dictExpr.content.as(DictionaryElementListSyntax.self) ?? [] {
      if let keyString = element.key.as(StringLiteralExprSyntax.self),
        let keySegment = keyString.segments.first?.as(StringSegmentSyntax.self),
        let valueString = element.value.as(StringLiteralExprSyntax.self),
        let valueSegment = valueString.segments.first?.as(StringSegmentSyntax.self) {
        headers[keySegment.content.text] = valueSegment.content.text
      }
    }

    return headers
  }

  // MARK: - Helper Methods

  /// Extracts default headers from protocol attributes.
  ///
  /// This is used by APIMacro and HTTP method macros to find the default headers
  /// configuration on the protocol.
  public static func extractDefaultHeaders(
    from declaration: some WithAttributesSyntax
  ) -> [String: String] {
    for attribute in declaration.attributes {
      guard case .attribute(let attr) = attribute else { continue }
      let attrName = attr.attributeName.description
        .trimmingCharacters(in: CharacterSet.whitespaces)

      if attrName == "DefaultHeaders" {
        // Extract headers from this attribute
        if let arguments = attr.arguments?.as(LabeledExprListSyntax.self),
          let firstArg = arguments.first,
          let dictExpr = firstArg.expression.as(DictionaryExprSyntax.self) {
          var headers: [String: String] = [:]

          for element in dictExpr.content.as(DictionaryElementListSyntax.self) ?? [] {
            if let keyString = element.key.as(StringLiteralExprSyntax.self),
              let keySegment = keyString.segments.first?.as(StringSegmentSyntax.self),
              let valueString = element.value.as(StringLiteralExprSyntax.self),
              let valueSegment = valueString.segments.first?.as(StringSegmentSyntax.self) {
              headers[keySegment.content.text] = valueSegment.content.text
            }
          }

          return headers
        }
      }
    }

    return [:]
  }

  /// Generates a dictionary expression for default headers using Template algebra.
  ///
  /// Constructs a Template representing a dictionary literal with string key-value pairs,
  /// then renders it to SwiftSyntax ExprSyntax for macro expansion.
  ///
  /// Dictionary literals are represented using binaryOperation with ":" operator for each
  /// key-value pair, wrapped in an arrayLiteral (which uses [...] syntax).
  ///
  /// - Parameter headers: Dictionary of header names to values
  /// - Returns: SwiftSyntax expression representing `["key": "value", ...]`
  public static func generateHeadersExpression(
    from headers: [String: String]
  ) -> ExprSyntax {
    // Sort headers for deterministic output
    let sortedHeaders = headers.sorted(by: { $0.key < $1.key })

    // Build array of binary operation templates representing dictionary key-value pairs
    // Each pair is rendered as: "key": "value"
    let headerPairs: [Template<Void>] = sortedHeaders.map { key, value in
      .binaryOperation(
        left: .literal(.string(key)),
        operator: ":",
        right: .literal(.string(value))
      )
    }

    // Construct dictionary literal template (array syntax with : operators creates dict literal)
    let dictionaryTemplate: Template<Void> = .arrayLiteral(headerPairs)

    // Render template to ExprSyntax
    return Renderer.render(dictionaryTemplate)
  }
}
