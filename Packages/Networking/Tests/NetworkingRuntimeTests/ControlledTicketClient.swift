import Foundation
import NetworkingCore
import NetworkingRuntime
import Testing

actor ControlledTicketClient: HTTPClient {
  let started: AsyncStream<Void>
  private let signalStarted: AsyncStream<Void>.Continuation
  private let release: AsyncStream<Void>
  private let signalRelease: AsyncStream<Void>.Continuation
  private(set) var didCancel = false
  private(set) var didFinish = false

  init() {
    (started, signalStarted) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    (release, signalRelease) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
  }

  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    defer { didFinish = true }
    signalStarted.yield(())
    await withTaskCancellationHandler {
      for await _ in release {}
    } onCancel: {
      self.signalRelease.finish()
    }
    didCancel = Task.isCancelled
    try Task.checkCancellation()
    return HTTPResponse(request: request, status: .ok, body: HTTPBody(Data()))
  }
}
