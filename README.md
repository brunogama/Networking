# Networking

A Swift 6 compliant networking framework built with structured concurrency, modern Swift features, and an exceptional developer experience.

## ✨ Features

### 🚀 Swift 6 Ready
- **Full async/await support** - No more completion handlers
- **Sendable compliant** - Thread-safe by design
- **Structured concurrency** - Proper cancellation and error handling
- **Actor isolation** - Safe shared state management

### 🎨 Beautiful API Design
- **Request Builder DSL** - Fluent, readable request construction
- **Result builders** - Type-safe configuration
- **Swift Macros** - Generate API clients from protocol definitions
- **Zero boilerplate** - Focus on your business logic

### 🛡️ Production Ready
- **Comprehensive error handling** - Rich error types with context
- **Automatic retries** - Exponential backoff with circuit breaking
- **Request/Response logging** - Built-in observability
- **Middleware architecture** - Extensible and testable

## 📦 Installation

Add Networking to your Swift package:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/Networking.git", from: "1.0.0")
]
```

## 🚀 Quick Start

### Basic Usage

```swift
import Networking

// Create a client with beautiful configuration
let client = NetworkClient {
    BaseURL("https://api.example.com")
    EnableLogging()
    EnableRetry()
    DefaultHeader("User-Agent", "MyApp/1.0")
}

// Make requests with the elegant DSL
let response = try await client.execute {
    GET("/users/123")
    BearerAuth(token)
    Timeout(15.0)
}

// Decode responses effortlessly
let user: User = try response.decode(User.self)
```

### POST Requests with JSON

```swift
let newUser = User(name: "John Doe", email: "john@example.com")

let response = try await client.execute {
    POST("/users")
    BearerAuth(token)
    JSONBody(newUser)
    Header("Content-Type", "application/json")
}
```
### Generated API Clients (Macros)

The framework's true power shines with generated API clients:

```swift
@API(baseURL: "https://api.example.com")
protocol UserAPI {
    @GET("/users/{id}")
    func getUser(@Path id: String) async throws -> User
    
    @POST("/users")
    func createUser(@Body user: User) async throws -> User
    
    @PUT("/users/{id}")
    func updateUser(@Path id: String, @Body user: User) async throws -> User
    
    @DELETE("/users/{id}")
    func deleteUser(@Path id: String) async throws
}

// Use the generated implementation
let userAPI = UserAPIImplementation()
let user = try await userAPI.getUser(id: "123")
```

## 🏗️ Architecture

### Core Components

#### HTTPClient Protocol
The foundation of all networking operations:
```swift
public protocol HTTPClient: Sendable {
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse
}
```

#### Request Builder DSL
Build requests with a fluent, type-safe API:
```swift
let request = try HTTPRequest {
    BaseURL("https://api.example.com")
    GET("/users")
    BearerAuth("your-token")
    QueryParam("limit", "10")
    Timeout(30.0)
}
```

#### Middleware Architecture
Extend functionality with composable middleware:
```swift
// Request middleware
public protocol HTTPRequestMiddleware: Sendable {
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest
}

// Response middleware  
public protocol HTTPResponseMiddleware: Sendable {
    func processResponse(_ response: HTTPResponse, for request: HTTPRequest) async throws -> HTTPResponse
}

// Error middleware
public protocol HTTPErrorMiddleware: Sendable {
    func handleError(_ error: HTTPError, for request: HTTPRequest) async throws -> HTTPResponse
}
```

## 🎯 Advanced Features

### Retry Logic with Exponential Backoff

```swift
let client = NetworkClient {
    EnableRetry(RetryMiddleware.Configuration(
        maxAttempts: 3,
        baseDelay: 1.0,
        backoffMultiplier: 2.0,
        shouldRetry: { error in
            // Custom retry logic
            error.status?.rawValue ?? 0 >= 500
        }
    ))
}
```
### Comprehensive Logging

```swift
let client = NetworkClient {
    EnableLogging(LoggingMiddleware.Configuration(
        logLevel: .debug,
        logHeaders: true,
        logBody: true,
        maxBodyLength: 1024
    ))
}
```

### Authentication Patterns

```swift
// Bearer token
let response = try await client.execute {
    GET("/protected")
    BearerAuth("your-jwt-token")
}

// Basic auth
let response = try await client.execute {
    GET("/protected") 
    BasicAuth(username: "user", password: "pass")
}

// Custom headers
let response = try await client.execute {
    GET("/protected")
    Header("X-API-Key", "your-api-key")
}
```

## 🧪 Testing

The framework is designed for easy testing:

```swift
import Testing
import Networking

@Test("User API client works correctly")
func testUserAPI() async throws {
    let mockClient = MockHTTPClient()
    let userAPI = UserAPIImplementation(client: mockClient)
    
    mockClient.expect { request in
        #expect(request.method == .get)
        #expect(request.url.path.contains("/users/123"))
        return HTTPResponse(
            request: request,
            status: .ok,
            body: #"{"id": "123", "name": "John"}"#.data(using: .utf8)
        )
    }
    
    let user = try await userAPI.getUser(id: "123")
    #expect(user.id == "123")
    #expect(user.name == "John")
}
```

## 📈 Migration from Legacy Framework

### Before (Old Framework)
```swift
// Complex, error-prone setup
let factory = NetworkingFactory()
let session = factory.makeURLSessionLoader()
let retry = factory.makeRetryLoader()
let logging = factory.makeLoggingLoader()
let chain = logging --> retry --> session

let request = HTTPRequest()
request.method = .get
request.host = "api.example.com"
request.path = "/users"
request.headers["Authorization"] = "Bearer \(token)"

chain.load(task: HTTPTask(request: request) { result in
    // Handle completion on potentially wrong thread
})
```

### After (Modern Framework)
```swift
// Clean, type-safe, async/await
let client = NetworkClient {
    BaseURL("https://api.example.com")
    EnableLogging()
    EnableRetry()
}

let user: User = try await client.execute {
    GET("/users/123")
    BearerAuth(token)
}.decode(User.self)
```

## 🎯 Key Improvements

| Feature | Legacy | Modern |
|---------|--------|--------|
| **Concurrency** | Completion handlers | async/await |
| **Thread Safety** | Manual synchronization | Sendable + Actor isolation |
| **Error Handling** | Basic NSError | Rich HTTPError with context |
| **Request Building** | Imperative property setting | Declarative DSL |
| **API Generation** | Manual implementation | Swift Macros |
| **Testing** | Mock complexity | Built-in test utilities |
| **Configuration** | Factory methods | Result builders |

## 📋 Requirements

- iOS 16.0+ / macOS 13.0+ / tvOS 16.0+ / watchOS 9.0+
- Swift 6.0+
- Xcode 16.0+

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## ⭐ Acknowledgments

Built with ❤️ for the Swift community, leveraging the latest Swift 6 features for maximum performance and developer experience.
