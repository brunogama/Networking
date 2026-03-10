import NetworkingRuntime
import NetworkingTesting
import Foundation

// swiftlint:disable file_length

// MARK: - BDD Configuration

/// Configuration for BDD test execution.
///
/// ```swift
/// let config = BDDConfiguration(
///   featureDirectory: "Features",
///   stepDefinitions: myStepRegistry,
///   tags: ["@smoke"],
///   generateReport: true
/// )
/// ```
public struct BDDConfiguration: Sendable {
  /// Directory containing .feature files.
  public let featureDirectory: BDDDirectoryPath?

  /// Tags to filter scenarios.
  public let includeTags: [BDDTagText]

  /// Tags to exclude scenarios.
  public let excludeTags: [BDDTagText]

  /// Whether to generate reports after execution.
  public let generateReport: BDDGenerateReportFlag

  /// Report output directory.
  public let reportDirectory: BDDDirectoryPath

  /// Report format.
  public let reportFormat: ReportFormat

  /// Whether to stop on first failure.
  public let stopOnFirstFailure: BDDStopOnFirstFailureFlag

  /// Default timeout for steps in seconds.
  public let defaultStepTimeout: MeasurementDuration

  /// Whether to run scenarios in parallel.
  public let parallelExecution: BDDParallelExecutionFlag

  /// Report format options.
  public enum ReportFormat: Sendable {
    case markdown
    case json
    case html
    case junit
  }

  /// Creates a BDD configuration.
  ///
  /// - Parameters:
  ///   - featureDirectory: Directory containing .feature files
  ///   - includeTags: Tags to include (empty means all)
  ///   - excludeTags: Tags to exclude
  ///   - generateReport: Whether to generate reports
  ///   - reportDirectory: Output directory for reports
  ///   - reportFormat: Report format
  ///   - stopOnFirstFailure: Stop on first failure
  ///   - defaultStepTimeout: Default step timeout in seconds
  ///   - parallelExecution: Run scenarios in parallel
  public init(
    featureDirectory: BDDDirectoryPath? = nil,
    includeTags: [BDDTagText] = [],
    excludeTags: [BDDTagText] = [],
    generateReport: BDDGenerateReportFlag = false,
    reportDirectory: BDDDirectoryPath = "Reports",
    reportFormat: ReportFormat = .markdown,
    stopOnFirstFailure: BDDStopOnFirstFailureFlag = false,
    defaultStepTimeout: MeasurementDuration = 30,
    parallelExecution: BDDParallelExecutionFlag = false
  ) {
    self.featureDirectory = featureDirectory
    self.includeTags = includeTags
    self.excludeTags = excludeTags
    self.generateReport = generateReport
    self.reportDirectory = reportDirectory
    self.reportFormat = reportFormat
    self.stopOnFirstFailure = stopOnFirstFailure
    self.defaultStepTimeout = defaultStepTimeout
    self.parallelExecution = parallelExecution
  }

  /// Default configuration.
  public static var `default`: Self {
    Self()
  }
}

// MARK: - BDD Test Runner

// swiftlint:disable type_body_length
/// Runs BDD tests from Gherkin feature files.
///
/// - Note: `@unchecked Sendable` justification:
///   1. Test infrastructure only
///   2. Mutable state (`results`) protected by NSLock
///   3. Configuration and parser are immutable after initialization
///   4. Tests run sequentially or with explicit parallelization control
///   5. Temporary test execution lifetime
public final class BDDTestRunner: @unchecked Sendable {
  // MARK: - Properties

  private let configuration: BDDConfiguration
  private let parser: GherkinParser
  private let stepRegistry: StepRegistry
  private let lock = NSLock()
  private var results: [ScenarioResult] = []

  // MARK: - Types

  /// Result of a scenario execution.
  public struct ScenarioResult: Sendable {
    public let featureName: BDDFeatureName
    public let scenarioName: BDDScenarioName
    public let status: Status
    public let duration: MeasurementDuration
    public let steps: [StepResult]
    public let error: Error?

    public enum Status: Sendable {
      case passed
      case failed
      case skipped
      case pending
    }
  }

  /// Result of a step execution.
  public struct StepResult: Sendable {
    public let keyword: BDDStepKeyword
    public let text: BDDStepText
    public let status: ScenarioResult.Status
    public let duration: MeasurementDuration
    public let error: Error?
  }

