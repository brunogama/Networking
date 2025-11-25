import SnapshotTesting
import XCTest
@testable import Networking

/// Snapshot tests for error message stability.
///
/// These tests capture the exact textual output of error messages to prevent
/// unintended changes to user-facing error descriptions and recovery suggestions.
final class ErrorSnapshotTests: XCTestCase {
  // MARK: - Recording Mode

  override func invokeTest() {
    // Set record mode to generate/update snapshots:
    // withSnapshotTesting(record: .all) { super.invokeTest() }
    super.invokeTest()
  }

  // MARK: - HTTPError Network Errors

  func testNetworkError_noConnection() {
    let error = HTTPError(category: .network(.noConnection))
    assertSnapshot(of: formatHTTPError(error), as: .lines)
  }

  func testNetworkError_dnsFailure() {
    let error = HTTPError(category: .network(.dnsFailure))
    assertSnapshot(of: formatHTTPError(error), as: .lines)
  }

  func testNetworkError_connectionLost() {
    let error = HTTPError(category: .network(.connectionLost))
    assertSnapshot(of: formatHTTPError(error), as: .lines)
  }

  func testNetworkError_serverUnreachable() {
    let error = HTTPError(category: .network(.serverUnreachable))
    assertSnapshot(of: formatHTTPError(error), as: .lines)
  }

  func testNetworkError_sslError() {
    let error = HTTPError(category: .network(.sslError))
    assertSnapshot(of: formatHTTPError(error), as: .lines)
  }

  // MARK: - HTTPError HTTP Status Errors

  func testHTTPStatus_400BadRequest() {
    let error = HTTPError(category: .http(HTTPStatus(rawValue: 400)))
    assertSnapshot(of: formatHTTPError(error), as: .lines)
  }

  func testHTTPStatus_401Unauthorized() {
    let error = HTTPError(category: .http(HTTPStatus(rawValue: 401)))
    assertSnapshot(of: formatHTTPError(error), as: .lines)
  }

  func testHTTPStatus_403Forbidden() {
    let error = HTTPError(category: .http(HTTPStatus(rawValue: 403)))
    assertSnapshot(of: formatHTTPError(error), as: .lines)
  }

  func testHTTPStatus_404NotFound() {
    let error = HTTPError(category: .http(HTTPStatus(rawValue: 404)))
    assertSnapshot(of: formatHTTPError(error), as: .lines)
  }

  func testHTTPStatus_408RequestTimeout() {
    let error = HTTPError(category: .http(HTTPStatus(rawValue: 408)))
    assertSnapshot(of: formatHTTPError(error), as: .lines)
  }

  func testHTTPStatus_429TooManyRequests() {
    let error = HTTPError(category: .http(HTTPStatus(rawValue: 429)))
    assertSnapshot(of: formatHTTPError(error), as: .lines)
  }

  func testHTTPStatus_500InternalServerError() {
    let error = HTTPError(category: .http(HTTPStatus(rawValue: 500)))
    assertSnapshot(of: formatHTTPError(error), as: .lines)
  }

  func testHTTPStatus_502BadGateway() {
    let error = HTTPError(category: .http(HTTPStatus(rawValue: 502)))
    assertSnapshot(of: formatHTTPError(error), as: .lines)
  }

  func testHTTPStatus_503ServiceUnavailable() {
    let error = HTTPError(category: .http(HTTPStatus(rawValue: 503)))
    assertSnapshot(of: formatHTTPError(error), as: .lines)
  }

  // MARK: - HTTPError Other Categories

  func testHTTPError_timeout() {
    let error = HTTPError(category: .timeout)
    assertSnapshot(of: formatHTTPError(error), as: .lines)
  }

  func testHTTPError_cancelled() {
    let error = HTTPError(category: .cancelled)
    assertSnapshot(of: formatHTTPError(error), as: .lines)
  }

  func testHTTPError_decoding() {
    let error = HTTPError(category: .decoding("Invalid JSON format"))
    assertSnapshot(of: formatHTTPError(error), as: .lines)
  }

  func testHTTPError_encoding() {
    let error = HTTPError(category: .encoding("Failed to encode request body"))
    assertSnapshot(of: formatHTTPError(error), as: .lines)
  }

  func testHTTPError_configuration() {
    let error = HTTPError(category: .configuration("Missing API key"))
    assertSnapshot(of: formatHTTPError(error), as: .lines)
  }

  func testHTTPError_customSecurity() {
    let error = HTTPError(category: .custom("security", "Certificate validation failed"))
    assertSnapshot(of: formatHTTPError(error), as: .lines)
  }

