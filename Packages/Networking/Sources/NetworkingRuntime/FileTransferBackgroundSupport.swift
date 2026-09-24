import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if !os(Linux)

/// Delegate for handling background transfer events.
///
/// URLSession may invoke delegate methods concurrently. All mutable state is private and every
/// access uses `lock`; the sendable handlers and immutable configuration can safely cross tasks.
final class BackgroundTransferDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
  typealias ProgressHandler = @Sendable (URLSessionDownloadTask, Int64, Int64) async -> Void
  typealias CompletionHandler =
    @Sendable (URLSessionTask, BackgroundTransferCompletion) async -> Void

  private let downloadDirectory: URL
  private let eventContinuation: AsyncStream<Event>.Continuation
  private let eventConsumer: Task<Void, Never>
  private let lock = NSLock()
  private var downloadedFiles: [Int: Result<URL, any Error>] = [:]

  private enum Event: Sendable {
    case progress(URLSessionDownloadTask, Int64, Int64)
    case completion(URLSessionTask, BackgroundTransferCompletion)
  }

  init(
    downloadDirectory: URL,
    progressHandler: @escaping ProgressHandler,
    completionHandler: @escaping CompletionHandler
  ) {
    let events = AsyncStream.makeStream(of: Event.self)
    self.downloadDirectory = downloadDirectory
    self.eventContinuation = events.continuation
    self.eventConsumer = Task {
      for await event in events.stream {
        switch event {
        case .progress(let task, let transferredBytes, let expectedBytes):
          await progressHandler(task, transferredBytes, expectedBytes)
        case .completion(let task, let completion):
          await completionHandler(task, completion)
        }
      }
    }
    super.init()
  }

  deinit {
    eventContinuation.finish()
    eventConsumer.cancel()
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    let downloadedFile = Result<URL, any Error>(catching: {
      let fileManager = FileManager.default
      try fileManager.createDirectory(
        at: downloadDirectory,
        withIntermediateDirectories: true
      )

      let suggestedName =
        downloadTask.response?.suggestedFilename
        ?? downloadTask.originalRequest?.url?.lastPathComponent
      let fileName =
        suggestedName.flatMap { name in
          let sanitizedName = URL(fileURLWithPath: name).lastPathComponent
          return sanitizedName.isEmpty ? nil : sanitizedName
        } ?? "download"
      let destination = downloadDirectory.appendingPathComponent(
        "\(UUID().uuidString)-\(fileName)"
      )

      try fileManager.moveItem(at: location, to: destination)
      return destination
    })

    lock.lock()
    downloadedFiles[downloadTask.taskIdentifier] = downloadedFile
    lock.unlock()
  }

  // swiftlint:disable:next function_parameter_count
  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    eventContinuation.yield(
      .progress(
        downloadTask,
        totalBytesWritten,
        totalBytesExpectedToWrite
      )
    )
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didResumeAtOffset fileOffset: Int64,
    expectedTotalBytes: Int64
  ) {
    eventContinuation.yield(.progress(downloadTask, fileOffset, expectedTotalBytes))
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: (any Error)?
  ) {
    lock.lock()
    let downloadedFile = downloadedFiles.removeValue(forKey: task.taskIdentifier)
    lock.unlock()

    let completion: BackgroundTransferCompletion
    if let error {
      let downloadedFileURL = try? downloadedFile?.get()
      completion = .failure(error, downloadedFileURL: downloadedFileURL)
    } else if let downloadedFile {
      switch downloadedFile {
      case .success(let fileURL):
        completion = .success(fileURL)
      case .failure(let error):
        completion = .failure(error, downloadedFileURL: nil)
      }
    } else {
      completion = .failure(
        FileTransferError.temporaryDirectoryUnavailable,
        downloadedFileURL: nil
      )
    }

    eventContinuation.yield(.completion(task, completion))
  }
}

func makeBackgroundTransferSession(
  transferConfiguration: FileTransferConfiguration,
  backgroundConfiguration: BackgroundTransferConfiguration,
  coordinator: BackgroundTransferCoordinator
) -> URLSession {
  let sessionConfiguration = URLSessionConfiguration.background(
    withIdentifier: backgroundConfiguration.backgroundSessionIdentifier.rawValue
  )
  sessionConfiguration.allowsCellularAccess =
    backgroundConfiguration.allowsCellularAccess.rawValue
  sessionConfiguration.allowsExpensiveNetworkAccess =
    backgroundConfiguration.allowsExpensiveNetworkAccess.rawValue
  sessionConfiguration.timeoutIntervalForRequest =
    backgroundConfiguration.timeoutIntervalForRequest.rawValue
  sessionConfiguration.timeoutIntervalForResource =
    backgroundConfiguration.timeoutIntervalForResource.rawValue

  let downloadDirectory =
    transferConfiguration.temporaryDirectory?.rawValue
    ?? FileManager.default.temporaryDirectory
  let delegate = BackgroundTransferDelegate(
    downloadDirectory: downloadDirectory,
    progressHandler: { task, totalBytesWritten, totalBytesExpected in
      await coordinator.didWriteData(
        task: task,
        totalBytesWritten: totalBytesWritten,
        totalBytesExpected: totalBytesExpected
      )
    },
    completionHandler: { task, completion in
      await coordinator.didComplete(task: task, completion: completion)
    }
  )

  let delegateQueue = OperationQueue()
  delegateQueue.maxConcurrentOperationCount = 1

  return URLSession(
    configuration: sessionConfiguration,
    delegate: delegate,
    delegateQueue: delegateQueue
  )
}

#endif
