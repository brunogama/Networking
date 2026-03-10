import Foundation
import NetworkingRuntime

/// A chain of interceptors that execute sequentially during HTTP request/response processing.
///
/// The `InterceptorChain` manages the execution of both request and response interceptors,
/// ensuring they run in registration order and handling control flow (proceed, short-circuit, retry).
///
/// ## Example: Creating an Interceptor Chain
///
/// ```swift
/// let chain = InterceptorChain(
///   requestInterceptors: [
///     AuthenticationInterceptor(tokenProvider: .shared),
///     LoggingInterceptor()
///   ],
///   responseInterceptors: [
///     TokenRefreshInterceptor(tokenProvider: .shared),
///     RetryInterceptor(maxAttempts: 3),
///     LoggingInterceptor()
///   ]
/// )
/// ```
///
/// ## Example: Using in Macro-Generated Code
///
/// ```swift
/// public func getUser(id: String) async throws -> User {
///   let path = "/users/\(id)"
///   var request = HTTPRequest(method: .get, path: path, baseURL: baseURL)
///   let context = InterceptorContext(path: path, method: .get, attemptCount: 0)
///
///   // Execute request interceptors
///   let requestResult = try await interceptors.executeRequestInterceptors(
///     request: &request,
///     context: context
///   )
///
///   // Handle short-circuit
///   if case .shortCircuit(let response) = requestResult {
///     return try JSONDecoder().decode(User.self, from: response.body ?? Data())
///   }
///
///   // Execute network call
///   let response = try await client.execute(request)
///
///   // Execute response interceptors (with retry support)
///   _ = try await interceptors.executeResponseInterceptors(
///     response: response,
///     context: context
///   )
///
///   return try JSONDecoder().decode(User.self, from: response.body ?? Data())
/// }
/// ```
///
/// - Note: All interceptors must be Sendable for Swift 6 strict concurrency compliance.
/// - Important: Interceptors execute in registration order. The order matters when interceptors
///   depend on each other (e.g., authentication before logging).
/// - Important: `InterceptorChain` is a compatibility layer. Prefer `NetworkClient` middleware
///   composition for new runtime behavior.
@available(
  *,
  deprecated,
  message: """
    InterceptorChain is a compatibility API.
    Prefer NetworkClient middleware composition for new runtime behavior.
    """
)
public struct InterceptorChain: Sendable {
  // MARK: - Properties

  /// Request interceptors that execute before network calls
  private let requestInterceptors: [any RequestInterceptor]

  /// Response interceptors that execute after network calls
  private let responseInterceptors: [any ResponseInterceptor]

  // MARK: - Initialization

  /// Creates a new interceptor chain with the specified interceptors.
  ///
  /// - Parameters:
  ///   - requestInterceptors: Interceptors to execute before network calls (default: empty)
  ///   - responseInterceptors: Interceptors to execute after network calls (default: empty)
  ///
  /// - Note: Interceptors execute in the order they appear in the arrays.
  public init(
    requestInterceptors: [any RequestInterceptor] = [],
    responseInterceptors: [any ResponseInterceptor] = []
  ) {
    self.requestInterceptors = requestInterceptors
    self.responseInterceptors = responseInterceptors
  }

  // MARK: - Request Interceptor Execution

  /// Executes all request interceptors in sequence.
  ///
  /// Request interceptors execute in registration order. Each interceptor can:
  /// - Modify the request (add headers, query parameters, etc.)
  /// - Continue to the next interceptor (`.proceed`)
  /// - Short-circuit the network call with a cached response (`.shortCircuit`)
  ///
  /// - Parameters:
  ///   - request: The mutable HTTP request that interceptors can modify
  ///   - context: Contextual information about the request
  /// - Returns: The result from the last interceptor, or `.shortCircuit` if any interceptor
  ///   short-circuited the chain
  /// - Throws: `InterceptorError.interceptorFailed` if any interceptor throws an error
  public func executeRequestInterceptors(
    request: inout HTTPRequest,
    context: InterceptorContext
  ) async throws -> InterceptorResult {
    for interceptor in requestInterceptors {
      do {
        let result = try await interceptor.intercept(request: &request, context: context)

        // Handle short-circuit: stop execution and return the response
        if case .shortCircuit = result {
          return result
        }

        // Continue to next interceptor
      } catch {
        throw InterceptorError.interceptorFailed(underlyingError: error)
      }
    }

    // All interceptors returned .proceed
    return .proceed
  }

