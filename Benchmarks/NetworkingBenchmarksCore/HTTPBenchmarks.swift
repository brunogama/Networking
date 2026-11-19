import Foundation
import Networking

struct HTTPRequestBenchmark: Sendable {
  private let context: BenchmarkContext

  init(context: BenchmarkContext) {
    self.context = context
  }

  func run() async throws -> BenchmarkResult {
    let request = context.makeRequest("request")
    try await warmUp(request)
    context.diagnostics.clear()
    let samples = try await measure(request)
    let duration = samples.reduce(0, +) / 1_000
    let measurement = BenchmarkMeasurement(
      name: "HTTP request / 1 KiB",
      samplesMilliseconds: samples,
      bytesTransferred: 1_024 * Int64(context.configuration.iterations),
      durationSeconds: duration
    )
    return context.makeResult(measurement)
  }

  private func warmUp(_ request: HTTPRequest) async throws {
    for _ in 0..<3 {
      _ = try await context.clients.http.execute(request)
    }
  }

  private func measure(_ request: HTTPRequest) async throws -> [Double] {
    var samples: [Double] = []
    for _ in 0..<context.configuration.iterations {
      let start = ContinuousClock.now
      _ = try await context.clients.http.execute(request)
      samples.append(BenchmarkTiming.milliseconds(start.duration(to: .now)))
    }
    return samples
  }
}

struct HTTPUploadBenchmark: Sendable {
  private let context: BenchmarkContext
  private let transfers: FileTransferOperations

  init(context: BenchmarkContext) {
    self.context = context
    transfers = FileTransferOperations(httpClient: context.clients.http)
  }

  func run() async throws -> BenchmarkResult {
    let fileURL = try BenchmarkFiles.create(
      byteCount: 65_536,
      prefix: "networking-upload"
    )
    defer { BenchmarkFiles.remove(fileURL) }
    let request = context.makeRequest("upload", method: .post)
    try await warmUp(request, fileURL: fileURL)
    context.diagnostics.clear()
    let samples = try await measure(request, fileURL: fileURL)
    let duration = samples.reduce(0, +) / 1_000
    let measurement = BenchmarkMeasurement(
      name: "HTTP upload / 64 KiB",
      samplesMilliseconds: samples,
      bytesTransferred: 65_536 * Int64(context.configuration.iterations),
      durationSeconds: duration
    )
    return context.makeResult(measurement)
  }

  private func warmUp(_ request: HTTPRequest, fileURL: URL) async throws {
    for _ in 0..<3 {
      try await upload(request, fileURL)
    }
  }

  private func measure(
    _ request: HTTPRequest,
    fileURL: URL
  ) async throws -> [Double] {
    var samples: [Double] = []
    for _ in 0..<context.configuration.iterations {
      let start = ContinuousClock.now
      try await upload(request, fileURL)
      let elapsed = start.duration(to: .now)
      samples.append(BenchmarkTiming.milliseconds(elapsed))
    }
    return samples
  }

  private func upload(_ request: HTTPRequest, _ fileURL: URL) async throws {
    _ = try await transfers.uploadFile(
      from: LocalFileURL(fileURL),
      to: RemoteTransferURL(request.url.rawValue)
    )
  }
}

struct HTTPDownloadBenchmark: Sendable {
  private let context: BenchmarkContext
  private let transfers: FileTransferOperations

  init(context: BenchmarkContext) {
    self.context = context
    transfers = FileTransferOperations(httpClient: context.clients.http)
  }

  func run() async throws -> BenchmarkResult {
    let request = context.makeRequest("download")
    try await warmUp(request)
    context.diagnostics.clear()
    let samples = try await measure(request)
    let duration = samples.reduce(0, +) / 1_000
    let measurement = BenchmarkMeasurement(
      name: "HTTP download / 1 MiB",
      samplesMilliseconds: samples,
      bytesTransferred: 1_048_576 * Int64(context.configuration.iterations),
      durationSeconds: duration
    )
    return context.makeResult(measurement)
  }

  private func warmUp(_ request: HTTPRequest) async throws {
    for _ in 0..<3 {
      try await download(request)
    }
  }

  private func measure(_ request: HTTPRequest) async throws -> [Double] {
    var samples: [Double] = []
    for _ in 0..<context.configuration.iterations {
      let start = ContinuousClock.now
      try await download(request)
      samples.append(BenchmarkTiming.milliseconds(start.duration(to: .now)))
    }
    return samples
  }

  private func download(_ request: HTTPRequest) async throws {
    let destinationURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: destinationURL) }
    _ = try await transfers.downloadFile(
      from: RemoteTransferURL(request.url.rawValue),
      to: LocalFileURL(destinationURL)
    )
  }
}
