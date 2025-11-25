import Foundation

// MARK: - BDD Error Types

/// Errors that can occur during BDD test execution.
public enum BDDError: Error, LocalizedError, Sendable {
  // MARK: - Step Execution Errors

  /// No step definition found for the given step text.
  case undefinedStep(String)

  /// Multiple step definitions match the given step text.
  case ambiguousStep(String, matchCount: Int)

  /// Step execution failed with an error.
  case stepExecutionFailed(step: String, underlyingError: Error)

  /// Step timed out during execution.
  case stepTimeout(step: String, duration: TimeInterval)

  /// Step was skipped (pending implementation).
  case pendingStep(String)

  // MARK: - Context Errors

  /// Required context value is missing.
  case missingContextValue(key: String)

  /// Context value has wrong type.
  case invalidContextType(key: String, expected: String, actual: String)

  /// No response available in context.
  case noResponse

  /// No request available in context.
  case noRequest

  /// No body available in response.
  case noBody

  // MARK: - Assertion Errors

  /// Status code mismatch.
  case statusMismatch(expected: Int, actual: Int)

  /// Response was not successful (2xx).
  case notSuccessful(status: Int)

  /// Missing header in response.
  case missingHeader(String)

  /// Header value mismatch.
  case headerValueMismatch(header: String, expected: String, actual: String)

  /// Body does not contain expected content.
  case bodyDoesNotContain(String)

  /// Body decode mismatch.
  case bodyDecodeMismatch(expected: String, actual: String)

  /// Expected an error but none occurred.
  case expectedError(HTTPError.Category)

  /// Wrong error category.
  case wrongErrorCategory(expected: HTTPError.Category, actual: HTTPError.Category)

  /// Expected a timeout error.
  case expectedTimeout

  // MARK: - Parser Errors

  /// Unexpected token during parsing.
  case unexpectedToken(expected: String, found: String, location: GherkinSourceLocation)

  /// Unterminated doc string.
  case unterminatedDocString(location: GherkinSourceLocation)

  /// Invalid table row.
  case invalidTableRow(location: GherkinSourceLocation)

  /// Missing feature declaration.
  case missingFeature

  /// Duplicate background declaration.
  case duplicateBackground(location: GherkinSourceLocation)

  /// Invalid examples section.
  case invalidExamples(reason: String, location: GherkinSourceLocation)

  /// General syntax error.
  case syntaxError(message: String, location: GherkinSourceLocation)

  /// File not found.
  case fileNotFound(path: String)

  /// Failed to read file.
  case fileReadError(path: String, underlyingError: Error)

  // MARK: - Registry Errors

  /// Invalid step pattern regex.
  case invalidStepPattern(pattern: String, error: String)

  /// Step definition already registered.
  case duplicateStepDefinition(pattern: String)

  // MARK: - Configuration Errors

  /// Missing required configuration.
  case missingConfiguration(String)

  /// Invalid configuration value.
  case invalidConfiguration(key: String, reason: String)

  // MARK: - Scenario Errors

  /// No scenarios found in feature.
  case noScenarios

  /// Scenario was filtered out by tags.
  case scenarioSkipped(name: String, reason: String)

  // MARK: - Doc String Errors

  /// Expected a doc string but none was provided.
  case missingDocString

  // MARK: - Reporting Errors

  /// Report generation failed.
  case reportGenerationFailed(reason: String)

  // MARK: - LocalizedError

