import Foundation

// MARK: - When Steps for Network Testing

/// When step that performs an HTTP request.
public struct WhenRequest: WhenStep, DescribableStep {
  private let method: HTTPMethod
  private let path: String
  private let body: Data?
  private let headers: [String: String]
  private let queryParams: [String: String]

  public var stepDescription: String {
    "\(method.rawValue) request to \"\(path)\""
  }

  /// Creates an HTTP request step.
  ///
  /// - Parameters:
  ///   - method: HTTP method
  ///   - path: Request path
  ///   - body: Optional request body
  ///   - headers: Request headers
  ///   - queryParams: Query parameters
  public init(
    method: HTTPMethod,
    path: String,
    body: Data? = nil,
    headers: [String: String] = [:],
    queryParams: [String: String] = [:]
  ) {
    self.method = method
    self.path = path
    self.body = body
    self.headers = headers
    self.queryParams = queryParams
  }

  public func perform(context: ScenarioContext) async throws {
    let mockClient = context.mockClient

    // Build URL
    let baseURL = context[.baseURL] ?? URL(string: "https://localhost")!
    var urlComponents = URLComponents(
      url: baseURL.appendingPathComponent(path),
      resolvingAgainstBaseURL: true
    )

    if !queryParams.isEmpty {
      urlComponents?.queryItems = queryParams.map {
        URLQueryItem(name: $0.key, value: $0.value)
      }
    }

    guard let url = urlComponents?.url else {
      throw BDDError.invalidConfiguration(key: "url", reason: "Could not construct URL")
    }

    // Build headers
    var allHeaders: [String: String] = [:]

    // Add headers from context
    if let authHeader: String = context[.authHeader] {
      allHeaders["Authorization"] = authHeader
    }

    if let customHeaders: [String: String] = context[.customHeaders] {
      for (key, value) in customHeaders {
        allHeaders[key] = value
      }
    }

    // Add step-specific headers
    for (key, value) in headers {
      allHeaders[key] = value
    }

    // Build request
    let request = HTTPRequest(
      method: method,
      url: url,
      headers: allHeaders,
      body: body
    )

    // Record the request
    context.lastRequest = request

    // Execute the request
    do {
      let response = try await mockClient.execute(request)
      context.lastResponse = response
      context.lastError = nil
    } catch {
      context.lastError = error
      context.lastResponse = nil
    }
  }
}

/// When step for GET requests.
public struct WhenGET: WhenStep, DescribableStep {
  private let path: String
  private let queryParams: [String: String]

  public var stepDescription: String {
    "GET request to \"\(path)\""
  }

  /// Creates a GET request step.
  ///
  /// - Parameters:
  ///   - path: Request path
  ///   - queryParams: Query parameters
  public init(_ path: String, queryParams: [String: String] = [:]) {
    self.path = path
    self.queryParams = queryParams
  }

  public func perform(context: ScenarioContext) async throws {
    let request = WhenRequest(method: .get, path: path, queryParams: queryParams)
    try await request.perform(context: context)
  }
}

/// When step for POST requests.
public struct WhenPOST: WhenStep, DescribableStep {
  private let path: String
  private let body: Data?

  public var stepDescription: String {
    "POST request to \"\(path)\""
  }

  /// Creates a POST request step.
  ///
  /// - Parameters:
  ///   - path: Request path
  ///   - body: Request body
  public init(_ path: String, body: Data? = nil) {
    self.path = path
    self.body = body
  }

  /// Creates a POST request step with JSON body.
  ///
  /// - Parameters:
  ///   - path: Request path
  ///   - json: Encodable JSON body
  public init<T: Encodable>(_ path: String, json: T) throws {
    self.path = path
    self.body = try JSONEncoder().encode(json)
  }

  public func perform(context: ScenarioContext) async throws {
    var headers: [String: String] = [:]
    if body != nil {
      headers["Content-Type"] = "application/json"
    }
    let request = WhenRequest(method: .post, path: path, body: body, headers: headers)
    try await request.perform(context: context)
  }
}

/// When step for PUT requests.
public struct WhenPUT: WhenStep, DescribableStep {
  private let path: String
  private let body: Data?

  public var stepDescription: String {
    "PUT request to \"\(path)\""
  }

  /// Creates a PUT request step.
  ///
  /// - Parameters:
  ///   - path: Request path
  ///   - body: Request body
  public init(_ path: String, body: Data? = nil) {
    self.path = path
    self.body = body
  }