  func testHTTPError_customGeneric() {
    let error = HTTPError(category: .custom("validation", "Invalid input data"))
    assertSnapshot(of: formatHTTPError(error), as: .lines)
  }

  // MARK: - InterceptorError

  func testInterceptorError_maxRetriesExceeded() {
    let error = InterceptorError.maxRetriesExceeded(maxAttempts: 3)
    assertSnapshot(of: formatInterceptorError(error), as: .lines)
  }

  func testInterceptorError_interceptorFailed() {
    struct TestError: Error, LocalizedError {
      var errorDescription: String? { "Connection timeout" }
    }
    let error = InterceptorError.interceptorFailed(underlyingError: TestError())
    assertSnapshot(of: formatInterceptorError(error), as: .lines)
  }

  func testInterceptorError_invalidResult() {
    let error = InterceptorError.invalidResult(reason: "Missing response body")
    assertSnapshot(of: formatInterceptorError(error), as: .lines)
  }

  func testInterceptorError_rateLimitExceeded() {
    let error = InterceptorError.rateLimitExceeded(path: "/api/users", limit: 100, window: 60.0)
    assertSnapshot(of: formatInterceptorError(error), as: .lines)
  }

  // MARK: - MacroExpansionError

  func testMacroExpansionError_parameterMismatch() {
    let error = MacroExpansionError.parameterMismatch(
      path: "/users/{userId}",
      declared: ["id"],
      required: ["userId"]
    )
    assertSnapshot(of: formatMacroExpansionError(error), as: .lines)
  }

  func testMacroExpansionError_invalidPathTemplate() {
    let error = MacroExpansionError.invalidPathTemplate(
      "/users/{id",
      suggestion: "Use /users/{id} with closing brace"
    )
    assertSnapshot(of: formatMacroExpansionError(error), as: .lines)
  }

  func testMacroExpansionError_invalidPathTemplateNoSuggestion() {
    let error = MacroExpansionError.invalidPathTemplate(
      "/users/{{id}}",
      suggestion: nil
    )
    assertSnapshot(of: formatMacroExpansionError(error), as: .lines)
  }

  func testMacroExpansionError_bodyParameterNotFound() {
    let error = MacroExpansionError.bodyParameterNotFound(
      "userRequest",
      available: ["user", "data", "payload"]
    )
    assertSnapshot(of: formatMacroExpansionError(error), as: .lines)
  }

  func testMacroExpansionError_queryParameterNotFound() {
    let error = MacroExpansionError.queryParameterNotFound(
      "pageSize",
      available: ["page", "limit", "offset"]
    )
    assertSnapshot(of: formatMacroExpansionError(error), as: .lines)
  }

  func testMacroExpansionError_multipleHTTPMethods() {
    let error = MacroExpansionError.multipleHTTPMethods(
      "createUser",
      found: ["@GET", "@POST"]
    )
    assertSnapshot(of: formatMacroExpansionError(error), as: .lines)
  }

  func testMacroExpansionError_missingAsyncKeyword() {
    let error = MacroExpansionError.missingAsyncKeyword("getUsers")
    assertSnapshot(of: formatMacroExpansionError(error), as: .lines)
  }

  func testMacroExpansionError_missingThrowsKeyword() {
    let error = MacroExpansionError.missingThrowsKeyword("getUsers")
    assertSnapshot(of: formatMacroExpansionError(error), as: .lines)
  }

  func testMacroExpansionError_nonDecodableReturnType() {
    let error = MacroExpansionError.nonDecodableReturnType("CustomResponse")
    assertSnapshot(of: formatMacroExpansionError(error), as: .lines)
  }

  func testMacroExpansionError_nonEncodableBodyType() {
    let error = MacroExpansionError.nonEncodableBodyType("CustomRequest")
    assertSnapshot(of: formatMacroExpansionError(error), as: .lines)
  }

  // MARK: - APIClientError

  func testAPIClientError_httpError() {
    let request = try? HTTPRequest(method: .get, url: URL(string: "https://api.example.com/users")!)
    let response = HTTPResponse(
      request: request ?? HTTPRequest(method: .get, url: URL(string: "https://example.com")!),
      status: HTTPStatus(rawValue: 404),
      headers: [:],
      body: nil
    )
    let error = APIClientError.httpError(statusCode: 404, response: response)
    assertSnapshot(of: formatAPIClientError(error), as: .lines)
  }

  func testAPIClientError_networkError() {
    struct NetworkFailure: Error, LocalizedError {
      var errorDescription: String? { "The Internet connection appears to be offline." }
    }
    let error = APIClientError.networkError(NetworkFailure())
    assertSnapshot(of: formatAPIClientError(error), as: .lines)
  }

