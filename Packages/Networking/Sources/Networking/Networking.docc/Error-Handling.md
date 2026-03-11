# Error Handling

Comprehensive error handling strategies and recovery mechanisms.

## Overview

Networking provides a sophisticated error handling system designed to help you build resilient networking applications. The framework categorizes errors by type and severity, provides actionable error information, and offers automatic recovery strategies.

## HTTPError Structure

### Error Categories

``HTTPError`` categorizes all networking errors into specific types:

```swift
public enum Category: Sendable, Hashable {
    case network(NetworkError)      // Network-level failures
    case http(HTTPStatus)          // HTTP status code errors  
    case decoding(String)          // JSON/data decoding failures
    case encoding(String)          // Request encoding failures
    case timeout                   // Request timeout
    case cancelled                 // Request cancellation
    case configuration(String)     // Configuration errors
    case custom(String, String)    // Custom error types
}
```

### Network Error Types

Network errors represent connection-level failures:

```swift
public enum NetworkError: Sendable, Hashable {
    case noConnection          // No internet connection
    case dnsFailure           // DNS resolution failed
    case connectionLost       // Connection dropped during request
    case serverUnreachable    // Server not responding
    case sslError            // SSL/TLS errors
}
```

### Complete Error Information

Each ``HTTPError`` includes comprehensive context:

```swift
public struct HTTPError: Error, Sendable, LocalizedError {
    public let category: Category           // Error classification
    public let request: HTTPRequest?        // Original request
    public let response: HTTPResponse?      // Response (if received)
    public let underlyingError: Error?      // System error details
    
    // Additional properties for severity and recovery
    public let severity: ErrorSeverity
    public let recoveryCategory: RecoveryCategory
}
```

## Basic Error Handling

### Try-Catch Pattern

Handle errors using standard Swift error handling:

```swift
do {
    let response = try await client.execute {
        GET("/api/users/123")
        BearerAuth(token)
    }
    
    let user: User = try response.decode(User.self)
    return user
    
} catch let httpError as HTTPError {
    switch httpError.category {
    case .network(let networkError):
        return handleNetworkError(networkError)
        
    case .http(let status):
        return handleHTTPError(status, response: httpError.response)
        
    case .decoding(let message):
        return handleDecodingError(message)
        
    case .timeout:
        return handleTimeout()
        
    case .cancelled:
        return handleCancellation()
        
    case .configuration(let message):
        return handleConfigurationError(message)
        
    case .custom(let type, let message):
        return handleCustomError(type: type, message: message)
    }
    
} catch {
    // Handle non-HTTP errors
    return handleUnexpectedError(error)
}
```

## Network Error Handling

### Connection Failures

Handle different types of network failures:

```swift
func handleNetworkError(_ networkError: HTTPError.NetworkError) -> User? {
    switch networkError {
    case .noConnection:
        // Show offline UI, use cached data
        showOfflineMessage()
        return loadUserFromCache()
        
    case .dnsFailure:
        // DNS issues, suggest checking connectivity
        showDNSErrorMessage()
        return nil
        
    case .connectionLost:
        // Connection dropped, retry automatically
        scheduleRetry()
        return nil
        
    case .serverUnreachable:
        // Server issues, show maintenance message
        showServerMaintenanceMessage()
        return nil
        
    case .sslError:
        // Security issue, alert user
        showSecurityErrorMessage()
        return nil
    }
}
```

### Network Status Monitoring

Monitor network connectivity:

```swift
import Network

class NetworkErrorHandler {
    private let pathMonitor = NWPathMonitor()
    private var isConnected = true
    
    func startMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                
                if path.status == .satisfied {
                    self?.handleConnectionRestored()
                } else {
                    self?.handleConnectionLost()
                }
            }
        }
        
        pathMonitor.start(queue: DispatchQueue.global())
    }
    
    func handleNetworkError(_ error: HTTPError) -> Bool {
        guard case .network(let networkError) = error.category else {
            return false
        }
        
        switch networkError {
        case .noConnection:
            if isConnected {
                // Network says connected but request failed
                // Might be a server issue
                return handleServerConnectivityIssue()
            } else {
                return handleOfflineState()
            }
            
        default:
            return false
        }
    }
}
```

## HTTP Status Error Handling

### Status Code Categorization

Handle different HTTP status code ranges:

