import NetworkingCore
import os

/// A thread-safe, idempotent cancellation capability that cannot resurrect a completed request.
///
/// Copies share one state protected by a lock; continuations are resumed after releasing that lock.
public final class RequestCancellation: Sendable {
  typealias Waiter = CheckedContinuation<Result<HTTPResponse, HTTPError>, Never>

  let id = RequestTicketID()
  let termination: AsyncStream<Void>
  private let signal: AsyncStream<Void>.Continuation
  private let request: HTTPRequest
  private let state = OSAllocatedUnfairLock(initialState: State.pending(nil))

  init(request: HTTPRequest) {
    self.request = request
    (termination, signal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
  }

  /// Cancels this ticket's wait and signals the scoped task to stop.
  ///
  /// The first terminal operation wins. This method returns `true` only when it records the
  /// cancellation result; every later cancellation or completion returns `false` without
  /// changing that result. It is safe to call concurrently from multiple tasks.
  @discardableResult
  public func cancel() -> Bool { finish(.failure(.cancelled(request: request))) }

  func value() async -> Result<HTTPResponse, HTTPError> {
    await withTaskCancellationHandler {
      if Task.isCancelled { cancel() }
      return await withCheckedContinuation { continuation in
        let result = state.withLock { state -> Result<HTTPResponse, HTTPError>? in
          if case .finished(let result) = state { return result }
          state = .pending(continuation)
          return nil
        }
        if let result { continuation.resume(returning: result) }
      }
    } onCancel: {
      self.cancel()
    }
  }

  @discardableResult
  func finish(_ result: Result<HTTPResponse, HTTPError>) -> Bool {
    let completion = state.withLock { state -> (accepted: Bool, waiter: Waiter?) in
      guard case .pending(let waiter) = state else { return (false, nil) }
      state = .finished(result)
      return (true, waiter)
    }
    guard completion.accepted else { return false }
    completion.waiter?.resume(returning: result)
    signal.finish()
    return true
  }

  func execute(using client: any HTTPClient) async {
    do {
      try Task.checkCancellation()
      finish(.success(try await client.execute(request)))
    } catch let error as HTTPError {
      finish(.failure(error))
    } catch is CancellationError {
      cancel()
    } catch {
      finish(
        .failure(
          HTTPError(
            category: .custom("Client", "Request execution failed"),
            request: request,
            underlyingError: error
          )
        )
      )
    }
  }

  func run(using client: any HTTPClient) async {
    guard
      state.withLock({
        if case .pending = $0 { return true }
        return false
      })
    else { return }
    await withTaskGroup(of: Void.self) { group in
      group.addTask { await self.execute(using: client) }
      group.addTask { for await _ in self.termination {} }
      await group.next()
      group.cancelAll()
    }
  }
}