  func testAPIClientError_decodingError() {
    struct DecodingFailure: Error, LocalizedError {
      var errorDescription: String? { "Expected Int but found String at keyPath $.id" }
    }
    let error = APIClientError.decodingError(DecodingFailure(), data: Data())
    assertSnapshot(of: formatAPIClientError(error), as: .lines)
  }

  func testAPIClientError_invalidRequest() {
    let error = APIClientError.invalidRequest("URL contains invalid characters")
    assertSnapshot(of: formatAPIClientError(error), as: .lines)
  }

  // MARK: - ActionableErrorInfo

  func testActionableErrorInfo_networkNoConnection() {
    let httpError = HTTPError(category: .network(.noConnection))
    let info = ActionableErrorInfo.analyze(httpError)
    assertSnapshot(of: formatActionableErrorInfo(info), as: .lines)
  }

  func testActionableErrorInfo_http401() {
    let httpError = HTTPError(category: .http(HTTPStatus(rawValue: 401)))
    let info = ActionableErrorInfo.analyze(httpError)
    assertSnapshot(of: formatActionableErrorInfo(info), as: .lines)
  }

  func testActionableErrorInfo_http429() {
    let httpError = HTTPError(category: .http(HTTPStatus(rawValue: 429)))
    let info = ActionableErrorInfo.analyze(httpError)
    assertSnapshot(of: formatActionableErrorInfo(info), as: .lines)
  }

  func testActionableErrorInfo_timeout() {
    let httpError = HTTPError(category: .timeout)
    let info = ActionableErrorInfo.analyze(httpError)
    assertSnapshot(of: formatActionableErrorInfo(info), as: .lines)
  }

  func testActionableErrorInfo_repeatedFailure() {
    let httpError = HTTPError(category: .network(.connectionLost))
    let context = ActionableErrorInfo.ErrorContext(
      timestamp: Date(timeIntervalSince1970: 0),
      attemptNumber: 4,
      networkCondition: .poor,
      deviceState: .normal,
      userAction: "Refreshing feed"
    )
    let info = ActionableErrorInfo.analyze(httpError, context: context)
    assertSnapshot(of: formatActionableErrorInfo(info), as: .lines)
  }

  // MARK: - Formatting Helpers

  private func formatHTTPError(_ error: HTTPError) -> String {
    """
    === HTTPError ===
    Category: \(error.category)
    Severity: \(error.severity)
    Recovery Category: \(error.recoveryCategory)

    Error Description:
    \(error.errorDescription ?? "nil")

    User Friendly Description:
    \(error.userFriendlyDescription)

    Recovery Suggestions:
    \(error.recoverySuggestions.enumerated().map { "  \($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

    Debug Description:
    \(error.debugDescription)

    Is Client Error: \(error.isClientError)
    Is Server Error: \(error.isServerError)
    Is Transient Error: \(error.isTransientError)
    """
  }

  private func formatInterceptorError(_ error: InterceptorError) -> String {
    """
    === InterceptorError ===
    Error Description:
    \(error.errorDescription ?? "nil")

    Failure Reason:
    \(error.failureReason ?? "nil")

    Recovery Suggestion:
    \(error.recoverySuggestion ?? "nil")
    """
  }

  private func formatMacroExpansionError(_ error: MacroExpansionError) -> String {
    """
    === MacroExpansionError ===
    Description:
    \(error.description)

    Error Description:
    \(error.errorDescription ?? "nil")

    Recovery Suggestion:
    \(error.recoverySuggestion ?? "nil")
    """
  }

  private func formatAPIClientError(_ error: APIClientError) -> String {
    """
    === APIClientError ===
    Description:
    \(error.description)

    Error Description:
    \(error.errorDescription ?? "nil")

    Failure Reason:
    \(error.failureReason ?? "nil")

    Recovery Suggestion:
    \(error.recoverySuggestion ?? "nil")
    """
  }

  private func formatActionableErrorInfo(_ info: ActionableErrorInfo) -> String {
    let actionsFormatted = info.recoveryActions.enumerated().map { index, action in
      """
        \(index + 1). \(action.title)
           Type: \(action.type)
           Description: \(action.description)
           Can Auto Execute: \(action.canAutoExecute)
           Estimated Duration: \(action.estimatedDuration.map { "\($0)s" } ?? "nil")
      """
    }.joined(separator: "\n")

    return """
    === ActionableErrorInfo ===
    User Message:
    \(info.userMessage)

    Technical Summary:
    \(info.technicalSummary)

    Impact Level: \(info.impactLevel)
    Confidence Level: \(info.confidenceLevel)

    Recovery Actions:
    \(actionsFormatted)
    """
  }
}
