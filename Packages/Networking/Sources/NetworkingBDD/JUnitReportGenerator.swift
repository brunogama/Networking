import NetworkingRuntime
import NetworkingTesting
import Foundation

/// Generates JUnit XML reports for CI integration.
public struct JUnitReportGenerator: Sendable {
  public init() {}

  /// Generates a JUnit XML report.
  ///
  /// - Parameter data: Report data from collector
  /// - Returns: JUnit XML formatted string
  public func generate(from data: ReportCollector.ReportData) -> UserMessageText {
    var lines: [String] = []

    lines.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
    lines.append(testSuitesHeader(for: data))

    for feature in data.features {
      lines.append(testSuiteLine(for: feature))

      for scenario in feature.scenarios {
        lines.append(contentsOf: testCaseLines(for: scenario, featureName: feature.name))
      }

      lines.append("  </testsuite>")
    }

    lines.append("</testsuites>")

    return UserMessageText(lines.joined(separator: "\n"))
  }

  /// Writes a JUnit report to file.
  ///
  /// - Parameters:
  ///   - url: File URL to write to
  ///   - data: Report data
  public func write(to url: BDDFileURL, from data: ReportCollector.ReportData) throws {
    let content = generate(from: data)
    try content.rawValue.write(to: url.rawValue, atomically: true, encoding: .utf8)
  }

  private func testSuitesHeader(for data: ReportCollector.ReportData) -> String {
    "<testsuites name=\"\(escapeXML(data.title.rawValue))\" tests=\"\(data.summary.totalScenarios.rawValue)\" failures=\"\(data.summary.failedScenarios.rawValue)\" errors=\"0\" time=\"\(data.summary.totalDuration.rawValue)\">"
  }

  private func testSuiteLine(for feature: ReportCollector.ReportData.FeatureReport) -> String {
    "  <testsuite name=\"\(escapeXML(feature.name.rawValue))\" tests=\"\(feature.scenarios.count)\" failures=\"\(feature.failedCount.rawValue)\" errors=\"0\" time=\"\(feature.duration.rawValue)\">"
  }

  private func testCaseLines(
    for scenario: ReportCollector.TestResult,
    featureName: BDDFeatureName
  ) -> [String] {
    var lines = [
      "    <testcase name=\"\(escapeXML(scenario.scenarioName.rawValue))\" classname=\"\(escapeXML(featureName.rawValue))\" time=\"\(scenario.duration.rawValue)\">"
    ]

    if scenario.status == .failed, let error = scenario.error {
      lines.append(
        "      <failure message=\"\(escapeXML(error.rawValue))\" type=\"AssertionError\">"
      )
      lines.append("        <![CDATA[\(error.rawValue)]]>")
      lines.append("      </failure>")
    } else if scenario.status == .skipped {
      lines.append("      <skipped/>")
    }

    lines.append("    </testcase>")
    return lines
  }

  private func escapeXML(_ string: String) -> String {
    string
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
      .replacingOccurrences(of: "'", with: "&apos;")
  }
}
