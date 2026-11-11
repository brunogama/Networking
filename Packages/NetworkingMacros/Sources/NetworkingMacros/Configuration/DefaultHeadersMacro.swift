import Foundation
import SwiftSyntax
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
        id: .defaultHeadersRequiresProtocol,
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
        id: .emptyDefaultHeaders,
        node: node,
        context: context
      )
      return []
    }

    // Note: The actual header application is handled by APIMacro
    // This macro just validates the syntax and makes the information available
    // to other macros via the attribute syntax

    return []
  }

  // MARK: - Header Extraction

  private static func extractHeaders(
    from node: AttributeSyntax,
    context: some MacroExpansionContext
  ) -> [String: String]? {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
      let firstArg = arguments.first,
      let headers = BoundaryExpressionParser.dictionaryOfStrings(from: firstArg.expression)
    else {
      MacroHelpers.emitError(
        "@DefaultHeaders requires a dictionary argument",
        id: .invalidDefaultHeaders,
        node: node,
        context: context
      )
      return nil
    }

    return headers
  }

  // MARK: - Helper Methods

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
          let headers = BoundaryExpressionParser.dictionaryOfStrings(from: firstArg.expression)
        {
          return headers
        }
      }
    }

    return [:]
  }

}
