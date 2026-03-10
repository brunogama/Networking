import Foundation
@testable import NetworkingDSL
import NetworkingRuntime
import NetworkingRuntimeDSL
import NetworkingTesting
import Testing

@Suite("TypedHTTPRequest Tests")
struct TypedHTTPRequestTests {
  // MARK: - Phantom Type Method Tests

  @Test("GETMethod has correct raw value")
  func gETMethodRawValue() {
    #expect(GETMethod.method == .get)
  }

  @Test("POSTMethod has correct raw value")
  func pOSTMethodRawValue() {
    #expect(POSTMethod.method == .post)
  }

  @Test("PUTMethod has correct raw value")
  func pUTMethodRawValue() {
    #expect(PUTMethod.method == .put)
  }

  @Test("DELETEMethod has correct raw value")
  func dELETEMethodRawValue() {
    #expect(DELETEMethod.method == .delete)
  }

  @Test("PATCHMethod has correct raw value")
  func pATCHMethodRawValue() {
    #expect(PATCHMethod.method == .patch)
  }

  // MARK: - Environment Type Tests

  @Test("ProductionEnvironment has correct base URL and name")
  func productionEnvironment() {
    #expect(ProductionEnvironment.name == "production")
    #expect(ProductionEnvironment.baseURL.absoluteString == "https://api.example.com")
  }

  @Test("StagingEnvironment has correct base URL and name")
  func stagingEnvironment() {
    #expect(StagingEnvironment.name == "staging")
    #expect(StagingEnvironment.baseURL.absoluteString == "https://staging-api.example.com")
  }

  @Test("DevelopmentEnvironment has correct base URL and name")
  func developmentEnvironment() {
    #expect(DevelopmentEnvironment.name == "development")
    #expect(DevelopmentEnvironment.baseURL.absoluteString == "http://localhost:8080")
  }

  // MARK: - TypedHTTPRequest Construction

  @Test("TypedHTTPRequest constructs with correct URL")
  func requestConstructsCorrectURL() {
    let request = TypedHTTPRequest<GETMethod, ProductionEnvironment>(path: "/users")
    #expect(request.url.absoluteString == "https://api.example.com/users")
    #expect(request.method == .get)
  }

  @Test("TypedHTTPRequest constructs path with leading slash")
  func requestPathWithLeadingSlash() {
    let request = TypedHTTPRequest<POSTMethod, StagingEnvironment>(path: "/api/v2/items")
    #expect(request.url.absoluteString == "https://staging-api.example.com/api/v2/items")
    #expect(request.method == .post)
  }

  @Test("TypedHTTPRequest defaults")
  func requestDefaults() {
    let request = TypedHTTPRequest<GETMethod, AnyEnvironment>(path: "/test")
    #expect(request.headers.isEmpty == true)
    #expect(request.body == nil)
    #expect(request.timeout == 30.0)
  }

  @Test("TypedHTTPRequest with custom headers and body")
  func requestCustomProperties() {
    let body = Data("test".utf8)
    let request = TypedHTTPRequest<POSTMethod, DevelopmentEnvironment>(
      path: "/submit",
      headers: ["Content-Type": "application/json"],
      body: HTTPBody(body),
      timeout: 60.0
    )
    #expect(request.headers["Content-Type"] == "application/json")
    #expect(request.body == HTTPBody(body))
    #expect(request.timeout == 60.0)
  }

  // MARK: - Conversion

  @Test("TypedHTTPRequest converts to HTTPRequest")
  func conversionToHTTPRequest() {
    let typed = TypedHTTPRequest<DELETEMethod, ProductionEnvironment>(
      path: "/users/123",
      headers: ["Authorization": "Bearer token"]
    )
    let http = typed.toHTTPRequest()

    #expect(http.method == .delete)
    #expect(http.url.absoluteString == "https://api.example.com/users/123")
    #expect(http.headers["Authorization"] == "Bearer token")
  }

  // MARK: - Fluent Modifiers

  @Test("addingHeader creates new request with header")
  func testAddingHeader() {
    let request = TypedHTTPRequest<GETMethod, AnyEnvironment>(path: "/test")
    let modified = request.addingHeader("X-Custom", "value")
    #expect(modified.headers["X-Custom"] == "value")
    #expect(request.headers["X-Custom"] == nil)  // Original unchanged
  }

  @Test("withBody creates new request with body")
  func testWithBody() {
    let request = TypedHTTPRequest<POSTMethod, AnyEnvironment>(path: "/test")
    let body = Data("payload".utf8)
    let modified = request.withBody(HTTPBody(body))
    #expect(modified.body == HTTPBody(body))
    #expect(request.body == nil)
  }

  @Test("withTimeout creates new request with timeout")
  func testWithTimeout() {
    let request = TypedHTTPRequest<GETMethod, AnyEnvironment>(path: "/test")
    let modified = request.withTimeout(120.0)
    #expect(modified.timeout == 120.0)
    #expect(request.timeout == 30.0)
  }

  // MARK: - HTTPClient Extension

  @Test("HTTPClient can execute typed requests")
  func hTTPClientExecuteTyped() async throws {
    let mockClient = MockNetworkClient()
    mockClient.stubGET(path: "/users", response: Data(#"[]"#.utf8))

    let typed = TypedHTTPRequest<GETMethod, AnyEnvironment>(path: "/users")
    let response = try await mockClient.execute(typed)
    #expect(response.status.rawValue == 200)
  }
}
