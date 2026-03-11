import NetworkingRuntime
import NetworkingTesting
import Foundation

// MARK: - JSON Report Generator

/// Generates JSON reports from test execution data.
///
/// ```swift
/// let generator = JSONReportGenerator()
/// let json = generator.generate(from: reportData)
///
/// // Write to file
/// try generator.write(to: URL(fileURLWithPath: "report.json"), from: reportData)
/// ```
public struct JSONReportGenerator: Sendable {
  // MARK: - Configuration

  /// Configuration for JSON report generation.
  public struct Configuration: Sendable {
    public enum PrettyPrintOption: Sendable {
      case enabled
      case disabled

      fileprivate var isEnabled: Bool { self == .enabled }
    }

    public enum StepInclusion: Sendable {
      case included
      case omitted

      fileprivate var includesSteps: Bool { self == .included }
    }

    public enum KeySorting: Sendable {
      case sorted
      case unsorted

      fileprivate var isSorted: Bool { self == .sorted }
    }

    /// Pretty print JSON output.
    public let prettyPrint: PrettyPrintOption

    /// Include step details.
    public let includeSteps: StepInclusion

    /// Sort keys alphabetically.
    public let sortKeys: KeySorting

    /// Creates a configuration.
    public init(
      prettyPrint: PrettyPrintOption = .enabled,
      includeSteps: StepInclusion = .included,
      sortKeys: KeySorting = .unsorted
    ) {
      self.prettyPrint = prettyPrint
      self.includeSteps = includeSteps
      self.sortKeys = sortKeys
    }

    /// Default configuration.
    public static var `default`: Self { Self() }
  }

  // MARK: - Codable Types

  /// JSON-encodable report structure.
  public struct JSONReport: Codable, Sendable {
    public let title: BDDReportTitle
    public let timestamp: UserMessageText
    public let duration: MeasurementDuration
    public let summary: Summary
    public let features: [Feature]

    public struct Summary: Codable, Sendable {
      public let totalScenarios: BDDScenarioCount
      public let passed: BDDScenarioCount
      public let failed: BDDScenarioCount
      public let skipped: BDDScenarioCount
      public let pending: BDDScenarioCount
      public let totalSteps: BDDStepCount
      public let passedSteps: BDDStepCount
      public let failedSteps: BDDStepCount
      public let totalDuration: MeasurementDuration
      public let passRate: BDDPassRate
    }

    public struct Feature: Codable, Sendable {
      public let name: BDDFeatureName
      public let passedCount: BDDScenarioCount
      public let failedCount: BDDScenarioCount
      public let skippedCount: BDDScenarioCount
      public let duration: MeasurementDuration
      public let scenarios: [Scenario]
    }

    public struct Scenario: Codable, Sendable {
      public let id: BDDResultIdentifier
      public let name: BDDScenarioName
      public let status: UserMessageText
      public let duration: MeasurementDuration
      public let tags: [BDDTagText]
      public let error: BDDFailureMessage?
      public let steps: [Step]?
    }

    public struct Step: Codable, Sendable {
      public let keyword: BDDStepKeyword
      public let text: BDDStepText
      public let status: UserMessageText
      public let duration: MeasurementDuration
      public let error: BDDFailureMessage?
    }
  }

  // MARK: - Properties

  private let configuration: Configuration

  // MARK: - Initialization

  /// Creates a JSON report generator.
  ///
  /// - Parameter configuration: Generation configuration
  public init(configuration: Configuration = .default) {
    self.configuration = configuration
  }

  // MARK: - Generation

  /// Generates a JSON report.
  ///
  /// - Parameter data: Report data from collector
  /// - Returns: JSON formatted string
  public func generate(from data: ReportCollector.ReportData) throws -> UserMessageText {
    let jsonReport = buildReport(from: data)

    let encoder = JSONEncoder()
    if configuration.prettyPrint.isEnabled {
      encoder.outputFormatting = [.prettyPrinted]
    }
    if configuration.sortKeys.isSorted {
      encoder.outputFormatting.insert(.sortedKeys)
    }

    let jsonData = try encoder.encode(jsonReport)
    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
      throw BDDError.reportGenerationFailed(reason: UserMessageText("Failed to encode JSON"))
    }

    return UserMessageText(jsonString)
  }

  /// Generates JSON data.
  ///
  /// - Parameter data: Report data from collector
  /// - Returns: JSON data
  public func generateData(from data: ReportCollector.ReportData) throws -> HTTPBody {
    let jsonReport = buildReport(from: data)

    let encoder = JSONEncoder()
    if configuration.prettyPrint.isEnabled {
      encoder.outputFormatting = [.prettyPrinted]
    }
    if configuration.sortKeys.isSorted {
      encoder.outputFormatting.insert(.sortedKeys)
    }

    return HTTPBody(try encoder.encode(jsonReport))
  }

  /// Writes a JSON report to file.
  ///
  /// - Parameters:
  ///   - url: File URL to write to
  ///   - data: Report data
  public func write(to url: BDDFileURL, from data: ReportCollector.ReportData) throws {
    let jsonData = try generateData(from: data)
    try jsonData.rawValue.write(to: url.rawValue)
  }

  // MARK: - Private Methods

  private func buildReport(from data: ReportCollector.ReportData) -> JSONReport {
    let formatter = ISO8601DateFormatter()

    return JSONReport(
      title: data.title,
      timestamp: UserMessageText(formatter.string(from: data.timestamp)),
      duration: data.duration,
      summary: buildSummary(from: data.summary),
      features: data.features.map(buildFeature(from:))
    )
  }

  private func buildSummary(
    from summary: ReportCollector.ReportData.Summary
  ) -> JSONReport.Summary {
    JSONReport.Summary(
      totalScenarios: summary.totalScenarios,
      passed: summary.passedScenarios,
      failed: summary.failedScenarios,
      skipped: summary.skippedScenarios,
      pending: summary.pendingScenarios,
      totalSteps: summary.totalSteps,
      passedSteps: summary.passedSteps,
      failedSteps: summary.failedSteps,
      totalDuration: summary.totalDuration,
      passRate: summary.passRate
    )
  }

  private func buildFeature(
    from feature: ReportCollector.ReportData.FeatureReport
  ) -> JSONReport.Feature {
    JSONReport.Feature(
      name: feature.name,
      passedCount: feature.passedCount,
      failedCount: feature.failedCount,
      skippedCount: feature.skippedCount,
      duration: feature.duration,
      scenarios: feature.scenarios.map(buildScenario(from:))
    )
  }

  private func buildScenario(from scenario: ReportCollector.TestResult) -> JSONReport.Scenario {
    JSONReport.Scenario(
      id: scenario.id,
      name: scenario.scenarioName,
      status: UserMessageText(scenario.status.identifier.rawValue),
      duration: scenario.duration,
      tags: scenario.tags,
      error: scenario.error,
      steps: buildSteps(from: scenario.steps)
    )
  }

  private func buildSteps(
    from steps: [ReportCollector.StepResult]
  ) -> [JSONReport.Step]? {
    guard configuration.includeSteps.includesSteps else {
      return nil
    }

    return steps.map { step in
      JSONReport.Step(
        keyword: step.keyword,
        text: step.text,
        status: UserMessageText(step.status.identifier.rawValue),
        duration: step.duration,
        error: step.error
      )
    }
  }
}
