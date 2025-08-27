# Client Configuration

Comprehensive configuration options for NetworkClient using the declarative configuration DSL.

## Overview

NetworkClient uses a declarative configuration system that allows you to set up clients with complex configurations in a readable, type-safe manner. The configuration system uses result builders to provide a clean syntax for specifying base URLs, timeouts, headers, authentication, middleware, and more.

Configuration components include:
- **Base Configuration**: URLs, timeouts, headers
- **Authentication Setup**: Various authentication methods
- **Session Configuration**: URLSession customization
- **Middleware Integration**: Request/response processing
- **Security Settings**: SSL pinning, certificate validation
- **Performance Tuning**: Caching, connection limits, retry logic

## Basic Configuration

### Essential Settings

Every NetworkClient needs basic configuration:

```swift
let client = NetworkClient {
    // Required: Base URL for all requests
    BaseURL("https://api.example.com")
    
    // Recommended: Default timeout
    DefaultTimeout(30.0)
    
    // Optional: Default headers applied to all requests
    DefaultHeader("User-Agent", "MyApp/1.0")
    DefaultHeader("Accept", "application/json")
}
```

### Multiple Base URLs

Handle APIs with multiple endpoints:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")          // Primary API
    FallbackURL("https://api-backup.example.com") // Fallback if primary fails
    
    DefaultTimeout(30.0)
}
```

### Environment-Based Configuration

Configure clients for different environments:

```swift
enum APIEnvironment {
    case development, staging, production
    
    var baseURL: String {
        switch self {
        case .development: return "https://dev-api.example.com"
        case .staging: return "https://staging-api.example.com"
        case .production: return "https://api.example.com"
        }
    }
    
    var timeout: TimeInterval {
        switch self {
        case .development: return 60.0  // Longer for debugging
        case .staging: return 45.0      // Moderate for testing
        case .production: return 30.0   // Optimized for production
        }
    }
}

let environment = APIEnvironment.production

let client = NetworkClient {
    BaseURL(environment.baseURL)
    DefaultTimeout(environment.timeout)
    
    // Environment-specific headers
    DefaultHeader("X-Environment", "\(environment)")
    DefaultHeader("X-Client-Version", Bundle.main.version)
}
```

## URLSession Configuration

### Custom Session Settings

Customize the underlying URLSession:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    Session {
        // Network access control
        AllowsCellularAccess(true)
        AllowsExpensiveNetworkAccess(false)
        AllowsConstrainedNetworkAccess(true)
        
        // Timeout intervals
        TimeoutIntervalForRequest(60.0)
        TimeoutIntervalForResource(300.0)
        
        // Connection limits
        HTTPMaximumConnectionsPerHost(4)
        HTTPShouldUsePipelining(false)
        
        // Cookie and credential handling
        HTTPCookieAcceptPolicy(.always)
        HTTPShouldSetCookies(true)
        
        // Cache behavior
        RequestCachePolicy(.useProtocolCachePolicy)
    }
}
```

### Proxy Configuration

Configure proxy settings:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    Session {
        // HTTP proxy
        ProxyConfiguration {
            HTTPProxy(host: "proxy.company.com", port: 8080)
            HTTPSProxy(host: "secure-proxy.company.com", port: 8443)
            ProxyCredentials(username: "user", password: "pass")
        }
        
        // Bypass proxy for certain hosts
        ProxyBypass(["localhost", "127.0.0.1", "*.local"])
    }
}
```

## Authentication Configuration

### Bearer Token Authentication

Simple token-based authentication:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    // Static token
    BearerToken("your-static-token")
    
    // Or dynamic token
    DynamicBearerToken {
        await AuthService.shared.getCurrentToken()
    }
}
```

### Basic Authentication

Username/password authentication:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    BasicAuth(username: "api-user", password: "secret-password")
    
    // Or with credentials from keychain
    BasicAuth {
        let credentials = try await Keychain.getCredentials(for: "api.example.com")
        return (credentials.username, credentials.password)
    }
}
```

### API Key Authentication

API key in headers or query parameters:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    // API key in header
    APIKey(header: "X-API-Key", key: "your-api-key")
    
    // API key in query parameter
    APIKey(queryParam: "api_key", key: "your-api-key")
    
    // Multiple API keys
    APIKey(header: "X-Primary-Key", key: primaryKey)
    APIKey(header: "X-Secondary-Key", key: secondaryKey)
}
```

