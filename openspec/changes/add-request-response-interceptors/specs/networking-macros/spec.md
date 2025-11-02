# Spec Delta: Networking Macros - Request/Response Interceptors

## ADDED Requirements

### Requirement: Request Interceptor Protocol

The system SHALL provide a RequestInterceptor protocol that allows developers to define reusable middleware components that inspect and modify HTTP requests before they are sent to the network.

#### Scenario: Define protocol for request interception

- **WHEN** a developer implements the RequestInterceptor protocol
- **AND** the interceptor is registered in an @Interceptors annotation
- **THEN** the interceptor's intercept method is called before each network request
- **AND** the interceptor can modify request headers, query parameters, and body
- **AND** the interceptor can short-circuit the network call by returning a cached response

#### Acceptance Criteria
- `RequestInterceptor` protocol defined with `intercept(request:context:)` method
- Protocol marked `Sendable` for Swift 6 compliance
- Method signature: `func intercept(request: inout HTTPRequest, context: InterceptorContext) async throws -> InterceptorResult`
- Interceptors can add/modify headers, query parameters, body
- Interceptors can short-circuit network call (e.g., cache hit)
- Interceptors execute in registration order

**Example**:
```swift
public protocol RequestInterceptor: Sendable {
  func intercept(
    request: inout HTTPRequest,
    context: InterceptorContext
  ) async throws -> InterceptorResult
}

// Implementation
struct AuthenticationInterceptor: RequestInterceptor {
  func intercept(request: inout HTTPRequest, context: InterceptorContext) async throws -> InterceptorResult {
    request.addHeader(name: "Authorization", value: "Bearer \(token)")
    return .proceed
  }
}
```

---

### Requirement: Response Interceptor Protocol

The system SHALL provide a ResponseInterceptor protocol that allows developers to define middleware components that inspect HTTP responses and trigger retries or response replacement after network calls complete.

#### Scenario: Define protocol for response interception

- **WHEN** a developer implements the ResponseInterceptor protocol
- **AND** the interceptor is registered in an @Interceptors annotation
- **THEN** the interceptor's intercept method is called after each network response
- **AND** the interceptor can inspect response status, headers, and body
- **AND** the interceptor can trigger a retry (e.g., after token refresh on 401)
- **AND** the interceptor can replace the response (e.g., with cached version)

#### Acceptance Criteria
- `ResponseInterceptor` protocol defined with `intercept(response:context:)` method
- Protocol marked `Sendable` for Swift 6 compliance
- Method signature: `func intercept(response: HTTPResponse, context: InterceptorContext) async throws -> InterceptorResult`
- Interceptors can inspect response status, headers, body
- Interceptors can trigger retry (e.g., on 401 after token refresh)
- Interceptors can replace response (e.g., cached version)
- Interceptors execute in registration order

**Example**:
```swift
public protocol ResponseInterceptor: Sendable {
  func intercept(
    response: HTTPResponse,
    context: InterceptorContext
  ) async throws -> InterceptorResult
}

// Implementation
struct TokenRefreshInterceptor: ResponseInterceptor {
  func intercept(response: HTTPResponse, context: InterceptorContext) async throws -> InterceptorResult {
    guard response.statusCode == 401 else { return .proceed }
    try await refreshToken()
    return .retry(after: nil)
  }
}
```

---

### Requirement: Interceptor Result Type

The system SHALL provide an InterceptorResult enum that interceptors return to control execution flow, supporting proceed, short-circuit, and retry operations.

#### Scenario: Control flow from interceptors

- **WHEN** an interceptor completes its work
- **THEN** it returns an InterceptorResult value
- **AND** .proceed continues to next interceptor or network call
- **AND** .shortCircuit(HTTPResponse) skips network call and uses provided response
- **AND** .retry(after: Duration?) triggers request retry with optional delay

#### Acceptance Criteria
- `InterceptorResult` enum defined with three cases
- `.proceed` case: Continue to next interceptor or network call
- `.shortCircuit(HTTPResponse)` case: Skip network call, use provided response
- `.retry(after: Duration?)` case: Retry request after optional delay
- Enum marked `Sendable`
- Chain executor handles all cases correctly

**Example**:
```swift
public enum InterceptorResult: Sendable {
  case proceed
  case shortCircuit(HTTPResponse)
  case retry(after: Duration? = nil)
}

// Usage
func intercept(request: inout HTTPRequest, context: InterceptorContext) async throws -> InterceptorResult {
  if let cached = cache.get(request.path) {
    return .shortCircuit(cached) // Skip network call
  }
  return .proceed // Continue to network
}
```

---

### Requirement: Interceptor Context

The system SHALL provide an InterceptorContext struct containing request metadata (path, method, attempt count) that is passed to all interceptors for context-aware decision making.

#### Scenario: Pass request metadata to interceptors

- **WHEN** an interceptor is called during request/response processing
- **THEN** it receives an InterceptorContext parameter
- **AND** context contains the request path, HTTP method, and current attempt count
- **AND** context is immutable and Sendable for thread safety

