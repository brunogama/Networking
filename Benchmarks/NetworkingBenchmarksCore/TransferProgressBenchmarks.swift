import Foundation
import Networking
import os

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

private struct BatchProgressBenchmarks: Sendable {
  private let context: BenchmarkContext
  private let transfers: FileTransferOperations

  init(context: BenchmarkContext) {
    self.context = context
    transfers = FileTransferOperations(httpClient: context.clients.http)
  }

  func run() async throws -> [BenchmarkResult] {
    let regular = try await measureConcurrentUploads()
    let slowSink = try await measureSlowProgressCallback()
    return [regular, slowSink]
  }

  private func measureConcurrentUploads() async throws -> BenchmarkResult {
    let fileURL = try makeUploadFile()
    defer { BenchmarkFiles.remove(fileURL) }
    let batch = uploadInputs(fileURL)
    let callbackCount = OSAllocatedUnfairLock(initialState: 0)
    let callback = progressCallback(callbackCount)
    try await upload(batch.files, batch.destinations, callback: callback)
    callbackCount.withLock { $0 = 0 }
    context.diagnostics.clear()
    let samples = try await sampleUploads(batch, callback: callback)
    let callbacks = callbackCount.withLock { $0 }
    guard callbacks > 0 else {
      throw TransferProgressBenchmarkFailure.noProgressCallbacks
    }
    return makeUploadResult(
      samples,
      callbacks: callbacks,
      batchCount: Workload.sampleCount
    )
  }

  private func measureSlowProgressCallback() async throws -> BenchmarkResult {
    let fileURL = try makeUploadFile()
    defer { BenchmarkFiles.remove(fileURL) }
    let batch = uploadInputs(fileURL)
    let callbackCount = OSAllocatedUnfairLock(initialState: 0)
    let callback = progressCallback(callbackCount, delayMilliseconds: 1)
    context.diagnostics.clear()
    let start = ContinuousClock.now
    try await upload(batch.files, batch.destinations, callback: callback)
    let duration = BenchmarkTiming.seconds(start.duration(to: .now))
    let callbacks = callbackCount.withLock { $0 }
    guard callbacks > 0 else {
      throw TransferProgressBenchmarkFailure.noProgressCallbacks
    }
    let measurement = BenchmarkMeasurement(
      name: "Batch upload / 1 ms progress sink / \(callbacks) callbacks",
      samplesMilliseconds: [duration * 1_000],
      bytesTransferred: Workload.totalUploadBytes,
      durationSeconds: duration
    )
    return context.makeResult(measurement)
  }

  private func sampleUploads(
    _ batch: (files: [LocalFileURL], destinations: [RemoteTransferURL]),
    callback: @escaping ProgressCallback
  ) async throws -> [Double] {
    var samples: [Double] = []
    for _ in 0..<Workload.sampleCount {
      let start = ContinuousClock.now
      try await upload(batch.files, batch.destinations, callback: callback)
      samples.append(BenchmarkTiming.milliseconds(start.duration(to: .now)))
    }
    return samples
  }

  private func makeUploadResult(
    _ samples: [Double],
    callbacks: Int,
    batchCount: Int
  ) -> BenchmarkResult {
    let duration = samples.reduce(0, +) / 1_000
    let measurement = BenchmarkMeasurement(
      name: "Batch upload / 8 x 8 MiB / \(callbacks) progress callbacks",
      samplesMilliseconds: samples,
      bytesTransferred: Workload.totalUploadBytes * Int64(batchCount),
      durationSeconds: duration
    )
    return context.makeResult(measurement)
  }

  private func progressCallback(
    _ callbackCount: OSAllocatedUnfairLock<Int>,
    delayMilliseconds: Int = 0
  ) -> ProgressCallback {
    { _ in
      callbackCount.withLock { $0 += 1 }
      if delayMilliseconds > 0 {
        // Block the serial consumer so uploads can outpace event draining.
        Thread.sleep(forTimeInterval: Double(delayMilliseconds) / 1_000)
      }
    }
  }

  private func upload(
    _ files: [LocalFileURL],
    _ destinations: [RemoteTransferURL],
    callback: @escaping ProgressCallback
  ) async throws {
    _ = try await transfers.uploadFiles(
      from: files,
      to: destinations,
      maxConcurrency: BatchConcurrencyLimit(Workload.uploadCount),
      progressCallback: callback
    )
  }

}

private extension BatchProgressBenchmarks {
  func uploadInputs(
    _ fileURL: URL
  ) -> (files: [LocalFileURL], destinations: [RemoteTransferURL]) {
    let localFile = LocalFileURL(fileURL)
    let uploadCount = Workload.uploadCount
    let files = Array(repeating: localFile, count: uploadCount)
    let baseURL = context.configuration.baseURL
    let remoteURL = baseURL.appending(path: "batch-upload")
    let destination = RemoteTransferURL(remoteURL)
    let destinations = Array(repeating: destination, count: uploadCount)
    return (files, destinations)
  }

  func makeUploadFile() throws -> URL {
    try BenchmarkFiles.create(
      byteCount: Workload.uploadBytes,
      prefix: "networking-progress"
    )
  }
}

private struct SSEBackpressureBenchmark: Sendable {
  private let context: BenchmarkContext

  init(context: BenchmarkContext) {
    self.context = context
  }

  func run() async throws -> BenchmarkResult {
    context.diagnostics.clear()
    let start = ContinuousClock.now
    let eventCount = try await consumeSlowly()
    let duration = BenchmarkTiming.seconds(start.duration(to: .now))
    let measurement = BenchmarkMeasurement(
      name: "SSE slow consumer / buffer 32 / overflow after \(eventCount) events",
      samplesMilliseconds: [duration * 1_000],
      bytesTransferred: Int64(eventCount * Workload.eventBytes),
      durationSeconds: duration
    )
    return context.makeResult(measurement)
  }

  private func consumeSlowly() async throws -> Int {
    let request = context.makeRequest("sse")
    let configuration = SSEConfiguration(
      reconnectMode: .disabled,
      maxBufferedEvents: Workload.sseBufferSize
    )
    return try await consume(request, configuration: configuration)
  }

  private func consume(
    _ request: HTTPRequest,
    configuration: SSEConfiguration
  ) async throws -> Int {
    var deliveredEvents = 0
    do {
      let eventClient = context.clients.events
      let stream = eventClient.connect(
        request,
        configuration: configuration
      )
      for try await event in stream {
        guard case .event = event else { continue }
        deliveredEvents += 1
        try await Task.sleep(for: Workload.consumerDelay)
      }
    } catch SSEStreamError.bufferOverflow {
      return deliveredEvents
    }
    throw TransferProgressBenchmarkFailure.backpressureNotObserved
  }
}

private enum TransferProgressBenchmarkFailure: Error {
  case noProgressCallbacks
  case backpressureNotObserved
}

private enum Workload {
  static let uploadBytes = 8 * 1_024 * 1_024
  static let uploadCount = 8
  static let sampleCount = 3
  static let sseBufferSize = 32
  static let eventBytes = 40
  static let consumerDelay = Duration.milliseconds(2)
  static let totalUploadBytes = Int64(uploadBytes * uploadCount)
}
