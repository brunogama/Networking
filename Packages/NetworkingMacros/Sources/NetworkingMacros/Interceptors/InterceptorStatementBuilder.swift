import Foundation
import MacroTemplateKit

/// Helper utilities for building interceptor-related statements.
///
/// Extracts statement construction logic from InterceptorCodeGenerator
/// to maintain file length and complexity budgets.
enum InterceptorStatementBuilder {
  // MARK: - Request Statements

  /// Builds path binding statement.
  static func buildPathBinding(pathCode: String) -> Statement<Void> {
    .letBinding(
      name: "path",
      type: nil,
      initializer: .variable(pathCode, payload: ())
    )
  }

  /// Builds request variable initialization.
  static func buildRequestInitialization(method: String) -> Statement<Void> {
    .varBinding(
      name: "request",
      type: nil,
      initializer: .functionCall(
        function: "HTTPRequest",
        arguments: [
          (
            label: "method",
            value: .propertyAccess(
              base: .literal(.nil),
              property: method
            )
          ),
          (label: "path", value: .variable("path", payload: ())),
          (label: "baseURL", value: .variable("baseURL", payload: ())),
        ]
      )
    )
  }

  /// Builds additional request code statement.
  static func buildAdditionalRequestCode(_ code: String) -> Statement<Void>? {
    guard !code.isEmpty else { return nil }
    return .expression(.variable(code, payload: ()))
  }

  // MARK: - Response Statements

  /// Builds client execute call statement.
  static func buildExecuteCall() -> Statement<Void> {
    .letBinding(
      name: "response",
      type: nil,
      initializer: .functionCall(
        function: "client.execute",
        arguments: [
          (label: nil, value: .variable("request", payload: ()))
        ]
      )
    )
  }

  /// Builds JSON decoding return statement.
  static func buildDecodeReturn(returnType: String) -> Statement<Void> {
    .returnStatement(
      .functionCall(
        function: "JSONDecoder().decode",
        arguments: [
          (
            label: nil,
            value: .propertyAccess(
              base: .variable(returnType, payload: ()),
              property: "self"
            )
          ),
          (
            label: "from",
            value: .propertyAccess(
              base: .variable("response", payload: ()),
              property: "data"
            )
          ),
        ]
      )
    )
  }
}
