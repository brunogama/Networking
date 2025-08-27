# Client Configuration

Configure NetworkClient instances using the declarative DSL.

## Overview

ModernNetworking provides a powerful, declarative API for configuring HTTP clients. The configuration system uses Swift's result builder pattern to create readable, maintainable client setups.

## Basic Configuration

### Creating a Client

Use the ``NetworkClientBuilder`` to configure a client:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    DefaultTimeout(30.0)
    DefaultHeader("User-Agent", "MyApp/1.0")
    DefaultHeader("Accept", "application/json")
}
```

### Configuration Components

#### BaseURL Configuration

Set a base URL that will be prepended to relative request paths:

```swift
// String-based configuration
ClientBaseURL("https://api.example.com")

// URL-based configuration  
ClientBaseURL(URL(string: "https://api.example.com")!)
```

#### Default Headers

Add headers that will be included in all requests:

```swift
DefaultHeader("Authorization", "Bearer token")
DefaultHeader("Content-Type", "application/json")
DefaultHeader("X-API-Version", "v1")
```

#### Timeout Configuration

Set default request timeouts:

```swift
DefaultTimeout(60.0) // 60 seconds
```

## Authentication Configuration

### Bearer Token Authentication

Configure Bearer token authentication with automatic refresh:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    Authentication {
        BearerToken(tokenProvider)
        AuthRefreshStrategy(.automatic)
        AuthorizationHeader("Authorization")
        AuthenticateWhen { request in
            // Only authenticate API requests, not auth requests
            !request.url.path.contains("/auth/")
        }
    }
}
```

### Basic Authentication

Configure HTTP Basic authentication:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com") 
    Authentication {
        ClientBasicAuth(username: "user", password: "pass")
    }
}
```

### Custom Authentication

Implement custom authentication strategies:

```swift
struct CustomAuthProvider: CustomAuthProvider {
    func authenticateRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
        // Add custom authentication logic
        var headers = request.headers
        headers["X-Custom-Auth"] = await getCustomToken()
        
        return HTTPRequest(
            method: request.method,
            url: request.url,
            headers: headers,
            body: request.body,
            timeout: request.timeout
        )
    }
    
    func handleAuthenticationError(
        _ error: HTTPError,
        for request: HTTPRequest
    ) async throws -> HTTPResponse? {
        // Handle auth errors, potentially refresh tokens
        return nil
    }
}

let client = NetworkClient {
    BaseURL("https://api.example.com")
    Authentication {
        CustomAuth(CustomAuthProvider())
    }
}
```

### Token Providers

Implement token providers for Bearer authentication:

```swift
// Static token provider
let staticProvider = StaticTokenProvider(token: "your-token")

// Dynamic token provider
let dynamicProvider = ClosureBearerTokenProvider(
    getCurrentToken: {
        return await KeychainService.getToken("api_token")
    },
    refreshToken: {
        let newToken = try await authService.refreshToken()
        await KeychainService.store(newToken, forKey: "api_token")
        return newToken
    }
)

let client = NetworkClient {
    BaseURL("https://api.example.com")
    Authentication {
        BearerToken(dynamicProvider)
        AuthRefreshStrategy(.automatic)
    }
}
```

## Retry Configuration

### Basic Retry Setup

Enable automatic retries for failed requests:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    Retry {
        MaxAttempts(3)
        BackoffStrategy(.exponential)
        InitialDelay(1.0)
    }
}
```

### Custom Retry Conditions

Define when requests should be retried:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    Retry {
        MaxAttempts(5)
        BackoffStrategy(.linear)
        RetryWhen { error in
            switch error.category {
            case .network(.serverUnreachable), .network(.connectionLost):
                return true
            case .http(let status) where status.rawValue >= 500:
                return true
            case .timeout:
                return true
            default:
                return false
            }
        }
    }
}
```

### Backoff Strategies

Choose from several backoff strategies:

```swift
// Fixed delay between retries
BackoffStrategy(.fixed) // Uses InitialDelay value

// Linear backoff (delay × attempt)
BackoffStrategy(.linear)

// Exponential backoff (delay × 2^attempt)
BackoffStrategy(.exponential)

// Custom backoff function
BackoffStrategy(.custom { attempt in
    // Custom delay calculation
    return TimeInterval(attempt * 2) + Double.random(in: 0...1)
})
```

## Caching Configuration

### Basic Caching

Enable response caching with default settings:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    Caching {
        Policy(.standard)
        Storage(.memory(size: .MB(50)))
        Duration(.ttl(300)) // 5 minutes
    }
}
```

### Advanced Caching

