import Foundation
import NetworkingCore
import NetworkingRuntime

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

typealias SSEContinuation = AsyncThrowingStream<SSEConnectionEvent, any Error>.Continuation

struct SSEConnectionState {
  var lastEventID: SSELastEventID?
  var serverRetryHint: SSEReconnectDelay?
  var reconnectAttempts: SSEReconnectAttempt = 0

  init(configuration: SSEConfiguration) {
    lastEventID = configuration.lastEventID
  }
}

public final class SSEClient: Sendable {
  let session: URLSession
  let requestMiddlewares: [any HTTPRequestMiddleware]

  public init(
    session: URLSession = .shared,
    requestMiddlewares: [any HTTPRequestMiddleware] = []
  ) {
    self.session = session
    self.requestMiddlewares = requestMiddlewares
  }

  public convenience init(
    sessionConfiguration: SessionConfiguration = .init(),
    securityConfiguration: SecurityConfiguration? = nil,
    requestMiddlewares: [any HTTPRequestMiddleware] = []
  ) {
    self.init(
      session: sessionConfiguration.createURLSession(securityConfiguration: securityConfiguration),
      requestMiddlewares: requestMiddlewares
    )
  }

  public func connect(
    _ request: HTTPRequest,
    configuration: SSEConfiguration = .init()
  ) -> AsyncThrowingStream<SSEConnectionEvent, any Error> {
    AsyncThrowingStream { continuation in
      let connectionTask = Task {
        do {
          try await runConnectionLoop(
            for: request,
            configuration: configuration,
            continuation: continuation
          )
          continuation.finish()
        } catch is CancellationError {
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }

      continuation.onTermination = { @Sendable _ in
        connectionTask.cancel()
      }
    }
  }
}