### Custom Authentication

Implement complex authentication schemes:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    CustomAuth { request in
        var modifiedRequest = request
        
        // Generate signature
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let signature = generateHMACSignature(
            method: request.method.rawValue,
            path: request.url.path,
            timestamp: timestamp,
            body: request.body,
            secretKey: "your-secret-key"
        )
        
        // Add authentication headers
        modifiedRequest.headers["X-Timestamp"] = timestamp
        modifiedRequest.headers["X-Signature"] = signature
        modifiedRequest.headers["X-API-Key"] = "your-api-key"
        
        return modifiedRequest
    }
}
```

## Security Configuration

### SSL Certificate Pinning

Pin SSL certificates for enhanced security:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    EnableSecurity {
        // SHA-256 certificate fingerprints
        CertificatePinning(sha256Hashes: [
            "E9CZ9INDbd+2eRQozYqqbQ2yXLVKB9+xcprMF+44U1g=",
            "LvRiGEjRqfzurezaWuj8Wie2gyHMrW5Q06LspMnox7A="
        ])
        
        // Minimum TLS version
        MinTLSVersion(.v1_2)
        
        // Certificate validation callback
        CustomCertificateValidation { challenge, completionHandler in
            // Custom certificate validation logic
            let trust = challenge.protectionSpace.serverTrust
            let result = SecTrustEvaluateWithError(trust!, nil)
            completionHandler(result ? .useCredential : .cancelAuthenticationChallenge, nil)
        }
    }
}
```

### Security Headers

Add security-related headers:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    // Security headers
    DefaultHeader("Strict-Transport-Security", "max-age=31536000")
    DefaultHeader("X-Frame-Options", "DENY")
    DefaultHeader("X-Content-Type-Options", "nosniff")
    DefaultHeader("Referrer-Policy", "strict-origin-when-cross-origin")
}
```

## Middleware Configuration

### Built-in Middleware

Configure common middleware:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    // Retry middleware
    EnableRetry {
        MaxAttempts(3)
        BackoffStrategy(.exponential(multiplier: 2.0))
        RetryCondition(.networkErrors)
        RetryCondition(.serverErrors)
        RetryCondition { error in
            // Custom retry logic
            return error.isTransientError
        }
    }
    
    // Caching middleware
    EnableCaching {
        Policy(.standard)
        Storage(.hybrid(
            memorySize: .megabytes(50),
            diskSize: .megabytes(500)
        ))
        Duration(.minutes(15))
        
        // Custom cache key generation
        KeyGenerator { request in
            return "\(request.method.rawValue):\(request.url.absoluteString)"
        }
    }
    
    // Logging middleware
    EnableLogging {
        Level(.info)
        LogRequests(true)
        LogResponses(true)
        LogHeaders(true)
        LogBodies(false)
        
        // Custom logger
        Logger(OSLog(subsystem: "com.example.app", category: "networking"))
    }
    
    // Observability middleware
    EnableObservability {
        CollectMetrics(true)
        TrackTiming(true)
        
        // Custom metrics handler
        MetricsHandler { metrics in
            await AnalyticsService.shared.record(metrics)
        }
    }
}
```

### Custom Middleware

Add custom middleware to the pipeline:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    // Custom request middleware
    Middleware(APIVersionMiddleware(version: "v2"))
    Middleware(RequestIDMiddleware())
    Middleware(RateLimitingMiddleware(requestsPerSecond: 10))
    
    // Custom response middleware
    Middleware(ResponseTimingMiddleware())
    Middleware(ErrorTrackingMiddleware())
    
    // Custom error middleware
    Middleware(TokenRefreshMiddleware(authService: authService))
}
```

## Performance Configuration

### Connection Management

Optimize connection handling:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    Session {
        // Connection pooling
        HTTPMaximumConnectionsPerHost(6)
        HTTPShouldUsePipelining(true)
        
        // Keep-alive settings
        HTTPAdditionalHeaders([
            "Connection": "keep-alive",
            "Keep-Alive": "timeout=30, max=100"
        ])
        
        // Connection timeout
        TimeoutIntervalForRequest(30.0)
        TimeoutIntervalForResource(300.0)
    }
    
    // Request coalescing for duplicate requests
    EnableRequestCoalescing()
    
    // Connection prewarming
    PrewarmConnections(count: 2)
}
```

