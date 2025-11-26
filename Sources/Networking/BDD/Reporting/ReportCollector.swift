import Foundation

// MARK: - Report Collector

/// Collects test execution results for reporting.
///
/// The collector aggregates results from multiple scenario executions
/// and provides data for report generation.
///
/// ```swift
/// let collector = ReportCollector()
///
/// // Record scenario results
/// collector.recordScenario(
///   feature: "User API",
///   scenario: "Fetch user",
///   status: .passed,
///   duration: 0.5,
///   steps: stepResults
/// )
///
/// // Generate report
/// let report = collector.generateReport()
/// ```
public final class ReportCollector: @unchecked Sendable {
  // MARK: - Types

  /// A collected test result.
  public struct TestResult: Sendable {
    public let id: UUID
    public let featureName: String
    public let scenarioName: String
    public let status: Status
    public let duration: TimeInterval
    public let steps: [StepResult]
    public let error: String?
    public let timestamp: Date
    public let tags: [String]

    public enum Status: String, Sendable, Codable {
      case passed
      case failed
      case skipped
      case pending
    }

    public init(
      id: UUID = UUID(),
      featureName: String,
      scenarioName: String,
      status: Status,
      duration: TimeInterval,
      steps: [StepResult],
      error: String?,
      timestamp: Date = Date(),
      tags: [String] = []
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
    public let keyword: String
    public let text: String
    public let status: TestResult.Status
    public let duration: TimeInterval
    public let error: String?

    public init(
      keyword: String,
      text: String,
      status: TestResult.Status,
      duration: TimeInterval,
      error: String?
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
    public let title: String
    public let timestamp: Date
    public let duration: TimeInterval
    public let features: [FeatureReport]
    public let summary: Summary

    public struct FeatureReport: Sendable {
      public let name: String
      public let scenarios: [TestResult]
      public let passedCount: Int
      public let failedCount: Int
      public let skippedCount: Int
      public let duration: TimeInterval
    }

    public struct Summary: Sendable {
      public let totalScenarios: Int
      public let passedScenarios: Int
      public let failedScenarios: Int
      public let skippedScenarios: Int
      public let pendingScenarios: Int
      public let totalSteps: Int
      public let passedSteps: Int
      public let failedSteps: Int
      public let totalDuration: TimeInterval
      public let passRate: Double
    }
  }

  // MARK: - Properties

  private let lock = NSLock()
  private var results: [TestResult] = []
  private var startTime: Date?
  private var endTime: Date?
  private let title: String

  // MARK: - Initialization

  /// Creates a report collector.
  ///
  /// - Parameter title: Title for the generated report
  public init(title: String = "BDD Test Report") {
    self.title = title
  }

  // MARK: - Recording

  /// Starts the test run timer.
  public func startRun() {
    lock.withLock {
      startTime = Date()
      results.removeAll()
    }
  }

  /// Ends the test run timer.
  public func endRun() {
    lock.withLock {
      endTime = Date()
    }
  }

  /// Records a scenario result.
  ///
  /// - Parameters:
  ///   - feature: Feature name
  ///   - scenario: Scenario name
  ///   - status: Execution status
  ///   - duration: Execution duration
  ///   - steps: Step results
  ///   - error: Error message if failed
  ///   - tags: Scenario tags
  public func recordScenario(
    feature: String,
    scenario: String,
    status: TestResult.Status,
    duration: TimeInterval,
    steps: [StepResult],
    error: String? = nil,
    tags: [String] = []
  ) {
    let result = TestResult(
      featureName: feature,
      scenarioName: scenario,
      status: status,
      duration: duration,
      steps: steps,
      error: error,
      tags: tags
    )

    lock.withLock {
      results.append(result)
    }
  }

  /// Records a result from BDDTestRunner.
  public func record(_ result: BDDTestRunner.ScenarioResult) {
    let steps = result.steps.map { step in
      StepResult(
        keyword: step.keyword,
        text: step.text,
        status: mapStatus(step.status),
        duration: step.duration,
        error: step.error?.localizedDescription
      )
    }

    recordScenario(
      feature: result.featureName,
      scenario: result.scenarioName,
      status: mapStatus(result.status),
      duration: result.duration,
      steps: steps,
      error: result.error?.localizedDescription
    )
  }

  private func mapStatus(_ status: BDDTestRunner.ScenarioResult.Status) -> TestResult.Status {
    switch status {
    case .passed: return .passed
    case .failed: return .failed
    case .skipped: return .skipped
    case .pending: return .pending
    }
  }

  // MARK: - Report Generation

  /// Generates aggregated report data.
  ///
  /// - Returns: Report data for rendering
  public func generateReport() -> ReportData {
    let currentResults = lock.withLock { results }
    let start = lock.withLock { startTime ?? Date() }
    let end = lock.withLock { endTime ?? Date() }

    // Group by feature
    let groupedByFeature = Dictionary(grouping: currentResults) { $0.featureName }

    let features = groupedByFeature.map { featureName, scenarios in
      ReportData.FeatureReport(
        name: featureName,
        scenarios: scenarios,
        passedCount: scenarios.filter { $0.status == .passed }.count,
        failedCount: scenarios.filter { $0.status == .failed }.count,
        skippedCount: scenarios.filter { $0.status == .skipped }.count,
        duration: scenarios.reduce(0) { $0 + $1.duration }
      )
    }.sorted { $0.name < $1.name }

    // Calculate summary
    let totalScenarios = currentResults.count
    let passedScenarios = currentResults.filter { $0.status == .passed }.count
    let failedScenarios = currentResults.filter { $0.status == .failed }.count
    let skippedScenarios = currentResults.filter { $0.status == .skipped }.count
    let pendingScenarios = currentResults.filter { $0.status == .pending }.count

    let allSteps = currentResults.flatMap { $0.steps }
    let totalSteps = allSteps.count
    let passedSteps = allSteps.filter { $0.status == .passed }.count
    let failedSteps = allSteps.filter { $0.status == .failed }.count

    let totalDuration = end.timeIntervalSince(start)
    let passRate = totalScenarios > 0 ? Double(passedScenarios) / Double(totalScenarios) * 100 : 0

    let summary = ReportData.Summary(
      totalScenarios: totalScenarios,
      passedScenarios: passedScenarios,
      failedScenarios: failedScenarios,
      skippedScenarios: skippedScenarios,
      pendingScenarios: pendingScenarios,
      totalSteps: totalSteps,
      passedSteps: passedSteps,
      failedSteps: failedSteps,
      totalDuration: totalDuration,
      passRate: passRate
    )

    return ReportData(
      title: title,
      timestamp: start,
      duration: totalDuration,
      features: features,
      summary: summary
    )
  }

  /// Clears all collected results.
  public func clear() {
    lock.withLock {
      results.removeAll()
      startTime = nil
      endTime = nil
    }
  }

  /// Returns all collected results.
  public func getAllResults() -> [TestResult] {
    lock.withLock { results }
  }
}
