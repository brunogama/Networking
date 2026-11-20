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
      bytesTransferred:
        Int64(HTTPBenchmarkFixture.requestPayload.count)
        * Int64(context.configuration.iterations),
      durationSeconds: duration
    )
    return context.makeResult(measurement)
  }

  private func warmUp(_ request: HTTPRequest) async throws {
    for _ in 0..<3 {
      let response = try await context.clients.http.execute(request)
      try BenchmarkIntegrity.validatePayload(
        response.body?.rawValue,
        matches: HTTPBenchmarkFixture.requestPayload,
        operation: "HTTP request"
      )
    }
  }

  private func measure(_ request: HTTPRequest) async throws -> [Double] {
    var samples: [Double] = []
    for _ in 0..<context.configuration.iterations {
      let start = ContinuousClock.now
      let response = try await context.clients.http.execute(request)
      let elapsed = BenchmarkTiming.milliseconds(start.duration(to: .now))
      try BenchmarkIntegrity.validatePayload(
        response.body?.rawValue,
        matches: HTTPBenchmarkFixture.requestPayload,
        operation: "HTTP request"
      )
      samples.append(elapsed)
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
      byteCount: HTTPBenchmarkFixture.uploadPayloadSize,
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
      bytesTransferred:
        Int64(HTTPBenchmarkFixture.uploadPayloadSize)
        * Int64(context.configuration.iterations),
      durationSeconds: duration
    )
    return context.makeResult(measurement)
  }

  private func warmUp(_ request: HTTPRequest, fileURL: URL) async throws {
    for _ in 0..<3 {
      let result = try await upload(request, fileURL)
      try BenchmarkIntegrity.validateTransfer(
        result,
        expectedBytes: Int64(HTTPBenchmarkFixture.uploadPayloadSize),
        operation: "HTTP upload"
      )
    }
  }

  private func measure(
    _ request: HTTPRequest,
    fileURL: URL
  ) async throws -> [Double] {
    var samples: [Double] = []
    for _ in 0..<context.configuration.iterations {
      let start = ContinuousClock.now
      let result = try await upload(request, fileURL)
      let elapsed = BenchmarkTiming.milliseconds(start.duration(to: .now))
      try BenchmarkIntegrity.validateTransfer(
        result,
        expectedBytes: Int64(HTTPBenchmarkFixture.uploadPayloadSize),
        operation: "HTTP upload"
      )
      samples.append(elapsed)
    }
    return samples
  }

  private func upload(
    _ request: HTTPRequest,
    _ fileURL: URL
  ) async throws -> FileTransferResult {
    try await transfers.uploadFile(
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
      bytesTransferred:
        Int64(HTTPBenchmarkFixture.downloadPayload.count)
        * Int64(context.configuration.iterations),
      durationSeconds: duration
    )
    return context.makeResult(measurement)
  }

  private func warmUp(_ request: HTTPRequest) async throws {
    for _ in 0..<3 {
      let (result, fileURL) = try await download(request)
      defer { BenchmarkFiles.remove(fileURL) }
      try validateDownload(result, at: fileURL)
    }
  }

  private func measure(_ request: HTTPRequest) async throws -> [Double] {
    var samples: [Double] = []
    for _ in 0..<context.configuration.iterations {
      let start = ContinuousClock.now
      let (result, fileURL) = try await download(request)
      let elapsed = BenchmarkTiming.milliseconds(start.duration(to: .now))
      defer { BenchmarkFiles.remove(fileURL) }
      try validateDownload(result, at: fileURL)
      samples.append(elapsed)
    }
    return samples
  }

  private func download(
    _ request: HTTPRequest
  ) async throws -> (FileTransferResult, URL) {
    let destinationURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    do {
      let result = try await transfers.downloadFile(
        from: RemoteTransferURL(request.url.rawValue),
        to: LocalFileURL(destinationURL)
      )
      return (result, destinationURL)
    } catch {
      if FileManager.default.fileExists(atPath: destinationURL.path) {
        BenchmarkFiles.remove(destinationURL)
      }
      throw error
    }
  }

  private func validateDownload(
    _ result: FileTransferResult,
    at fileURL: URL
  ) throws {
    try BenchmarkIntegrity.validateTransfer(
      result,
      expectedBytes: Int64(HTTPBenchmarkFixture.downloadPayload.count),
      operation: "HTTP download"
    )
    try BenchmarkIntegrity.validateFile(
      at: fileURL,
      matches: HTTPBenchmarkFixture.downloadPayload,
      operation: "HTTP download"
    )
  }
}

private enum HTTPBenchmarkFixture {
  static let uploadPayloadSize = 65_536
  static let requestPayload = Data(repeating: 0x72, count: 1_024)
  static let downloadPayload = Data(repeating: 0x64, count: 1_048_576)
}