Configure sophisticated caching behaviors:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    Caching {
        Policy(.aggressive)
        Storage(.hybrid(
            memorySize: .MB(25),
            diskSize: .GB(1),
            path: nil
        ))
        Duration(.ttl(3600)) // 1 hour
        CacheWhen { request, response in
            // Custom caching logic
            return request.method == .get && 
                   response.status.isSuccess &&
                   !request.url.path.contains("/dynamic/")
        }
    }
}
```

### Cache Policies

Available caching policies:

- `.none`: No caching
- `.standard`: HTTP standard caching with conditional requests
- `.aggressive`: Cache responses regardless of headers
- `.custom(maxAge:revalidate:)`: Custom cache behavior

### Storage Options

Configure cache storage:

```swift
// Memory-only cache
Storage(.memory(size: .MB(50)))

// Disk-only cache  
Storage(.disk(size: .GB(1), path: "/custom/cache/path"))

// Hybrid memory + disk cache
Storage(.hybrid(
    memorySize: .MB(25),
    diskSize: .MB(500), 
    path: nil
))
```

## Session Configuration

### URLSession Customization

Configure the underlying URLSession:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    Session {
        SessionTimeout(60.0)
        AllowsCellular(true)
        AllowsExpensiveNetworkAccess(false)
        AllowsConstrainedNetworkAccess(true)
        WaitsForConnectivity(true)
        MaxConnectionsPerHost(6)
        RequestCachePolicy(.reloadIgnoringLocalCacheData)
    }
}
```

### Custom URLSession

Use a pre-configured URLSession:

```swift
let customSession = URLSession(configuration: .ephemeral)
let client = NetworkClient {
    BaseURL("https://api.example.com")
    CustomSession(customSession)
}
```

## Security Configuration

### SSL Pinning

Configure certificate or public key pinning:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    EnableSecurity {
        SSLPinning(.certificates(certificates))
        AllowInsecureConnections(false)
        ValidatesCertificateChain(true)
    }
}
```

### Security Headers

Enable security headers middleware:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    EnableSecurity {
        SecurityHeaders(.strict)
        CSPPolicy("default-src 'self'")
        HSTSMaxAge(31536000) // 1 year
    }
}
```

## Middleware Configuration

### Logging

Enable request/response logging:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    EnableLogging(LoggingMiddleware.Configuration(
        level: .detailed,
        includeHeaders: true,
        includeBody: true,
        redactedHeaders: ["Authorization", "X-API-Key"]
    ))
}
```

### Custom Middleware

Add custom middleware to the pipeline:

```swift
struct CustomMiddleware: HTTPRequestMiddleware {
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
        // Custom request processing
        return request
    }
}

let client = NetworkClient(
    session: .shared,
    requestMiddlewares: [CustomMiddleware()],
    responseMiddlewares: [],
    errorMiddlewares: []
)
```

## Complete Configuration Example

Here's a comprehensive client configuration example:

```swift
let client = NetworkClient {
    // Base configuration
    BaseURL("https://api.example.com")
    DefaultTimeout(30.0)
    DefaultHeader("User-Agent", "MyApp/2.0")
    DefaultHeader("Accept", "application/json")
    
    // Authentication
    Authentication {
        BearerToken(tokenProvider)
        AuthRefreshStrategy(.automatic)
        AuthenticateWhen { request in
            !request.url.path.hasPrefix("/public/")
        }
    }
    
    // Retry configuration
    Retry {
        MaxAttempts(3)
        BackoffStrategy(.exponential)
        InitialDelay(1.0)
        RetryWhen { error in
            error.isRetryable
        }
    }
    
    // Caching
    Caching {
        Policy(.standard)
        Storage(.hybrid(
            memorySize: .MB(25),
            diskSize: .MB(100),
            path: nil
        ))
        Duration(.ttl(600)) // 10 minutes
        CacheWhen { request, response in
            request.method == .get && response.status.isSuccess
        }
    }
    
    // Session configuration
    Session {
        SessionTimeout(60.0)
        AllowsCellular(true)
        WaitsForConnectivity(true)
        MaxConnectionsPerHost(4)
    }
    
    // Security
    EnableSecurity {
        SSLPinning(.publicKeys(publicKeys))
        SecurityHeaders(.moderate)
    }
    
    // Logging
    EnableLogging(LoggingMiddleware.Configuration(
        level: .basic,
        includeHeaders: false,
        redactedHeaders: ["Authorization"]
    ))
}
```

## Related Topics

- <doc:Authentication>: Detailed authentication configuration
- <doc:Caching-System>: Advanced caching strategies  
- <doc:Security-Features>: Security configuration options
- <doc:Middleware-System>: Creating custom middleware