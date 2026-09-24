import SwiftSyntax

enum HTTPMethodImplementationBuilder {
  struct Input {
    let function: FunctionDeclSyntax
    let returnType: String
    let pathCode: String
    let method: String
    let bodyParameter: String?
    let queryParameters: [String]
    let headers: [ParsedHeader]
    let accessLevel: String?
    let hasInterceptors: Bool
  }

  static func generate(_ input: Input) -> DeclSyntax {
    let signature = FunctionSignatureAdapter.renderedSignature(
      for: input.function,
      renamedTo: input.function.name.text
    )
    let accessPrefix = input.accessLevel.map { "\($0) " } ?? ""
    let body = statements(for: input).joined(separator: "\n")

    return DeclSyntax(
      stringLiteral: """
        \(accessPrefix)\(signature) {
        \(indent(body))
        }
        """
    )
  }

  private static func statements(for input: Input) -> [String] {
    let methodMember = input.method.lowercased()
    let requestBinding =
      input.bodyParameter != nil || !input.queryParameters.isEmpty || !input.headers.isEmpty
      ? "var"
      : "let"

    var statements = [
      "let path = \(input.pathCode)",
      """
      guard let url = HTTPRequestURL(BaseURLText(rawValue: baseURL.rawValue + path)) else {
        throw URLError(.badURL)
      }
      """,
      """
      \(requestBinding) request = HTTPRequest(
        method: .\(methodMember),
        url: url,
        headers: defaultHeaders,
        timeout: defaultTimeout
      )
      """,
    ]

    statements.append(contentsOf: bodyStatements(input.bodyParameter))
    statements.append(contentsOf: headerStatements(input.headers))
    statements.append(contentsOf: queryStatements(input.queryParameters, in: input.function))

    if input.hasInterceptors {
      statements.append(
        contentsOf: interceptorExecution(method: methodMember, returnType: input.returnType)
      )
    } else if isVoid(input.returnType) {
      statements.append("_ = try await client.execute(request)")
      statements.append("return")
    } else {
      statements.append("let response = try await client.execute(request)")
      statements.append(
        contentsOf: decodeStatements(response: "response", returnType: input.returnType)
      )
    }
    return statements
  }

  private static func bodyStatements(_ bodyParameter: String?) -> [String] {
    guard let bodyParameter else { return [] }
    return [
      "request.setBody(HTTPBody(try JSONEncoder().encode(\(bodyParameter))))",
      "request.addHeader(name: \"Content-Type\", value: \"application/json\")",
    ]
  }

  private static func headerStatements(_ headers: [ParsedHeader]) -> [String] {
    headers.map { header in
      let name = swiftLiteral(header.name)
      switch header.valueSource {
      case .parameter(let parameter):
        return
          "request.addHeader(name: \(name), value: \"\\(\(parameter))\")"
      case .literal(let value):
        return "request.addHeader(name: \(name), value: \(swiftLiteral(value)))"
      }
    }
  }

  private static func queryStatements(
    _ queryParameters: [String],
    in function: FunctionDeclSyntax
  ) -> [String] {
    queryParameters.map { parameter in
      let call =
        "request.addQueryParameter(name: \(swiftLiteral(parameter)), value: \(parameter))"
      if isOptionalParameter(named: parameter, in: function) {
        return """
          if let \(parameter) {
            \(call)
          }
          """
      }
      return call
    }
  }

  private static func isOptionalParameter(
    named name: String,
    in function: FunctionDeclSyntax
  ) -> Bool {
    guard
      let parameter = function.signature.parameterClause.parameters.first(where: {
        ($0.secondName?.text ?? $0.firstName.text) == name
      })
    else {
      return false
    }

    return parameter.type.is(OptionalTypeSyntax.self)
      || parameter.type.trimmedDescription.hasPrefix("Optional<")
  }

  private static func interceptorExecution(
    method: String,
    returnType: String
  ) -> [String] {
    let shortCircuit =
      decodeStatements(response: "interceptedResponse", returnType: returnType)
      .joined(separator: "\n")
    let decodedResponse =
      decodeStatements(response: "finalResponse", returnType: returnType)
      .joined(separator: "\n")
    return [
      "let preparedRequest = request",
      "var context = InterceptorContext(path: RequestPathPattern(rawValue: path), method: .\(method))",
      """
      while true {
      \(indent(requestInterceptorStep(shortCircuit: shortCircuit)))
      \(indent(responseInterceptorStep()))
      \(indent(decodedResponse))
      }
      """,
    ]
  }

  private static func decodeStatements(response: String, returnType: String) -> [String] {
    guard !isVoid(returnType) else { return ["return"] }
    return [
      """
      guard let responseBody = \(response).body else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(codingPath: [], debugDescription: "Response body is empty")
        )
      }
      """,
      "return try JSONDecoder().decode(\(returnType).self, from: responseBody.rawValue)",
    ]
  }

  private static func isVoid(_ returnType: String) -> Bool {
    returnType == "Void" || returnType == "()"
  }

  static func indent(_ source: String) -> String {
    source.split(separator: "\n", omittingEmptySubsequences: false)
      .map { "  \($0)" }
      .joined(separator: "\n")
  }

  private static func swiftLiteral(_ value: String) -> String { String(reflecting: value) }
}
