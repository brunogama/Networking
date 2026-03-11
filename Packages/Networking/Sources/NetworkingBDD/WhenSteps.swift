import NetworkingRuntime
import NetworkingTesting
import Foundation

// swiftlint:disable file_length

// MARK: - When Steps for Network Testing

/// When step that performs an HTTP request.
public struct WhenRequest: WhenStep, DescribableStep {
  private let method: HTTPMethod
  private let path: RequestPathPattern
  private let body: HTTPBody?
  private let headers: HTTPHeaders
  private let queryParams: [QueryParameterName: QueryParameterValue]

  public var stepDescription: BDDStepText {
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
    path: RequestPathPattern,
    body: HTTPBody? = nil,
    headers: HTTPHeaders = [:],
    queryParams: [QueryParameterName: QueryParameterValue] = [:]
  ) {
    self.method = method
    self.path = path
    self.body = body
    self.headers = headers
    self.queryParams = queryParams
  }

  public func perform(context: ScenarioContext) async throws {
    let request = try buildRequest(context: context)
    context.lastRequest = request
    try await execute(request, with: context)
  }

  private func buildRequest(context: ScenarioContext) throws -> HTTPRequest {
    HTTPRequest(
      method: method,
      url: HTTPRequestURL(try buildURL(context: context)),
      headers: buildHeaders(context: context),
      body: body
    )
  }

  private func buildURL(context: ScenarioContext) throws -> URL {
    let baseURL =
      context[ContextKey<HTTPRequestURL>.baseURL]?.rawValue ?? URL(string: "https://localhost")!
    var urlComponents = URLComponents(
      url: baseURL.appendingPathComponent(path.rawValue),
      resolvingAgainstBaseURL: true
    )

    if !queryParams.isEmpty {
      urlComponents?.queryItems = queryParams.map {
        URLQueryItem(name: $0.key.rawValue, value: $0.value.rawValue)
      }
    }

    guard let url = urlComponents?.url else {
      throw BDDError.invalidConfiguration(
        key: UserMessageText("url"),
        reason: UserMessageText("Could not construct URL")
      )
    }

    return url
  }

  private func buildHeaders(context: ScenarioContext) -> HTTPHeaders {
    var allHeaders = HTTPHeaders()

    if let authHeader: HTTPHeaderValue = context[ContextKey<HTTPHeaderValue>.authHeader] {
      allHeaders["Authorization"] = authHeader
    }

    if let customHeaders: HTTPHeaders = context[ContextKey<HTTPHeaders>.customHeaders] {
      for (key, value) in customHeaders {
        allHeaders[key] = value
      }
    }

    for (key, value) in headers {
      allHeaders[key] = value
    }

    return allHeaders
  }