  // MARK: - Response Interceptor Execution

  /// Executes all response interceptors in sequence.
  ///
  /// Response interceptors execute in registration order. Each interceptor can:
  /// - Inspect the response (status, headers, body)
  /// - Continue to the next interceptor (`.proceed`)
  /// - Trigger a retry (`.retry(after:)`)
  /// - Replace the response (`.shortCircuit`)
  ///
  /// - Parameters:
  ///   - response: The HTTP response from the network
  ///   - context: Contextual information about the request
  /// - Returns: The result from the last interceptor, or `.retry`/`.shortCircuit` if any
  ///   interceptor returned those values
  /// - Throws: `InterceptorError.interceptorFailed` if any interceptor throws an error
  ///
  /// - Important: If an interceptor returns `.retry()`, execution stops and the result is returned.
  ///   The caller is responsible for implementing the retry loop and checking max attempts.
  public func executeResponseInterceptors(
    response: HTTPResponse,
    context: InterceptorContext
  ) async throws -> InterceptorResult {
    for interceptor in responseInterceptors {
      do {
        let result = try await interceptor.intercept(response: response, context: context)

        // Handle retry: stop execution and signal retry
        if case .retry = result {
          return result
        }

        // Handle short-circuit: stop execution and return replacement response
        if case .shortCircuit = result {
          return result
        }

        // Continue to next interceptor
      } catch {
        throw InterceptorError.interceptorFailed(underlyingError: error)
      }
    }

    // All interceptors returned .proceed
    return .proceed
  }

  // MARK: - Convenience Methods

  /// Checks if the chain has any request interceptors.
  public var hasRequestInterceptors: InterceptorPresenceFlag {
    InterceptorPresenceFlag(!requestInterceptors.isEmpty)
  }

  /// Checks if the chain has any response interceptors.
  public var hasResponseInterceptors: InterceptorPresenceFlag {
    InterceptorPresenceFlag(!responseInterceptors.isEmpty)
  }

  /// Checks if the chain has any interceptors at all.
  public var isEmpty: InterceptorPresenceFlag {
    InterceptorPresenceFlag(requestInterceptors.isEmpty && responseInterceptors.isEmpty)
  }

  // MARK: - Monoid Operations

  /// Empty interceptor chain (identity element for monoid).
  ///
  /// The empty chain is the identity element for `appending(_:)`:
  /// - `empty.appending(a)` is equivalent to `a`
  /// - `a.appending(empty)` is equivalent to `a`
  public static var empty: Self {
    Self(requestInterceptors: [], responseInterceptors: [])
  }

  /// Combines this chain with another chain.
  ///
  /// Creates a new chain that executes the interceptors from both chains in sequence.
  /// Request interceptors from `self` execute before those from `other`.
  /// Response interceptors from `self` execute before those from `other`.
  ///
  /// - Parameter other: The chain to append to this chain
  /// - Returns: A new chain containing all interceptors from both chains
  ///
  /// ## Monoid Laws
  ///
  /// This operation satisfies the monoid laws:
  /// - **Left Identity**: `empty.appending(a)` is equivalent to `a`
  /// - **Right Identity**: `a.appending(empty)` is equivalent to `a`
  /// - **Associativity**: `(a.appending(b)).appending(c)` is equivalent to `a.appending(b.appending(c))`
  public func appending(_ other: Self) -> Self {
    Self(
      requestInterceptors: requestInterceptors + other.requestInterceptors,
      responseInterceptors: responseInterceptors + other.responseInterceptors
    )
  }

  // MARK: - Accessors for Testing

  /// Returns the count of request interceptors for testing purposes.
  public var requestInterceptorCount: InterceptorCount {
    InterceptorCount(requestInterceptors.count)
  }

  /// Returns the count of response interceptors for testing purposes.
  public var responseInterceptorCount: InterceptorCount {
    InterceptorCount(responseInterceptors.count)
  }
}
