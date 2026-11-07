import Foundation
import NetworkingCore
import NetworkingRuntime

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

typealias SSEContinuation = AsyncThrowingStream<SSEConnectionEvent, any Error>.Continuation

/// Streams server-sent events with cancellation, bounded buffering, and optional diagnostics.
public final class SSEClient: Sendable {
  let session: URLSession
  let requestMiddlewares: [any HTTPRequestMiddleware]
  let diagnostics: NetworkDiagnostics?

  /// Creates a streaming client whose connection task ends when the stream is terminated.
  public init(
    session: URLSession = .shared,
    requestMiddlewares: [any HTTPRequestMiddleware] = [],
    diagnostics: NetworkDiagnostics? = nil
  ) {
    self.session = session
    self.requestMiddlewares = requestMiddlewares
    self.diagnostics = diagnostics
  }

  /// Creates a streaming client with the configured session and TLS policies.
  public convenience init(
    sessionConfiguration: SessionConfiguration = .init(),
    securityConfiguration: SecurityConfiguration? = nil,
    requestMiddlewares: [any HTTPRequestMiddleware] = [],
    diagnostics: NetworkDiagnostics? = nil
  ) {
    self.init(
      session: sessionConfiguration.createURLSession(securityConfiguration: securityConfiguration),
      requestMiddlewares: requestMiddlewares,
      diagnostics: diagnostics
    )
  }

  /// Opens a stream that cancels its connection task when iteration terminates.
  public func connect(
    _ request: HTTPRequest,
    configuration: SSEConfiguration = .init()
  ) -> AsyncThrowingStream<SSEConnectionEvent, any Error> {
    AsyncThrowingStream(bufferingPolicy: .bufferingOldest(configuration.maxBufferedEvents)) {
      continuation in
      let connectionTask = Task {
        do {
          if let limit = configuration.maximumResponseBytes, limit < 0 {
            throw SSEStreamError.invalidConfiguration
          }
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

  func yieldEvent(
    _ event: SSEConnectionEvent,
    to continuation: SSEContinuation
  ) throws {
    switch continuation.yield(event) {
    case .enqueued:
      return
    case .dropped:
      throw SSEStreamError.bufferOverflow
    case .terminated:
      throw CancellationError()
    @unknown default:
      throw SSEStreamError.bufferOverflow
    }
  }
}
