import NetworkingRuntime
import NetworkingTesting
import Foundation

/// Result of executing a single step.
public enum StepResult: Sendable {
  /// Step passed successfully.
  case passed(duration: MeasurementDuration)

  /// Step failed with an error.
  case failed(error: Error, duration: MeasurementDuration)

  /// Step was skipped.
  case skipped(reason: UserMessageText)

  /// Step is pending implementation.
  case pending

  /// Whether the step passed.
  public var isPassed: BDDPassedFlag {
    if case .passed = self { return true }
    return false
  }

  /// Whether the step failed.
  public var isFailed: BDDFailedFlag {
    if case .failed = self { return true }
    return false
  }

  /// The duration of step execution (if applicable).
  public var duration: MeasurementDuration? {
    switch self {
    case .passed(let durationValue): return durationValue
    case .failed(_, let durationValue): return durationValue
    default: return nil
    }
  }

  /// The error if the step failed.
  public var error: Error? {
    if case .failed(let error, _) = self { return error }
    return nil
  }
}

/// Result of executing a scenario.
public struct ScenarioResult: Sendable {
  /// The scenario that was executed.
  public let scenario: GherkinScenario

  /// Results for each step.
  public let stepResults: [StepResultEntry]

  /// Total duration.
  public let duration: MeasurementDuration

  /// Whether all steps passed.
  public var passed: BDDPassedFlag {
    BDDPassedFlag(stepResults.allSatisfy { $0.result.isPassed.rawValue })
  }

  /// The first error encountered.
  public var error: Error? {
    stepResults.compactMap { $0.result.error }.first
  }

  /// Number of passed steps.
  public var passedCount: BDDStepCount {
    BDDStepCount(stepResults.filter { $0.result.isPassed.rawValue }.count)
  }

  /// Number of failed steps.
  public var failedCount: BDDStepCount {
    BDDStepCount(stepResults.filter { $0.result.isFailed.rawValue }.count)
  }

  /// Creates a new scenario result.
  public init(
    scenario: GherkinScenario,
    stepResults: [StepResultEntry],
    duration: MeasurementDuration
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

/// Result of executing a feature.
public struct FeatureResult: Sendable {
  /// The feature that was executed.
  public let feature: GherkinFeature

  /// Results for each scenario.
  public let scenarioResults: [ScenarioResult]

  /// Total duration.
  public let duration: MeasurementDuration

  /// Whether all scenarios passed.
  public var passed: BDDPassedFlag {
    BDDPassedFlag(scenarioResults.allSatisfy { $0.passed.rawValue })
  }

  /// Number of passed scenarios.
  public var passedCount: BDDScenarioCount {
    BDDScenarioCount(scenarioResults.filter { $0.passed.rawValue }.count)
  }

  /// Number of failed scenarios.
  public var failedCount: BDDScenarioCount {
    BDDScenarioCount(scenarioResults.filter { !$0.passed.rawValue }.count)
  }

  /// Creates a new feature result.
  public init(
    feature: GherkinFeature,
    scenarioResults: [ScenarioResult],
    duration: MeasurementDuration
  ) {
    self.feature = feature
    self.scenarioResults = scenarioResults
    self.duration = duration
  }
}
