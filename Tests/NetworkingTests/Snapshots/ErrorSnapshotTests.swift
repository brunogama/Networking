import SnapshotTesting
import XCTest
@testable import Networking

/// Snapshot tests for error message stability.
///
/// These tests capture the exact textual output of error messages to prevent
/// unintended changes to user-facing error descriptions and recovery suggestions.
final class ErrorSnapshotTests: XCTestCase {
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
