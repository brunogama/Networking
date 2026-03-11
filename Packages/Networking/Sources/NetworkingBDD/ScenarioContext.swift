import NetworkingRuntime
import NetworkingTesting
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
  private struct StorageKey: Hashable {
    let name: String
    let valueType: ObjectIdentifier

    init<T>(_ key: ContextKey<T>) {
      name = key.name.rawValue
      valueType = ObjectIdentifier(T.self)
    }
  }

  private var storage: [StorageKey: Any] = [:]

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
      storage[StorageKey(key)] = value
    }
  }

  /// Gets a value from the context for a given key.
  ///
  /// - Parameter key: The context key
  /// - Returns: The value, or nil if not set
  public func get<T: Sendable>(_ key: ContextKey<T>) -> T? {
    lock.withLock {
      storage[StorageKey(key)] as? T
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
    storage.removeValue(forKey: StorageKey(key))
  }

  /// Checks if a value exists for a key.
  ///
  /// - Parameter key: The context key
  /// - Returns: True if a value is set
  public func contains<T>(_ key: ContextKey<T>) -> ValidationFlag {
    lock.withLock {
      ValidationFlag(storage[StorageKey(key)] != nil)
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

  /// Dynamic subscript access for named keys.
  ///
  /// - Parameter key: Key name
  public subscript<T: Sendable>(dynamicKey key: BDDContextKeyName) -> T? {
    get { getValue(forKey: key, as: T.self) }
    set {
      if let newValue = newValue {
        setValue(newValue, forKey: key)
      }
    }
  }

  // MARK: - Named Storage

  /// Sets a value using a named key.
  ///
  /// - Parameters:
  ///   - value: The value to store
  ///   - key: Key name
  public func setValue<T: Sendable>(_ value: T, forKey key: BDDContextKeyName) {
    let contextKey = ContextKey<T>(key)
    set(value, for: contextKey)
  }

  /// Gets a value using a named key.
  ///
  /// - Parameters:
  ///   - key: Key name
  ///   - type: The expected type
  /// - Returns: The value, or nil if not set or wrong type
  public func getValue<T: Sendable>(forKey key: BDDContextKeyName, as type: T.Type = T.self) -> T? {
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
  public func requireBody() throws -> HTTPBody {
    let response = try requireResponse()
    guard let body = response.body else {
      throw BDDError.noBody
    }
    return body
  }

  /// Gets the response body as a string.
  ///
  /// - Parameter encoding: String encoding (default: UTF-8)
  /// - Returns: The body as text
  /// - Throws: `BDDError.noResponse`, `BDDError.noBody`
  public func requireBodyString(encoding: HTTPTextEncoding = .utf8) throws -> HTTPResponseText {
    let body = try requireBody()
    guard let resolvedEncoding = encoding.foundationEncoding,
      let string = String(data: body, encoding: resolvedEncoding)
    else {
      throw BDDError.noBody
    }
    return HTTPResponseText(string)
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
    return try decoder.decode(type, from: body.rawValue)
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
