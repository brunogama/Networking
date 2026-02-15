import Foundation

// MARK: - Scenario Context

/// Thread-safe context for sharing state between BDD steps.
///
/// `ScenarioContext` maintains state across Given, When, and Then steps
/// within a single scenario execution. It provides type-safe storage
/// for arbitrary values and convenience properties for networking tests.
///
/// ## Usage
///
/// ```swift
/// // In a Given step
/// context.set(URL(string: "https://api.example.com")!, for: .baseURL)
///
/// // In a When step
/// let baseURL = try context.require(.baseURL)
/// let response = try await client.execute(request)
/// context.lastResponse = response
///
/// // In a Then step
/// let response = try context.requireResponse()
/// expect(response.status).to(equal(.ok))
/// ```
///
/// ## Thread Safety
///
/// All operations are thread-safe via internal locking.
/// The context can be safely accessed from multiple concurrent steps.
public final class ScenarioContext: @unchecked Sendable {
  // MARK: - Private State

  private let lock = NSLock()
  private var storage: [ObjectIdentifier: Any] = [:]

  // MARK: - Network State

  /// The mock client for this scenario.
  public var mockClient: MockNetworkClient {
    get { lock.withLock { _mockClient } }
    set { lock.withLock { _mockClient = newValue } }
  }

  private var _mockClient = MockNetworkClient()

  /// The last HTTP request executed.
  public var lastRequest: HTTPRequest? {
    get { lock.withLock { _lastRequest } }
    set { lock.withLock { _lastRequest = newValue } }
  }

  private var _lastRequest: HTTPRequest?

  /// The last HTTP response received.
  public var lastResponse: HTTPResponse? {
    get { lock.withLock { _lastResponse } }
    set { lock.withLock { _lastResponse = newValue } }
  }

  private var _lastResponse: HTTPResponse?

  /// The last error encountered.
  public var lastError: Error? {
    get { lock.withLock { _lastError } }
    set { lock.withLock { _lastError = newValue } }
  }

  private var _lastError: Error?

  /// All requests executed in this scenario.
  public var requestHistory: [HTTPRequest] {
    get { lock.withLock { _requestHistory } }
    set { lock.withLock { _requestHistory = newValue } }
  }

  private var _requestHistory: [HTTPRequest] = []

  /// All responses received in this scenario.
  public var responseHistory: [HTTPResponse] {
    get { lock.withLock { _responseHistory } }
    set { lock.withLock { _responseHistory = newValue } }
  }

  private var _responseHistory: [HTTPResponse] = []

  // MARK: - Initialization

  /// Creates a new scenario context.
  public init() {}

  /// Creates a new scenario context with a pre-configured mock client.
  ///
  /// - Parameter mockClient: The mock client to use
  public init(mockClient: MockNetworkClient) {
    self._mockClient = mockClient
  }

  // MARK: - Type-Safe Storage

  /// Sets a value in the context for a given key.
  ///
  /// - Parameters:
  ///   - value: The value to store
  ///   - key: The context key
  public func set<T: Sendable>(_ value: T, for key: ContextKey<T>) {
    lock.withLock {
      storage[ObjectIdentifier(key)] = value
    }
  }

  /// Gets a value from the context for a given key.
  ///
  /// - Parameter key: The context key
  /// - Returns: The value, or nil if not set
  public func get<T: Sendable>(_ key: ContextKey<T>) -> T? {
    lock.withLock {
      storage[ObjectIdentifier(key)] as? T
    }
  }

  /// Gets a required value from the context.
  ///
  /// - Parameter key: The context key
  /// - Returns: The value
  /// - Throws: `BDDError.missingContextValue` if not set
  public func require<T: Sendable>(_ key: ContextKey<T>) throws -> T {
    guard let value = get(key) else {
      throw BDDError.missingContextValue(key: key.name)
    }
    return value
  }

  /// Removes a value from the context.
  ///
  /// - Parameter key: The context key
  public func remove<T>(_ key: ContextKey<T>) {
    lock.lock()
    defer { lock.unlock() }
    storage.removeValue(forKey: ObjectIdentifier(key))
  }

  /// Checks if a value exists for a key.
  ///
  /// - Parameter key: The context key
  /// - Returns: True if a value is set
  public func contains<T>(_ key: ContextKey<T>) -> Bool {
    lock.withLock {
      storage[ObjectIdentifier(key)] != nil
    }
  }

  // MARK: - Subscript Access

  /// Subscript access for context values.
  ///
  /// - Parameter key: The context key
  public subscript<T: Sendable>(key: ContextKey<T>) -> T? {
    get { get(key) }
    set {
      if let newValue = newValue {
        set(newValue, for: key)
      } else {
        remove(key)
      }
    }
  }

  /// Dynamic subscript access for string keys.
  ///
  /// - Parameter key: String key name
  public subscript<T: Sendable>(dynamicKey key: String) -> T? {
    get { getValue(forKey: key, as: T.self) }
    set {
      if let newValue = newValue {
        setValue(newValue, forKey: key)
      }
    }
  }

  // MARK: - String-Keyed Storage

  /// Sets a value using a string key.
  ///
  /// - Parameters:
  ///   - value: The value to store
  ///   - key: String key name
  public func setValue<T: Sendable>(_ value: T, forKey key: String) {
    let contextKey = ContextKey<T>(key)
    set(value, for: contextKey)
  }

  /// Gets a value using a string key.
  ///
  /// - Parameters:
  ///   - key: String key name
  ///   - type: The expected type
  /// - Returns: The value, or nil if not set or wrong type
  public func getValue<T: Sendable>(forKey key: String, as type: T.Type = T.self) -> T? {
    let contextKey = ContextKey<T>(key)
    return get(contextKey)
  }