### Caching Strategy

Configure intelligent caching:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    EnableCaching {
        // Multi-tier caching
        Storage(.hybrid(
            memorySize: .megabytes(50),    // Fast memory cache
            diskSize: .megabytes(500)      // Persistent disk cache
        ))
        
        // Cache policies by endpoint
        PolicyForPath("/api/static/**", policy: .aggressive)
        PolicyForPath("/api/user/**", policy: .standard)
        PolicyForPath("/api/realtime/**", policy: .networkFirst)
        
        // Cache validation
        EnableETagValidation(true)
        EnableLastModifiedValidation(true)
        
        // Cache invalidation
        InvalidateOn(.backgroundAppRefresh)
        InvalidateOn(.significantTimeChange)
    }
}
```

## Advanced Configuration Patterns

### Configuration Builders

Create reusable configuration patterns:

```swift
struct APIClientConfiguration {
    static func development(apiKey: String) -> NetworkClientConfiguration {
        return {
            BaseURL("https://dev-api.example.com")
            DefaultTimeout(60.0)
            APIKey(header: "X-API-Key", key: apiKey)
            
            EnableLogging {
                Level(.debug)
                LogRequests(true)
                LogResponses(true)
                LogHeaders(true)
                LogBodies(true)
            }
            
            EnableRetry {
                MaxAttempts(1) // No retry in development
            }
        }
    }
    
    static func production(apiKey: String) -> NetworkClientConfiguration {
        return {
            BaseURL("https://api.example.com")
            FallbackURL("https://api-backup.example.com")
            DefaultTimeout(30.0)
            APIKey(header: "X-API-Key", key: apiKey)
            
            EnableSecurity {
                CertificatePinning(sha256Hashes: productionCertHashes)
                MinTLSVersion(.v1_2)
            }
            
            EnableRetry {
                MaxAttempts(3)
                BackoffStrategy(.exponential(multiplier: 2.0))
            }
            
            EnableCaching {
                Policy(.standard)
                Duration(.minutes(15))
                Storage(.hybrid(memorySize: .megabytes(50), diskSize: .megabytes(200)))
            }
            
            EnableObservability {
                CollectMetrics(true)
                TrackTiming(true)
            }
        }
    }
}

// Usage
let client = NetworkClient(APIClientConfiguration.production(apiKey: "prod-key"))
```

### Configuration Composition

Compose configurations from multiple sources:

```swift
@NetworkClientBuilder
func baseConfiguration() -> NetworkClientConfiguration {
    DefaultTimeout(30.0)
    DefaultHeader("User-Agent", "MyApp/\(Bundle.main.version)")
    DefaultHeader("Accept", "application/json")
}

@NetworkClientBuilder
func authenticationConfiguration(token: String) -> NetworkClientConfiguration {
    BearerToken(token)
    Middleware(TokenRefreshMiddleware())
}

@NetworkClientBuilder
func performanceConfiguration() -> NetworkClientConfiguration {
    EnableCaching {
        Policy(.standard)
        Duration(.minutes(15))
    }
    
    EnableRetry {
        MaxAttempts(3)
        BackoffStrategy(.exponential(multiplier: 2.0))
    }
    
    Session {
        HTTPMaximumConnectionsPerHost(4)
        AllowsExpensiveNetworkAccess(false)
    }
}

// Compose configurations
let client = NetworkClient {
    BaseURL("https://api.example.com")
    baseConfiguration()
    authenticationConfiguration(token: userToken)
    performanceConfiguration()
}
```

### Dynamic Configuration

Update configuration at runtime:

```swift
class DynamicNetworkClient {
    private var client: NetworkClient
    