#### Acceptance Criteria
- `InterceptorContext` struct defined with required properties
- Properties: `path: String`, `method: HTTPMethod`, `attemptCount: Int`, `metadata: [String: Any]`
- Struct marked `Sendable`
- Context created per-request, immutable during interceptor execution
- Attempt count incremented on each retry

**Example**:
```swift
public struct InterceptorContext: Sendable {
  public let path: String
  public let method: HTTPMethod
  public let attemptCount: Int
  public let metadata: [String: AnySendable]

  public init(path: String, method: HTTPMethod, attemptCount: Int = 0, metadata: [String: AnySendable] = [:]) {
    self.path = path
    self.method = method
    self.attemptCount = attemptCount
    self.metadata = metadata
  }
}

// Usage
let context = InterceptorContext(path: "/users/123", method: .GET, attemptCount: 0)
```

---

### Requirement: Interceptor Chain Executor

The system SHALL provide an InterceptorChain struct that executes registered interceptors sequentially in order, handling proceed, short-circuit, and retry results appropriately.

#### Scenario: Execute interceptors sequentially

- **WHEN** an HTTP method is called on a macro-generated API client
- **THEN** all request interceptors execute in registration order before the network call
- **AND** all response interceptors execute in registration order after the network call
- **AND** execution stops early on short-circuit results
- **AND** retry results trigger the retry loop with incremented attempt count

#### Acceptance Criteria
- `InterceptorChain` struct defined with request/response interceptor arrays
- `executeRequestInterceptors(request:context:)` method executes all request interceptors sequentially
- `executeResponseInterceptors(response:context:)` method executes all response interceptors sequentially
- Short-circuit stops chain execution and returns response
- Retry triggers retry loop with max attempts checking
- Errors from interceptors wrapped in `InterceptorError` and propagated
- Chain marked `Sendable`

**Example**:
```swift
public struct InterceptorChain: Sendable {
  private let requestInterceptors: [any RequestInterceptor]
  private let responseInterceptors: [any ResponseInterceptor]

  public func executeRequestInterceptors(
    request: inout HTTPRequest,
    context: InterceptorContext
  ) async throws -> InterceptorResult {
    for interceptor in requestInterceptors {
      let result = try await interceptor.intercept(request: &request, context: context)
      if case .shortCircuit = result { return result }
    }
    return .proceed
  }

  public func executeResponseInterceptors(
    response: HTTPResponse,
    context: InterceptorContext
  ) async throws -> InterceptorResult {
    for interceptor in responseInterceptors {
      let result = try await interceptor.intercept(response: response, context: context)
      if case .retry = result { return result }
    }
    return .proceed
  }
}
```

---

### Requirement: Interceptor Error Handling

The system SHALL provide an InterceptorError enum that wraps interceptor failures and max retry violations with actionable error messages.

#### Scenario: Handle interceptor failures

- **WHEN** an interceptor throws an error during execution
- **OR** the retry loop exceeds maximum attempts
- **THEN** the error is wrapped in an InterceptorError
- **AND** error messages include context (interceptor name, attempt count)
- **AND** errors propagate to the caller with full diagnostic information

#### Acceptance Criteria
- `InterceptorError` enum defined with three cases
- `.maxRetriesExceeded(maxAttempts: Int)` case for retry limit
- `.interceptorFailed(underlyingError: Error)` case for interceptor errors
- `.invalidResult(reason: String)` case for invalid result states
- Enum conforms to `Error` and `Sendable`
- All cases provide `localizedDescription` with actionable info

**Example**:
```swift
public enum InterceptorError: Error, Sendable {
  case maxRetriesExceeded(maxAttempts: Int)
  case interceptorFailed(underlyingError: Error)
  case invalidResult(reason: String)
}

extension InterceptorError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .maxRetriesExceeded(let max):
      return "Maximum retry attempts (\(max)) exceeded"
    case .interceptorFailed(let error):
      return "Interceptor failed: \(error.localizedDescription)"
    case .invalidResult(let reason):
      return "Invalid interceptor result: \(reason)"
    }
  }
}
```

---

### Requirement: @Interceptors Macro Annotation

The system SHALL provide an @Interceptors macro that accepts an array of interceptor instances and generates interceptor chain initialization code in the implementation struct.

#### Scenario: Declare interceptors on API protocol

- **WHEN** a developer annotates an @API protocol with @Interceptors([...])
- **THEN** the macro extracts all interceptor instances from the array
- **AND** generates an InterceptorChain property in the implementation struct
- **AND** initializes the chain with request and response interceptors in the init() method
- **AND** validates at compile-time that all instances conform to interceptor protocols

#### Acceptance Criteria
- `@Interceptors` macro accepts array of interceptor instances
- Macro validates interceptor types conform to `RequestInterceptor` or `ResponseInterceptor`
- Generated implementation struct contains `private let interceptors: InterceptorChain` property
- Generated `init(client:)` initializes chain with provided interceptors
- Macro emits compile-time diagnostics for invalid interceptor types
- Works with all existing `@API` configuration macros

