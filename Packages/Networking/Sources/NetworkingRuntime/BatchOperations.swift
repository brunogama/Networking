import NetworkingCore

/// The result of one request in a batch, identified by its original index.
public struct BatchResult: Sendable {

  public let index: BatchRequestIndex

  public let request: HTTPRequest

  public let result: Result<HTTPResponse, HTTPError>

  public var isSuccess: RequestSuccessFlag { RequestSuccessFlag(response != nil) }

  public var response: HTTPResponse? {
    guard case .success(let response) = result else { return nil }
    return response
  }

  public var error: HTTPError? {
    guard case .failure(let error) = result else { return nil }
    return error
  }
}

extension HTTPClient {

  public func executeBatch(
    _ requests: [HTTPRequest],
    configuration: BatchConfiguration = .default
  ) async -> [BatchResult] {
    await withTaskGroup(of: BatchResult.self) { group in
      let limit = configuration.maxConcurrency.rawValue
      let initialCount = limit > 0 ? min(limit, requests.count) : requests.count
      var nextIndex = 0
      while nextIndex < initialCount, !Task.isCancelled {
        let index = nextIndex
        group.addTask { await executeBatchRequest(requests[index], at: index) }
        nextIndex += 1
      }
      var results: [BatchResult] = []
      var stopped = Task.isCancelled
      for await result in group {
        results.append(result)
        stopped = stopped || Task.isCancelled || shouldStop(result, configuration: configuration)
        if stopped { group.cancelAll() }
        guard !stopped, nextIndex < requests.count else { continue }
        let index = nextIndex
        group.addTask { await executeBatchRequest(requests[index], at: index) }
        nextIndex += 1
      }
      return results.sorted { $0.index < $1.index }
    }
  }

  private func shouldStop(_ result: BatchResult, configuration: BatchConfiguration) -> Bool {
    configuration.cancelOnFailure.rawValue && result.error != nil
  }

  private func executeBatchRequest(_ request: HTTPRequest, at index: Int) async -> BatchResult {
    let outcome: Result<HTTPResponse, HTTPError>
    do {
      try Task.checkCancellation()
      outcome = .success(try await execute(request))
    } catch let error as HTTPError {
      outcome = .failure(error)
    } catch is CancellationError {
      outcome = .failure(.cancelled(request: request))
    } catch {
      outcome = .failure(
        HTTPError(
          category: .custom("Batch", "Request execution failed"),
          request: request,
          underlyingError: error
        )
      )
    }
    return BatchResult(index: BatchRequestIndex(index), request: request, result: outcome)
  }
}
