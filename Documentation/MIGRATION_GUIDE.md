# Migration Guide to Networking

## Table of Contents

1. [Overview](#overview)
2. [Swift 6 Migration](#swift-6-migration)
3. [From URLSession](#from-urlsession)
4. [From Alamofire](#from-alamofire)
5. [From Legacy Frameworks](#from-legacy-frameworks)
6. [Common Migration Patterns](#common-migration-patterns)
7. [Breaking Changes](#breaking-changes)
8. [Performance Considerations](#performance-considerations)
9. [Testing Migration](#testing-migration)
10. [Troubleshooting](#troubleshooting)

---

## Overview

This guide helps you migrate to Networking from existing networking solutions, with special attention to Swift 6 compliance and modern concurrency patterns.

### Migration Benefits

**Swift 6 Compliance**
- Full `Sendable` conformance
- Actor-based state management
- Structured concurrency support
- Data race safety at compile time

**Developer Experience**
- Fluent configuration DSL
- Result builders for requests
- Generated API clients via macros
- Comprehensive error handling

**Production Features**
- Advanced middleware system
- Automatic retry with backoff
- Circuit breaker pattern
- Response caching
- Request/response logging

---

## Swift 6 Migration

### From Swift 5 Code

#### Before (Swift 5 with Completion Handlers)

```swift
// Legacy completion handler approach
class UserService {
    func fetchUser(id: String, completion: @escaping (Result<User, Error>) -> Void) {
        let url = URL(string: "https://api.example.com/users/\(id)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NetworkError.noData))
                    return
                }
                
                do {
                    let user = try JSONDecoder().decode(User.self, from: data)
                    completion(.success(user))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}
```

#### After (Swift 6 with Networking)

```swift
// Modern async/await approach
class UserService {
    private let client: NetworkClient
    
    init(authToken: String) {
        self.client = NetworkClient {
            BaseURL("https://api.example.com")
            Authentication {
                BearerToken(authToken)
            }
            EnableLogging()
        }
    }
    
    func fetchUser(id: String) async throws -> User {
        let response = try await client.execute {
            GET("/users/\(id)")
        }
        
        return try response.decode(User.self)
    }
}

// Usage
Task {
    do {
        let user = try await userService.fetchUser(id: "123")
        // Use user on main actor if needed
    } catch {
        // Handle error
    }
}
```

### Sendable Compliance Migration

#### Before (Non-Sendable Types)

```swift
// Not Sendable - will cause warnings in Swift 6
class NetworkConfiguration {
    var baseURL: String = ""
    var headers: [String: String] = [:]
    var timeout: TimeInterval = 30.0
    
    // Mutable reference type - not thread-safe
}

class APIClient {
    let config: NetworkConfiguration  // Warning: non-Sendable
    
    init(config: NetworkConfiguration) {
        self.config = config
    }
}
```

#### After (Sendable Compliant)

```swift
// Sendable value type - thread-safe
struct NetworkConfiguration: Sendable {
    let baseURL: String
    let headers: [String: String]
    let timeout: TimeInterval
    
    init(baseURL: String, headers: [String: String] = [:], timeout: TimeInterval = 30.0) {
        self.baseURL = baseURL
        self.headers = headers
        self.timeout = timeout
    }
}

// Or use Networking's built-in configuration
let client = NetworkClient {
    BaseURL("https://api.example.com")
    DefaultHeader("User-Agent", "MyApp/1.0")
    DefaultTimeout(30.0)
}
```

### Actor Migration

#### Before (Manual Synchronization)

```swift
// Manual synchronization - error-prone
class TokenManager {
    private let queue = DispatchQueue(label: "token-queue")
    private var _currentToken: String?
    
    var currentToken: String? {
        get {
            queue.sync { _currentToken }
        }
        set {
            queue.sync { _currentToken = newValue }
        }
    }
    
    func refreshToken(completion: @escaping (String?) -> Void) {
        queue.async {
            // Token refresh logic
            self._currentToken = "new-token"
            DispatchQueue.main.async {
                completion(self._currentToken)
            }
        }
    }
}
```

#### After (Actor-Based)

```swift
// Actor provides automatic synchronization
actor TokenManager {
    private var currentToken: String?
    
    func getCurrentToken() -> String? {
        currentToken
    }
    
    func setToken(_ token: String) {
        currentToken = token
    }
    
    func refreshToken() async throws -> String {
        // Token refresh logic
        let newToken = try await performTokenRefresh()
        currentToken = newToken
        return newToken
    }
}

// Or use Networking's built-in authentication
let client = NetworkClient {
    BaseURL("https://api.example.com")
    Authentication {
        BearerToken { await tokenManager.getCurrentToken() }
        RefreshStrategy.automatic()
    }
}
```

---

## From URLSession

### Basic Request Migration

#### Before (URLSession)

```swift
func fetchUsers() async throws -> [User] {
    let url = URL(string: "https://api.example.com/users")!
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = 30.0
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw NetworkError.invalidResponse
    }
    
    guard 200...299 ~= httpResponse.statusCode else {
        throw NetworkError.httpError(httpResponse.statusCode)
    }
    
    return try JSONDecoder().decode([User].self, from: data)
}
```

#### After (Networking)

```swift
func fetchUsers() async throws -> [User] {
    let response = try await client.execute {
        GET("/users")
        Header("Accept", "application/json")
        BearerAuth(token)
        Timeout(30.0)
    }
    
    return try response.decode([User].self)
}
```

### POST Request Migration

#### Before (URLSession)

```swift
func createUser(_ user: CreateUserRequest) async throws -> User {
    let url = URL(string: "https://api.example.com/users")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    
    do {
        request.httpBody = try JSONEncoder().encode(user)
    } catch {
        throw NetworkError.encodingError(error)
    }
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw NetworkError.invalidResponse
    }
    
    guard 200...299 ~= httpResponse.statusCode else {
        throw NetworkError.httpError(httpResponse.statusCode)
    }
    
    return try JSONDecoder().decode(User.self, from: data)
}
```

#### After (Networking)

```swift
func createUser(_ user: CreateUserRequest) async throws -> User {
    let response = try await client.execute {
        POST("/users")
        JSONBody(user)
        BearerAuth(token)
    }
    
    return try response.decode(User.self)
}
```

### Session Configuration Migration

#### Before (URLSession)

```swift
let configuration = URLSessionConfiguration.default
configuration.timeoutIntervalForRequest = 30.0
configuration.timeoutIntervalForResource = 60.0
configuration.allowsCellularAccess = true
configuration.waitsForConnectivity = true

let session = URLSession(configuration: configuration)
```

#### After (Networking)

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    Session {
        SessionTimeout(30.0)
        ResourceTimeout(60.0)
        AllowsCellular(true)
        WaitsForConnectivity(true)
    }
}
```

---

## From Alamofire

### Basic Request Migration

#### Before (Alamofire 5)

```swift
import Alamofire

func fetchUser(id: String) async throws -> User {
    return try await withCheckedThrowingContinuation { continuation in
        AF.request("https://api.example.com/users/\(id)",
                   headers: ["Authorization": "Bearer \(token)"])
            .validate()
            .responseDecodable(of: User.self) { response in
                switch response.result {
                case .success(let user):
                    continuation.resume(returning: user)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
    }
}
```

#### After (Networking)

```swift
func fetchUser(id: String) async throws -> User {
    let response = try await client.execute {
        GET("/users/\(id)")
        BearerAuth(token)
    }
    
    return try response.decode(User.self)
}
```

### Alamofire Session Migration

#### Before (Alamofire)

```swift
let configuration = URLSessionConfiguration.af.default
configuration.timeoutIntervalForRequest = 30
configuration.headers = HTTPHeaders([
    "User-Agent": "MyApp/1.0",
    "Accept": "application/json"
])

let session = Session(configuration: configuration)

let interceptor = AuthenticationInterceptor(
    authenticator: TokenAuthenticator(),
    credential: TokenCredential(token: token)
)

session.request("https://api.example.com/users", interceptor: interceptor)
    .validate()
    .responseDecodable(of: [User].self) { response in
        // Handle response
    }
```

#### After (Networking)

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    DefaultHeader("User-Agent", "MyApp/1.0")
    DefaultHeader("Accept", "application/json")
    DefaultTimeout(30.0)
    
    Authentication {
        BearerToken(token)
        RefreshStrategy.automatic()
    }
}

let users: [User] = try await client.execute {
    GET("/users")
}.decode([User].self)
```

### Request Modifier Migration

#### Before (Alamofire)

```swift
struct APIRequestModifier: RequestModifier {
    let token: String
    
    func modify(_ urlRequest: inout URLRequest) throws {
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
    }
}

AF.request("https://api.example.com/users", modifier: APIRequestModifier(token: token))
```

#### After (Networking)

```swift
struct RequestIDMiddleware: HTTPRequestMiddleware {
    let token: String
    
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
        var headers = request.headers
        headers["Authorization"] = "Bearer \(token)"
        headers["X-Request-ID"] = UUID().uuidString
        
        return HTTPRequest(
            method: request.method,
            url: request.url,
            headers: headers,
            body: request.body,
            timeout: request.timeout
        )
    }
}

let client = NetworkClient(
    requestMiddlewares: [RequestIDMiddleware(token: token)]
)
```

---

## From Legacy Frameworks

### From NSURLConnection (Pre-iOS 7)

#### Before (NSURLConnection)

```swift
// Legacy NSURLConnection approach (deprecated)
class LegacyNetworkManager: NSURLConnectionDelegate {
    private var receivedData: NSMutableData?
    private var completion: ((Data?, URLResponse?, Error?) -> Void)?
    
    func fetchData(from url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        self.completion = completion
        self.receivedData = NSMutableData()
        
        let request = URLRequest(url: url)
        NSURLConnection(request: request, delegate: self, startImmediately: true)
    }
    
    // NSURLConnectionDelegate methods...
    func connection(_ connection: NSURLConnection, didReceive data: Data) {
        receivedData?.append(data)
    }
    
    func connectionDidFinishLoading(_ connection: NSURLConnection) {
        completion?(receivedData as Data?, nil, nil)
    }
}
```

#### After (Networking)

```swift
// Modern async/await approach
let response = try await client.execute {
    GET(url.path)
}

let data = response.body
```

### From AFNetworking (Objective-C)

#### Before (AFNetworking 3.x)

```objc
// Objective-C AFNetworking
AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
manager.requestSerializer = [AFJSONRequestSerializer serializer];
manager.responseSerializer = [AFJSONResponseSerializer serializer];

[manager.requestSerializer setValue:@"Bearer token" forHTTPHeaderField:@"Authorization"];

[manager GET:@"https://api.example.com/users" 
  parameters:nil 
    progress:nil 
     success:^(NSURLSessionDataTask *task, id responseObject) {
         // Handle success
     } 
     failure:^(NSURLSessionDataTask *task, NSError *error) {
         // Handle error
     }];
```

#### After (Networking)

```swift
// Swift Networking
let client = NetworkClient {
    BaseURL("https://api.example.com")
    DefaultHeader("Content-Type", "application/json")
    DefaultHeader("Accept", "application/json")
    
    Authentication {
        BearerToken("token")
    }
}

let users: [User] = try await client.execute {
    GET("/users")
}.decode([User].self)
```

---

## Common Migration Patterns

### 1. Singleton Pattern Migration

#### Before (Singleton with Shared State)

```swift
class NetworkManager {
    static let shared = NetworkManager()
    
    private var baseURL = "https://api.example.com"
    private var authToken: String?
    private let session = URLSession.shared
    
    private init() {}
    
    func setAuthToken(_ token: String) {
        authToken = token
    }
    
    func request<T: Codable>(_ endpoint: String, type: T.Type) async throws -> T {
        // Manual request building and execution
    }
}
```

#### After (Dependency Injection)

```swift
protocol APIClient {
    func fetchUser(id: String) async throws -> User
    func fetchPosts() async throws -> [Post]
}

class ModernAPIClient: APIClient {
    private let client: NetworkClient
    
    init(baseURL: String, authToken: String) {
        self.client = NetworkClient {
            BaseURL(baseURL)
            Authentication {
                BearerToken(authToken)
            }
            EnableLogging()
            EnableRetry()
        }
    }
    
    func fetchUser(id: String) async throws -> User {
        return try await client.execute {
            GET("/users/\(id)")
        }.decode(User.self)
    }
}

// Dependency injection in app
class UserViewModel {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
}
```

### 2. Error Handling Migration

#### Before (Generic Error Handling)

```swift
enum NetworkError: Error {
    case noInternet
    case serverError(Int)
    case decodingError
    case unknown
}

func handleError(_ error: Error) {
    if let urlError = error as? URLError {
        switch urlError.code {
        case .notConnectedToInternet:
            // Handle no internet
        case .timedOut:
            // Handle timeout
        default:
            // Handle other URL errors
        }
    }
}
```

#### After (Rich Error Context)

```swift
func handleError(_ error: Error) {
    guard let httpError = error as? HTTPError else {
        // Handle non-HTTP errors
        return
    }
    
    switch httpError.category {
    case .network(let networkError):
        switch networkError {
        case .noConnection:
            showOfflineMessage()
        case .dnsFailure:
            showDNSError()
        case .serverUnreachable:
            showServerError()
        default:
            showGenericNetworkError()
        }
        
    case .http(let status):
        switch status.rawValue {
        case 401:
            // Use built-in auth refresh or redirect to login
            break
        case 429:
            showRateLimitError(retryAfter: httpError.response?.headers["Retry-After"])
        default:
            showHTTPError(status: status)
        }
        
    case .decoding(let message):
        logDecodingError(message, request: httpError.request)
        
    default:
        showGenericError()
    }
}
```

### 3. Configuration Migration

#### Before (Manual Configuration)

```swift
class NetworkConfig {
    static func createURLSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpMaximumConnectionsPerHost = 5
        config.waitsForConnectivity = true
        
        return URLSession(configuration: config)
    }
    
    static func createHeaders(with token: String?) -> [String: String] {
        var headers = [
            "Accept": "application/json",
            "Content-Type": "application/json",
            "User-Agent": "MyApp/1.0"
        ]
        
        if let token = token {
            headers["Authorization"] = "Bearer \(token)"
        }
        
        return headers
    }
}
```

#### After (Declarative Configuration)

```swift
func createAPIClient(authToken: String?) -> NetworkClient {
    return NetworkClient {
        BaseURL("https://api.example.com")
        DefaultHeader("Accept", "application/json")
        DefaultHeader("Content-Type", "application/json")
        DefaultHeader("User-Agent", "MyApp/1.0")
        
        if let token = authToken {
            Authentication {
                BearerToken(token)
                RefreshStrategy.automatic()
            }
        }
        
        Session {
            SessionTimeout(30.0)
            ResourceTimeout(60.0)
            MaxConnectionsPerHost(5)
            WaitsForConnectivity(true)
        }
        
        Retry {
            MaxAttempts(3)
            BackoffStrategy.exponential()
            RetryWhen.networkErrors()
        }
        
        EnableLogging(LoggingMiddleware.Configuration(
            logLevel: .debug,
            logHeaders: true,
            logBody: true
        ))
    }
}
```

---

## Breaking Changes

### API Changes

#### Async/Await Requirement

**Breaking**: All network operations are now async.

```swift
// Before: Completion handler
func fetchUser(completion: @escaping (Result<User, Error>) -> Void)

// After: Async/await
func fetchUser() async throws -> User
```

**Migration**: Wrap existing completion handler code in `withCheckedThrowingContinuation` if needed during transition.

#### Sendable Conformance

**Breaking**: All types must be `Sendable`.

```swift
// Before: Mutable reference types
class RequestConfig {
    var timeout: TimeInterval = 30
    var headers: [String: String] = [:]
}

// After: Immutable value types or actors
struct RequestConfig: Sendable {
    let timeout: TimeInterval
    let headers: [String: String]
}
```

#### Error Type Changes

**Breaking**: Generic `Error` replaced with `HTTPError`.

```swift
// Before: Generic error handling
catch let error {
    if let nsError = error as? NSError {
        // Handle NSError
    }
}

// After: Structured error handling
catch let error as HTTPError {
    switch error.category {
    case .network(let networkError):
        // Handle specific network errors
    case .http(let status):
        // Handle HTTP status errors
    }
}
```

### Configuration Changes

#### Session Configuration

**Breaking**: URLSession configuration moved to DSL.

```swift
// Before: Direct URLSessionConfiguration
let config = URLSessionConfiguration.default
config.timeoutIntervalForRequest = 30
let session = URLSession(configuration: config)

// After: Session DSL block
let client = NetworkClient {
    Session {
        SessionTimeout(30.0)
    }
}
```

#### Header Configuration

**Breaking**: Headers configured through DSL, not manually.

```swift
// Before: Manual header setting
var request = URLRequest(url: url)
request.setValue("Bearer token", forHTTPHeaderField: "Authorization")

// After: DSL configuration
let response = try await client.execute {
    GET("/endpoint")
    BearerAuth(token)
}
```

---

## Performance Considerations

### Memory Usage

#### Before (Potential Memory Leaks)

```swift
// Retain cycles possible with completion handlers
class DataLoader {
    var completion: ((Data?) -> Void)?
    
    func loadData() {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            self.completion?(data)  // Potential retain cycle
        }.resume()
    }
}
```

#### After (Automatic Memory Management)

```swift
// No retain cycles with async/await
class DataLoader {
    private let client: NetworkClient
    
    func loadData() async throws -> Data? {
        let response = try await client.execute {
            GET("/data")
        }
        return response.body
    }
}
```

### Connection Management

Networking automatically handles connection pooling and management through URLSession, but provides additional configuration options:

```swift
let client = NetworkClient {
    Session {
        MaxConnectionsPerHost(6)        // Optimize for concurrent requests
        AllowsCellular(true)           // Control cellular usage
        WaitsForConnectivity(true)     // Better offline handling
    }
}
```

### Request Optimization

#### Concurrent Requests

```swift
// Efficient concurrent requests
async let user = client.execute { GET("/user/123") }
async let posts = client.execute { GET("/user/123/posts") }
async let followers = client.execute { GET("/user/123/followers") }

let (userResponse, postsResponse, followersResponse) = try await (user, posts, followers)
```

#### Caching

```swift
let client = NetworkClient {
    Caching {
        Storage.memory(size: .MB(50))
        Duration.ttl(300)  // 5 minutes
        CacheWhen.getRequestsOnly()
    }
}
```

---

## Testing Migration

### From URLSession Testing

#### Before (URLProtocol Mocking)

```swift
class MockURLProtocol: URLProtocol {
    static var mockData: [URL: Data] = [:]
    static var mockError: [URL: Error] = [:]
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        if let url = request.url {
            if let data = MockURLProtocol.mockData[url] {
                client?.urlProtocol(self, didLoad: data)
            }
            
            if let error = MockURLProtocol.mockError[url] {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
        
        client?.urlProtocolDidFinishLoading(self)
    }
}
```

#### After (Mock HTTPClient)

```swift
struct MockHTTPClient: HTTPClient {
    private let responses: [String: HTTPResponse]
    
    init(responses: [String: HTTPResponse]) {
        self.responses = responses
    }
    
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        let key = "\(request.method.rawValue):\(request.url.path)"
        guard let response = responses[key] else {
            throw HTTPError(category: .configuration("No mock response for \(key)"))
        }
        return response
    }
}

// Usage in tests
let mockClient = MockHTTPClient(responses: [
    "GET:/users/123": HTTPResponse(
        request: testRequest,
        status: .ok,
        body: """
        {"id": "123", "name": "Test User"}
        """.data(using: .utf8)
    )
])

let service = UserService(client: mockClient)
let user = try await service.getUser(id: "123")
```

### Swift Testing Integration

```swift
import Testing
import Networking

@Test("User service returns correct user data")
func userServiceTest() async throws {
    let expectedUser = User(id: "123", name: "Test User", email: "test@example.com")
    
    let mockClient = MockHTTPClient { request in
        #expect(request.method == .get)
        #expect(request.url.path.contains("users/123"))
        
        return HTTPResponse(
            request: request,
            status: .ok,
            body: try JSONEncoder().encode(expectedUser)
        )
    }
    
    let service = UserService(client: mockClient)
    let actualUser = try await service.getUser(id: "123")
    
    #expect(actualUser.id == expectedUser.id)
    #expect(actualUser.name == expectedUser.name)
    #expect(actualUser.email == expectedUser.email)
}
```

---

## Troubleshooting

### Common Migration Issues

#### 1. Async/Await Adoption

**Issue**: "Cannot call async function in non-async context"

**Solution**: Wrap in Task or make calling function async:

```swift
// Problem
func viewDidLoad() {
    let user = try await fetchUser()  // Error
}

// Solution 1: Task wrapper
func viewDidLoad() {
    Task {
        do {
            let user = try await fetchUser()
            // Update UI on main actor
            await MainActor.run {
                self.updateUI(with: user)
            }
        } catch {
            // Handle error
        }
    }
}

// Solution 2: Make function async
func loadData() async {
    do {
        let user = try await fetchUser()
        // Use user
    } catch {
        // Handle error
    }
}
```

#### 2. Sendable Compliance

**Issue**: "Type 'MyClass' does not conform to the 'Sendable' protocol"

**Solution**: Make types Sendable or use actors:

```swift
// Problem
class UserData {
    var users: [User] = []
}

// Solution 1: Value type
struct UserData: Sendable {
    let users: [User]
}

// Solution 2: Actor
actor UserDataManager {
    private var users: [User] = []
    
    func getUsers() -> [User] {
        users
    }
    
    func addUser(_ user: User) {
        users.append(user)
    }
}
```

#### 3. Error Handling Updates

**Issue**: Generic error handling doesn't work with HTTPError

**Solution**: Update to use HTTPError categories:

```swift
// Problem
catch {
    if error.localizedDescription.contains("timeout") {
        // Handle timeout
    }
}

// Solution
catch let error as HTTPError {
    switch error.category {
    case .timeout:
        // Handle timeout
    case .network(let networkError):
        // Handle network errors
    case .http(let status):
        // Handle HTTP status errors
    default:
        // Handle other errors
    }
}
```

#### 4. Configuration Migration

**Issue**: URLSessionConfiguration no longer directly accessible

**Solution**: Use Session DSL block:

```swift
// Problem
let config = URLSessionConfiguration.default
config.timeoutIntervalForRequest = 60
config.allowsCellularAccess = false

// Solution
let client = NetworkClient {
    Session {
        SessionTimeout(60.0)
        AllowsCellular(false)
    }
}
```

### Performance Issues

#### Memory Usage

If experiencing high memory usage after migration:

1. **Check for retain cycles** - async/await should eliminate most, but verify
2. **Configure caching limits** - Set appropriate cache sizes
3. **Use weak references** where needed in custom middleware

```swift
let client = NetworkClient {
    Caching {
        Storage.memory(size: .MB(25))  // Reduce if needed
        Duration.ttl(180)              // Shorter TTL
    }
}
```

#### Network Performance

If network requests seem slower:

1. **Enable connection pooling**:
```swift
Session {
    MaxConnectionsPerHost(6)
    WaitsForConnectivity(true)
}
```

2. **Use concurrent requests** where possible:
```swift
async let user = fetchUser()
async let posts = fetchPosts()
let (userData, postsData) = try await (user, posts)
```

3. **Configure appropriate timeouts**:
```swift
Session {
    SessionTimeout(15.0)     // Shorter for mobile
    ResourceTimeout(30.0)
}
```

### Debug Logging

Enable comprehensive logging during migration:

```swift
let client = NetworkClient {
    EnableLogging(LoggingMiddleware.Configuration(
        logLevel: .debug,
        logHeaders: true,
        logBody: true,
        maxBodyLength: 2048
    ))
}
```

This will help identify issues with request/response handling during migration.

Migration to Networking provides significant benefits in terms of Swift 6 compliance, developer experience, and production readiness. The structured approach outlined in this guide should help ensure a smooth transition from legacy networking code.