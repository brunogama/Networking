import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Macro for generating API client implementations from protocol definitions.
///
/// Reads HTTP method attributes (@GET, @POST, etc.) with their parameters:
/// - path: URL path with {placeholder} for path parameters
/// - body: Parameter name to use as JSON body
/// - query: Dictionary mapping param names to query string keys
/// - headers: Dictionary mapping param names to header names
public struct APIMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
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

    // Generate the implementation struct as a peer declaration
    // Match the visibility of the protocol
    let visibility = protocolDecl.modifiers.first { modifier in
      modifier.name.tokenKind == .keyword(.public) || modifier.name.tokenKind == .keyword(.internal)
    }
    let visibilityPrefix = visibility.map { "\($0.name.text) " } ?? ""

    let structDecl: DeclSyntax =
      """
      \(raw: visibilityPrefix)struct \(raw: implName): \(raw: protocolName) {
          private let client: HTTPClient
          private let baseURL: URL

          \(raw: visibilityPrefix)init(client: HTTPClient = NetworkClient()) {
              self.client = client
              // swiftlint:disable:next force_unwrapping
              self.baseURL = URL(string: "\(raw: baseURL)")!
          }

          \(raw: methodImplementations.joined(separator: "\n\n"))
      }
      """

    return [structDecl]
  }

  // MARK: - Base URL Extraction

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

  // MARK: - Method Implementation Generation

  private static func generateMethodImplementation(
    for method: FunctionDeclSyntax,
    baseURL: String
  ) throws -> String {
    // Extract HTTP info from the method attribute
    let httpInfo = try extractHTTPInfo(from: method)

    // Get function parameters
    let functionParams = method.signature.parameterClause.parameters.map { param in
      FunctionParameter(
        name: param.firstName.text,
        localName: param.secondName?.text ?? param.firstName.text,
        type: param.type.description.trimmingCharacters(in: .whitespaces)
      )
    }

    // Classify parameters based on HTTP attribute metadata
    let classifiedParams = classifyParameters(
      functionParams: functionParams,
      path: httpInfo.path,
      bodyParam: httpInfo.body,
      queryMapping: httpInfo.query,
      headerMapping: httpInfo.headers
    )

    // Generate method signature
    let signature = generateMethodSignature(from: method)

    // Generate request building
    let requestBuilding = generateRequestBuilding(
      httpMethod: httpInfo.method,
      path: httpInfo.path,
      params: classifiedParams,
      staticQuery: httpInfo.query
    )

    // Generate return handling
    let returnHandling = generateReturnTypeHandling(from: method.signature.returnClause)

    return """
      \(signature) {
          \(requestBuilding)

          let response = try await client.execute(request)
          \(returnHandling)
      }
      """
  }

  // MARK: - HTTP Attribute Parsing

  private static func extractHTTPInfo(
    from method: FunctionDeclSyntax
  ) throws -> HTTPMethodInfo {
    for attribute in method.attributes {
      guard let attr = attribute.as(AttributeSyntax.self),
        let identifierType = attr.attributeName.as(IdentifierTypeSyntax.self)
      else {
        continue
      }

      let attrName = identifierType.name.text

      switch attrName {
      case "GET", "POST", "PUT", "DELETE", "PATCH":
        return try parseHTTPMethodAttribute(attr, method: attrName)

      default:
        continue
      }
    }

    throw MacroError.missingAnnotation(
      "Method must have HTTP method annotation (@GET, @POST, etc.)"
    )
  }

  private static func parseHTTPMethodAttribute(
    _ attribute: AttributeSyntax,
    method: String
  ) throws -> HTTPMethodInfo {
    guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self) else {
      throw MacroError.missingAnnotation("HTTP method annotation requires a path parameter")
    }

    var path: String?
    var body: String?
    var query: [String: String] = [:]
    var headers: [String: String] = [:]

    for arg in arguments {
      let label = arg.label?.text

      if label == nil {
        // Unlabeled argument is the path
        if let stringLiteral = arg.expression.as(StringLiteralExprSyntax.self),
          let pathValue = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text
        {
          path = pathValue
        }
      } else if label == "body" {
        // body: "paramName"
        if let stringLiteral = arg.expression.as(StringLiteralExprSyntax.self),
          let bodyValue = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text
        {
          body = bodyValue
        }
      } else if label == "query" {
        // query: ["paramName": "queryKey"]
        query = extractDictionaryLiteral(from: arg.expression)
      } else if label == "headers" {
        // headers: ["paramName": "Header-Name"]
        headers = extractDictionaryLiteral(from: arg.expression)
      }
    }

    guard let pathValue = path else {
      throw MacroError.missingAnnotation("HTTP method annotation requires a path parameter")
    }

    return HTTPMethodInfo(
      method: method,
      path: pathValue,
      body: body,
      query: query,
      headers: headers
    )
  }

  private static func extractDictionaryLiteral(from expr: ExprSyntax) -> [String: String] {
    guard let dictExpr = expr.as(DictionaryExprSyntax.self) else {
      return [:]
    }

    var result: [String: String] = [:]

    if case .elements(let elements) = dictExpr.content {
      for element in elements {
        if let keyLiteral = element.key.as(StringLiteralExprSyntax.self),
          let key = keyLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text,
          let valueLiteral = element.value.as(StringLiteralExprSyntax.self),
          let value = valueLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text
        {
          result[key] = value
        }
      }
    }

    return result
  }

  // MARK: - Parameter Classification

  private static func classifyParameters(
    functionParams: [FunctionParameter],
    path: String,
    bodyParam: String?,
    queryMapping: [String: String],
    headerMapping: [String: String]
  ) -> ClassifiedParameters {
    // Extract path placeholders from the path string
    let pathPlaceholders = extractPathPlaceholders(from: path)

    var pathParams: [ClassifiedParam] = []
    var queryParams: [ClassifiedParam] = []
    var headerParams: [ClassifiedParam] = []
    var bodyParamResult: ClassifiedParam?

    for param in functionParams {
      // Check if it's a path parameter (matches a placeholder)
      if pathPlaceholders.contains(param.name) {
        pathParams.append(
          ClassifiedParam(
            name: param.name,
            localName: param.localName,
            type: param.type,
            mappedName: param.name  // Path params use their name as the placeholder key
          )
        )
      }
      // Check if it's the body parameter
      else if param.name == bodyParam {
        bodyParamResult = ClassifiedParam(
          name: param.name,
          localName: param.localName,
          type: param.type,
          mappedName: nil
        )
      }
      // Check if it's a header parameter
      else if let headerName = headerMapping[param.name] {
        headerParams.append(
          ClassifiedParam(
            name: param.name,
            localName: param.localName,
            type: param.type,
            mappedName: headerName
          )
        )
      }
      // Otherwise it's a query parameter
      else {
        let queryKey = queryMapping[param.name] ?? param.name
        queryParams.append(
          ClassifiedParam(
            name: param.name,
            localName: param.localName,
            type: param.type,
            mappedName: queryKey
          )
        )
      }
    }

    return ClassifiedParameters(
      path: pathParams,
      query: queryParams,
      headers: headerParams,
      body: bodyParamResult
    )
  }

  private static func extractPathPlaceholders(from path: String) -> Set<String> {
    var placeholders: Set<String> = []
    var currentPlaceholder = ""
    var inPlaceholder = false

    for char in path {
      if char == "{" {
        inPlaceholder = true
        currentPlaceholder = ""
      } else if char == "}" {
        if inPlaceholder && !currentPlaceholder.isEmpty {
          placeholders.insert(currentPlaceholder)
        }
        inPlaceholder = false
      } else if inPlaceholder {
        currentPlaceholder.append(char)
      }
    }

    return placeholders
  }

  // MARK: - Code Generation

  private static func generateMethodSignature(from method: FunctionDeclSyntax) -> String {
    let name = method.name.text
    let parameters = method.signature.parameterClause.parameters

    let paramStrings = parameters.map { param in
      let firstName = param.firstName.text
      let secondName = param.secondName?.text ?? param.firstName.text
      let type = param.type.description.trimmingCharacters(in: .whitespaces)
      if firstName == secondName {
        return "\(firstName): \(type)"
      }
      return "\(firstName) \(secondName): \(type)"
    }

    let returnClause =
      method.signature.returnClause?.type.description
      .trimmingCharacters(in: .whitespaces) ?? "Void"
    let effectSpecifiers =
      method.signature.effectSpecifiers?.description
      .trimmingCharacters(in: .whitespaces) ?? ""

    return
      "func \(name)(\(paramStrings.joined(separator: ", "))) \(effectSpecifiers) -> \(returnClause)"
  }

  private static func generateRequestBuilding(
    httpMethod: String,
    path: String,
    params: ClassifiedParameters,
    staticQuery: [String: String]
  ) -> String {
    var components: [String] = []

    // Base URL
    components.append("RequestBaseURL(baseURL)")

    // Build path with substitutions
    var pathExpr = "\"\(path)\""
    for param in params.path {
      pathExpr +=
        ".replacingOccurrences(of: \"{\(param.mappedName ?? param.name)}\", with: String(\(param.localName)))"
    }
    components.append("\(httpMethod)(\(pathExpr))")

    // Static query parameters (values without placeholders)
    for (key, value) in staticQuery {
      if !value.contains("{") {
        components.append("QueryParam(\"\(key)\", \"\(value)\")")
      }
    }

    // Dynamic query parameters (from function arguments)
    for param in params.query {
      components.append("QueryParam(\"\(param.mappedName ?? param.name)\", \(param.localName))")
    }

    // Headers
    for param in params.headers {
      if let headerName = param.mappedName {
        components.append("Header(\"\(headerName)\", \(param.localName))")
      }
    }

    // Body
    if let body = params.body {
      components.append("JSONBody(\(body.localName))")
    }

    return """
      let request = try HTTPRequest {
              \(components.joined(separator: "\n            "))
          }
      """
  }

  private static func generateReturnTypeHandling(
    from returnClause: ReturnClauseSyntax?
  ) -> String {
    guard let returnClause = returnClause else {
      return "return"
    }

    let returnType = returnClause.type.description.trimmingCharacters(in: .whitespaces)

    if returnType == "Void" || returnType.isEmpty {
      return "return"
    } else {
      return "return try response.chain().decode(\(returnType).self).value"
    }
  }
}

// MARK: - Supporting Types

private struct HTTPMethodInfo {
  let method: String
  let path: String
  let body: String?
  let query: [String: String]
  let headers: [String: String]
}

private struct FunctionParameter {
  let name: String
  let localName: String
  let type: String
}

private struct ClassifiedParam {
  let name: String
  let localName: String
  let type: String
  let mappedName: String?
}

private struct ClassifiedParameters {
  let path: [ClassifiedParam]
  let query: [ClassifiedParam]
  let headers: [ClassifiedParam]
  let body: ClassifiedParam?
}