  private func execute(_ request: HTTPRequest, with context: ScenarioContext) async throws {
    do {
      let response = try await context.mockClient.execute(request)
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
  private let path: RequestPathPattern
  private let queryParams: [QueryParameterName: QueryParameterValue]

  public var stepDescription: BDDStepText {
    "GET request to \"\(path)\""
  }

  /// Creates a GET request step.
  ///
  /// - Parameters:
  ///   - path: Request path
  ///   - queryParams: Query parameters
  public init(
    _ path: RequestPathPattern,
    queryParams: [QueryParameterName: QueryParameterValue] = [:]
  ) {
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
  private let path: RequestPathPattern
  private let body: HTTPBody?

  public var stepDescription: BDDStepText {
    "POST request to \"\(path)\""
  }

  /// Creates a POST request step.
  ///
  /// - Parameters:
  ///   - path: Request path
  ///   - body: Request body
  public init(_ path: RequestPathPattern, body: HTTPBody? = nil) {
    self.path = path
    self.body = body
  }

  /// Creates a POST request step with JSON body.
  ///
  /// - Parameters:
  ///   - path: Request path
  ///   - json: Encodable JSON body
  public init<T: Encodable>(_ path: RequestPathPattern, json: T) throws {
    self.path = path
    self.body = HTTPBody(try JSONEncoder().encode(json))
  }

  public func perform(context: ScenarioContext) async throws {
    var headers = HTTPHeaders()
    if body != nil {
      headers["Content-Type"] = "application/json"
    }
    let request = WhenRequest(method: .post, path: path, body: body, headers: headers)
    try await request.perform(context: context)
  }
}

/// When step for PUT requests.
public struct WhenPUT: WhenStep, DescribableStep {
  private let path: RequestPathPattern
  private let body: HTTPBody?

  public var stepDescription: BDDStepText {
    "PUT request to \"\(path)\""
  }

  /// Creates a PUT request step.
  ///
  /// - Parameters:
  ///   - path: Request path
  ///   - body: Request body
  public init(_ path: RequestPathPattern, body: HTTPBody? = nil) {
    self.path = path
    self.body = body
  }

  /// Creates a PUT request step with JSON body.
  ///
  /// - Parameters:
  ///   - path: Request path
  ///   - json: Encodable JSON body
  public init<T: Encodable>(_ path: RequestPathPattern, json: T) throws {
    self.path = path
    self.body = HTTPBody(try JSONEncoder().encode(json))
  }

  public func perform(context: ScenarioContext) async throws {
    var headers = HTTPHeaders()
    if body != nil {
      headers["Content-Type"] = "application/json"
    }
    let request = WhenRequest(method: .put, path: path, body: body, headers: headers)
    try await request.perform(context: context)
  }
}

/// When step for PATCH requests.
public struct WhenPATCH: WhenStep, DescribableStep {
  private let path: RequestPathPattern
  private let body: HTTPBody?

  public var stepDescription: BDDStepText {
    "PATCH request to \"\(path)\""
  }

  /// Creates a PATCH request step.
  ///
  /// - Parameters:
  ///   - path: Request path
  ///   - body: Request body
  public init(_ path: RequestPathPattern, body: HTTPBody? = nil) {
    self.path = path
    self.body = body
  }

  public func perform(context: ScenarioContext) async throws {
    var headers = HTTPHeaders()
    if body != nil {
      headers["Content-Type"] = "application/json"
    }
    let request = WhenRequest(method: .patch, path: path, body: body, headers: headers)
    try await request.perform(context: context)
  }
}

/// When step for DELETE requests.
public struct WhenDELETE: WhenStep, DescribableStep {
  private let path: RequestPathPattern

  public var stepDescription: BDDStepText {
    "DELETE request to \"\(path)\""
  }

  /// Creates a DELETE request step.
  ///
  /// - Parameter path: Request path
  public init(_ path: RequestPathPattern) {
    self.path = path
  }

  public func perform(context: ScenarioContext) async throws {
    let request = WhenRequest(method: .delete, path: path)
    try await request.perform(context: context)
  }
}

/// When step that waits for a duration.
public struct WhenWait: WhenStep, DescribableStep {
  private let duration: RetryDelay

  public var stepDescription: BDDStepText {
    "wait for \(duration) seconds"
  }

  /// Creates a wait step.
  ///
  /// - Parameter duration: Duration to wait in seconds
  public init(_ duration: RetryDelay) {
    self.duration = duration
  }

  public func perform(context: ScenarioContext) async throws {
    try await Task.sleep(nanoseconds: UInt64(duration.rawValue * 1_000_000_000))
  }
}

/// When step that executes a custom action.
public struct WhenCustom: WhenStep, DescribableStep {
  private let description: BDDStepText
  private let action: @Sendable (ScenarioContext) async throws -> Void

  public var stepDescription: BDDStepText {
    description
  }

  /// Creates a custom When step.
  ///
  /// - Parameters:
  ///   - description: Step description
  ///   - action: The action to perform
  public init(
    _ description: BDDStepText,
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
public func whenGET(
  _ path: RequestPathPattern,
  queryParams: [QueryParameterName: QueryParameterValue] = [:]
) -> WhenGET {
  WhenGET(path, queryParams: queryParams)
}

/// Creates a POST request When step.
public func whenPOST(_ path: RequestPathPattern, body: HTTPBody? = nil) -> WhenPOST {
  WhenPOST(path, body: body)
}

/// Creates a POST request When step with JSON body.
public func whenPOST<T: Encodable>(_ path: RequestPathPattern, json: T) throws -> WhenPOST {
  try WhenPOST(path, json: json)
}

/// Creates a PUT request When step.
public func whenPUT(_ path: RequestPathPattern, body: HTTPBody? = nil) -> WhenPUT {
  WhenPUT(path, body: body)
}

/// Creates a PUT request When step with JSON body.
public func whenPUT<T: Encodable>(_ path: RequestPathPattern, json: T) throws -> WhenPUT {
  try WhenPUT(path, json: json)
}

/// Creates a PATCH request When step.
public func whenPATCH(_ path: RequestPathPattern, body: HTTPBody? = nil) -> WhenPATCH {
  WhenPATCH(path, body: body)
}

/// Creates a DELETE request When step.
public func whenDELETE(_ path: RequestPathPattern) -> WhenDELETE {
  WhenDELETE(path)
}

/// Creates a wait When step.
public func whenWait(_ duration: RetryDelay) -> WhenWait {
  WhenWait(duration)
}

/// Creates a custom When step.
public func whenRequest(
  _ description: BDDStepText,
  action: @escaping @Sendable (ScenarioContext) async throws -> Void
) -> WhenCustom {
  WhenCustom(description, action: action)
}
