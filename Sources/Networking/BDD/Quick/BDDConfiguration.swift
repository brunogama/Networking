import Foundation

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
  public let featureDirectory: String?

  /// Tags to filter scenarios.
  public let includeTags: [String]

  /// Tags to exclude scenarios.
  public let excludeTags: [String]

  /// Whether to generate reports after execution.
  public let generateReport: Bool

  /// Report output directory.
  public let reportDirectory: String

  /// Report format.
  public let reportFormat: ReportFormat

  /// Whether to stop on first failure.
  public let stopOnFirstFailure: Bool

  /// Default timeout for steps in seconds.
  public let defaultStepTimeout: TimeInterval

  /// Whether to run scenarios in parallel.
  public let parallelExecution: Bool

  /// Report format options.
  public enum ReportFormat: String, Sendable {
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
    featureDirectory: String? = nil,
    includeTags: [String] = [],
    excludeTags: [String] = [],
    generateReport: Bool = false,
    reportDirectory: String = "Reports",
    reportFormat: ReportFormat = .markdown,
    stopOnFirstFailure: Bool = false,
    defaultStepTimeout: TimeInterval = 30,
    parallelExecution: Bool = false
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
    public let featureName: String
    public let scenarioName: String
    public let status: Status
    public let duration: TimeInterval
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
    public let keyword: String
    public let text: String
    public let status: ScenarioResult.Status
    public let duration: TimeInterval
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
      throw BDDError.invalidConfiguration(key: "featureDirectory", reason: "Not set")
    }

    let featureFiles = try findFeatureFiles(in: directory)
    var allResults: [ScenarioResult] = []

    for fileURL in featureFiles {
      let featureResults = try await runFeature(at: fileURL)
      allResults.append(contentsOf: featureResults)

      if configuration.stopOnFirstFailure && featureResults.contains(where: { $0.status == .failed }) {
        break
      }
    }

    return allResults
  }

  /// Runs a single feature file.
  ///
  /// - Parameter url: URL to the feature file
  /// - Returns: Array of scenario results
  public func runFeature(at url: URL) async throws -> [ScenarioResult] {
    let feature = try parser.parse(url: url)
    return try await runFeature(feature)
  }

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

      if configuration.stopOnFirstFailure && results.last?.status == .failed {
        break
      }
    }

    return results
  }

  // MARK: - Private Methods

  private func findFeatureFiles(in directory: String) throws -> [URL] {
    let fileManager = FileManager.default
    let directoryURL = URL(fileURLWithPath: directory)

    guard fileManager.fileExists(atPath: directory) else {
      throw BDDError.fileNotFound(path: directory)
    }

    let contents = try fileManager.contentsOfDirectory(
      at: directoryURL,
      includingPropertiesForKeys: nil
    )

    return contents.filter { $0.pathExtension == "feature" }
  }

  private func shouldRunScenario(tags: [Tag]) -> Bool {
    // If no include tags specified, include all
    if !configuration.includeTags.isEmpty {
      let scenarioTags = Set(tags.map { $0.name })
      let includeTags = Set(configuration.includeTags)
      if scenarioTags.isDisjoint(with: includeTags) {
        return false
      }
    }

    // Check exclude tags
    if !configuration.excludeTags.isEmpty {
      let scenarioTags = Set(tags.map { $0.name })
      let excludeTags = Set(configuration.excludeTags)
      if !scenarioTags.isDisjoint(with: excludeTags) {
        return false
      }
    }

    return true
  }

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

    let duration = Date().timeIntervalSince(startTime)

    return ScenarioResult(
      featureName: feature.name,
      scenarioName: definition.name,
      status: scenarioStatus,
      duration: duration,
      steps: stepResults,
      error: scenarioError
    )
  }

  private func runScenarioOutline(
    _ outline: ScenarioOutlineDefinition,
    feature: GherkinFeature
  ) async throws -> [ScenarioResult] {
    var results: [ScenarioResult] = []

    for examplesTable in outline.examples {
      for (rowIndex, row) in examplesTable.rows.enumerated() {
        // Create example dictionary
        var example: [String: String] = [:]
        for (columnIndex, header) in examplesTable.headers.enumerated() {
          if columnIndex < row.count {
            example[header] = row[columnIndex]
          }
        }

        // Substitute placeholders in steps
        let substitutedSteps = outline.steps.map { step -> GherkinStep in
          var substitutedText = step.text
          for (key, value) in example {
            substitutedText = substitutedText.replacingOccurrences(of: "<\(key)>", with: value)
          }
          return GherkinStep(
            keyword: step.keyword,
            text: substitutedText,
            dataTable: step.dataTable,
            docString: step.docString,
            location: step.location
          )
        }

        let exampleScenario = ScenarioDefinition(
          name: "\(outline.name) (Example \(rowIndex + 1))",
          description: outline.description,
          tags: outline.tags,
          steps: substitutedSteps,
          location: outline.location
        )

        let result = try await runScenario(exampleScenario, feature: feature)
        results.append(result)

        if configuration.stopOnFirstFailure && result.status == .failed {
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

      let duration = Date().timeIntervalSince(startTime)
      return StepResult(
        keyword: step.keyword.rawValue,
        text: step.text,
        status: .passed,
        duration: duration,
        error: nil
      )
    } catch {
      let duration = Date().timeIntervalSince(startTime)
      return StepResult(
        keyword: step.keyword.rawValue,
        text: step.text,
        status: .failed,
        duration: duration,
        error: error
      )
    }
  }
}

// MARK: - GherkinStep Extension

extension GherkinStep {
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
}
