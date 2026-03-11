import NetworkingRuntime
import NetworkingTesting
import Foundation

extension ReportCollector {
  /// A collected test result.
  public struct TestResult: Sendable {
    public let id: BDDResultIdentifier
    public let featureName: BDDFeatureName
    public let scenarioName: BDDScenarioName
    public let status: Status
    public let duration: MeasurementDuration
    public let steps: [StepResult]
    public let error: BDDFailureMessage?
    public let timestamp: Date
    public let tags: [BDDTagText]

    public enum Status: Sendable, Codable {
      case passed
      case failed
      case skipped
      case pending

      public var identifier: BDDResultStatusName {
        switch self {
        case .passed: return "passed"
        case .failed: return "failed"
        case .skipped: return "skipped"
        case .pending: return "pending"
        }
      }
    }

    public init(
      id: BDDResultIdentifier = BDDResultIdentifier(),
      featureName: BDDFeatureName,
      scenarioName: BDDScenarioName,
      status: Status,
      duration: MeasurementDuration,
      steps: [StepResult],
      error: BDDFailureMessage?,
      timestamp: Date = Date(),
      tags: [BDDTagText] = []
    ) {
      self.id = id
      self.featureName = featureName
      self.scenarioName = scenarioName
      self.status = status
      self.duration = duration
      self.steps = steps
      self.error = error
      self.timestamp = timestamp
      self.tags = tags
    }
  }

  /// A collected step result.
  public struct StepResult: Sendable, Codable {
    public let keyword: BDDStepKeyword
    public let text: BDDStepText
    public let status: TestResult.Status
    public let duration: MeasurementDuration
    public let error: BDDFailureMessage?

    public init(
      keyword: BDDStepKeyword,
      text: BDDStepText,
      status: TestResult.Status,
      duration: MeasurementDuration,
      error: BDDFailureMessage?
    ) {
      self.keyword = keyword
      self.text = text
      self.status = status
      self.duration = duration
      self.error = error
    }
  }

  /// Aggregated report data.
  public struct ReportData: Sendable {
    public let title: BDDReportTitle
    public let timestamp: Date
    public let duration: MeasurementDuration
    public let features: [FeatureReport]
    public let summary: Summary

    public struct FeatureReport: Sendable {
      public let name: BDDFeatureName
      public let scenarios: [TestResult]
      public let passedCount: BDDScenarioCount
      public let failedCount: BDDScenarioCount
      public let skippedCount: BDDScenarioCount
      public let duration: MeasurementDuration
    }

    public struct Summary: Sendable {
      public let totalScenarios: BDDScenarioCount
      public let passedScenarios: BDDScenarioCount
      public let failedScenarios: BDDScenarioCount
      public let skippedScenarios: BDDScenarioCount
      public let pendingScenarios: BDDScenarioCount
      public let totalSteps: BDDStepCount
      public let passedSteps: BDDStepCount
      public let failedSteps: BDDStepCount
      public let totalDuration: MeasurementDuration
      public let passRate: BDDPassRate
    }
  }
}