**Example**:
```swift
@API(baseURL: "https://api.example.com")
@Interceptors([
  AuthenticationInterceptor(tokenProvider: .shared),
  LoggingInterceptor()
])
protocol UserAPI {
  @GET("/users/{id}")
  func getUser(id: String) async throws -> User
}

// Generated code
public struct UserAPIImplementation: UserAPI, Sendable {
  private let client: NetworkClient
  private let baseURL: String = "https://api.example.com"
  private let interceptors: InterceptorChain

  public init(client: NetworkClient = .shared) {
    self.client = client
    self.interceptors = InterceptorChain(
      requestInterceptors: [AuthenticationInterceptor(tokenProvider: .shared)],
      responseInterceptors: [LoggingInterceptor()]
    )
  }
}
```

---

## MODIFIED Requirements

### Requirement: HTTP Method Macro Code Generation

The HTTP method macros SHALL detect the presence of @Interceptors on the parent protocol and inject interceptor chain execution hooks in all generated endpoint methods.

#### Scenario: Inject interceptor hooks in generated code

- **WHEN** a developer uses an HTTP method macro (@GET, @POST, etc.)
- **AND** the parent protocol has an @Interceptors annotation
- **THEN** the generated method creates an InterceptorContext
- **AND** calls executeRequestInterceptors before the network call
- **AND** calls executeResponseInterceptors after the network call
- **AND** handles short-circuit, retry, and proceed results correctly

#### Acceptance Criteria
- All HTTP method macros detect presence of `@Interceptors` on parent protocol
- Generated code creates `InterceptorContext` with path, method, attempt count
- Generated code calls `interceptors.executeRequestInterceptors()` before network call
- Generated code calls `interceptors.executeResponseInterceptors()` after network call
- Generated code handles `.shortCircuit` by skipping network and using provided response
- Generated code handles `.retry` by looping with updated context
- Generated code respects max retry attempts (default: 3)
- Zero interceptors case generates identical code to Phase 5.2 (no overhead)

**Example**:
```swift
// With @Interceptors
public func getUser(id: String) async throws -> User {
  let path = "/users/\(id)"
  var request = HTTPRequest(method: .GET, path: path, baseURL: baseURL)
  let context = InterceptorContext(path: path, method: .GET, attemptCount: 0)

  // Request interceptors
  let requestResult = try await interceptors.executeRequestInterceptors(
    request: &request, context: context
  )
  guard case .proceed = requestResult else {
    if case .shortCircuit(let response) = requestResult {
      return try JSONDecoder().decode(User.self, from: response.data)
    }
    fatalError("Unexpected result from request interceptors")
  }

  // Network call
  var response = try await client.execute(request)

  // Response interceptors with retry loop
  var retryContext = context
  while retryContext.attemptCount < 3 {
    let responseResult = try await interceptors.executeResponseInterceptors(
      response: response, context: retryContext
    )

    if case .proceed = responseResult {
      break
    } else if case .retry(let delay) = responseResult {
      if let delay = delay {
        try await Task.sleep(for: delay)
      }
      retryContext = InterceptorContext(
        path: retryContext.path,
        method: retryContext.method,
        attemptCount: retryContext.attemptCount + 1
      )
      response = try await client.execute(request)
    }
  }

  return try JSONDecoder().decode(User.self, from: response.data)
}
```

---

### Requirement: APIMacro Implementation Struct Generation

The APIMacro SHALL detect @Interceptors annotations and generate an InterceptorChain property with proper initialization in the implementation struct's init method.

#### Scenario: Add interceptor chain property to implementation

- **WHEN** an @API protocol is annotated with @Interceptors
- **THEN** the generated implementation struct contains an interceptors property
- **AND** the property is initialized with request and response interceptors
- **AND** initialization separates RequestInterceptor from ResponseInterceptor conformances
- **AND** works correctly with existing @DefaultHeaders and @Timeout macros

#### Acceptance Criteria
- APIMacro detects `@Interceptors` attribute on protocol
- Extracts interceptor types from annotation arguments
- Generates `private let interceptors: InterceptorChain` property
- Generates chain initialization in `init(client:)` method
- Separates request interceptors from response interceptors
- Validates all interceptor types at compile-time
- Works with existing `@DefaultHeaders` and `@Timeout` macros

**Example**:
```swift
// Input
@API(baseURL: "https://api.example.com")
@DefaultHeaders(["User-Agent": "MyApp"])
@Interceptors([
  AuthenticationInterceptor(),
  LoggingInterceptor(),
  RetryInterceptor(maxAttempts: 3)
])
protocol MyAPI {
  @GET("/data")
  func getData() async throws -> Data
}

// Generated
public struct MyAPIImplementation: MyAPI, Sendable {
  private let client: NetworkClient
  private let baseURL: String = "https://api.example.com"
  private let defaultHeaders: [String: String] = ["User-Agent": "MyApp"]
  private let interceptors: InterceptorChain

  public init(client: NetworkClient = .shared) {
    self.client = client
    self.interceptors = InterceptorChain(
      requestInterceptors: [
        AuthenticationInterceptor(),
        LoggingInterceptor()
      ],
      responseInterceptors: [
        LoggingInterceptor(),
        RetryInterceptor(maxAttempts: 3)
      ]
    )
  }
}
```

---

## REMOVED Requirements

None. This change is purely additive with no removed functionality.
