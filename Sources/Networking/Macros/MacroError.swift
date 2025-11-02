import Foundation

// MARK: - Macro Expansion Errors

/// Errors that occur during compile-time macro expansion.
///
/// These errors are emitted by the Swift compiler during macro expansion
/// and provide detailed diagnostics about API protocol declarations.
public enum MacroExpansionError: Error, Sendable, LocalizedError, CustomStringConvertible {
  /// Path parameters in template don't match function parameters.
  ///
  /// Example: `@GET("/users/{userId}")` but function has parameter `id: String`
  case parameterMismatch(
    path: String,
    declared: [String],
    required: [String]
  )

  /// Path template syntax is invalid.
  ///
  /// Example: `/users/{id` (missing closing brace)
  case invalidPathTemplate(String, suggestion: String?)

  /// Body parameter specified in macro not found in function signature.
  ///
  /// Example: `@POST("/users", body: "user")` but function has no `user` parameter
  case bodyParameterNotFound(String, available: [String])

  /// Query parameter specified in macro not found in function signature.
  ///
  /// Example: `@GET("/search", queryParameters: ["q"])` but function has no `q` parameter
  case queryParameterNotFound(String, available: [String])

  /// Multiple HTTP method macros on same function.
  ///
  /// Example: Both `@GET` and `@POST` on same function
  case multipleHTTPMethods(String, found: [String])

  /// Function missing required `async` keyword.
  ///
  /// All API methods must be `async throws`
  case missingAsyncKeyword(String)

  /// Function missing required `throws` keyword.
  ///
  /// All API methods must be `async throws`
  case missingThrowsKeyword(String)

  /// Return type doesn't conform to Decodable.
  ///
  /// All API method return types must be Decodable for JSON decoding
  case nonDecodableReturnType(String)

  /// Body parameter type doesn't conform to Encodable.
  ///
  /// Request body types must be Encodable for JSON encoding
  case nonEncodableBodyType(String)

  public var description: String {
    switch self {
    case .parameterMismatch(let path, let declared, let required):
      return """
        Path parameter mismatch in '\(path)':
        - Function parameters: \(declared.joined(separator: ", "))
        - Required path parameters: \(required.joined(separator: ", "))
        """

    case .invalidPathTemplate(let template, let suggestion):
      var message = "Invalid path template: '\(template)'"
      if let suggestion = suggestion {
        message += "\n  Suggestion: \(suggestion)"
      }
      return message

    case .bodyParameterNotFound(let name, let available):
      return """
        Body parameter '\(name)' not found in function signature.
        Available parameters: \(available.joined(separator: ", "))
        """

    case .queryParameterNotFound(let name, let available):
      return """
        Query parameter '\(name)' not found in function signature.
        Available parameters: \(available.joined(separator: ", "))
        """

    case .multipleHTTPMethods(let functionName, let found):
      return """
        Multiple HTTP method macros on '\(functionName)':
        Found: \(found.joined(separator: ", "))
        Only one HTTP method macro allowed per function.
        """

    case .missingAsyncKeyword(let functionName):
      return "Function '\(functionName)' must be marked 'async'"

    case .missingThrowsKeyword(let functionName):
      return "Function '\(functionName)' must be marked 'throws'"

    case .nonDecodableReturnType(let typeName):
      return "Return type '\(typeName)' must conform to Decodable"

    case .nonEncodableBodyType(let typeName):
      return "Body parameter type '\(typeName)' must conform to Encodable"
    }
  }

  public var errorDescription: String? {
    description
  }

  public var recoverySuggestion: String? {
    switch self {
    case .parameterMismatch:
      return "Ensure path parameter names in {braces} match function parameter names exactly."

    case .invalidPathTemplate:
      return "Use {parameterName} syntax for path parameters. Example: /users/{id}"

    case .bodyParameterNotFound(let name, _):
      return "Add a '\(name)' parameter to the function, or change the body attribute."

    case .queryParameterNotFound(let name, _):
      return "Add a '\(name)' parameter to the function, or remove it from queryParameters."

    case .multipleHTTPMethods:
      return "Remove all but one HTTP method macro (@GET, @POST, @PUT, @PATCH, @DELETE)."

    case .missingAsyncKeyword:
      return "Add 'async' keyword: func methodName(...) async throws -> Type"

    case .missingThrowsKeyword:
      return "Add 'throws' keyword: func methodName(...) async throws -> Type"

    case .nonDecodableReturnType:
      return "Add Decodable conformance: struct Type: Decodable { ... }"

    case .nonEncodableBodyType:
      return "Add Encodable conformance: struct Type: Encodable { ... }"
    }
  }
}

// MARK: - API Client Runtime Errors

/// Errors that occur during runtime execution of generated API client code.
///
/// These errors are thrown by the generated implementations when network
/// requests fail or responses can't be processed.
public enum APIClientError: Error, Sendable, LocalizedError, CustomStringConvertible {
  /// HTTP request completed with error status code (4xx, 5xx).
  case httpError(statusCode: Int, response: HTTPResponse)

  /// Network layer error (connectivity, timeout, etc).
  case networkError(Error)

  /// JSON decoding failed for response body.
  case decodingError(Error, data: Data)

  /// Request configuration is invalid (malformed URL, missing parameters).
  case invalidRequest(String)

  public var description: String {
    switch self {
    case .httpError(let statusCode, let response):
      return
        "HTTP error \(statusCode): \(HTTPURLResponse.localizedString(forStatusCode: statusCode))"

    case .networkError(let error):
      return "Network error: \(error.localizedDescription)"

    case .decodingError(let error, _):
      return "Failed to decode response: \(error.localizedDescription)"

    case .invalidRequest(let message):
      return "Invalid request: \(message)"
    }
  }

  public var errorDescription: String? {
    description
  }

  public var recoverySuggestion: String? {
    switch self {
    case .httpError(let statusCode, _):
      if statusCode >= 500 {
        return "Server error. Try again later or contact support."
      } else if statusCode == 404 {
        return "Resource not found. Verify the endpoint path."
      } else if statusCode == 401 || statusCode == 403 {
        return "Authentication failed. Check your credentials."
      } else {
        return "Check request parameters and try again."
      }

    case .networkError:
      return "Check your internet connection and try again."

    case .decodingError:
      return "Response format may have changed. Verify your data models match the API response."

    case .invalidRequest:
      return "Fix the request configuration and try again."
    }
  }

  public var failureReason: String? {
    switch self {
    case .httpError(let statusCode, _):
      return "Server returned status code \(statusCode)"

    case .networkError:
      return "Network connection failed"

    case .decodingError:
      return "Response body could not be decoded"

    case .invalidRequest:
      return "Request configuration is invalid"
    }
  }
}
