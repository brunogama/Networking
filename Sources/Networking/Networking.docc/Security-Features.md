# Security Features

Comprehensive security capabilities including SSL pinning, certificate validation, and security headers.

## Overview

Networking provides enterprise-grade security features to protect your application's network communications. The framework includes SSL/TLS pinning, certificate validation, security headers, and secure credential storage.

## SSL Pinning

### Certificate Pinning

Pin specific certificates to prevent man-in-the-middle attacks:

```swift
// Load certificates from bundle
guard let certificate1 = Bundle.main.certificate(named: "api-cert-1"),
      let certificate2 = Bundle.main.certificate(named: "api-cert-2") else {
    fatalError("Failed to load certificates")
}

let client = NetworkClient {
    BaseURL("https://api.example.com")
    EnableSecurity {
        SSLPinning(.certificates([certificate1, certificate2]))
        AllowInsecureConnections(false)
        ValidatesCertificateChain(true)
    }
}
```

### Public Key Pinning

Pin public keys for more flexible certificate rotation:

```swift
let publicKeys = [
    "AAAB3NzaC1yc2EAAAADAQABAAABAQ...", // Base64 encoded public key
    "AAAB3NzaC1yc2EAAAADAQABAAABAQ..."  // Backup key
]

let client = NetworkClient {
    BaseURL("https://api.example.com")
    EnableSecurity {
        SSLPinning(.publicKeys(publicKeys))
        PinValidationMode(.strict)
    }
}
```

### Pinning Configuration

Configure SSL pinning behavior:

```swift
EnableSecurity {
    SSLPinning(.certificates(certificates))
    
    // Validation modes
    PinValidationMode(.strict)      // Fail on any mismatch
    PinValidationMode(.permissive)  // Allow some mismatches
    
    // Backup strategies
    AllowBackupPins(true)           // Allow backup pins
    PinningTimeout(10.0)           // Pin validation timeout
    
    // Development settings
    AllowInsecureConnections(false) // For debug builds only
    SkipPinningForDebug(false)      // Disable in debug builds
}
```

## Certificate Validation

### Custom Certificate Validation

Implement custom certificate validation logic:

```swift
struct CustomCertificateValidator: CertificateValidator {
    func validate(
        _ trust: SecTrust,
        for host: String
    ) async throws -> Bool {
        // Custom validation logic
        
        // 1. Check certificate chain
        var result = SecTrustResultType.invalid
        let status = SecTrustEvaluate(trust, &result)
        
        guard status == errSecSuccess else {
            throw SecurityError.certificateValidationFailed
        }
        
        // 2. Additional custom checks
        let certificate = SecTrustGetCertificateAtIndex(trust, 0)
        
        // Check certificate properties
        if let commonName = certificate?.commonName {
            guard isValidCommonName(commonName, for: host) else {
                throw SecurityError.invalidCommonName
            }
        }
        
        // 3. Check certificate transparency logs
        guard await verifyCertificateTransparency(certificate) else {
            throw SecurityError.certificateTransparencyFailed
        }
        
        return true
    }
}

let client = NetworkClient {
    BaseURL("https://api.example.com")
    EnableSecurity {
        CertificateValidator(CustomCertificateValidator())
    }
}
```

### Built-in Validation Options

Use pre-configured validation strategies:

```swift
EnableSecurity {
    // Standard validation with additional checks
    CertificateValidation(.enhanced)
    
    // Strict validation for high-security environments
    CertificateValidation(.strict)
    
    // Permissive validation for development
    CertificateValidation(.permissive)
    
    // Custom validation rules
    CertificateValidation(.custom { trust, host in
        // Custom validation logic
        return await customValidate(trust, for: host)
    })
}
```

## Security Headers

### Automatic Security Headers

Add security headers to all requests:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    EnableSecurity {
        SecurityHeaders(.strict)
    }
}
```

### Security Header Levels

Choose from predefined security levels:

```swift
// Basic security headers
SecurityHeaders(.basic)
// Adds: X-Content-Type-Options, X-Frame-Options

// Moderate security (recommended)
SecurityHeaders(.moderate) 
// Adds: X-XSS-Protection, Referrer-Policy, X-Content-Type-Options, X-Frame-Options

