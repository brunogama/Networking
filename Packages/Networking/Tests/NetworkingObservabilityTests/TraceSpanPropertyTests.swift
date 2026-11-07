import NetworkingCore
import PremiseCore
import PremiseStrategies
import PremiseTesting
import Testing

@testable import NetworkingObservability

@Suite("Trace span properties")
struct TraceSpanPropertyTests {
  @Test("Concurrent completion records exactly one terminal outcome")
  func exactlyOneCompletionWins() async throws {
    try await forAll(Strategy<Bool>.booleans, config: Self.config) { firstIsSuccess in
      let span = TraceSpan(name: "request", context: TraceContext())
      let firstStatus: TraceSpan.SpanStatus = firstIsSuccess ? .ok : .error("first")
      let secondStatus: TraceSpan.SpanStatus = firstIsSuccess ? .error("second") : .ok
      let completions = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
        group.addTask { await span.end(status: firstStatus) }
        group.addTask { await span.end(status: secondStatus) }
        var results: [Bool] = []
        for await completion in group {
          results.append(completion)
        }
        return results
      }

      #expect(completions.filter { $0 }.count == 1)
      #expect(await span.isEnded.rawValue)
    }
  }

  private static let config = PropertyConfig.bounded(runs: 40, shrinks: 160)
}