  // MARK: - Initialization

  /// Creates a BDD test runner.
  ///
  /// - Parameters:
  ///   - configuration: BDD configuration
  ///   - stepRegistry: Registry containing step definitions
  public init(configuration: BDDConfiguration, stepRegistry: StepRegistry) {
    self.configuration = configuration
    self.parser = GherkinParser()
    self.stepRegistry = stepRegistry
  }

  // MARK: - Running Tests

  /// Runs all features in the configured directory.
  ///
  /// - Returns: Array of scenario results
  /// - Throws: BDDError if feature files cannot be loaded
  public func runAllFeatures() async throws -> [ScenarioResult] {
    guard let directory = configuration.featureDirectory else {
      throw BDDError.invalidConfiguration(
        key: UserMessageText("featureDirectory"),
        reason: UserMessageText("Not set")
      )
    }

    let featureFiles = try findFeatureFiles(in: directory)
    var allResults: [ScenarioResult] = []

    for fileURL in featureFiles {
      let featureResults = try await runFeature(at: fileURL)
      allResults.append(contentsOf: featureResults)

      if configuration.stopOnFirstFailure.rawValue
        && featureResults.contains(where: { $0.status == .failed })
      {
        break
      }
    }

    return allResults
  }

  /// Runs a single feature file.
  ///
  /// - Parameter url: URL to the feature file
  /// - Returns: Array of scenario results
  public func runFeature(at url: BDDFileURL) async throws -> [ScenarioResult] {
    let feature = try parser.parse(url: url)
    return try await runFeature(feature)
  }

  // swiftlint:disable cyclomatic_complexity
  /// Runs a parsed feature.
  ///
  /// - Parameter feature: The parsed Gherkin feature
  /// - Returns: Array of scenario results
  public func runFeature(_ feature: GherkinFeature) async throws -> [ScenarioResult] {
    var results: [ScenarioResult] = []

    for scenario in feature.scenarios {
      switch scenario {
      case .scenario(let definition):
        if shouldRunScenario(tags: definition.tags) {
          let result = try await runScenario(definition, feature: feature)
          results.append(result)
        }

      case .outline(let outline):
        if shouldRunScenario(tags: outline.tags) {
          let outlineResults = try await runScenarioOutline(outline, feature: feature)
          results.append(contentsOf: outlineResults)
        }
      }

      if configuration.stopOnFirstFailure.rawValue && results.last?.status == .failed {
        break
      }
    }

    return results
  }
  // swiftlint:enable cyclomatic_complexity

  // MARK: - Private Methods

  private func findFeatureFiles(in directory: BDDDirectoryPath) throws -> [BDDFileURL] {
    let fileManager = FileManager.default
    let directoryURL = URL(fileURLWithPath: directory.rawValue)

    guard fileManager.fileExists(atPath: directory.rawValue) else {
      throw BDDError.fileNotFound(path: BDDSourceFilePath(directory.rawValue))
    }

    let contents = try fileManager.contentsOfDirectory(
      at: directoryURL,
      includingPropertiesForKeys: nil
    )

    return
      contents
      .filter { $0.pathExtension == "feature" }
      .map { BDDFileURL($0) }
  }

