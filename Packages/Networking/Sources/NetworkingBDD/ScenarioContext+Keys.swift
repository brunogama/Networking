import NetworkingRuntime
import NetworkingTesting
import Foundation

/// Type-safe key for storing values in `ScenarioContext`.
///
/// Context keys provide type safety when storing and retrieving values
/// from the scenario context.
public final class ContextKey<Value: Sendable>: Sendable {
  /// The key name for debugging.
  public let name: BDDContextKeyName

  /// Creates a new context key.
  ///
  /// - Parameter name: Descriptive name for the key
  public init(_ name: BDDContextKeyName) {
    self.name = name
  }
}

extension ContextKey where Value == HTTPRequestURL {
  /// Key for base URL.
  public static var baseURL: ContextKey<HTTPRequestURL> { ContextKey("baseURL") }
}

extension ContextKey where Value == BearerTokenValue {
  /// Key for authentication token.
  public static var authToken: ContextKey<BearerTokenValue> { ContextKey("authToken") }
}

extension ContextKey where Value == HTTPHeaderValue {
  /// Key for API key.
  public static var apiKey: ContextKey<HTTPHeaderValue> { ContextKey("apiKey") }

  /// Authentication header value.
  public static var authHeader: ContextKey<HTTPHeaderValue> { ContextKey("authHeader") }
}

extension ContextKey where Value == BasicAuthUsername {
  /// Key for username.
  public static var username: ContextKey<BasicAuthUsername> { ContextKey("username") }
}

extension ContextKey where Value == BasicAuthPassword {
  /// Key for password.
  public static var password: ContextKey<BasicAuthPassword> { ContextKey("password") }
}

extension ContextKey where Value == HTTPBody {
  /// Key for response data.
  public static var responseData: ContextKey<HTTPBody> { ContextKey("responseData") }

  /// Key for request body data.
  public static var requestBody: ContextKey<HTTPBody> { ContextKey("requestBody") }
}

extension ContextKey where Value == HTTPHeaders {
  /// Key for custom headers.
  public static var customHeaders: ContextKey<HTTPHeaders> { ContextKey("customHeaders") }
}

extension ContextKey where Value == RequestTimeout {
  /// Key for timeout duration.
  public static var timeout: ContextKey<RequestTimeout> { ContextKey("timeout") }
}

extension ContextKey where Value == RetryAttemptCount {
  /// Key for retry count.
  public static var retryCount: ContextKey<RetryAttemptCount> { ContextKey("retryCount") }
}

extension ContextKey where Value == HTTPStatusCode {
  /// Key for expected status code.
  public static var expectedStatus: ContextKey<HTTPStatusCode> { ContextKey("expectedStatus") }
}

extension ContextKey where Value == AuthenticationRequiredFlag {
  /// Key for authentication required flag.
  public static var requiresAuth: ContextKey<AuthenticationRequiredFlag> {
    ContextKey("requiresAuth")
  }
}

extension NSLock {
  /// Executes a closure while holding the lock.
  func withLock<T>(_ body: () throws -> T) rethrows -> T {
    lock()
    defer { unlock() }
    return try body()
  }
}
