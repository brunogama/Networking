import Foundation
import NetworkingCore
@testable import NetworkingRuntime
import NetworkingTesting
import Testing

struct CancellationCacheClient: HTTPClient {
  let started = AsyncStream<Void>.makeStream()
  let pending = AsyncStream<Void>.makeStream()

  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    started.continuation.yield(())
    for await _ in pending.stream {}
    try Task.checkCancellation()
    return HTTPResponse(request: request, status: .ok)
  }
}