    init(baseURL: String) {
        self.client = NetworkClient {
            BaseURL(baseURL)
            DefaultTimeout(30.0)
        }
    }
    
    func updateAuthentication(token: String) {
        client = NetworkClient {
            BaseURL(client.baseURL)
            DefaultTimeout(client.defaultTimeout)
            BearerToken(token)
            
            // Preserve existing middleware
            client.middleware.forEach { middleware in
                Middleware(middleware)
            }
        }
    }
    
    func updateEnvironment(_ environment: APIEnvironment) {
        client = NetworkClient {
            BaseURL(environment.baseURL)
            DefaultTimeout(environment.timeout)
            
            // Environment-specific configuration
            switch environment {
            case .development:
                EnableLogging { Level(.debug) }
            case .production:
                EnableObservability { CollectMetrics(true) }
            default:
                break
            }
        }
    }
}
```

## Configuration Validation

### Runtime Validation

Validate configuration at client creation:

```swift
struct ValidatedNetworkClient {
    let client: NetworkClient
    
    init(@NetworkClientBuilder configuration: () -> NetworkClientConfiguration) throws {
        let config = configuration()
        
        // Validate required configuration
        guard !config.baseURL.isEmpty else {
            throw ConfigurationError.missingBaseURL
        }
        
        guard config.defaultTimeout > 0 else {
            throw ConfigurationError.invalidTimeout
        }
        
        // Validate security configuration
        if config.certificatePinning.isEnabled && config.baseURL.hasPrefix("http:") {
            throw ConfigurationError.certificatePinningWithHTTP
        }
        
        self.client = NetworkClient(config)
    }
}
```

### Configuration Testing

Test different configuration scenarios:

```swift
@Test func testDevelopmentConfiguration() throws {
    let client = NetworkClient(APIClientConfiguration.development(apiKey: "test-key"))
    
    #expect(client.baseURL == "https://dev-api.example.com")
    #expect(client.defaultTimeout == 60.0)
    #expect(client.loggingLevel == .debug)
    #expect(client.maxRetryAttempts == 1)
}

@Test func testProductionConfiguration() throws {
    let client = NetworkClient(APIClientConfiguration.production(apiKey: "prod-key"))
    
    #expect(client.baseURL == "https://api.example.com")
    #expect(client.defaultTimeout == 30.0)
    #expect(client.certificatePinning.isEnabled)
    #expect(client.maxRetryAttempts == 3)
}

@Test func testConfigurationComposition() throws {
    let client = NetworkClient {
        BaseURL("https://api.example.com")
        baseConfiguration()
        authenticationConfiguration(token: "test-token")
        performanceConfiguration()
    }
    
    #expect(client.defaultHeaders["User-Agent"]?.starts(with: "MyApp/") == true)
    #expect(client.authenticationHeaders["Authorization"] == "Bearer test-token")
    #expect(client.caching.isEnabled)
    #expect(client.retry.isEnabled)
}
```

## Best Practices

### Configuration Organization

**Structure by concern:**
```swift
extension NetworkClient {
    static func apiClient(environment: Environment) -> NetworkClient {
        NetworkClient {
            // Base configuration
            baseConfiguration(for: environment)
            
            // Authentication
            authenticationConfiguration(for: environment)
            
            // Security
            securityConfiguration(for: environment)
            
            // Performance
            performanceConfiguration(for: environment)
            
            // Observability
            observabilityConfiguration(for: environment)
        }
    }
}
```

**Environment-specific patterns:**
- Use different timeouts for development vs production
- Enable verbose logging only in development
- Apply certificate pinning only in production
- Use different retry strategies per environment

**Security considerations:**
- Never hardcode secrets in configuration
- Use secure storage for sensitive configuration
- Validate SSL certificates in production
- Apply appropriate timeout values to prevent hanging

## See Also

- ``NetworkClient``
- ``NetworkClientBuilder``
- ``HTTPClient``
- <doc:NetworkClient>
- <doc:MiddlewareOverview>
- <doc:SecurityFeatures>
- <doc:SessionManagement>