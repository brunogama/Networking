import Foundation
import Networking
import os

struct BatchProgressBenchmarks: Sendable {
  private let context: BenchmarkContext

  init(context: BenchmarkContext) {
    self.context = context
  }

  func run() async throws -> [BenchmarkResult] {
    let uploadClient = BatchProgressUploadClient(context: context)
    let regular = try await ConcurrentBatchUploadBenchmark(
      context: context,
      uploadClient: uploadClient
    ).run()
    let slowSink = try await SlowProgressUploadBenchmark(
      context: context,
      uploadClient: uploadClient
    ).run()
    return [regular, slowSink]
  }
}

private struct ConcurrentBatchUploadBenchmark: Sendable {
  private let context: BenchmarkContext
  private let uploadClient: BatchProgressUploadClient

  init(context: BenchmarkContext, uploadClient: BatchProgressUploadClient) {
    self.context = context
    self.uploadClient = uploadClient
  }

  func run() async throws -> BenchmarkResult {
    let fileURL = try uploadClient.makeUploadFile()
    defer { BenchmarkFiles.remove(fileURL) }
    let batch = uploadClient.uploadInputs(fileURL)
    let callbackCount = OSAllocatedUnfairLock(initialState: 0)
    let callback = uploadClient.progressCallback(callbackCount)
    try await warmUp(batch, callback: callback)
    callbackCount.withLock { $0 = 0 }
    context.diagnostics.clear()
    let samples = try await sampleUploads(batch, callback: callback)
    let callbacks = callbackCount.withLock { $0 }
    guard callbacks > 0 else {
      throw TransferProgressBenchmarkFailure.noProgressCallbacks
    }
    return makeResult(samples, callbacks: callbacks)
  }

  private func warmUp(
    _ batch: BatchUploadInputs,
    callback: @escaping ProgressCallback
  ) async throws {
    let results = try await uploadClient.upload(batch, callback: callback)
    try BenchmarkIntegrity.validateTransfers(
      results,
      expecting: TransferProgressWorkload.uploadExpectation(
        operation: "Batch upload warm-up"
      )
    )
  }

  private func sampleUploads(
    _ batch: BatchUploadInputs,
    callback: @escaping ProgressCallback
  ) async throws -> [Double] {
    var samples: [Double] = []
    for _ in 0..<TransferProgressWorkload.sampleCount {
      let start = ContinuousClock.now
      let results = try await uploadClient.upload(batch, callback: callback)
      samples.append(BenchmarkTiming.milliseconds(start.duration(to: .now)))
      try BenchmarkIntegrity.validateTransfers(
        results,
        expecting: TransferProgressWorkload.uploadExpectation(
          operation: "Batch upload"
        )
      )
    }
    return samples
  }

  private func makeResult(
    _ samples: [Double],
    callbacks: Int
  ) -> BenchmarkResult {
    let duration = samples.reduce(0, +) / 1_000
    let sampleCount = Int64(samples.count)
    let byteCount = TransferProgressWorkload.totalUploadBytes * sampleCount
    let measurement = BenchmarkMeasurement(
      name: "Batch upload / 8 x 8 MiB / \(callbacks) progress callbacks",
      samplesMilliseconds: samples,
      bytesTransferred: byteCount,
      durationSeconds: duration
    )
    return context.makeResult(measurement)
  }
}

private struct SlowProgressUploadBenchmark: Sendable {
  private let context: BenchmarkContext
  private let uploadClient: BatchProgressUploadClient

  init(context: BenchmarkContext, uploadClient: BatchProgressUploadClient) {
    self.context = context
    self.uploadClient = uploadClient
  }

  func run() async throws -> BenchmarkResult {
    let fileURL = try uploadClient.makeUploadFile()
    defer { BenchmarkFiles.remove(fileURL) }
    let batch = uploadClient.uploadInputs(fileURL)
    let callbackCount = OSAllocatedUnfairLock(initialState: 0)
    let callback = uploadClient.progressCallback(
      callbackCount,
      delayMilliseconds: 1
    )
    context.diagnostics.clear()
    return try await measureSingleBatch(
      batch,
      callback: callback,
      count: callbackCount
    )
  }

  private func measureSingleBatch(
    _ batch: BatchUploadInputs,
    callback: @escaping ProgressCallback,
    count: OSAllocatedUnfairLock<Int>
  ) async throws -> BenchmarkResult {
    let start = ContinuousClock.now
    let results = try await uploadClient.upload(batch, callback: callback)
    let duration = BenchmarkTiming.seconds(start.duration(to: .now))
    try BenchmarkIntegrity.validateTransfers(
      results,
      expecting: TransferProgressWorkload.uploadExpectation(
        operation: "Batch upload"
      )
    )
    let callbackCount = count.withLock { $0 }
    guard callbackCount > 0 else {
      throw TransferProgressBenchmarkFailure.noProgressCallbacks
    }
    let measurement = BenchmarkMeasurement(
      name: "Batch upload / 1 ms progress sink / \(callbackCount) callbacks",
      samplesMilliseconds: [duration * 1_000],
      bytesTransferred: TransferProgressWorkload.totalUploadBytes,
      durationSeconds: duration
    )
    return context.makeResult(measurement)
  }
}

private struct BatchProgressUploadClient: Sendable {
  private let context: BenchmarkContext
  private let transfers: FileTransferOperations

  init(context: BenchmarkContext) {
    self.context = context
    transfers = FileTransferOperations(httpClient: context.clients.http)
  }

  func upload(
    _ batch: BatchUploadInputs,
    callback: @escaping ProgressCallback
  ) async throws -> [FileTransferResult] {
    let concurrency = BatchConcurrencyLimit(
      TransferProgressWorkload.uploadCount
    )
    return try await transfers.uploadFiles(
      from: batch.files,
      to: batch.destinations,
      maxConcurrency: concurrency,
      progressCallback: callback
    )
  }

  func uploadInputs(_ fileURL: URL) -> BatchUploadInputs {
    let localFile = LocalFileURL(fileURL)
    let uploadCount = TransferProgressWorkload.uploadCount
    let files = Array(repeating: localFile, count: uploadCount)
    let baseURL = context.configuration.baseURL
    let remoteURL = baseURL.appending(path: "batch-upload")
    let destination = RemoteTransferURL(remoteURL)
    let destinations = Array(repeating: destination, count: uploadCount)
    return BatchUploadInputs(files: files, destinations: destinations)
  }

  func makeUploadFile() throws -> URL {
    try BenchmarkFiles.create(
      byteCount: TransferProgressWorkload.uploadBytes,
      prefix: "networking-progress"
    )
  }

  func progressCallback(
    _ callbackCount: OSAllocatedUnfairLock<Int>,
    delayMilliseconds: Int = 0
  ) -> ProgressCallback {
    { _ in
      callbackCount.withLock { $0 += 1 }
      guard delayMilliseconds > 0 else { return }
      Thread.sleep(forTimeInterval: Double(delayMilliseconds) / 1_000)
    }
  }
}

private struct BatchUploadInputs {
  let files: [LocalFileURL]
  let destinations: [RemoteTransferURL]
}
