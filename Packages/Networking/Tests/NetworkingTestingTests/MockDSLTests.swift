import Foundation
@testable import NetworkingTesting
import NetworkingRuntime
import NetworkingObservability
import NetworkingDSL
import NetworkingRuntimeDSL
import Testing

@Suite("Mock DSL Tests")
struct MockDSLTests {
    // MARK: - MockExpectation Tests

    @Test("MockExpectation defaults")
    func expectationDefaults() {
        let expectation = MockExpectation()
        #expect(expectation.method == nil)
        #expect(expectation.path == nil)
        #expect(expectation.requiredHeaders.isEmpty)
        #expect(expectation.headerValues.isEmpty)
        #expect(expectation.count == nil)
    }

    @Test("MockExpectation with all properties")
    func expectationProperties() {
        let expectation = MockExpectation(
            method: .get,
            path: "/users",
            requiredHeaders: ["Authorization"],
            headerValues: ["Accept": "application/json"],
            count: 2
        )
        #expect(expectation.method == .get)
        #expect(expectation.path == "/users")
        #expect(expectation.requiredHeaders == ["Authorization"])
        #expect(expectation.headerValues["Accept"] == "application/json")
        #expect(expectation.count == 2)
    }

    // MARK: - MockResponse Tests

    @Test("MockResponse defaults")
    func responseDefaults() {
        let response = MockResponse()
        #expect(response.statusCode == 200)
        #expect(response.body == nil)
        #expect(response.headers.isEmpty)
        #expect(response.error == nil)
        #expect(!response.isJSON)
    }

    // MARK: - DSL Component Functions

    @Test("Method component creates correct ExpectComponent")
    func methodComponent() {
        let component = Method(.get)
        if case let .method(method) = component {
            #expect(method == .get)
        } else {
            Issue.record("Expected .method component")
        }
    }

    @Test("Path component creates correct ExpectComponent")
    func pathComponent() {
        let component = Path("/users")
        if case let .path(path) = component {
            #expect(path == "/users")
        } else {
            Issue.record("Expected .path component")
        }
    }

    @Test("HeaderPresent component creates correct ExpectComponent")
    func headerPresentComponent() {
        let component = HeaderPresent("Authorization")
        if case let .headerPresent(name) = component {
            #expect(name == "Authorization")
        } else {
            Issue.record("Expected .headerPresent component")
        }
    }

    @Test("Status component creates correct RespondComponent")
    func statusComponent() {
        let component = Status(.ok)
        if case let .status(code) = component {
            #expect(code == 200)
        } else {
            Issue.record("Expected .status component")
        }
    }

    @Test("Body component creates correct RespondComponent")
    func bodyComponent() {
        let data = "test".data(using: .utf8)!
        let component = Body(data)
        if case let .body(body) = component {
            #expect(body == data)
        } else {
            Issue.record("Expected .body component")
        }
    }

    @Test("MockJSONBody component encodes value")
    func mockJSONBodyComponent() throws {
        struct User: Codable {
            let id: Int
            let name: String
        }
        let component = try MockJSONBody(User(id: 1, name: "Test"))
        if case let .jsonBody(data) = component {
            let decoded = try JSONDecoder().decode(User.self, from: data)
            #expect(decoded.id == 1)
            #expect(decoded.name == "Test")
        } else {
            Issue.record("Expected .jsonBody component")
        }
    }

    // MARK: - Expect Builder Tests

    @Test("Expect builder composes components")
    func expectBuilder() {
        let expectation = Expect {
            Method(.get)
            Path("/users/123")
            HeaderPresent("Authorization")
            Count(1)
        }

        #expect(expectation.method == .get)
        #expect(expectation.path == "/users/123")
        #expect(expectation.requiredHeaders.contains("Authorization"))
        #expect(expectation.count == 1)
    }

    // MARK: - Respond Builder Tests

    @Test("Respond builder composes components")
    func respondBuilder() {
        let response = Respond {
            Status(.ok)
            Body("test".data(using: .utf8)!)
            ResponseHeader("X-Custom", "value")
        }

        #expect(response.statusCode == 200)
        #expect(response.body == "test".data(using: .utf8))
        #expect(response.headers["X-Custom"] == "value")
    }

    // MARK: - Full NetworkingMock Integration

    @Test("NetworkingMock GET with JSON response")
    func networkingMockGET() async throws {
        struct User: Codable, Equatable {
            let id: Int
            let name: String
        }

        let mockUser = User(id: 42, name: "Alice")

        let jsonBody = try MockJSONBody(mockUser)
        let mock = try NetworkingMock {
            Expect {
                Method(.get)
                Path("/users/42")
            }
            Respond {
                Status(.ok)
                jsonBody
            }
        }

        let request = HTTPRequest(
            method: .get,
            url: URL(string: "https://api.example.com/users/42")!
        )

        let response = try await mock.client.execute(request)
        #expect(response.status.rawValue == 200)

        let decoded = try JSONDecoder().decode(User.self, from: response.body!)
        #expect(decoded == mockUser)
    }

    @Test("NetworkingMock POST with body")
    func networkingMockPOST() async throws {
        let mock = try NetworkingMock {
            Expect {
                Method(.post)
                Path("/items")
            }
            Respond {
                Status(.created)
                Body(#"{"id": 999}"#.data(using: .utf8)!)
            }
        }

        let request = HTTPRequest(
            method: .post,
            url: URL(string: "https://api.example.com/items")!,
            body: "{}".data(using: .utf8)
        )

        let response = try await mock.client.execute(request)
        #expect(response.status.rawValue == 201)
    }
}