```swift
func handleHTTPError(_ status: HTTPStatus, response: HTTPResponse?) -> Result<User, Error> {
    switch status.rawValue {
    // 2xx Success (shouldn't reach here normally)
    case 200..<300:
        break
        
    // 3xx Redirection
    case 300..<400:
        return handleRedirection(status, response: response)
        
    // 4xx Client Errors
    case 400..<500:
        return handleClientError(status, response: response)
        
    // 5xx Server Errors  
    case 500..<600:
        return handleServerError(status, response: response)
        
    default:
        return .failure(HTTPError(
            category: .custom("unknown_status", "Unknown status code: \(status.rawValue)")
        ))
    }
}

func handleClientError(_ status: HTTPStatus, response: HTTPResponse?) -> Result<User, Error> {
    switch status.rawValue {
    case 400: // Bad Request
        let errorDetails = parseErrorResponse(response)
        return .failure(ValidationError(details: errorDetails))
        
    case 401: // Unauthorized
        return handleUnauthorizedError(response)
        
    case 403: // Forbidden
        return .failure(PermissionError("Access denied to resource"))
        
    case 404: // Not Found
        return .failure(NotFoundError("User not found"))
        
    case 409: // Conflict
        let conflictInfo = parseConflictResponse(response)
        return .failure(ConflictError(info: conflictInfo))
        
    case 422: // Unprocessable Entity
        let validationErrors = parseValidationErrors(response)
        return .failure(ValidationError(errors: validationErrors))
        
    case 429: // Too Many Requests
        return handleRateLimitError(response)
        
    default:
        return .failure(ClientError("Client error \(status.rawValue)"))
    }
}
```

### Authentication Errors

Handle authentication failures with automatic recovery:

```swift
func handleUnauthorizedError(_ response: HTTPResponse?) -> Result<User, Error> {
    // Check if this is a token expiration
    if let wwwAuthenticate = response?.headers["WWW-Authenticate"],
       wwwAuthenticate.contains("error=\"invalid_token\"") {
        
        // Attempt token refresh
        Task {
            do {
                let newToken = try await authService.refreshToken()
                await TokenStore.save(newToken)
                
                // Retry original request with new token
                let retryResult = await retryWithNewToken(newToken)
                // Handle retry result...
                
            } catch {
                // Refresh failed, redirect to login
                await MainActor.run {
                    authService.redirectToLogin()
                }
            }
        }
        
        return .failure(TokenExpiredError())
    }
    
    // Not a token issue, redirect to login
    authService.redirectToLogin()
    return .failure(AuthenticationError("Authentication required"))
}
```

### Server Errors

Handle server errors with retry logic:

```swift
func handleServerError(_ status: HTTPStatus, response: HTTPResponse?) -> Result<User, Error> {
    switch status.rawValue {
    case 500: // Internal Server Error
        // Log error details for debugging
        logServerError(status, response: response)
        return .failure(ServerError("Internal server error"))
        
    case 502, 503, 504: // Bad Gateway, Service Unavailable, Gateway Timeout
        // These are often temporary, suggest retry
        return .failure(TemporaryServerError(
            message: "Service temporarily unavailable",
            suggestedRetryAfter: parseRetryAfterHeader(response)
        ))
        
    default:
        return .failure(ServerError("Server error \(status.rawValue)"))
    }
}

func parseRetryAfterHeader(_ response: HTTPResponse?) -> TimeInterval? {
    guard let retryAfterValue = response?.headers["Retry-After"] else {
        return nil
    }
    
    // Retry-After can be in seconds or HTTP date format
    if let seconds = TimeInterval(retryAfterValue) {
        return seconds
    }
    
    // Parse HTTP date format
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
    if let retryDate = formatter.date(from: retryAfterValue) {
        return retryDate.timeIntervalSinceNow
    }
    
    return nil
}
```

## Data Processing Errors

### JSON Decoding Errors

Handle JSON parsing failures with detailed information:

