#if os(macOS)
import Darwin
#endif
import Foundation
import NetworkingBenchmarksCore
import SwiftUI

@main
struct NetworkingBenchmarksApp: App {
  var body: some Scene {
    WindowGroup {
      BenchmarkView()
        .frame(minWidth: 720, minHeight: 460)
    }
  }
}

private struct BenchmarkView: View {
  @State private var baseURL =
    ProcessInfo.processInfo.environment["NETWORKING_BENCH_URL"]
    ?? "https://localhost:18443"
  @State private var iterations = 25
  @State private var results: [BenchmarkResult] = []
  @State private var status = "Ready"
  @State private var isRunning = false

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Networking Performance Lab")
        .font(.largeTitle.weight(.semibold))
      Text("Measures the Swift client and negotiated URLSession protocols.")
        .foregroundStyle(.secondary)
      controls
      Text(status).foregroundStyle(.secondary)
      BenchmarkResultTable(results: results)
      Spacer(minLength: 0)
    }
    .padding(28)
    .task { await runIfRequested() }
  }

  private var controls: some View {
    BenchmarkControls(
      baseURL: $baseURL,
      iterations: $iterations,
      isRunning: isRunning,
      runAction: { Task { _ = await runBenchmark() } }
    )
  }

  @MainActor
  private func runIfRequested() async {
    let arguments = ProcessInfo.processInfo.arguments
    let exitsAfterRun = arguments.contains("--benchmark-and-exit")
    let profiles = arguments.contains("--benchmark-profile")
    guard exitsAfterRun || profiles else { return }
    #if os(macOS)
    guard !exitsAfterRun || outputArgument != nil else {
      let message = "Provide --output=<path> when using --benchmark-and-exit.\n"
      FileHandle.standardError.write(Data(message.utf8))
      Darwin.exit(EXIT_FAILURE)
    }
    #endif
    let succeeded = await runBenchmark()
    #if os(macOS)
    if exitsAfterRun {
      Darwin.exit(succeeded ? EXIT_SUCCESS : EXIT_FAILURE)
    }
    #endif
  }

  @MainActor
  private func runBenchmark() async -> Bool {
    guard let url = URL(string: baseURL) else {
      status = "Enter a valid loopback URL."
      return false
    }
    isRunning = true
    results = []
    status = "Running HTTP, transfer-progress, and SSE pressure workloads..."
    defer { isRunning = false }
    do {
      results = try await performBenchmark(url)
      status = "Complete. Export the report with --output=<path>."
      try exportIfRequested(results)
      return true
    } catch {
      let message = "Networking benchmark failed: \(error.localizedDescription)\n"
      FileHandle.standardError.write(Data(message.utf8))
      status = "Failed: \(error.localizedDescription)"
      return false
    }
  }

  private func performBenchmark(_ url: URL) async throws -> [BenchmarkResult] {
    let session = URLSession(
      configuration: .ephemeral,
      delegate: LoopbackCertificateDelegate(),
      delegateQueue: nil
    )
    defer { session.invalidateAndCancel() }
    let runner = try NetworkingBenchmarkRunner(
      baseURL: url,
      session: session,
      iterations: iterations
    )
    return try await runner.run()
  }

  private func exportIfRequested(_ results: [BenchmarkResult]) throws {
    guard let argument = outputArgument else { return }
    let path = String(argument.dropFirst("--output=".count))
    try BenchmarkReportWriter.write(
      results,
      to: URL(fileURLWithPath: path)
    )
  }

  private var outputArgument: String? {
    ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--output=") }
  }
}
