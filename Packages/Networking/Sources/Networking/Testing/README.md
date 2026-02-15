# Networking Framework Testing Utilities

This directory contains testing utilities that are automatically available when you import the Networking framework in your test targets.

## Available Testing Tools

### MockURLProtocol

URLProtocol-based mock for comprehensive request/response simulation.

```swift
import Networking

// Set up mock responses
MockURLProtocol.stub(
  matching: .url("https://api.example.com/users/123"),
  response: .success(statusCode: 200, data: userData)
)

// Configure URLSession with mock
let config = URLSessionConfiguration.ephemeral
config.protocolClasses = [MockURLProtocol.self]
let client = NetworkClient(session: URLSession(configuration: config))

// Execute test
let response = try await client.execute(request)
```

**Features:**
- Response stubbing with flexible matching
- Error simulation with network conditions  
- Request verification and capture
- Streaming response simulation
- Performance testing with delays
- Thread-safe operation for concurrent testing

### MockNetworkClient

Expectation-based mock network client for declarative testing.

```swift
import Networking

let mockClient = MockNetworkClient()

// Set up expectations
mockClient.expectGET("/users/123")
  .andReturn(.success(statusCode: 200, data: userData))
  .once()

// Execute test
let response = try await mockClient.execute(request)

// Verify expectations
mockClient.expectationsAreFulfilled()
```

**Features:**
- Declarative request/response expectations
- Automatic request verification
- Flexible response stubbing
- Request history tracking
- Performance measurement integration

### AsyncExpectation

Testing utility for async/await code.

```swift
import Networking

let expectation = AsyncExpectation("Network request completed")

Task {
  let response = try await client.execute(request)
  expectation.fulfill()
}

// Wait for expectation...
```

## Integration with Testing Frameworks

### Swift Testing

The utilities integrate seamlessly with Swift Testing:

```swift
import Testing
import Networking

@Test func testUserAPI() async throws {
  MockURLProtocol.stub(
    matching: .url("https://api.example.com/users/123"),
    response: .success(statusCode: 200, data: userData)
  )
  
  let client = MockURLProtocol.createMockHTTPClient()
  let response = try await client.execute(request)
  
  #expect(response.status.isSuccess)
  await MockURLProtocol.expectRequest(
    url: "https://api.example.com/users/123",
    count: 1
  )
}
```

### XCTest

Also works with traditional XCTest:

```swift
import XCTest
import Networking

class NetworkTests: XCTestCase {
  func testUserAPI() async throws {
    let mockClient = MockNetworkClient()
    
    mockClient.expectGET("/users/123")
      .andReturn(.success(statusCode: 200, data: userData))
      .once()
    
    let response = try await mockClient.execute(request)
    
    XCTAssertTrue(response.status.isSuccess)
    mockClient.expectationsAreFulfilled()
  }
}
```

## Best Practices

1. **Use MockURLProtocol for integration testing** - When you want to test the full networking stack
2. **Use MockNetworkClient for unit testing** - When you want to test business logic with mocked responses
3. **Clear mocks between tests** - Use `MockURLProtocol.clearAll()` in tearDown
4. **Verify expectations** - Always call `expectationsAreFulfilled()` to ensure tests are robust
5. **Use realistic data** - Mock responses should match your actual API responses

## Availability

These testing utilities are automatically available when:
- Building in DEBUG mode
- Running tests (TESTING or TEST flags)
- Importing the Networking framework

In production builds, the testing utilities are not included to keep the framework lightweight.