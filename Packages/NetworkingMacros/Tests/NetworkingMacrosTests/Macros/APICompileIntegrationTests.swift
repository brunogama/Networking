import Networking
import NetworkingMacros
import NetworkingTesting
import Testing

public struct MacroCompileUser: Codable, Equatable, Sendable {
  public let id: Int
  public let name: String

  public init(id: Int, name: String) {
    self.id = id
    self.name = name
  }
}

@API(baseURL: .absolute("https://api.example.com"))
public protocol MacroCompileUsersAPI {
  @GET(.path("/users/{id}"))
  func user(id: Int) async throws -> MacroCompileUser

  @POST(.path("/users"), queryParameters: [.parameter("notify")])
  @Body(.parameter("user"))
  func create(user: MacroCompileUser, notify: Bool) async throws -> MacroCompileUser

  @PUT(.path("/users/{id}"))
  @Body(.parameter("user"))
  func replace(id: Int, with user: MacroCompileUser) async throws -> MacroCompileUser

  @PATCH(.path("/users/{id}"))
  @Body(.parameter("user"))
  func update(id: Int, with user: MacroCompileUser) async throws -> MacroCompileUser

  @DELETE(.path("/users/{id}"))
  func delete(id: Int) async throws
}

@API(baseURL: .absolute("https://api.example.com"))
@Interceptors([
  AuthenticationInterceptor.bearer("token"),
  RetryInterceptor(maxAttempts: 1, baseDelay: 0, maxDelay: 0),
])
public protocol MacroCompileRetryAPI {
  @GET(.path("/retry"))
  func user() async throws -> MacroCompileUser
}

private struct AlwaysRetryInterceptor: ResponseInterceptor {
  func intercept(
    response: HTTPResponse,
    context: InterceptorContext
  ) async throws -> InterceptorResult {
    .retry()
  }
}

@API(baseURL: .absolute("https://api.example.com"))
@Interceptors([AlwaysRetryInterceptor()])
protocol MacroCompileBoundedRetryAPI {
  @GET(.path("/retry"))
  func user() async throws -> MacroCompileUser
}

private actor RetryTestClient: HTTPClient {
  private var requests: [HTTPRequest] = []

  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    requests.append(request)
    let user = MacroCompileUser(id: 42, name: "Blob")
    return HTTPResponse(
      request: request,
      status: requests.count == 1 ? .internalServerError : .ok,
      body: HTTPBody(try JSONEncoder().encode(user))
    )
  }

  func recordedRequests() -> [HTTPRequest] { requests }
}

@Test("@API and all HTTP methods compile and execute against Networking")
func apiAndHTTPMethodsCompileAndExecute() async throws {
  let expected = MacroCompileUser(id: 42, name: "Blob")
  let created = MacroCompileUser(id: 43, name: "Glob")
  let replaced = MacroCompileUser(id: 43, name: "Globby")
  let updated = MacroCompileUser(id: 43, name: "Globster")
  let client = MockNetworkClient()
  try client.stubGET(path: "/users/42", json: expected)
  try client.expectPOST("/users").andReturnJSON(created, statusCode: 201).once()
  try client.expectPUT("/users/43").andReturnJSON(replaced).once()
  try client.expect(.method(.patch))
    .expect(.path("/users/43"))
    .andReturnJSON(updated)
    .once()
  client.expectDELETE("/users/42")
    .andReturn(.success(statusCode: 204, data: HTTPBody(Data())))
    .once()

  let api = MacroCompileUsersAPIImplementation(client: client)
  let actual = try await api.user(id: 42)
  let createResult = try await api.create(user: expected, notify: true)
  let replaceResult = try await api.replace(id: 43, with: created)
  let updateResult = try await api.update(id: 43, with: replaced)
  try await api.delete(id: 42)

  #expect(actual == expected)
  #expect(createResult == created)
  #expect(replaceResult == replaced)
  #expect(updateResult == updated)
  try client.verifyExpectations()

  let requests = client.getRequestHistory()
  #expect(requests.map(\.method) == [.get, .post, .put, .patch, .delete])
  #expect(
    requests.map(\.url.description) == [
      "https://api.example.com/users/42",
      "https://api.example.com/users?notify=true",
      "https://api.example.com/users/43",
      "https://api.example.com/users/43",
      "https://api.example.com/users/42",
    ]
  )

  let createRequest = try #require(requests.dropFirst().first)
  let body = try #require(createRequest.body)
  #expect(try JSONDecoder().decode(MacroCompileUser.self, from: body.rawValue) == expected)
}

@Test("@API routes direction-specific interceptors and retries a response")
func apiInterceptorsCompileAndRetry() async throws {
  let contextID = MockContextIdentifier()
  let url = try #require(HTTPRequestURL(BaseURLText(rawValue: "https://api.example.com/retry")))
  let user = MacroCompileUser(id: 42, name: "Blob")
  let body = HTTPBody(try JSONEncoder().encode(user))
  MockURLProtocol.clearAll(contextID: contextID)
  defer { MockURLProtocol.clearAll(contextID: contextID) }
  MockURLProtocol.stubSequential(
    url: url,
    responses: [
      .success(statusCode: 500, data: body),
      .success(statusCode: 200, data: body),
    ],
    contextID: contextID
  )
  let session = URLSession(
    configuration: MockURLProtocol.createMockConfiguration(contextID: contextID)
  )
  defer { session.invalidateAndCancel() }
  let client = NetworkClient(session: session)
  let api = MacroCompileRetryAPIImplementation(client: client)

  let result = try await api.user()
  let requests = await MockURLProtocol.getCapturedRequests(contextID: contextID)

  #expect(result == user)
  #expect(requests.count == 2)
  #expect(
    requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer token" }
  )
}

@Test("@API stops an interceptor that always requests retries")
func apiInterceptorsBoundRetries() async throws {
  let client = RetryTestClient()
  let api = MacroCompileBoundedRetryAPIImplementation(client: client)

  do {
    _ = try await api.user()
    Issue.record("Expected bounded retry failure")
  } catch InterceptorError.maxRetriesExceeded(let maxAttempts) {
    #expect(maxAttempts == 10)
  }

  #expect(await client.recordedRequests().count == 11)
}