// Strict security headers
SecurityHeaders(.strict)
// Adds all moderate headers plus: Strict-Transport-Security, Content-Security-Policy

// Custom security headers
SecurityHeaders(.custom([
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY", 
    "X-XSS-Protection": "1; mode=block",
    "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
    "Content-Security-Policy": "default-src 'self'"
]))
```

### Content Security Policy

Configure CSP headers:

```swift
EnableSecurity {
    SecurityHeaders(.strict)
    CSPPolicy("default-src 'self'; img-src 'self' data: https:; script-src 'self'")
    CSPReportURI("https://api.example.com/csp-report")
}
```

### HTTP Strict Transport Security

Configure HSTS:

```swift
EnableSecurity {
    HSTSMaxAge(31536000)        // 1 year
    HSTSIncludeSubdomains(true)
    HSTSPreload(true)
}
```

## Credential Security

### Keychain Integration

Securely store authentication credentials:

```swift
// Store credentials in keychain
try await KeychainService.store("user_token", forKey: "api_token")
try await KeychainService.store("refresh_token", forKey: "refresh_token")

// Retrieve credentials securely
let token = try await KeychainService.retrieve("api_token")

// Token provider using keychain
let secureTokenProvider = ClosureBearerTokenProvider(
    getCurrentToken: {
        try await KeychainService.retrieve("api_token")
    },
    refreshToken: {
        let refreshToken = try await KeychainService.retrieve("refresh_token")
        let newTokens = try await authService.refreshTokens(refreshToken)
        
        try await KeychainService.store(newTokens.accessToken, forKey: "api_token")
        try await KeychainService.store(newTokens.refreshToken, forKey: "refresh_token")
        
        return newTokens.accessToken
    }
)
```

### Keychain Configuration

Configure keychain access and security:

```swift
let keychainService = KeychainService(
    service: "com.myapp.networking",
    accessGroup: "group.myapp.shared",
    accessibility: .whenUnlockedThisDeviceOnly,
    synchronizable: false
)

// Use biometric authentication for sensitive data
try await keychainService.store(
    "sensitive_token",
    forKey: "sensitive_api_key",
    biometricAuthentication: true
)
```

## Network Security

### TLS Configuration

Configure TLS/SSL settings:

```swift
EnableSecurity {
    TLSMinimumVersion(.v1_2)
    TLSMaximumVersion(.v1_3) 
    AllowInsecureConnections(false)
    RequireSSL(true)
}
```

### Connection Security

Secure network connections:

```swift
Session {
    // Only allow secure connections
    RequireSecureConnection(true)
    
    // Disable HTTP redirect following to prevent downgrade attacks
    AllowRedirects(false)
    
    // Set connection timeout to prevent hanging connections
    ConnectionTimeout(10.0)
    
    // Use ephemeral session for sensitive operations
    UseEphemeralSession(true)
}
```

## Data Protection

### Request/Response Encryption

Add additional encryption layers:

```swift
struct EncryptionMiddleware: HTTPRequestMiddleware, HTTPResponseMiddleware {
    private let encryptionKey: SymmetricKey
    
    func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
        guard let body = request.body else { return request }
        
        // Encrypt request body
        let encryptedBody = try AES.GCM.seal(body, using: encryptionKey)
        let encryptedData = encryptedBody.combined
        
        var headers = request.headers
        headers["Content-Encoding"] = "aes-gcm"
        
        return HTTPRequest(
            method: request.method,
            url: request.url,
            headers: headers,
            body: encryptedData,
            timeout: request.timeout
        )
    }
    
    func processResponse(
        _ response: HTTPResponse,
        for request: HTTPRequest
    ) async throws -> HTTPResponse {
        guard let body = response.body,
              response.headers["Content-Encoding"] == "aes-gcm" else {
            return response
        }
        
        // Decrypt response body
        let sealedBox = try AES.GCM.SealedBox(combined: body)
        let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey)
        
        return HTTPResponse(
            request: response.request,
            status: response.status,
            headers: response.headers,
            body: decryptedData
        )
    }
}

