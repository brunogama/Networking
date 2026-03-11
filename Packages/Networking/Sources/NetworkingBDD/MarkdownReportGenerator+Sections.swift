import NetworkingRuntime
import NetworkingTesting
import Foundation

extension MarkdownReportGenerator {
  func featureSectionHeaderLines(
    for feature: ReportCollector.ReportData.FeatureReport
  ) -> [String] {
    let featureIcon = feature.failedCount.rawValue > 0 ? "X" : "V"
    var lines = [
      "### \(featureIcon) \(feature.name.rawValue)",
      "",
    ]

    if configuration.includeDuration.includesDuration {
      lines.append("Duration: \(formatDuration(feature.duration).rawValue)")
      lines.append("")
    }

    lines.append("| Status | Scenario | Duration |")
    lines.append("|--------|----------|----------|")
    return lines
  }

  func scenarioSectionLines(for scenario: ReportCollector.TestResult) -> [String] {
    var lines = [scenarioTableRow(for: scenario)]
    lines.append(contentsOf: errorDetailsLines(for: scenario))
    lines.append(contentsOf: stepDetailsLines(for: scenario))
    return lines
  }

  func scenarioTableRow(for scenario: ReportCollector.TestResult) -> String {
    let icon = statusIcon(for: scenario.status)
    let duration =
      configuration.includeDuration.includesDuration
      ? formatDuration(scenario.duration).rawValue : "-"
    let scenarioName = formattedScenarioName(for: scenario)
    return "| \(icon.rawValue) | \(scenarioName) | \(duration) |"
  }

  func formattedScenarioName(for scenario: ReportCollector.TestResult) -> String {
    guard configuration.includeTags.includesTags, !scenario.tags.isEmpty else {
      return scenario.scenarioName.rawValue
    }

    let tags = scenario.tags.map { "`\($0.rawValue)`" }.joined(separator: " ")
    return "\(scenario.scenarioName.rawValue) \(tags)"
  }

  func errorDetailsLines(for scenario: ReportCollector.TestResult) -> [String] {
    guard configuration.includeErrors.includesErrors,
      scenario.status == .failed,
      let error = scenario.error
    else {
      return []
    }

    return [
      "",
      "<details>",
      "<summary>Error Details</summary>",
      "",
      "```",
      error.rawValue,
      "```",
      "</details>",
      "",
    ]
  }

  func stepDetailsLines(for scenario: ReportCollector.TestResult) -> [String] {
    guard configuration.includeSteps.includesSteps, !scenario.steps.isEmpty else {
      return []
    }

    var lines = [
      "",
      "<details>",
      "<summary>Steps</summary>",
      "",
    ]

    for step in scenario.steps {
      lines.append(stepLine(for: step))
      if let error = step.error, step.status == .failed {
        lines.append("  - Error: `\(error.rawValue)`")
      }
    }

    lines.append("</details>")
    lines.append("")
    return lines
  }

  func stepLine(for step: ReportCollector.StepResult) -> String {
    let stepIcon = statusIcon(for: step.status)
    return "- \(stepIcon.rawValue) **\(step.keyword.rawValue)** \(step.text.rawValue)"
  }
}
