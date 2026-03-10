import Foundation
@testable import NetworkingTesting
import NetworkingRuntime
import NetworkingObservability
import NetworkingDSL
import NetworkingRuntimeDSL
import Testing

/// Comprehensive tests demonstrating MockURLProtocol and MockNetworkClient usage
@Suite("Mocking Framework Tests", .serialized)
struct MockingTests {
    // MARK: - MockURLProtocol Tests

    @Test("MockURLProtocol basic stubbing")
    func mockURLProtocolBasicStubbing() async throws {
        let contextID = UUID().uuidString

        // Clear any previous state
        MockURLProtocol.clearAll(contextID: contextID)

        // Setup
        let testData = #"{"id": 123, "name": "Test User"}"#.data(using: .utf8)!

        MockURLProtocol.stubSuccess(
            url: "https://api.example.com/users/123",
            statusCode: 200,
            data: testData,
            headers: ["Content-Type": "application/json"],
            contextID: contextID
        )

        // Execute
        let client = MockURLProtocol.createMockHTTPClient(contextID: contextID)
        let request = try HTTPRequest {
            GET("https://api.example.com/users/123")
        }

        let response = try await client.execute(request)

        // Verify
        #expect(response.status.rawValue == 200)
        #expect(response.body == testData)
        #expect(response.headers["Content-Type"] == "application/json")

        // Verify request was captured
        await MockURLProtocol.expectRequest(url: "https://api.example.com/users/123", contextID: contextID)

        // Cleanup
        MockURLProtocol.clearAll(contextID: contextID)
    }

    @Test("MockURLProtocol JSON stubbing")
    func mockURLProtocolJSONStubbing() async throws {
        let contextID = UUID().uuidString

        // Clear any previous state
        MockURLProtocol.clearAll(contextID: contextID)

        struct User: Codable, Equatable {
            let id: Int
            let name: String
        }

        let user = User(id: 123, name: "Test User")

        // Setup JSON stub
        try MockURLProtocol.stubJSON(
            url: "https://api.example.com/users/123",
            json: user,
            contextID: contextID
        )

        // Execute
        let client = MockURLProtocol.createMockHTTPClient(contextID: contextID)
        let request = try HTTPRequest {
            GET("https://api.example.com/users/123")
        }

        let response = try await client.execute(request)

        // Verify response
        #expect(response.status.rawValue == 200)

        // Decode and verify JSON
        let decodedUser = try JSONDecoder().decode(User.self, from: response.body!)
        #expect(decodedUser == user)

        MockURLProtocol.clearAll(contextID: contextID)
    }

    @Test("MockURLProtocol error simulation")
    func mockURLProtocolErrorSimulation() async throws {
        let contextID = UUID().uuidString

        // Clear any previous state
        MockURLProtocol.clearAll(contextID: contextID)

        // Setup error stub
        MockURLProtocol.stubError(
            url: "https://api.example.com/error",
            error: URLError(.notConnectedToInternet),
            contextID: contextID
        )

        // Execute
        let client = MockURLProtocol.createMockHTTPClient(contextID: contextID)
        let request = try HTTPRequest {
            GET("https://api.example.com/error")
        }

        // Verify HTTPError is thrown (wraps the underlying URLError)
        await #expect(throws: HTTPError.self) {
            try await client.execute(request)
        }

