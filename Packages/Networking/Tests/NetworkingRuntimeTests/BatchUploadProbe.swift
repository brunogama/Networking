import Foundation
import NetworkingCore

actor BatchUploadProbe: HTTPClient {
  private let releaseAutomatically: Bool
  private let arrivals = AsyncStream<Int>.makeStream()
  private let release = AsyncStream<Void>.makeStream()
  private var calls = 0
  private(set) var active = 0
  private(set) var maximumActive = 0

  init(releaseAutomatically: Bool = true) {
    self.releaseAutomatically = releaseAutomatically
  }

  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    calls += 1
    active += 1
    maximumActive = max(maximumActive, active)
    arrivals.continuation.yield(calls)
    defer { active -= 1 }
    if releaseAutomatically, calls == 2 { release.continuation.finish() }
    await waitForRelease()
    try Task.checkCancellation()
    return HTTPResponse(request: request, status: .ok, body: HTTPBody(Data()))
  }

  func waitForStarts(_ expected: Int) async {
    for await count in arrivals.stream where count >= expected { return }
  }

  private func waitForRelease() async {
    let stream = release.stream
    guard releaseAutomatically else {
      for await _ in stream {}
      return
    }
    let continuation = release.continuation
    await withTaskGroup(of: Void.self) { group in
      group.addTask { for await _ in stream {} }
      group.addTask {
        do {
          // The watchdog makes the broken serial implementation fail instead of hanging.
          try await Task.sleep(for: .milliseconds(500))
          continuation.finish()
        } catch {}
      }
      await group.next()
      group.cancelAll()
    }
  }
}