  public var errorDescription: String? {
    switch self {
    case .undefinedStep(let text):
      return "Undefined step: '\(text)'. No matching step definition found."

    case .ambiguousStep(let text, let count):
      return "Ambiguous step: '\(text)' matches \(count) step definitions."

    case .stepExecutionFailed(let step, let error):
      return "Step '\(step)' failed: \(error.localizedDescription)"

    case .stepTimeout(let step, let duration):
      return "Step '\(step)' timed out after \(duration) seconds."

    case .pendingStep(let text):
      return "Pending step: '\(text)' is not yet implemented."

    case .missingContextValue(let key):
      return "Missing context value for key: '\(key)'."

    case .invalidContextType(let key, let expected, let actual):
      return "Invalid type for context key '\(key)': expected \(expected), got \(actual)."

    case .noResponse:
      return "No response available. Ensure a request has been executed."

    case .noRequest:
      return "No request available in context."

    case .noBody:
      return "Response has no body."

    case .statusMismatch(let expected, let actual):
      return "Status mismatch: expected \(expected), got \(actual)."

    case .notSuccessful(let status):
      return "Response was not successful: status \(status)."

    case .missingHeader(let name):
      return "Missing header: '\(name)'."

    case .headerValueMismatch(let header, let expected, let actual):
      return "Header '\(header)' mismatch: expected '\(expected)', got '\(actual)'."

    case .bodyDoesNotContain(let content):
      return "Body does not contain: '\(content)'."

    case .bodyDecodeMismatch(let expected, let actual):
      return "Decoded body mismatch: expected '\(expected)', got '\(actual)'."

    case .expectedError(let category):
      return "Expected error with category: \(category)."

    case .wrongErrorCategory(let expected, let actual):
      return "Wrong error category: expected \(expected), got \(actual)."

    case .expectedTimeout:
      return "Expected a timeout error."

    case .unexpectedToken(let expected, let found, let location):
      return "Unexpected token at \(location.description): expected \(expected), found '\(found)'."

    case .unterminatedDocString(let location):
      return "Unterminated doc string at \(location.description)."

    case .invalidTableRow(let location):
      return "Invalid table row at \(location.description)."

    case .missingFeature:
      return "No Feature declaration found in file."

    case .duplicateBackground(let location):
      return "Duplicate Background at \(location.description). Only one Background per Feature is allowed."

    case .invalidExamples(let reason, let location):
      return "Invalid Examples at \(location.description): \(reason)."

    case .syntaxError(let message, let location):
      return "Syntax error at \(location.description): \(message)."

    case .fileNotFound(let path):
      return "File not found: '\(path)'."

    case .fileReadError(let path, let error):
      return "Failed to read file '\(path)': \(error.localizedDescription)."

    case .invalidStepPattern(let pattern, let error):
      return "Invalid step pattern '\(pattern)': \(error)."

    case .duplicateStepDefinition(let pattern):
      return "Duplicate step definition for pattern: '\(pattern)'."

    case .missingConfiguration(let key):
      return "Missing required configuration: '\(key)'."

    case .invalidConfiguration(let key, let reason):
      return "Invalid configuration '\(key)': \(reason)."

    case .noScenarios:
      return "No scenarios found in feature."

    case .scenarioSkipped(let name, let reason):
      return "Scenario '\(name)' skipped: \(reason)."

    case .missingDocString:
      return "Expected a doc string but none was provided."

    case .reportGenerationFailed(let reason):
      return "Report generation failed: \(reason)."
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

// MARK: - Step Result

/// Result of executing a single step.
public enum StepResult: Sendable {
  /// Step passed successfully.
  case passed(duration: TimeInterval)

  /// Step failed with an error.
  case failed(error: Error, duration: TimeInterval)

  /// Step was skipped.
  case skipped(reason: String)

  /// Step is pending implementation.
  case pending

  /// Whether the step passed.
  public var isPassed: Bool {
    if case .passed = self { return true }
    return false
  }

  /// Whether the step failed.
  public var isFailed: Bool {
    if case .failed = self { return true }
    return false
  }

  /// The duration of step execution (if applicable).
  public var duration: TimeInterval? {
    switch self {
    case .passed(let d): return d
    case .failed(_, let d): return d
    default: return nil
    }
  }

  /// The error if the step failed.
  public var error: Error? {
    if case .failed(let error, _) = self { return error }
    return nil
  }
}

// MARK: - Scenario Result

/// Result of executing a scenario.
public struct ScenarioResult: Sendable {
  /// The scenario that was executed.
  public let scenario: GherkinScenario

  /// Results for each step.
  public let stepResults: [StepResultEntry]

  /// Total duration.
  public let duration: TimeInterval

  /// Whether all steps passed.
  public var passed: Bool {
    stepResults.allSatisfy { $0.result.isPassed }
  }

  /// The first error encountered.
  public var error: Error? {
    stepResults.compactMap { $0.result.error }.first
  }

  /// Number of passed steps.
  public var passedCount: Int {
    stepResults.filter { $0.result.isPassed }.count
  }

  /// Number of failed steps.
  public var failedCount: Int {
    stepResults.filter { $0.result.isFailed }.count
  }

  /// Creates a new scenario result.
  public init(
    scenario: GherkinScenario,
    stepResults: [StepResultEntry],
    duration: TimeInterval
  ) {
    self.scenario = scenario
    self.stepResults = stepResults
    self.duration = duration
  }
}

/// Entry linking a step to its result.
public struct StepResultEntry: Sendable {
  /// The step that was executed.
  public let step: GherkinStep

  /// The result of execution.
  public let result: StepResult

  /// Creates a new step result entry.
  public init(step: GherkinStep, result: StepResult) {
    self.step = step
    self.result = result
  }
}

// MARK: - Feature Result

/// Result of executing a feature.
public struct FeatureResult: Sendable {
  /// The feature that was executed.
  public let feature: GherkinFeature

  /// Results for each scenario.
  public let scenarioResults: [ScenarioResult]

  /// Total duration.
  public let duration: TimeInterval

  /// Whether all scenarios passed.
  public var passed: Bool {
    scenarioResults.allSatisfy { $0.passed }
  }

  /// Number of passed scenarios.
  public var passedCount: Int {
    scenarioResults.filter { $0.passed }.count
  }

  /// Number of failed scenarios.
  public var failedCount: Int {
    scenarioResults.filter { !$0.passed }.count
  }

  /// Creates a new feature result.
  public init(
    feature: GherkinFeature,
    scenarioResults: [ScenarioResult],
    duration: TimeInterval
  ) {
    self.feature = feature
    self.scenarioResults = scenarioResults
    self.duration = duration
  }
}
