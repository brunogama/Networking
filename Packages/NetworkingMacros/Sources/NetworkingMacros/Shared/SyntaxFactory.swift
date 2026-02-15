import SwiftSyntax
import SwiftSyntaxBuilder

/// Factory methods for creating SwiftSyntax AST nodes.
///
/// This file provides convenience functions for generating common code patterns
/// used in macro expansion, particularly for NetworkClient-based implementations.
enum SyntaxFactory {
  // MARK: - Struct Generation

  /// Creates a struct declaration conforming to a protocol.
  ///
  /// Example:
  /// ```swift
  /// struct UserAPIImplementation: UserAPI, Sendable {
  ///   // members
  /// }
  /// ```
  static func createImplementationStruct(
    protocolName: String,
    members: [DeclSyntax]
  ) -> DeclSyntax {
    let structName = "\(protocolName)Implementation"

    return DeclSyntax(
      StructDeclSyntax(
        modifiers: [DeclModifierSyntax(name: .keyword(.public))],
        name: .identifier(structName),
        inheritanceClause: InheritanceClauseSyntax {
          InheritedTypeSyntax(type: IdentifierTypeSyntax(name: .identifier(protocolName)))
          InheritedTypeSyntax(type: IdentifierTypeSyntax(name: .identifier("Sendable")))
        },
        memberBlock: MemberBlockSyntax(
          members: MemberBlockItemListSyntax(
            members.map {
              MemberBlockItemSyntax(decl: $0)
            }
          )
        )
      )
    )
  }

  // MARK: - Property Generation

  /// Creates a private NetworkClient property.
  ///
  /// ```swift
  /// private let client: NetworkClient
  /// ```
  static func createClientProperty() -> DeclSyntax {
    DeclSyntax(
      VariableDeclSyntax(
        modifiers: [DeclModifierSyntax(name: .keyword(.private))],
        bindingSpecifier: .keyword(.let),
        bindings: PatternBindingListSyntax {
          PatternBindingSyntax(
            pattern: IdentifierPatternSyntax(identifier: .identifier("client")),
            typeAnnotation: TypeAnnotationSyntax(
              type: IdentifierTypeSyntax(name: .identifier("NetworkClient"))
            )
          )
        }
      )
    )
  }

  // MARK: - Initializer Generation

  /// Creates an initializer accepting optional NetworkClient.
  ///
  /// ```swift
  /// init(client: NetworkClient = .shared) {
  ///   self.client = client
  /// }
  /// ```
  static func createInitializer() -> DeclSyntax {
    DeclSyntax(
      """
      public init(client: NetworkClient = .shared) {
        self.client = client
      }
      """
    )
  }

  // MARK: - Function Generation

  /// Creates a function implementation with HTTPRequest building.
  ///
  /// This generates the complete function body including:
  /// - Query parameter handling
  /// - HTTPRequest builder
  /// - NetworkClient execution
  /// - Response decoding
  static func createFunctionImplementation(
    signature: FunctionSignatureSyntax,
    name: String,
    httpMethod: String,
    path: String,
    pathParameters: [String],
    queryParameters: [String],
    bodyParameter: String?,
    headers: [(key: String, value: String)],
    baseURL: String,
    timeout: Double?,
    returnType: String?
  ) -> DeclSyntax {
    var bodyStatements: [String] = []

    // Generate query parameter handling
    if !queryParameters.isEmpty {
      bodyStatements.append("var queryItems: [String: String] = [:]")

      for param in queryParameters {
        bodyStatements.append(
          """
          if let \(param) = \(param) {
            queryItems["\(param)"] = String(\(param))
          }
          """
        )
      }
    }

    // Generate path string with interpolation
    let pathWithParams = generatePathExpression(path: path, parameters: pathParameters)

    // Build HTTPRequest
    var requestBuilder = "let request = HTTPRequest {\n"
    requestBuilder += "  \(httpMethod)(\(pathWithParams))\n"
    requestBuilder += "  BaseURL(\"\(baseURL)\")\n"

    // Add query params if present
    if !queryParameters.isEmpty {
      requestBuilder += """
          if !queryItems.isEmpty {
            QueryParams(queryItems)
          }

        """
    }

    // Add body if present
    if let bodyParam = bodyParameter {
      requestBuilder += "  JSONBody(\(bodyParam))\n"
      requestBuilder += "  ContentType(.json)\n"
    }

    // Add headers
    for header in headers {
      requestBuilder += "  Header(\"\(header.key)\", \"\(header.value)\")\n"
    }

    // Add timeout if specified
    if let timeout = timeout {
      requestBuilder += "  Timeout(\(timeout))\n"
    }

    requestBuilder += "}"
    bodyStatements.append(requestBuilder)

    // Execute request
    bodyStatements.append("let response = try await client.execute(request)")

    // Handle response
    if let returnType = returnType, returnType != "Void" {
      bodyStatements.append("return try response.decode(\(returnType).self)")
    }

    let bodyString = bodyStatements.joined(separator: "\n")

    return DeclSyntax(
      """
      public func \(raw: name)\(raw: signature.parameterClause.description) async throws\(raw: returnType.map { " -> \($0)" } ?? "") {
      \(raw: bodyString)
      }
      """
    )
  }

