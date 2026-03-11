import NetworkingRuntime
import NetworkingTesting
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
///
/// - Note: `@unchecked Sendable` justification:
///   All mutable state (`results` array) is protected by an internal `NSLock`.
///   All public methods synchronize access through this lock.
public final class ReportCollector: @unchecked Sendable {
  // MARK: - Properties

  private struct Snapshot {
    let results: [TestResult]
    let start: Date
    let end: Date
  }

  private let lock = NSLock()
  private var results: [TestResult] = []
  private var startTime: Date?
  private var endTime: Date?
  private let title: BDDReportTitle

  // MARK: - Initialization

  /// Creates a report collector.
  ///
  /// - Parameter title: Title for the generated report
  public init(title: BDDReportTitle = BDDReportTitle(rawValue: "BDD Test Report")) {
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

  // swiftlint:disable function_parameter_count
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
    feature: BDDFeatureName,
    scenario: BDDScenarioName,
    status: TestResult.Status,
    duration: MeasurementDuration,
    steps: [StepResult],
    error: BDDFailureMessage? = nil,
    tags: [BDDTagText] = []
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
  // swiftlint:enable function_parameter_count

  /// Records a result from BDDTestRunner.
  public func record(_ result: BDDTestRunner.ScenarioResult) {
    let steps = result.steps.map { step in
      StepResult(
        keyword: step.keyword,
        text: step.text,
        status: mapStatus(step.status),
        duration: step.duration,
        error: step.error.map { BDDFailureMessage($0.localizedDescription) }
      )
    }

    recordScenario(
      feature: result.featureName,
      scenario: result.scenarioName,
      status: mapStatus(result.status),
      duration: result.duration,
      steps: steps,
      error: result.error.map { BDDFailureMessage($0.localizedDescription) }
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
    let snapshot = reportSnapshot()
    let features = featureReports(from: snapshot.results)
    let summary = buildSummary(from: snapshot.results, start: snapshot.start, end: snapshot.end)

    return ReportData(
      title: title,
      timestamp: snapshot.start,
      duration: summary.totalDuration,
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

  private func reportSnapshot() -> Snapshot {
    lock.withLock {
      Snapshot(results: results, start: startTime ?? Date(), end: endTime ?? Date())
    }
  }

  private func featureReports(from currentResults: [TestResult]) -> [ReportData.FeatureReport] {
    let groupedByFeature = Dictionary(grouping: currentResults) { $0.featureName }

    return
      groupedByFeature
      .map(buildFeatureReport(name:scenarios:))
      .sorted { $0.name < $1.name }
  }

  private func buildFeatureReport(
    name featureName: BDDFeatureName,
    scenarios: [TestResult]
  ) -> ReportData.FeatureReport {
    ReportData.FeatureReport(
      name: featureName,
      scenarios: scenarios,
      passedCount: scenarioCount(with: .passed, in: scenarios),
      failedCount: scenarioCount(with: .failed, in: scenarios),
      skippedCount: scenarioCount(with: .skipped, in: scenarios),
      duration: scenarios.reduce(MeasurementDuration(0)) { $0 + $1.duration }
    )
  }

  private func buildSummary(
    from currentResults: [TestResult],
    start: Date,
    end: Date
  ) -> ReportData.Summary {
    let totalScenarios = BDDScenarioCount(currentResults.count)
    let passedScenarios = scenarioCount(with: .passed, in: currentResults)
    let failedScenarios = scenarioCount(with: .failed, in: currentResults)
    let skippedScenarios = scenarioCount(with: .skipped, in: currentResults)
    let pendingScenarios = scenarioCount(with: .pending, in: currentResults)
    let allSteps = currentResults.flatMap(\.steps)
    let totalDuration = MeasurementDuration(end.timeIntervalSince(start))

    return ReportData.Summary(
      totalScenarios: totalScenarios,
      passedScenarios: passedScenarios,
      failedScenarios: failedScenarios,
      skippedScenarios: skippedScenarios,
      pendingScenarios: pendingScenarios,
      totalSteps: BDDStepCount(allSteps.count),
      passedSteps: stepCount(with: .passed, in: allSteps),
      failedSteps: stepCount(with: .failed, in: allSteps),
      totalDuration: totalDuration,
      passRate: calculatePassRate(passed: passedScenarios, total: totalScenarios)
    )
  }

  private func scenarioCount(
    with status: TestResult.Status,
    in scenarios: [TestResult]
  ) -> BDDScenarioCount {
    BDDScenarioCount(scenarios.filter { $0.status == status }.count)
  }

  private func stepCount(
    with status: TestResult.Status,
    in steps: [StepResult]
  ) -> BDDStepCount {
    BDDStepCount(steps.filter { $0.status == status }.count)
  }

  private func calculatePassRate(
    passed: BDDScenarioCount,
    total: BDDScenarioCount
  ) -> BDDPassRate {
    guard total.rawValue > 0 else {
      return BDDPassRate(0)
    }

    let percentage = Double(passed.rawValue) / Double(total.rawValue) * 100
    return BDDPassRate(percentage)
  }
}
