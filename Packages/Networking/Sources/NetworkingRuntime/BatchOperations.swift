import Foundation
import NetworkingCore

// MARK: - Batch Request Builder

/// Result builder for constructing a list of HTTP requests for batch execution.
///
/// ## Usage
///
/// ```swift
/// let results = try await client.batch {
///     request1
///     request2
///     request3
/// }
/// ```
@resultBuilder
public struct BatchRequestBuilder {
  public static func buildBlock(_ components: HTTPRequest...) -> [HTTPRequest] {
    components
  }

  public static func buildOptional(_ component: [HTTPRequest]?) -> [HTTPRequest] {
    component ?? []
  }

  public static func buildEither(first component: [HTTPRequest]) -> [HTTPRequest] {
    component
  }

  public static func buildEither(second component: [HTTPRequest]) -> [HTTPRequest] {
    component
  }

  public static func buildArray(_ components: [[HTTPRequest]]) -> [HTTPRequest] {
    components.flatMap { $0 }
  }

  public static func buildExpression(_ expression: HTTPRequest) -> [HTTPRequest] {
    [expression]
  }

  public static func buildPartialBlock(first: [HTTPRequest]) -> [HTTPRequest] {
    first
  }

  public static func buildPartialBlock(
    accumulated: [HTTPRequest],
    next: [HTTPRequest]
  ) -> [HTTPRequest] {
    accumulated + next
  }
}

// MARK: - Batch Result

/// The result of a single request within a batch operation.
public struct BatchResult: Sendable {
  /// The index of the request in the original batch.
  public let index: BatchRequestIndex

  /// The original request.
  public let request: HTTPRequest

  /// The result of executing the request.
  public let result: Result<HTTPResponse, HTTPError>

  /// Whether the request succeeded.
  public var isSuccess: RequestSuccessFlag {
    if case .success = result { return true }
    return false
  }

  /// The response, if the request succeeded.
  public var response: HTTPResponse? {
    if case .success(let response) = result { return response }
    return nil
  }

  /// The error, if the request failed.
  public var error: HTTPError? {
    if case .failure(let error) = result { return error }
    return nil
  }
}

// MARK: - Batch Configuration

/// Configuration for batch request execution.
public struct BatchConfiguration: Sendable {
  /// Maximum number of concurrent requests.
  public let maxConcurrency: BatchConcurrencyLimit

  /// Whether to cancel remaining requests if one fails.
  public let cancelOnFailure: CancelOnFailureFlag

  /// Creates a batch configuration.
  ///
  /// - Parameters:
  ///   - maxConcurrency: Maximum concurrent requests (default: unlimited, 0 = unlimited)
  ///   - cancelOnFailure: Cancel remaining on first failure (default: false)
  public init(
    maxConcurrency: BatchConcurrencyLimit = 0,
    cancelOnFailure: CancelOnFailureFlag = false
  ) {
    self.maxConcurrency = maxConcurrency
    self.cancelOnFailure = cancelOnFailure
  }

  /// Default configuration with unlimited concurrency and no cancel-on-failure.
  public static let `default` = Self()

  /// Serial execution (one request at a time).
  public static let serial = Self(maxConcurrency: 1)
}

// MARK: - HTTPClient Batch Extension

private struct BatchExecutionResult: Sendable {
  let index: Int
  let request: HTTPRequest
  let result: Result<HTTPResponse, HTTPError>
}

extension HTTPClient {
  /// Executes multiple HTTP requests concurrently and returns all results.
  ///
  /// Each request is executed independently. A failure in one request does not
  /// affect others (unless `cancelOnFailure` is set in the configuration).
  ///
  /// ## Usage
  ///
  /// ```swift
  /// let results = try await client.batch {
  ///     HTTPRequest(method: .get, url: URL(string: "https://api.example.com/users/1")!)
  ///     HTTPRequest(method: .get, url: URL(string: "https://api.example.com/users/2")!)
  ///     HTTPRequest(method: .get, url: URL(string: "https://api.example.com/users/3")!)
  /// }
  ///
  /// for result in results {
  ///     switch result.result {
  ///     case .success(let response):
  ///         logger("Request \(result.index): \(response.status)")
  ///     case .failure(let error):
  ///         logger("Request \(result.index) failed: \(error)")
  ///     }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - configuration: Batch execution configuration (default: `.default`)
  ///   - content: A result builder closure providing the requests
  /// - Returns: Array of ``BatchResult`` in the same order as the input requests
  public func batch(
    configuration: BatchConfiguration = .default,
    @BatchRequestBuilder _ content: () -> [HTTPRequest]
  ) async -> [BatchResult] {
    let requests = content()
    return await executeBatch(requests, configuration: configuration)
  }

  /// Executes an array of HTTP requests concurrently.
  ///
  /// - Parameters:
  ///   - requests: The requests to execute
  ///   - configuration: Batch execution configuration
  /// - Returns: Array of ``BatchResult`` in the same order as the input requests
  public func executeBatch(
    _ requests: [HTTPRequest],
    configuration: BatchConfiguration = .default
  ) async -> [BatchResult] {
    guard !requests.isEmpty else { return [] }

    let limiter = BatchConcurrencyLimiter(maxConcurrency: configuration.maxConcurrency)

    return await withTaskGroup(of: BatchExecutionResult.self) { group in
      for (index, request) in requests.enumerated() {
        group.addTask { await self.executeBatchRequest(request, at: index, limiter: limiter) }
      }

      var results = [BatchResult]()
      results.reserveCapacity(requests.count)

      for await batchResult in group {
        results.append(
          BatchResult(
            index: BatchRequestIndex(batchResult.index),
            request: batchResult.request,
            result: batchResult.result
          )
        )
      }

      // Sort by original index to preserve order
      return results.sorted { $0.index < $1.index }
    }
  }

  private func executeBatchRequest(
    _ request: HTTPRequest,
    at index: Int,
    limiter: BatchConcurrencyLimiter
  ) async -> BatchExecutionResult {
    await limiter.acquire()
    defer { Task { await limiter.release() } }

    do {
      let response = try await execute(request)
      return BatchExecutionResult(
        index: index,
        request: request,
        result: Result<HTTPResponse, HTTPError>.success(response)
      )
    } catch let error as HTTPError {
      return BatchExecutionResult(
        index: index,
        request: request,
        result: Result<HTTPResponse, HTTPError>.failure(error)
      )
    } catch {
      return BatchExecutionResult(
        index: index,
        request: request,
        result: Result<HTTPResponse, HTTPError>.failure(wrapBatchError(error, request: request))
      )
    }
  }

  private func wrapBatchError(_ error: any Error, request: HTTPRequest) -> HTTPError {
    HTTPError(
      category: .custom("batch", HTTPErrorDetail(error.localizedDescription)),
      request: request,
      underlyingError: error
    )
  }
}
