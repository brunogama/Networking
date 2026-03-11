import NetworkingRuntime
import NetworkingTesting
import Foundation

// MARK: - BDD Error Types

/// Errors that can occur during BDD test execution.
public enum BDDError: Error, LocalizedError, Sendable {
  // MARK: - Step Execution Errors

  /// No step definition found for the given step text.
  case undefinedStep(BDDStepText)

  /// Multiple step definitions match the given step text.
  case ambiguousStep(BDDStepText, matchCount: RequestCount)

  /// Step execution failed with an error.
  case stepExecutionFailed(step: BDDStepText, underlyingError: Error)

  /// Step timed out during execution.
  case stepTimeout(step: BDDStepText, duration: MeasurementDuration)

  /// Step was skipped (pending implementation).
  case pendingStep(BDDStepText)

  // MARK: - Context Errors

  /// Required context value is missing.
  case missingContextValue(key: BDDContextKeyName)

  /// Context value has wrong type.
  case invalidContextType(
    key: BDDContextKeyName,
    expected: UserMessageText,
    actual: UserMessageText
  )

  /// No response available in context.
  case noResponse

  /// No request available in context.
  case noRequest

  /// No body available in response.
  case noBody

  // MARK: - Assertion Errors

  /// Status code mismatch.
  case statusMismatch(expected: HTTPStatusCode, actual: HTTPStatusCode)

  /// Response was not successful (2xx).
  case notSuccessful(status: HTTPStatusCode)

  /// Missing header in response.
  case missingHeader(HTTPHeaderName)

  /// Header value mismatch.
  case headerValueMismatch(
    header: HTTPHeaderName,
    expected: HTTPHeaderValue,
    actual: HTTPHeaderValue
  )

  /// Body does not contain expected content.
  case bodyDoesNotContain(HTTPResponseText)

  /// Body decode mismatch.
  case bodyDecodeMismatch(expected: UserMessageText, actual: UserMessageText)

  /// Expected an error but none occurred.
  case expectedError(HTTPError.Category)

  /// Wrong error category.
  case wrongErrorCategory(expected: HTTPError.Category, actual: HTTPError.Category)

  /// Expected a timeout error.
  case expectedTimeout

  // MARK: - Parser Errors

  /// Unexpected token during parsing.
  case unexpectedToken(
    expected: UserMessageText,
    found: UserMessageText,
    location: GherkinSourceLocation
  )

  /// Unterminated doc string.
  case unterminatedDocString(location: GherkinSourceLocation)

  /// Invalid table row.
  case invalidTableRow(location: GherkinSourceLocation)

  /// Missing feature declaration.
  case missingFeature

  /// Duplicate background declaration.
  case duplicateBackground(location: GherkinSourceLocation)

  /// Invalid examples section.
  case invalidExamples(reason: UserMessageText, location: GherkinSourceLocation)

  /// General syntax error.
  case syntaxError(message: UserMessageText, location: GherkinSourceLocation)

  /// File not found.
  case fileNotFound(path: BDDSourceFilePath)

  /// Failed to read file.
  case fileReadError(path: BDDSourceFilePath, underlyingError: Error)

  // MARK: - Registry Errors

  /// Invalid step pattern regex.
  case invalidStepPattern(pattern: BDDStepPattern, error: UserMessageText)

  /// Step definition already registered.
  case duplicateStepDefinition(pattern: BDDStepPattern)

  // MARK: - Configuration Errors

  /// Missing required configuration.
  case missingConfiguration(UserMessageText)

  /// Invalid configuration value.
  case invalidConfiguration(key: UserMessageText, reason: UserMessageText)

  // MARK: - Scenario Errors

  /// No scenarios found in feature.
  case noScenarios

  /// Scenario was filtered out by tags.
  case scenarioSkipped(name: BDDScenarioName, reason: UserMessageText)

  // MARK: - Doc String Errors

  /// Expected a doc string but none was provided.
  case missingDocString

  // MARK: - Reporting Errors

  /// Report generation failed.
  case reportGenerationFailed(reason: UserMessageText)

  // MARK: - LocalizedError

