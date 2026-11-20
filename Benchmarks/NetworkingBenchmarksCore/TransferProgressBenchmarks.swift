struct TransferProgressBenchmarks: Sendable {
  private let context: BenchmarkContext

  init(context: BenchmarkContext) {
    self.context = context
  }

  func run() async throws -> [BenchmarkResult] {
    let progress = try await BatchProgressBenchmarks(context: context).run()
    let pressure = try await SSEBackpressureBenchmark(context: context).run()
    return progress + [pressure]
  }
}