        MockURLProtocol.clearAll(contextID: contextID)
    }

    @Test("MockURLProtocol timeout simulation")
    func mockURLProtocolTimeoutSimulation() async throws {
        let contextID = UUID().uuidString

        // Clear any previous state
        MockURLProtocol.clearAll(contextID: contextID)

        // Setup timeout stub
        MockURLProtocol.stubTimeout(url: "https://api.example.com/slow", contextID: contextID)

        // Execute
        let client = MockURLProtocol.createMockHTTPClient(contextID: contextID)
        let request = try HTTPRequest {
            GET("https://api.example.com/slow")
        }

        // Verify HTTPError is thrown (wraps the underlying URLError)
        await #expect(throws: HTTPError.self) {
            try await client.execute(request)
        }

        MockURLProtocol.clearAll(contextID: contextID)
    }

    @Test("MockURLProtocol pattern matching")
    func mockURLProtocolPatternMatching() async throws {
        let contextID = UUID().uuidString

        // Clear any previous state
        MockURLProtocol.clearAll(contextID: contextID)

        // Setup pattern-based stub
        try MockURLProtocol.stubPattern(
            "https://api\\.example\\.com/users/\\d+",
            response: .success(statusCode: 200, data: #"{"found": true}"#.data(using: .utf8)!),
            contextID: contextID
        )

        let client = MockURLProtocol.createMockHTTPClient(contextID: contextID)

        // Test multiple URLs that match the pattern
        let userIds = [123, 456, 789]
        for userId in userIds {
            let request = try HTTPRequest {
                GET("https://api.example.com/users/\(userId)")
            }

            let response = try await client.execute(request)
            #expect(response.status.rawValue == 200)

            let json = try JSONSerialization.jsonObject(with: response.body!) as! [String: Any]
            #expect(json["found"] as? Bool == true)
        }

        MockURLProtocol.clearAll(contextID: contextID)
    }

    @Test("MockURLProtocol sequential responses")
    func mockURLProtocolSequentialResponses() async throws {
        let contextID = UUID().uuidString

        // Clear any previous state
        MockURLProtocol.clearAll(contextID: contextID)

        // Setup sequential responses - each stub is consumed after one use
        MockURLProtocol.stubSequential(
            url: "https://api.example.com/counter",
            responses: [
                .success(statusCode: 200, data: #"{"count": 1}"#.data(using: .utf8)!),
                .success(statusCode: 200, data: #"{"count": 2}"#.data(using: .utf8)!),
                .success(statusCode: 200, data: #"{"count": 3}"#.data(using: .utf8)!),
            ],
            contextID: contextID
        )

        // Create URLSession directly with mock configuration
        let config = MockURLProtocol.createMockConfiguration(contextID: contextID)
        let session = URLSession(configuration: config)
        let url = URL(string: "https://api.example.com/counter")!

        var results: [Int] = []

        // Make three sequential requests using URLSession directly
        for expectedCount in 1 ... 3 {
            // Add delay between requests to ensure previous request completes fully
            if expectedCount > 1 {
                try await Task.sleep(for: .milliseconds(100))
            }

            // Create a new URLRequest for each request to avoid any caching
            var urlRequest = URLRequest(url: url)
            urlRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            urlRequest.httpMethod = "GET"

            let (data, _) = try await session.data(for: urlRequest)

            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let actualCount = json["count"] as? Int ?? 0
            results.append(actualCount)
        }

        // Verify all results
        #expect(results == [1, 2, 3], "Expected [1, 2, 3] but got \(results)")

        MockURLProtocol.clearAll(contextID: contextID)
    }

    // MARK: - MockNetworkClient Tests

    @Test("MockNetworkClient basic expectations")
    func mockNetworkClientBasicExpectations() async throws {
        struct User: Codable {
            let id: Int
            let name: String
        }

        let mockClient = MockNetworkClient()
        let user = User(id: 123, name: "Test User")

        // Setup expectation
        try mockClient.expectGET("/users/123")
            .andReturnJSON(user)
            .once()

        // Execute request
        let request = try HTTPRequest {
            GET("https://api.example.com/users/123")
        }

        let response = try await mockClient.execute(request)

        // Verify response
        #expect(response.status.rawValue == 200)
        let decodedUser = try JSONDecoder().decode(User.self, from: response.body!)
        #expect(decodedUser.id == user.id)
        #expect(decodedUser.name == user.name)

        // Verify expectations
        mockClient.expectationsAreFulfilled()
    }

    @Test("MockNetworkClient call count expectations")
    func mockNetworkClientCallCountExpectations() async throws {
        let mockClient = MockNetworkClient()

        // Setup expectations with different call counts
        mockClient.expectGET("/users")
            .andReturn(.success(statusCode: 200, data: #"[]"#.data(using: .utf8)!))
            .exactly(2)

        mockClient.expectPOST("/users")
            .andReturn(.success(statusCode: 201, data: #"{"id": 1}"#.data(using: .utf8)!))
            .once()

        mockClient.expectDELETE("/users/1")
            .andReturn(.success(statusCode: 204, data: Data()))
            .never() // Should not be called

        // Execute requests
        let getRequest = try HTTPRequest { GET("https://api.example.com/users") }
        let postRequest = try HTTPRequest { POST("https://api.example.com/users") }

        // Make GET requests (exactly 2)
        _ = try await mockClient.execute(getRequest)
        _ = try await mockClient.execute(getRequest)

        // Make POST request (once)
        _ = try await mockClient.execute(postRequest)

        // Don't make DELETE request (never)

        // Verify expectations
        mockClient.expectationsAreFulfilled()

        // Verify request history
        let history = mockClient.getRequestHistory()
        #expect(history.count == 3)

        // getRequestCount counts all requests to a path, regardless of method
        // We have 2 GETs and 1 POST to /users = 3 total
        let usersCount = mockClient.getRequestCount(for: "/users")
        #expect(usersCount == 3)

        // Use filter to count specific method
        let getCount = mockClient.getRequests { $0.method == .get && $0.url.path == "/users" }.count
        #expect(getCount == 2)
    }

    @Test("MockNetworkClient request capture")
    func mockNetworkClientRequestCapture() async throws {
        let mockClient = MockNetworkClient()
        class CapturedRequestBox: @unchecked Sendable {
            var request: HTTPRequest?
        }
        let capturedRequest = CapturedRequestBox()

        // Setup expectation with request capture
        mockClient.expectPOST("/users")
            .andReturn(.success(statusCode: 201, data: Data()))
            .capture { request in
                capturedRequest.request = request
            }
            .once()

        // Execute request with body
        let requestBody = #"{"name": "John Doe"}"#.data(using: .utf8)!
        let request = HTTPRequest(
            method: .post,
            url: URL(string: "https://api.example.com/users")!,
            headers: ["Content-Type": "application/json"],
            body: requestBody
        )

        _ = try await mockClient.execute(request)

        // Verify request was captured
        #expect(capturedRequest.request != nil)
        #expect(capturedRequest.request?.method == .post)
        #expect(capturedRequest.request?.body == requestBody)
        #expect(capturedRequest.request?.headers["Content-Type"] == "application/json")

        mockClient.expectationsAreFulfilled()
    }

    @Test("MockNetworkClient error expectations")
    func mockNetworkClientErrorExpectations() async throws {
        let mockClient = MockNetworkClient()

        // Setup error expectation
        mockClient.expectGET("/error")
            .andReturnError(URLError(.networkConnectionLost))
            .once()

        // Execute request
        let request = try HTTPRequest {
            GET("https://api.example.com/error")
        }

        // Verify HTTPError is thrown (MockNetworkClient wraps errors in HTTPError)
        await #expect(throws: HTTPError.self) {
            try await mockClient.execute(request)
        }

        mockClient.expectationsAreFulfilled()
    }

    @Test("MockNetworkClient timeout expectations")
    func mockNetworkClientTimeoutExpectations() async throws {
        let mockClient = MockNetworkClient()

        // Setup timeout expectation
        mockClient.expectGET("/slow")
            .andTimeout()
            .once()

        // Execute request
        let request = try HTTPRequest {
            GET("https://api.example.com/slow")
        }

        // Verify HTTPError is thrown (MockNetworkClient wraps errors in HTTPError)
        await #expect(throws: HTTPError.self) {
            try await mockClient.execute(request)
        }

        mockClient.expectationsAreFulfilled()
    }

    @Test("MockNetworkClient convenience methods")
    func mockNetworkClientConvenienceMethods() async throws {
        struct User: Codable {
            let id: Int
            let name: String
        }

        let mockClient = MockNetworkClient()
        let user = User(id: 123, name: "Test User")

        // Use convenience stubbing methods
        try mockClient.stubGET(path: "/users/123", json: user)
        mockClient.stubPOST(path: "/users", response: #"{"id": 456}"#.data(using: .utf8)!)

        // Execute requests
        let getRequest = try HTTPRequest {
            GET("https://api.example.com/users/123")
        }
        let postRequest = try HTTPRequest {
            POST("https://api.example.com/users")
        }

        let getResponse = try await mockClient.execute(getRequest)
        let postResponse = try await mockClient.execute(postRequest)

        // Verify responses
        #expect(getResponse.status.rawValue == 200)
        #expect(postResponse.status.rawValue == 201)

        let decodedUser = try JSONDecoder().decode(User.self, from: getResponse.body!)
        #expect(decodedUser.id == user.id)

        let postResult = try JSONSerialization.jsonObject(with: postResponse.body!) as! [String: Any]
        #expect(postResult["id"] as? Int == 456)
    }

    @Test("MockNetworkClient request history filtering")
    func mockNetworkClientRequestHistoryFiltering() async throws {
        let mockClient = MockNetworkClient()

        // Setup stubs for different endpoints
        mockClient.stubGET(path: "/users", response: Data())
        mockClient.stubGET(path: "/posts", response: Data())
        mockClient.stubPOST(path: "/users", response: Data())

        // Execute various requests
        let requests: [HTTPRequest] = try [
            HTTPRequest { GET("https://api.example.com/users") },
            HTTPRequest { GET("https://api.example.com/posts") },
            HTTPRequest { GET("https://api.example.com/users") }, // Duplicate GET
            HTTPRequest { POST("https://api.example.com/users") },
        ]

        for request in requests {
            _ = try await mockClient.execute(request)
        }

        // Test request history filtering
        let allRequests = mockClient.getRequestHistory()
        #expect(allRequests.count == 4)

        let getRequests = mockClient.getRequests { $0.method == .get }
        #expect(getRequests.count == 3)

        let userRequests = mockClient.getRequests { $0.url.path == "/users" }
        #expect(userRequests.count == 3)

        let postRequests = mockClient.getRequests { $0.method == .post }
        #expect(postRequests.count == 1)

        // Test specific path counting
        let userCount = mockClient.getRequestCount(for: "/users")
        #expect(userCount == 3)

        let postCount = mockClient.getRequestCount(for: "/posts")
        #expect(postCount == 1)
    }

    @Test("MockNetworkClient performance measurement")
    func mockNetworkClientPerformanceMeasurement() async throws {
        let mockClient = MockNetworkClient()
        let responseData = Data(repeating: 0x41, count: 10000) // 10KB of data

        // Setup stub with delay
        mockClient.expect(.path("/large"))
            .andReturn(.success(statusCode: 200, data: responseData), withDelay: 0.1)
            .once()

        let request = try HTTPRequest {
            GET("https://api.example.com/large")
        }

        // Measure performance
        let metrics = try await mockClient.measurePerformance(for: request)

        // Verify metrics
        #expect(metrics.duration > 0.1) // Should take at least 0.1 seconds due to delay
        #expect(metrics.responseSize == 10000)
        #expect(metrics.throughput > 0)

        mockClient.expectationsAreFulfilled()
    }

    @Test("MockNetworkClient unfulfilled expectations")
    func mockNetworkClientUnfulfilledExpectations() async throws {
        let mockClient = MockNetworkClient()

        // Setup expectations that won't be fulfilled
        mockClient.expectGET("/users")
            .andReturn(.success(statusCode: 200, data: Data()))
            .exactly(2) // But we'll only call once

        mockClient.expectPOST("/posts")
            .andReturn(.success(statusCode: 201, data: Data()))
            .once() // Won't call this at all

        // Execute only one request
        let request = try HTTPRequest {
            GET("https://api.example.com/users")
        }
        _ = try await mockClient.execute(request)

        // Verify expectations are not fulfilled
        #expect(!mockClient.areExpectationsFulfilled())

        let unfulfilled = mockClient.getUnfulfilledExpectations()
        #expect(unfulfilled.count == 2)

        // Verify that verifyExpectations throws
        #expect(throws: AssertionError.self) {
            try mockClient.verifyExpectations()
        }
    }

    @Test("MockNetworkClient reset functionality")
    func mockNetworkClientResetFunctionality() async throws {
        let mockClient = MockNetworkClient()

        // Setup expectations and execute requests
        // Use .exactly(2) so that after 1 call, the expectation is still unfulfilled
        mockClient.expectGET("/test")
            .andReturn(.success(statusCode: 200, data: Data()))
            .exactly(2)

        let request = try HTTPRequest {
            GET("https://api.example.com/test")
        }
        _ = try await mockClient.execute(request)

        // Verify state before reset - called once but expected twice, so unfulfilled
        #expect(mockClient.getRequestHistory().count == 1)
        #expect(!mockClient.getUnfulfilledExpectations().isEmpty)

        // Reset and verify state is cleared
        mockClient.reset()

        #expect(mockClient.getRequestHistory().isEmpty)
        #expect(mockClient.areExpectationsFulfilled()) // No expectations = fulfilled
    }

    // MARK: - Integration Tests

    @Test("Integration: MockURLProtocol with NetworkClient DSL")
    func integrationWithNetworkClientDSL() async throws {
        let contextID = UUID().uuidString

        // Clear any previous state
        MockURLProtocol.clearAll(contextID: contextID)

        struct User: Codable, Equatable {
            let id: Int
            let name: String
            let email: String
        }

        let user = User(id: 123, name: "Test User", email: "test@example.com")

        // Setup mock response using full URL
        try MockURLProtocol.stubJSON(
            url: "https://api.example.com/users/123",
            json: user,
            contextID: contextID
        )

        // Create NetworkClient with mock configuration
        let httpClient = NetworkClient(
            session: URLSession(configuration: MockURLProtocol.createMockConfiguration(contextID: contextID))
        )

        // Execute request using full URL (MockURLProtocol requires full URLs for matching)
        let request = try HTTPRequest {
            GET("https://api.example.com/users/123")
            Header("Accept", "application/json")
        }

        let response = try await httpClient.execute(request)

        // Verify response
        #expect(response.status.rawValue == 200)
        let decodedUser = try JSONDecoder().decode(User.self, from: response.body!)
        #expect(decodedUser == user)

        MockURLProtocol.clearAll(contextID: contextID)
    }

    @Test("Integration: Error handling with recovery strategies")
    func integrationErrorHandlingWithRecoveryStrategies() async throws {
        let contextID = UUID().uuidString

        // Clear any previous state
        MockURLProtocol.clearAll(contextID: contextID)

        // Setup sequence: first fails, then succeeds (simulating retry)
        MockURLProtocol.stubSequential(
            url: "https://api.example.com/retry-test",
            responses: [
                .failure(URLError(.networkConnectionLost)),
                .success(statusCode: 200, data: #"{"success": true}"#.data(using: .utf8)!),
            ],
            contextID: contextID
        )

        // Create client using MockURLProtocol
        let client = MockURLProtocol.createMockHTTPClient(contextID: contextID)

        let request = try HTTPRequest {
            GET("https://api.example.com/retry-test")
        }

        // First request should fail - HTTPError wraps the underlying URLError
        await #expect(throws: HTTPError.self) {
            try await client.execute(request)
        }

        // Second request should succeed
        let response = try await client.execute(request)
        #expect(response.status.rawValue == 200)

        let json = try JSONSerialization.jsonObject(with: response.body!) as! [String: Any]
        #expect(json["success"] as? Bool == true)

        MockURLProtocol.clearAll(contextID: contextID)
    }
}
