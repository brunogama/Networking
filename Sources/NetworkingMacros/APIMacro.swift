import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Macro for generating API client implementations from protocol definitions
public struct APIMacro: ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
      throw MacroError.invalidUsage("@API can only be applied to protocols")
    }

    let baseURL = try extractBaseURL(from: node)
    let protocolName = protocolDecl.name.text
    let implName = "\(protocolName)Implementation"

    // Extract all method declarations from the protocol
    let methods = protocolDecl.memberBlock.members.compactMap { member in
      member.decl.as(FunctionDeclSyntax.self)
    }

    // Generate method implementations
    let methodImplementations = try methods.map { method in
      try generateMethodImplementation(for: method, baseURL: baseURL)
    }

    let extensionDecl = ExtensionDeclSyntax(
      extendedType: IdentifierTypeSyntax(name: .identifier(protocolName))
    ) {
      // Generate the implementation struct
      DeclSyntax(
        """
        public struct \(raw: implName): \(raw: protocolName) {
            private let client: HTTPClient
            private let baseURL: String = "\(raw: baseURL)"

            public init(client: HTTPClient = NetworkClient()) {
                self.client = client
            }

            \(raw: methodImplementations.joined(separator: "\n\n"))
        }
        """
      )
    }

    return [extensionDecl]
  }

  private static func extractBaseURL(from attribute: AttributeSyntax) throws -> String {
    guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
      let firstArg = arguments.first,
      let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
      let baseURL = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text
    else {
      throw MacroError.missingAnnotation("@API requires a baseURL parameter")
    }
    return baseURL
  }

  private static func generateMethodImplementation(
    for method: FunctionDeclSyntax,
    baseURL: String
  ) throws -> String {
    _ = method.name.text

    // Extract HTTP method and path from attributes
    let httpInfo = try extractHTTPInfo(from: method)

    // Extract parameter information
    let parameters = method.signature.parameterClause.parameters
    let parameterInfo = try extractParameterInfo(from: parameters)

    // Generate the method signature
    let signature = try generateMethodSignature(from: method)

    // Generate the request building logic
    let requestBuilding = generateRequestBuilding(
      httpMethod: httpInfo.method,
      path: httpInfo.path,
      parameters: parameterInfo
    )

    // Generate return type handling
    let returnTypeHandling = try generateReturnTypeHandling(from: method.signature.returnClause)

    return """
      \(signature) {
          \(requestBuilding)

          let response = try await client.execute(request)
          \(returnTypeHandling)
      }
      """
  }

  private static func extractHTTPInfo(
    from method: FunctionDeclSyntax
  ) throws -> (method: String, path: String) {
    for attribute in method.attributes {
      guard let attributeType = attribute.as(AttributeSyntax.self),
        let identifierType = attributeType.attributeName.as(IdentifierTypeSyntax.self)
      else {
        continue
      }

      let attributeName = identifierType.name.text

      switch attributeName {
      case "GET", "POST", "PUT", "DELETE", "PATCH":
        let path = try extractPathFromAttribute(attributeType)
        return (method: attributeName, path: path)

      default:
        continue
      }
    }

    throw MacroError.missingAnnotation(
      "Method must have HTTP method annotation (@GET, @POST, etc.)"
    )
  }

  private static func extractPathFromAttribute(_ attribute: AttributeSyntax) throws -> String {
    guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
      let firstArg = arguments.first,
      let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
      let path = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text
    else {
      throw MacroError.missingAnnotation("HTTP method annotation requires a path parameter")
    }
    return path
  }

  private static func extractParameterInfo(
    from parameters: FunctionParameterListSyntax
  ) throws -> [ParameterInfo] {
    try parameters.map { param in
      let name = param.firstName.text
      let type = param.type.description
      let (paramType, customName) = try extractParameterTypeAndCustomName(from: param)
      return ParameterInfo(name: name, type: type, parameterType: paramType, customName: customName)
    }
  }

  private static func extractParameterTypeAndCustomName(
    from parameter: FunctionParameterSyntax
  ) throws -> (ParameterType, String?) {
    for attribute in parameter.attributes {
      guard let attributeType = attribute.as(AttributeSyntax.self),
        let identifierType = attributeType.attributeName.as(IdentifierTypeSyntax.self)
      else {
        continue
      }

      let attributeName = identifierType.name.text

      switch attributeName {
      case "Path":
        let customName = extractCustomName(from: attributeType)
        return (.path, customName)

      case "Body":
        return (.body, nil)

      case "Query":
        let customName = extractCustomName(from: attributeType)
        return (.query, customName)

      case "Header":
        let customName = try extractRequiredCustomName(from: attributeType, macroName: "Header")
        return (.header, customName)

      default:
        continue
      }
    }

    // Default to query parameter if no annotation is found
    return (.query, nil)
  }

  /// Extracts an optional custom name from a parameter macro attribute.
  /// Handles both `@Path("custom_name")` and `@Path` (no arguments).
  private static func extractCustomName(from attribute: AttributeSyntax) -> String? {
    guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
      let firstArg = arguments.first,
      let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
      let customName = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text,
      !customName.isEmpty
    else {
      return nil
    }
    return customName
  }

  /// Extracts a required custom name from a parameter macro attribute.
  /// Throws if the name is missing or empty.
  private static func extractRequiredCustomName(
    from attribute: AttributeSyntax,
    macroName: String
  ) throws -> String {
    guard let customName = extractCustomName(from: attribute) else {
      throw MacroError.missingAnnotation("@\(macroName) requires a non-empty string argument")
    }
    return customName
  }

  private static func generateMethodSignature(from method: FunctionDeclSyntax) throws -> String {
    let name = method.name.text
    let parameters = method.signature.parameterClause.parameters

    let paramStrings = parameters.map { param in
      let firstName = param.firstName.text
      let secondName = param.secondName?.text ?? firstName
      let type = param.type.description
      return "\(firstName) \(secondName): \(type)"
    }

    let returnClause = method.signature.returnClause?.type.description ?? "Void"
    let effectSpecifiers = method.signature.effectSpecifiers?.description ?? ""

    return
      "public func \(name)(\(paramStrings.joined(separator: ", "))) \(effectSpecifiers) -> \(returnClause)"
  }

  private static func generateRequestBuilding(
    httpMethod: String,
    path: String,
    parameters: [ParameterInfo]
  ) -> String {
    var requestComponents: [String] = []
    requestComponents.append("BaseURL(baseURL)")
    requestComponents.append("\(httpMethod)(\"\(path)\")")

    // Add path parameter substitutions
    // Uses effectiveName for the URL placeholder key, but param.name for the Swift variable
    let pathParams = parameters.filter { $0.parameterType == .path }
    if !pathParams.isEmpty {
      let substitutions = pathParams.map { param in
        ".replacingOccurrences(of: \"{\(param.effectiveName)}\", with: String(\(param.name)))"
      }
      let lastComponent = requestComponents.removeLast()
      requestComponents.append("\(lastComponent)\(substitutions.joined())")
    }

    // Add query parameters
    // Uses effectiveName for the query key, but param.name for the Swift variable
    for param in parameters.filter({ $0.parameterType == .query }) {
      requestComponents.append("QueryParam(\"\(param.effectiveName)\", \(param.name))")
    }

    // Add headers
    // Uses effectiveName for the header key, but param.name for the Swift variable
    for param in parameters.filter({ $0.parameterType == .header }) {
      requestComponents.append("Header(\"\(param.effectiveName)\", \(param.name))")
    }

    // Add body
    if let bodyParam = parameters.first(where: { $0.parameterType == .body }) {
      requestComponents.append("JSONBody(\(bodyParam.name))")
    }

    return """
      let request = try HTTPRequest {
          \(requestComponents.joined(separator: "\n            "))
      }
      """
  }

  private static func generateReturnTypeHandling(
    from returnClause: ReturnClauseSyntax?
  ) throws -> String {
    guard let returnClause = returnClause else {
      return "return"
    }

    let returnType = returnClause.type.description

    if returnType == "Void" || returnType.isEmpty {
      return "return"
    } else {
      return "return try response.decode(\(returnType).self)"
    }
  }
}

// MARK: - Supporting Types

private struct ParameterInfo {
  let name: String
  let type: String
  let parameterType: ParameterType
  let customName: String?

  /// Returns the effective name to use in generated code (custom name if provided, otherwise parameter name)
  var effectiveName: String {
    customName ?? name
  }
}

private enum ParameterType {
  case path
  case body
  case query
  case header
}
