import NetworkingRuntime
import Foundation

#if canImport(OSLog)
import OSLog

extension NetworkObservabilityMiddleware {
  // swiftlint:disable:next cyclomatic_complexity
  func calculateNetworkHealth(
    errorRate: Double,
    averageLatency: TimeInterval,
    p95Latency: TimeInterval,
    throughput: Double
  ) -> PerformanceMetrics.NetworkHealth {
    let latencyGrade = gradeLatency(averageLatency)
    let reliabilityGrade = gradeReliability(errorRate)
    let throughputGrade = gradeThroughput(throughput)

    let overallScore =
      (gradeToScore(reliabilityGrade) * 0.4
        + gradeToScore(latencyGrade) * 0.35
        + gradeToScore(throughputGrade) * 0.25)
    let overallGrade = scoreToGrade(overallScore)

    let status: PerformanceMetrics.NetworkHealth.HealthStatus
    switch overallGrade {
    case .a: status = .excellent
    case .b: status = .good
    case .c: status = .fair
    case .d: status = .poor
    case .f: status = .critical
    }

    _ = p95Latency

    return PerformanceMetrics.NetworkHealth(
      status: status,
      latencyGrade: latencyGrade,
      reliabilityGrade: reliabilityGrade,
      throughputGrade: throughputGrade,
      overallGrade: overallGrade
    )
  }

  // swiftlint:disable:next cyclomatic_complexity
  func gradeLatency(_ averageLatency: TimeInterval) -> PerformanceMetrics.NetworkHealth.Grade {
    let score = averageLatency * 1000
    switch score {
    case 0..<100: return .a
    case 100..<250: return .b
    case 250..<500: return .c
    case 500..<1000: return .d
    default: return .f
    }
  }

  // swiftlint:disable:next cyclomatic_complexity
  func gradeReliability(_ errorRate: Double) -> PerformanceMetrics.NetworkHealth.Grade {
    let percentage = errorRate * 100
    switch percentage {
    case 0..<1: return .a
    case 1..<2.5: return .b
    case 2.5..<5: return .c
    case 5..<10: return .d
    default: return .f
    }
  }

  // swiftlint:disable:next cyclomatic_complexity
  func gradeThroughput(_ throughput: Double) -> PerformanceMetrics.NetworkHealth.Grade {
    switch throughput {
    case 10...: return .a
    case 5..<10: return .b
    case 1..<5: return .c
    case 0.1..<1: return .d
    default: return .f
    }
  }

  func gradeToScore(_ grade: PerformanceMetrics.NetworkHealth.Grade) -> Double {
    Double(grade.rawValue)
  }

  func scoreToGrade(_ score: Double) -> PerformanceMetrics.NetworkHealth.Grade {
    let roundedScore = Int((score + 0.5).rounded(.down))
    let clampedScore = max(0, min(4, roundedScore))
    return PerformanceMetrics.NetworkHealth.Grade(rawValue: clampedScore) ?? .f
  }
}

#endif  // canImport(OSLog)