```swift
extension HTTPResponse {
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        guard let data = body else {
            throw HTTPError(category: .decoding("Response body is empty"))
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            return try decoder.decode(type, from: data)
            
        } catch let decodingError as DecodingError {
            let errorMessage = formatDecodingError(decodingError, data: data)
            throw HTTPError(
                category: .decoding(errorMessage),
                request: request,
                response: self,
                underlyingError: decodingError
            )
        }
    }
}

func formatDecodingError(_ error: DecodingError, data: Data) -> String {
    switch error {
    case .typeMismatch(let type, let context):
        return "Type mismatch for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        
    case .valueNotFound(let type, let context):
        return "Missing value for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        
    case .keyNotFound(let key, let context):
        return "Missing key '\(key.stringValue)' at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        
    case .dataCorrupted(let context):
        // Include sample of actual data for debugging
        let dataPreview = String(data: data.prefix(200), encoding: .utf8) ?? "Non-UTF8 data"
        return "Data corrupted at \(context.codingPath.map(\.stringValue).joined(separator: ".")). Data preview: \(dataPreview)"
        
    @unknown default:
        return "Unknown decoding error: \(error.localizedDescription)"
    }
}
```

## Error Recovery Strategies

### Automatic Retry

Implement automatic retry with exponential backoff:

```swift
struct RetryableError: Error {
    let originalError: HTTPError
    let attempt: Int
    let maxAttempts: Int
}

func executeWithRetry<T>(
    maxAttempts: Int = 3,
    backoffStrategy: BackoffStrategy = .exponential,
    operation: () async throws -> T
) async throws -> T {
    var lastError: Error?
    
    for attempt in 1...maxAttempts {
        do {
            return try await operation()
            
        } catch let httpError as HTTPError {
            lastError = httpError
            
            // Check if error is retryable
            guard shouldRetry(httpError, attempt: attempt) else {
                throw httpError
            }
            
            // Don't delay after the last attempt
            guard attempt < maxAttempts else {
                break
            }
            
            // Calculate backoff delay
            let delay = backoffStrategy.calculateDelay(for: attempt)
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
        } catch {
            // Non-HTTP errors are generally not retryable
            throw error
        }
    }
    
    throw lastError ?? RetryableError(
        originalError: HTTPError(category: .configuration("Max retry attempts exceeded")),
        attempt: maxAttempts,
        maxAttempts: maxAttempts
    )
}

func shouldRetry(_ error: HTTPError, attempt: Int) -> Bool {
    switch error.category {
    case .network(.serverUnreachable), .network(.connectionLost):
        return true
        
    case .http(let status) where status.rawValue >= 500:
        return true
        
    case .timeout:
        return attempt <= 2 // Only retry timeouts twice
        
    default:
        return false
    }
}
```

### Circuit Breaker Pattern

Prevent cascading failures with circuit breaker:

```swift
actor CircuitBreaker {
    enum State {
        case closed    // Normal operation
        case open      // Failing, reject requests
        case halfOpen  // Testing if service recovered
    }
    
    private var state: State = .closed
    private var failureCount = 0
    private var lastFailureTime: Date?
    private let failureThreshold: Int
    private let recoveryTimeout: TimeInterval
    
    init(failureThreshold: Int = 5, recoveryTimeout: TimeInterval = 60) {
        self.failureThreshold = failureThreshold
        self.recoveryTimeout = recoveryTimeout
    }
    
    func execute<T>(operation: () async throws -> T) async throws -> T {
        switch state {
        case .open:
            if let lastFailure = lastFailureTime,
               Date().timeIntervalSince(lastFailure) > recoveryTimeout {
                state = .halfOpen
            } else {
                throw CircuitBreakerError.circuitOpen
            }
            
        case .halfOpen:
            // Test request in half-open state
            break
            
        case .closed:
            // Normal operation
            break
        }
        
        do {
            let result = try await operation()
            
            // Success - reset failure count and close circuit
            failureCount = 0
            state = .closed
            
            return result
            
        } catch {
            failureCount += 1
            lastFailureTime = Date()
            
            if failureCount >= failureThreshold {
                state = .open
            }
            
            throw error
        }
    }
}
```

### Fallback Data

Provide fallback responses when services are unavailable:

```swift
struct FallbackDataProvider {
    private let cache: Cache
    private let staticData: [String: Any]
    
    func handleServiceUnavailable<T: Codable>(
        _ error: HTTPError,
        for request: HTTPRequest,
        responseType: T.Type
    ) async -> T? {
        // Try cache first
        if let cachedData = await cache.get(request.cacheKey),
           let cachedObject = try? JSONDecoder().decode(T.self, from: cachedData) {
            return cachedObject
        }
        
        // Try static fallback data
        if let staticResponse = staticData[request.url.path],
           let data = try? JSONSerialization.data(withJSONObject: staticResponse),
           let fallbackObject = try? JSONDecoder().decode(T.self, from: data) {
            return fallbackObject
        }
        
        return nil
    }
}
```