  // MARK: - Convenience Methods

  /// Records a request in the history.
  ///
  /// - Parameter request: The request to record
  public func recordRequest(_ request: HTTPRequest) {
    lock.withLock {
      _lastRequest = request
      _requestHistory.append(request)
    }
  }

  /// Records a response in the history.
  ///
  /// - Parameter response: The response to record
  public func recordResponse(_ response: HTTPResponse) {
    lock.withLock {
      _lastResponse = response
      _responseHistory.append(response)
      _lastError = nil
    }
  }

  /// Records an error.
  ///
  /// - Parameter error: The error to record
  public func recordError(_ error: Error) {
    lock.withLock {
      _lastError = error
    }
  }

  /// Gets the last response or throws if none.
  ///
  /// - Returns: The last response
  /// - Throws: `BDDError.noResponse`
  public func requireResponse() throws -> HTTPResponse {
    guard let response = lastResponse else {
      throw BDDError.noResponse
    }
    return response
  }

  /// Gets the last request or throws if none.
  ///
  /// - Returns: The last request
  /// - Throws: `BDDError.noRequest`
  public func requireRequest() throws -> HTTPRequest {
    guard let request = lastRequest else {
      throw BDDError.noRequest
    }
    return request
  }

  /// Gets the response body or throws if none.
  ///
  /// - Returns: The response body data
  /// - Throws: `BDDError.noResponse` or `BDDError.noBody`
  public func requireBody() throws -> Data {
    let response = try requireResponse()
    guard let body = response.body else {
      throw BDDError.noBody
    }
    return body
  }

  /// Gets the response body as a string.
  ///
  /// - Parameter encoding: String encoding (default: UTF-8)
  /// - Returns: The body as a string
  /// - Throws: `BDDError.noResponse`, `BDDError.noBody`
  public func requireBodyString(encoding: String.Encoding = .utf8) throws -> String {
    let body = try requireBody()
    guard let string = String(data: body, encoding: encoding) else {
      throw BDDError.noBody
    }
    return string
  }

  /// Decodes the response body as JSON.
  ///
  /// - Parameters:
  ///   - type: The type to decode
  ///   - decoder: JSON decoder to use
  /// - Returns: The decoded value
  /// - Throws: Decoding errors
  public func decodeBody<T: Decodable>(
    as type: T.Type,
    using decoder: JSONDecoder = JSONDecoder()
  ) throws -> T {
    let body = try requireBody()
    return try decoder.decode(type, from: body)
  }

  // MARK: - Reset

  /// Clears all state in the context.
  public func clear() {
    lock.withLock {
      storage.removeAll()
      _mockClient = MockNetworkClient()
      _lastRequest = nil
      _lastResponse = nil
      _lastError = nil
      _requestHistory.removeAll()
      _responseHistory.removeAll()
    }
  }

  /// Resets network state only, preserving custom storage.
  public func resetNetworkState() {
    lock.withLock {
      _lastRequest = nil
      _lastResponse = nil
      _lastError = nil
      _requestHistory.removeAll()
      _responseHistory.removeAll()
    }
  }
}

// MARK: - Context Key

/// Type-safe key for storing values in ScenarioContext.
///
/// Context keys provide type safety when storing and retrieving
/// values from the scenario context.
///
/// ## Usage
///
/// Define keys as static properties:
///
/// ```swift
/// extension ContextKey {
///   static var baseURL: ContextKey<URL> { ContextKey("baseURL") }
///   static var authToken: ContextKey<String> { ContextKey("authToken") }
/// }
///
/// // Use in steps:
/// context.set(url, for: .baseURL)
/// let token = context.get(.authToken)
/// ```
public final class ContextKey<Value: Sendable>: Sendable {
  /// The key name for debugging.
  public let name: String

  /// Creates a new context key.
  ///
  /// - Parameter name: Descriptive name for the key
  public init(_ name: String) {
    self.name = name
  }
}

// MARK: - Predefined Context Keys

extension ContextKey where Value == URL {
  /// Key for base URL.
  public static var baseURL: ContextKey<URL> { ContextKey("baseURL") }
}

extension ContextKey where Value == String {
  /// Key for authentication token.
  public static var authToken: ContextKey<String> { ContextKey("authToken") }

  /// Key for API key.
  public static var apiKey: ContextKey<String> { ContextKey("apiKey") }

  /// Key for username.
  public static var username: ContextKey<String> { ContextKey("username") }

  /// Key for password.
  public static var password: ContextKey<String> { ContextKey("password") }
}

extension ContextKey where Value == Data {
  /// Key for response data.
  public static var responseData: ContextKey<Data> { ContextKey("responseData") }

  /// Key for request body data.
  public static var requestBody: ContextKey<Data> { ContextKey("requestBody") }
}

extension ContextKey where Value == [String: String] {
  /// Key for custom headers.
  public static var customHeaders: ContextKey<[String: String]> { ContextKey("customHeaders") }
}

extension ContextKey where Value == TimeInterval {
  /// Key for timeout duration.
  public static var timeout: ContextKey<TimeInterval> { ContextKey("timeout") }
}

extension ContextKey where Value == Int {
  /// Key for retry count.
  public static var retryCount: ContextKey<Int> { ContextKey("retryCount") }

  /// Key for expected status code.
  public static var expectedStatus: ContextKey<Int> { ContextKey("expectedStatus") }
}

extension ContextKey where Value == Bool {
  /// Key for authentication required flag.
  public static var requiresAuth: ContextKey<Bool> { ContextKey("requiresAuth") }
}

// MARK: - NSLock Extension

extension NSLock {
  /// Executes a closure while holding the lock.
  func withLock<T>(_ body: () throws -> T) rethrows -> T {
    lock()
    defer { unlock() }
    return try body()
  }
}
