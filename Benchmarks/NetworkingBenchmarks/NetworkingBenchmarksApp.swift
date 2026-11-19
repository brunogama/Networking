#if os(macOS)
import AppKit
#endif
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
      runAction: { Task { await runBenchmark() } }
    )
  }

  @MainActor
  private func runIfRequested() async {
    let arguments = ProcessInfo.processInfo.arguments
    let exitsAfterRun = arguments.contains("--benchmark-and-exit")
    let profiles = arguments.contains("--benchmark-profile")
    guard exitsAfterRun || profiles else { return }
    await runBenchmark()
    #if os(macOS)
    if exitsAfterRun { NSApp.terminate(nil) }
    #endif
  }

  @MainActor
  private func runBenchmark() async {
    guard let url = URL(string: baseURL) else {
      status = "Enter a valid loopback URL."
      return
    }
    isRunning = true
    results = []
    status = "Running HTTP, transfer-progress, and SSE pressure workloads..."
    defer { isRunning = false }
    do {
      results = try await performBenchmark(url)
      status = "Complete. Export the report with --output=<path>."
      try exportIfRequested(results)
    } catch {
      status = "Failed: \(error.localizedDescription)"
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
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let json = try encoder.encode(results)
    try json.write(to: URL(fileURLWithPath: path), options: .atomic)
  }

  private var outputArgument: String? {
    ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--output=") }
  }
}

private struct BenchmarkControls: View {
  @Binding var baseURL: String
  @Binding var iterations: Int
  let isRunning: Bool
  let runAction: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      TextField("Local HTTP(S) endpoint", text: $baseURL)
        .textFieldStyle(.roundedBorder)
      Stepper("\(iterations) samples", value: $iterations, in: 1...100)
        .fixedSize()
      Button("Run benchmark", action: runAction)
        .buttonStyle(.borderedProminent)
        .disabled(isRunning)
    }
  }
}

private struct BenchmarkResultTable: View {
  let results: [BenchmarkResult]

  var body: some View {
    Table(results) {
      TableColumn("Operation", value: \.name)
      TableColumn("Samples") { Text("\($0.summary.sampleCount)") }
      TableColumn("Median") { Text(formattedMedian($0)) }
      TableColumn("p95 (2+ samples)") { Text(formattedP95($0)) }
      TableColumn("Protocol") { Text(formattedProtocols($0)) }
      TableColumn("Throughput") { Text(formattedThroughput($0)) }
    }
    .frame(minHeight: 240)
  }

  private func formattedMedian(_ benchmarkResult: BenchmarkResult) -> String {
    String(format: "%.2f ms", benchmarkResult.summary.medianMilliseconds)
  }

  private func formattedP95(_ benchmarkResult: BenchmarkResult) -> String {
    benchmarkResult.summary.p95Milliseconds.map {
      String(format: "%.2f ms", $0)
    } ?? "N/A"
  }

  private func formattedProtocols(
    _ benchmarkResult: BenchmarkResult
  ) -> String {
    let protocols = benchmarkResult.protocolsObserved.joined(separator: ", ")
    return protocols.ifEmpty("unknown")
  }

  private func formattedThroughput(
    _ benchmarkResult: BenchmarkResult
  ) -> String {
    let bytesPerSecond = Int64(benchmarkResult.summary.bytesPerSecond)
    let formatted = ByteCountFormatter.string(
      fromByteCount: bytesPerSecond,
      countStyle: .memory
    )
    return formatted + "/s"
  }
}

private final class LoopbackCertificateDelegate:
  NSObject,
  URLSessionDelegate
{
  func urlSession(
    _ session: URLSession,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler:
      @escaping (
        URLSession.AuthChallengeDisposition,
        URLCredential?
      ) -> Void
  ) {
    let host = challenge.protectionSpace.host.lowercased()
    let localHosts: Set<String> = ["localhost", "127.0.0.1"]
    let isLocalHost = localHosts.contains(host)
    let authenticationMethod = challenge.protectionSpace.authenticationMethod
    let isServerTrust =
      authenticationMethod == NSURLAuthenticationMethodServerTrust
    guard isServerTrust, isLocalHost,
      let trust = challenge.protectionSpace.serverTrust
    else {
      completionHandler(.performDefaultHandling, nil)
      return
    }
    let credential = URLCredential(trust: trust)
    completionHandler(.useCredential, credential)
  }
}

private extension String {
  func ifEmpty(_ fallback: String) -> String {
    isEmpty ? fallback : self
  }
}
