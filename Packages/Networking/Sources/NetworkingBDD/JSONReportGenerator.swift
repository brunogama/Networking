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
    /// Pretty print JSON output.
    public let prettyPrint: Bool

    /// Include step details.
    public let includeSteps: Bool

    /// Sort keys alphabetically.
    public let sortKeys: Bool

    /// Creates a configuration.
    public init(
      prettyPrint: Bool = true,
      includeSteps: Bool = true,
      sortKeys: Bool = false
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
    public let title: String
    public let timestamp: String
    public let duration: TimeInterval
    public let summary: Summary
    public let features: [Feature]

    public struct Summary: Codable, Sendable {
      public let totalScenarios: Int
      public let passed: Int
      public let failed: Int
      public let skipped: Int
      public let pending: Int
      public let totalSteps: Int
      public let passedSteps: Int
      public let failedSteps: Int
      public let totalDuration: TimeInterval
      public let passRate: Double
    }

    public struct Feature: Codable, Sendable {
      public let name: String
      public let passedCount: Int
      public let failedCount: Int
      public let skippedCount: Int
      public let duration: TimeInterval
      public let scenarios: [Scenario]
    }

    public struct Scenario: Codable, Sendable {
      public let id: String
      public let name: String
      public let status: String
      public let duration: TimeInterval
      public let tags: [String]
      public let error: String?
      public let steps: [Step]?
    }

    public struct Step: Codable, Sendable {
      public let keyword: String
      public let text: String
      public let status: String
      public let duration: TimeInterval
      public let error: String?
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
  public func generate(from data: ReportCollector.ReportData) throws -> String {
    let jsonReport = buildReport(from: data)

    let encoder = JSONEncoder()
    if configuration.prettyPrint {
      encoder.outputFormatting = [.prettyPrinted]
    }
    if configuration.sortKeys {
      encoder.outputFormatting.insert(.sortedKeys)
    }

    let jsonData = try encoder.encode(jsonReport)
    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
      throw BDDError.reportGenerationFailed(reason: "Failed to encode JSON")
    }

    return jsonString
  }

  /// Generates JSON data.
  ///
  /// - Parameter data: Report data from collector
  /// - Returns: JSON data
  public func generateData(from data: ReportCollector.ReportData) throws -> Data {
    let jsonReport = buildReport(from: data)

    let encoder = JSONEncoder()
    if configuration.prettyPrint {
      encoder.outputFormatting = [.prettyPrinted]
    }
    if configuration.sortKeys {
      encoder.outputFormatting.insert(.sortedKeys)
    }

    return try encoder.encode(jsonReport)
  }

  /// Writes a JSON report to file.
  ///
  /// - Parameters:
  ///   - url: File URL to write to
  ///   - data: Report data
  public func write(to url: URL, from data: ReportCollector.ReportData) throws {
    let jsonData = try generateData(from: data)
    try jsonData.write(to: url)
  }

  // MARK: - Private Methods

  private func buildReport(from data: ReportCollector.ReportData) -> JSONReport {
    let formatter = ISO8601DateFormatter()

    let summary = JSONReport.Summary(
      totalScenarios: data.summary.totalScenarios,
      passed: data.summary.passedScenarios,
      failed: data.summary.failedScenarios,
      skipped: data.summary.skippedScenarios,
      pending: data.summary.pendingScenarios,
      totalSteps: data.summary.totalSteps,
      passedSteps: data.summary.passedSteps,
      failedSteps: data.summary.failedSteps,
      totalDuration: data.summary.totalDuration,
      passRate: data.summary.passRate
    )

    let features = data.features.map { feature in
      JSONReport.Feature(
        name: feature.name,
        passedCount: feature.passedCount,
        failedCount: feature.failedCount,
        skippedCount: feature.skippedCount,
        duration: feature.duration,
        scenarios: feature.scenarios.map { scenario in
          JSONReport.Scenario(
            id: scenario.id.uuidString,
            name: scenario.scenarioName,
            status: scenario.status.rawValue,
            duration: scenario.duration,
            tags: scenario.tags,
            error: scenario.error,
            steps: configuration.includeSteps
              ? scenario.steps.map { step in
                JSONReport.Step(
                  keyword: step.keyword,
                  text: step.text,
                  status: step.status.rawValue,
                  duration: step.duration,
                  error: step.error
                )
              } : nil
          )
        }
      )
    }

    return JSONReport(
      title: data.title,
      timestamp: formatter.string(from: data.timestamp),
      duration: data.duration,
      summary: summary,
      features: features
    )
  }
}

// MARK: - JUnit Report Generator

/// Generates JUnit XML reports for CI integration.
public struct JUnitReportGenerator: Sendable {
  // MARK: - Initialization

  public init() {}

  // MARK: - Generation

  /// Generates a JUnit XML report.
  ///
  /// - Parameter data: Report data from collector
  /// - Returns: JUnit XML formatted string
  public func generate(from data: ReportCollector.ReportData) -> String {
    var lines: [String] = []

    lines.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
    lines.append(
      "<testsuites name=\"\(escapeXML(data.title))\" tests=\"\(data.summary.totalScenarios)\" failures=\"\(data.summary.failedScenarios)\" errors=\"0\" time=\"\(data.summary.totalDuration)\">"
    )

    for feature in data.features {
      let featureTests = feature.scenarios.count
      let featureFailures = feature.failedCount

      lines.append(
        "  <testsuite name=\"\(escapeXML(feature.name))\" tests=\"\(featureTests)\" failures=\"\(featureFailures)\" errors=\"0\" time=\"\(feature.duration)\">"
      )

      for scenario in feature.scenarios {
        lines.append(
          "    <testcase name=\"\(escapeXML(scenario.scenarioName))\" classname=\"\(escapeXML(feature.name))\" time=\"\(scenario.duration)\">"
        )

        if scenario.status == .failed, let error = scenario.error {
          lines.append("      <failure message=\"\(escapeXML(error))\" type=\"AssertionError\">")
          lines.append("        <![CDATA[\(error)]]>")
          lines.append("      </failure>")
        } else if scenario.status == .skipped {
          lines.append("      <skipped/>")
        }

        lines.append("    </testcase>")
      }

      lines.append("  </testsuite>")
    }

    lines.append("</testsuites>")

    return lines.joined(separator: "\n")
  }

  /// Writes a JUnit report to file.
  ///
  /// - Parameters:
  ///   - url: File URL to write to
  ///   - data: Report data
  public func write(to url: URL, from data: ReportCollector.ReportData) throws {
    let content = generate(from: data)
    try content.write(to: url, atomically: true, encoding: .utf8)
  }

  // MARK: - Private Methods

  private func escapeXML(_ string: String) -> String {
    string
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
      .replacingOccurrences(of: "'", with: "&apos;")
  }
}