## User-Facing Error Messages

### Localized Error Messages

Provide user-friendly error messages:

```swift
extension HTTPError {
    var userFriendlyMessage: String {
        switch category {
        case .network(.noConnection):
            return NSLocalizedString(
                "No internet connection. Please check your connection and try again.",
                comment: "No connection error message"
            )
            
        case .network(.serverUnreachable):
            return NSLocalizedString(
                "Unable to connect to the server. Please try again later.",
                comment: "Server unreachable error message"
            )
            
        case .http(let status) where status.rawValue == 404:
            return NSLocalizedString(
                "The requested information could not be found.",
                comment: "Not found error message"
            )
            
        case .http(let status) where status.rawValue >= 500:
            return NSLocalizedString(
                "The server is experiencing issues. Please try again later.",
                comment: "Server error message"
            )
            
        case .timeout:
            return NSLocalizedString(
                "The request took too long to complete. Please try again.",
                comment: "Timeout error message"
            )
            
        default:
            return NSLocalizedString(
                "An error occurred. Please try again.",
                comment: "Generic error message"
            )
        }
    }
}
```

### Error Presentation

Present errors to users appropriately:

```swift
@MainActor
class ErrorPresenter {
    func presentError(_ error: Error, from viewController: UIViewController) {
        let (title, message, actions) = formatErrorForPresentation(error)
        
        let alertController = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        
        for action in actions {
            alertController.addAction(action)
        }
        
        viewController.present(alertController, animated: true)
    }
    
    private func formatErrorForPresentation(_ error: Error) -> (String, String, [UIAlertAction]) {
        if let httpError = error as? HTTPError {
            switch httpError.category {
            case .network(.noConnection):
                return (
                    "No Internet Connection",
                    httpError.userFriendlyMessage,
                    [
                        UIAlertAction(title: "Settings", style: .default) { _ in
                            self.openNetworkSettings()
                        },
                        UIAlertAction(title: "Try Again", style: .default) { _ in
                            self.retryLastOperation()
                        },
                        UIAlertAction(title: "Cancel", style: .cancel)
                    ]
                )
                
            case .http(let status) where status.rawValue >= 500:
                return (
                    "Service Unavailable",
                    httpError.userFriendlyMessage,
                    [
                        UIAlertAction(title: "Try Again", style: .default) { _ in
                            self.retryLastOperation()
                        },
                        UIAlertAction(title: "OK", style: .cancel)
                    ]
                )
                
            default:
                return (
                    "Error",
                    httpError.userFriendlyMessage,
                    [UIAlertAction(title: "OK", style: .default)]
                )
            }
        }
        
        return (
            "Error",
            "An unexpected error occurred.",
            [UIAlertAction(title: "OK", style: .default)]
        )
    }
}
```

## Error Logging and Monitoring

### Structured Error Logging

Log errors with structured information:

```swift
struct ErrorLogger {
    func logError(_ error: HTTPError, additionalContext: [String: Any] = [:]) {
        var logContext: [String: Any] = [
            "error_category": String(describing: error.category),
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "request_id": error.request?.id.uuidString ?? "unknown"
        ]
        
        // Add request information
        if let request = error.request {
            logContext["request_method"] = request.method.rawValue
            logContext["request_url"] = request.url.absoluteString
            logContext["request_headers"] = redactSensitiveHeaders(request.headers)
        }
        
        // Add response information
        if let response = error.response {
            logContext["response_status"] = response.status.rawValue
            logContext["response_headers"] = response.headers
        }
        
        // Add additional context
        logContext.merge(additionalContext) { (_, new) in new }
        
        // Log to your preferred logging service
        Logger.error("HTTP Request Failed", context: logContext)
    }
    
    private func redactSensitiveHeaders(_ headers: [String: String]) -> [String: String] {
        let sensitiveHeaders = ["authorization", "x-api-key", "cookie"]
        
        return headers.mapValues { key, value in
            if sensitiveHeaders.contains(key.lowercased()) {
                return "[REDACTED]"
            }
            return value
        }
    }
}
```

## Related Topics

- <doc:Core-Networking>: HTTP primitives and error types
- <doc:Middleware-System>: Error handling middleware
- <doc:Client-Configuration>: Retry and error recovery configuration
- <doc:Security-Features>: Security-related error handling