let client = NetworkClient(
    session: .shared,
    requestMiddlewares: [EncryptionMiddleware(key: encryptionKey)],
    responseMiddlewares: [EncryptionMiddleware(key: encryptionKey)],
    errorMiddlewares: []
)
```

### Sensitive Data Handling

Protect sensitive data in logs and caches:

```swift
EnableLogging(LoggingMiddleware.Configuration(
    level: .basic,
    includeHeaders: true,
    includeBody: false, // Never log request/response bodies
    redactedHeaders: [
        "Authorization",
        "X-API-Key",
        "X-Auth-Token",
        "Cookie",
        "Set-Cookie"
    ]
))

Caching {
    CacheWhen { request, response in
        // Never cache responses containing sensitive data
        let sensitiveHeaders = ["Authorization", "X-API-Key"]
        let hasSensitiveHeaders = request.headers.keys.contains { key in
            sensitiveHeaders.contains(key)
        }
        
        return !hasSensitiveHeaders && 
               !request.url.path.contains("/auth/") &&
               !request.url.path.contains("/sensitive/")
    }
}
```

## Security Monitoring

### Security Event Logging

Monitor security events:

```swift
struct SecurityMonitoringMiddleware: HTTPErrorMiddleware {
    func handleError(
        _ error: HTTPError,
        for request: HTTPRequest
    ) async throws -> HTTPResponse {
        // Log security-relevant errors
        if isSecurityError(error) {
            await SecurityLogger.logSecurityEvent(
                type: .networkSecurityFailure,
                error: error,
                request: request,
                timestamp: Date(),
                additionalContext: [
                    "user_agent": request.headers["User-Agent"],
                    "ip_address": request.clientIPAddress
                ]
            )
        }
        
        throw error
    }
    
    private func isSecurityError(_ error: HTTPError) -> Bool {
        switch error.category {
        case .network(.sslError):
            return true
        case .http(let status) where status == .unauthorized || status == .forbidden:
            return true
        case .configuration:
            return true
        default:
            return false
        }
    }
}
```

### Certificate Transparency Monitoring

Monitor certificate changes:

```swift
struct CTMonitoringMiddleware: HTTPResponseMiddleware {
    func processResponse(
        _ response: HTTPResponse,
        for request: HTTPRequest
    ) async throws -> HTTPResponse {
        // Check certificate transparency logs
        if let serverTrust = response.serverTrust {
            await CertificateTransparencyService.verify(
                serverTrust,
                for: request.url.host!
            )
        }
        
        return response
    }
}
```

## Security Best Practices

### Production Configuration

Recommended security configuration for production:

```swift
let productionClient = NetworkClient {
    BaseURL("https://api.example.com")
    
    // Strong authentication
    Authentication {
        BearerToken(secureTokenProvider)
        AuthRefreshStrategy(.automatic)
    }
    
    // Comprehensive security
    EnableSecurity {
        SSLPinning(.certificates(productionCertificates))
        SecurityHeaders(.strict)
        CertificateValidation(.enhanced)
        TLSMinimumVersion(.v1_2)
        RequireSSL(true)
    }
    
    // Secure session configuration
    Session {
        UseEphemeralSession(false) // Use persistent for performance
        RequireSecureConnection(true)
        ConnectionTimeout(10.0)
        AllowRedirects(false)
    }
    
    // Minimal logging in production
    EnableLogging(LoggingMiddleware.Configuration(
        level: .error,
        includeHeaders: false,
        includeBody: false,
        redactedHeaders: ["Authorization", "X-API-Key"]
    ))
}
```

### Development vs Production

Use conditional compilation for security settings:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    
    EnableSecurity {
        #if DEBUG
        AllowInsecureConnections(true)
        SkipPinningForDebug(true)
        SecurityHeaders(.basic)
        #else
        AllowInsecureConnections(false)
        SSLPinning(.certificates(certificates))
        SecurityHeaders(.strict)
        #endif
    }
}
```

## Related Topics

- <doc:Authentication>: Authentication and credential management
- <doc:Client-Configuration>: Complete client configuration guide
- <doc:Error-Handling>: Security error handling strategies