  private func shouldRunScenario(tags: [Tag]) -> Bool {
    // If no include tags specified, include all
    if !configuration.includeTags.isEmpty {
      let scenarioTags = Set(tags.map(\.name))
      let includeTags = Set(configuration.includeTags)
      if scenarioTags.isDisjoint(with: includeTags) {
        return false
      }
    }

    // Check exclude tags
    if !configuration.excludeTags.isEmpty {
      let scenarioTags = Set(tags.map(\.name))
      let excludeTags = Set(configuration.excludeTags)
      if !scenarioTags.isDisjoint(with: excludeTags) {
        return false
      }
    }

    return true
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func runScenario(
    _ definition: ScenarioDefinition,
    feature: GherkinFeature
  ) async throws -> ScenarioResult {
    let startTime = Date()
    var stepResults: [StepResult] = []
    var scenarioError: Error?
    var scenarioStatus: ScenarioResult.Status = .passed

    let context = ScenarioContext()

    // Run background steps first
    if let background = feature.background {
      for step in background.steps {
        let stepResult = try await runStep(step, context: context, previousKeyword: nil)
        stepResults.append(stepResult)

        if stepResult.status == .failed {
          scenarioStatus = .failed
          scenarioError = stepResult.error
          break
        }
      }
    }

    // Run scenario steps if background passed
    if scenarioStatus == .passed {
      var previousKeyword: StepKeyword?
      for step in definition.steps {
        let stepResult = try await runStep(step, context: context, previousKeyword: previousKeyword)
        stepResults.append(stepResult)
        previousKeyword = step.keyword

        if stepResult.status == .failed {
          scenarioStatus = .failed
          scenarioError = stepResult.error
          break
        }
      }
    }

    let duration = MeasurementDuration(Date().timeIntervalSince(startTime))

    return ScenarioResult(
      featureName: feature.name,
      scenarioName: definition.name,
      status: scenarioStatus,
      duration: duration,
      steps: stepResults,
      error: scenarioError
    )
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func runScenarioOutline(
    _ outline: ScenarioOutlineDefinition,
    feature: GherkinFeature
  ) async throws -> [ScenarioResult] {
    var results: [ScenarioResult] = []

    for examplesTable in outline.examples {
      for (rowIndex, row) in examplesTable.rows.enumerated() {
        // Create example dictionary
        var example: [String: String] = [:]
        for (columnIndex, header) in examplesTable.headers.enumerated()
        where columnIndex < row.count {
          example[header.rawValue] = row[columnIndex].rawValue
        }

        // Substitute placeholders in steps
        let substitutedSteps = outline.steps.map { step -> GherkinStep in
          var substitutedText = step.text.rawValue
          for (key, value) in example {
            substitutedText = substitutedText.replacingOccurrences(of: "<\(key)>", with: value)
          }
          return GherkinStep(
            keyword: step.keyword,
            text: BDDStepText(substitutedText),
            dataTable: step.dataTable,
            docString: step.docString,
            location: step.location
          )
        }

        let exampleScenario = ScenarioDefinition(
          name: BDDScenarioName("\(outline.name.rawValue) (Example \(rowIndex + 1))"),
          description: outline.description,
          tags: outline.tags,
          steps: substitutedSteps,
          location: outline.location
        )

        let result = try await runScenario(exampleScenario, feature: feature)
        results.append(result)

        if configuration.stopOnFirstFailure.rawValue
          && result.status == ScenarioResult.Status.failed
        {
          break
        }
      }
    }

    return results
  }

  private func runStep(
    _ step: GherkinStep,
    context: ScenarioContext,
    previousKeyword: StepKeyword?
  ) async throws -> StepResult {
    let startTime = Date()

    // Determine semantic type
    let semanticType = step.semanticType(previousKeyword: previousKeyword)

    do {
      try await stepRegistry.execute(
        step: step,
        semanticType: semanticType,
        context: context
      )

      let duration = MeasurementDuration(Date().timeIntervalSince(startTime))
      return StepResult(
        keyword: BDDStepKeyword(step.keyword.identifier.rawValue),
        text: step.text,
        status: .passed,
        duration: duration,
        error: nil
      )
    } catch {
      let duration = MeasurementDuration(Date().timeIntervalSince(startTime))
      return StepResult(
        keyword: BDDStepKeyword(step.keyword.identifier.rawValue),
        text: step.text,
        status: .failed,
        duration: duration,
        error: error
      )
    }
  }
}
// swiftlint:enable type_body_length

// MARK: - GherkinStep Extension

extension GherkinStep {
  // swiftlint:disable cyclomatic_complexity
  /// Determines the semantic step type based on keyword and previous keyword.
  func semanticType(previousKeyword: StepKeyword?) -> SemanticStepType {
    switch keyword {
    case .given:
      return .given
    case .when:
      return .when
    case .then:
      return .then
    case .and, .but, .asterisk:
      // And/But/Asterisk inherit from previous step
      guard let previous = previousKeyword else {
        return .given  // Default to given if no previous
      }
      switch previous {
      case .given, .and, .but, .asterisk:
        return .given
      case .when:
        return .when
      case .then:
        return .then
      }
    }
  }
  // swiftlint:enable cyclomatic_complexity
}
// swiftlint:enable file_length