  // MARK: - Path Expression Generation

  /// Generates path string with parameter interpolation.
  ///
  /// Example: "/users/{id}" with pathParameters: ["id"]
  /// Returns: "\"/users/\\(id)\""
  private static func generatePathExpression(
    path: String,
    parameters: [String]
  ) -> String {
    var result = path

    for param in parameters {
      result = result.replacingOccurrences(of: "{\(param)}", with: "\\(\(param))")
    }

    return "\"\(result)\""
  }

  // MARK: - Attribute Parsing

  /// Extracts string argument from macro attribute.
  ///
  /// Example: @GET("/users/{id}") -> "/users/{id}"
  static func extractStringArgument(
    from attribute: AttributeSyntax,
    position: Int = 0
  ) -> String? {
    guard let arguments = attribute.arguments,
      case .argumentList(let list) = arguments
    else {
      return nil
    }

    guard position < list.count else { return nil }
    let arg = list[list.index(list.startIndex, offsetBy: position)]

    // Handle string literal
    if let stringLiteral = arg.expression.as(StringLiteralExprSyntax.self),
      let segment = stringLiteral.segments.first,
      case .stringSegment(let stringSegment) = segment {
      return stringSegment.content.text
    }

    return nil
  }

  /// Extracts array argument from macro attribute.
  ///
  /// Example: @GET("/users", queryParameters: ["sort", "limit"])
  /// Returns: ["sort", "limit"]
  static func extractArrayArgument(
    from attribute: AttributeSyntax,
    label: String
  ) -> [String]? {
    guard let arguments = attribute.arguments,
      case .argumentList(let list) = arguments
    else {
      return nil
    }

    for arg in list {
      guard arg.label?.text == label else { continue }

      if let arrayExpr = arg.expression.as(ArrayExprSyntax.self) {
        return arrayExpr.elements.compactMap { element in
          guard let stringLiteral = element.expression.as(StringLiteralExprSyntax.self),
            let segment = stringLiteral.segments.first,
            case .stringSegment(let stringSegment) = segment
          else {
            return nil
          }
          return stringSegment.content.text
        }
      }
    }

    return nil
  }

  /// Extracts dictionary argument from macro attribute.
  ///
  /// Example: @DefaultHeaders(["X-API-Version": "v1"])
  /// Returns: [("X-API-Version", "v1")]
  static func extractDictionaryArgument(
    from attribute: AttributeSyntax
  ) -> [(key: String, value: String)]? {
    guard let arguments = attribute.arguments,
      case .argumentList(let list) = arguments,
      let firstArg = list.first
    else {
      return nil
    }

    if let dictExpr = firstArg.expression.as(DictionaryExprSyntax.self) {
      guard case .elements(let elements) = dictExpr.content else { return nil }

      return elements.compactMap { element in
        guard let keyString = element.key.as(StringLiteralExprSyntax.self),
          let keySegment = keyString.segments.first,
          case .stringSegment(let keyStringSegment) = keySegment,
          let valueString = element.value.as(StringLiteralExprSyntax.self),
          let valueSegment = valueString.segments.first,
          case .stringSegment(let valueStringSegment) = valueSegment
        else {
          return nil
        }

        return (key: keyStringSegment.content.text, value: valueStringSegment.content.text)
      }
    }

    return nil
  }

  /// Extracts double argument from macro attribute.
  ///
  /// Example: @Timeout(30.0) -> 30.0
  static func extractDoubleArgument(
    from attribute: AttributeSyntax,
    position: Int = 0
  ) -> Double? {
    guard let arguments = attribute.arguments,
      case .argumentList(let list) = arguments
    else {
      return nil
    }

    guard position < list.count else { return nil }
    let arg = list[list.index(list.startIndex, offsetBy: position)]

    if let floatLiteral = arg.expression.as(FloatLiteralExprSyntax.self) {
      return Double(floatLiteral.literal.text)
    } else if let intLiteral = arg.expression.as(IntegerLiteralExprSyntax.self) {
      return Double(intLiteral.literal.text)
    }

    return nil
  }
}