  /// Creates a PUT request step with JSON body.
  ///
  /// - Parameters:
  ///   - path: Request path
  ///   - json: Encodable JSON body
  public init<T: Encodable>(_ path: String, json: T) throws {
    self.path = path
    self.body = try JSONEncoder().encode(json)
  }

  public func perform(context: ScenarioContext) async throws {
    var headers: [String: String] = [:]
    if body != nil {
      headers["Content-Type"] = "application/json"
    }
    let request = WhenRequest(method: .put, path: path, body: body, headers: headers)
    try await request.perform(context: context)
  }
}

/// When step for PATCH requests.
public struct WhenPATCH: WhenStep, DescribableStep {
  private let path: String
  private let body: Data?

  public var stepDescription: String {
    "PATCH request to \"\(path)\""
  }

  /// Creates a PATCH request step.
  ///
  /// - Parameters:
  ///   - path: Request path
  ///   - body: Request body
  public init(_ path: String, body: Data? = nil) {
    self.path = path
    self.body = body
  }

  public func perform(context: ScenarioContext) async throws {
    var headers: [String: String] = [:]
    if body != nil {
      headers["Content-Type"] = "application/json"
    }
    let request = WhenRequest(method: .patch, path: path, body: body, headers: headers)
    try await request.perform(context: context)
  }
}

/// When step for DELETE requests.
public struct WhenDELETE: WhenStep, DescribableStep {
  private let path: String

  public var stepDescription: String {
    "DELETE request to \"\(path)\""
  }

  /// Creates a DELETE request step.
  ///
  /// - Parameter path: Request path
  public init(_ path: String) {
    self.path = path
  }

  public func perform(context: ScenarioContext) async throws {
    let request = WhenRequest(method: .delete, path: path)
    try await request.perform(context: context)
  }
}

/// When step that waits for a duration.
public struct WhenWait: WhenStep, DescribableStep {
  private let duration: TimeInterval

  public var stepDescription: String {
    "wait for \(duration) seconds"
  }

  /// Creates a wait step.
  ///
  /// - Parameter duration: Duration to wait in seconds
  public init(_ duration: TimeInterval) {
    self.duration = duration
  }

  public func perform(context: ScenarioContext) async throws {
    try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
  }
}

/// When step that executes a custom action.
public struct WhenCustom: WhenStep, DescribableStep {
  private let description: String
  private let action: @Sendable (ScenarioContext) async throws -> Void

  public var stepDescription: String {
    description
  }

  /// Creates a custom When step.
  ///
  /// - Parameters:
  ///   - description: Step description
  ///   - action: The action to perform
  public init(
    _ description: String,
    action: @escaping @Sendable (ScenarioContext) async throws -> Void
  ) {
    self.description = description
    self.action = action
  }

  public func perform(context: ScenarioContext) async throws {
    try await action(context)
  }
}

// MARK: - Convenience Functions (prefixed to avoid macro conflicts)

/// Creates a GET request When step.
public func whenGET(_ path: String, queryParams: [String: String] = [:]) -> WhenGET {
  WhenGET(path, queryParams: queryParams)
}

/// Creates a POST request When step.
public func whenPOST(_ path: String, body: Data? = nil) -> WhenPOST {
  WhenPOST(path, body: body)
}

/// Creates a POST request When step with JSON body.
public func whenPOST<T: Encodable>(_ path: String, json: T) throws -> WhenPOST {
  try WhenPOST(path, json: json)
}

/// Creates a PUT request When step.
public func whenPUT(_ path: String, body: Data? = nil) -> WhenPUT {
  WhenPUT(path, body: body)
}

/// Creates a PUT request When step with JSON body.
public func whenPUT<T: Encodable>(_ path: String, json: T) throws -> WhenPUT {
  try WhenPUT(path, json: json)
}

/// Creates a PATCH request When step.
public func whenPATCH(_ path: String, body: Data? = nil) -> WhenPATCH {
  WhenPATCH(path, body: body)
}

/// Creates a DELETE request When step.
public func whenDELETE(_ path: String) -> WhenDELETE {
  WhenDELETE(path)
}

/// Creates a wait When step.
public func whenWait(_ duration: TimeInterval) -> WhenWait {
  WhenWait(duration)
}

/// Creates a custom When step.
public func whenRequest(
  _ description: String,
  action: @escaping @Sendable (ScenarioContext) async throws -> Void
) -> WhenCustom {
  WhenCustom(description, action: action)
}