  public var errorDescription: String? {
    switch self {
    case .undefinedStep(let text):
      return "Undefined step: '\(text.rawValue)'. No matching step definition found."

    case .ambiguousStep(let text, let count):
      return "Ambiguous step: '\(text.rawValue)' matches \(count.rawValue) step definitions."

    case .stepExecutionFailed(let step, let error):
      return "Step '\(step.rawValue)' failed: \(error.localizedDescription)"

    case .stepTimeout(let step, let duration):
      return "Step '\(step.rawValue)' timed out after \(duration.rawValue) seconds."

    case .pendingStep(let text):
      return "Pending step: '\(text.rawValue)' is not yet implemented."

    case .missingContextValue(let key):
      return "Missing context value for key: '\(key.rawValue)'."

    case .invalidContextType(let key, let expected, let actual):
      return
        "Invalid type for context key '\(key.rawValue)': expected \(expected.rawValue), got \(actual.rawValue)."

    case .noResponse:
      return "No response available. Ensure a request has been executed."

    case .noRequest:
      return "No request available in context."

    case .noBody:
      return "Response has no body."

    case .statusMismatch(let expected, let actual):
      return "Status mismatch: expected \(expected.rawValue), got \(actual.rawValue)."

    case .notSuccessful(let status):
      return "Response was not successful: status \(status.rawValue)."

    case .missingHeader(let name):
      return "Missing header: '\(name.rawValue)'."

    case .headerValueMismatch(let header, let expected, let actual):
      return
        "Header '\(header.rawValue)' mismatch: expected '\(expected.rawValue)', got '\(actual.rawValue)'."

    case .bodyDoesNotContain(let content):
      return "Body does not contain: '\(content.rawValue)'."

    case .bodyDecodeMismatch(let expected, let actual):
      return
        "Decoded body mismatch: expected '\(expected.rawValue)', got '\(actual.rawValue)'."

    case .expectedError(let category):
      return "Expected error with category: \(category)."

    case .wrongErrorCategory(let expected, let actual):
      return "Wrong error category: expected \(expected), got \(actual)."

    case .expectedTimeout:
      return "Expected a timeout error."

    case .unexpectedToken(let expected, let found, let location):
      return
        "Unexpected token at \(location.description): expected \(expected.rawValue), found '\(found.rawValue)'."

    case .unterminatedDocString(let location):
      return "Unterminated doc string at \(location.description)."

    case .invalidTableRow(let location):
      return "Invalid table row at \(location.description)."

    case .missingFeature:
      return "No Feature declaration found in file."

    case .duplicateBackground(let location):
      return
        "Duplicate Background at \(location.description). Only one Background per Feature is allowed."

    case .invalidExamples(let reason, let location):
      return "Invalid Examples at \(location.description): \(reason.rawValue)."

    case .syntaxError(let message, let location):
      return "Syntax error at \(location.description): \(message.rawValue)."

    case .fileNotFound(let path):
      return "File not found: '\(path.rawValue)'."

    case .fileReadError(let path, let error):
      return "Failed to read file '\(path.rawValue)': \(error.localizedDescription)."

    case .invalidStepPattern(let pattern, let error):
      return "Invalid step pattern '\(pattern.rawValue)': \(error.rawValue)."

    case .duplicateStepDefinition(let pattern):
      return "Duplicate step definition for pattern: '\(pattern.rawValue)'."

    case .missingConfiguration(let key):
      return "Missing required configuration: '\(key.rawValue)'."

    case .invalidConfiguration(let key, let reason):
      return "Invalid configuration '\(key.rawValue)': \(reason.rawValue)."

    case .noScenarios:
      return "No scenarios found in feature."

    case .scenarioSkipped(let name, let reason):
      return "Scenario '\(name.rawValue)' skipped: \(reason.rawValue)."

    case .missingDocString:
      return "Expected a doc string but none was provided."

    case .reportGenerationFailed(let reason):
      return "Report generation failed: \(reason.rawValue)."
    }
  }

  public var failureReason: String? {
    errorDescription
  }

  public var recoverySuggestion: String? {
    switch self {
    case .undefinedStep:
      return "Create a step definition that matches this step text."

    case .ambiguousStep:
      return "Make step patterns more specific to avoid ambiguity."

    case .stepExecutionFailed:
      return "Check the step implementation for errors."

    case .stepTimeout:
      return "Increase the timeout or optimize the step implementation."

    case .pendingStep:
      return "Implement the step definition."

    case .missingContextValue:
      return "Ensure previous steps set this value in the context."

    case .noResponse:
      return "Add a 'When' step that executes a request before assertions."

    case .statusMismatch, .notSuccessful:
      return "Check the mock configuration or expected status code."

    case .missingHeader:
      return "Ensure the server returns the expected header."

    case .fileNotFound:
      return "Check the file path and ensure the file exists."

    case .syntaxError, .unexpectedToken:
      return "Check the Gherkin syntax in your feature file."

    default:
      return nil
    }
  }
}
