# Conditional Requests

Build dynamic HTTP requests that adapt to runtime conditions using conditional components and control flow.

## Overview

Conditional request building allows you to construct HTTP requests that change based on runtime conditions, user state, feature flags, or other dynamic factors. This enables you to write flexible, maintainable request code that adapts to different scenarios without duplicating logic.

The conditional request system supports:
- **If/Else Logic**: Standard Swift control flow within request builders
- **Conditional Components**: Helper components for common conditional patterns
- **Switch Statements**: Multiple condition handling
- **Optional Components**: Apply components only when values are available
- **Feature Flags**: Enable/disable request features dynamically

## Basic Conditional Logic

### If Statements

Use standard Swift if statements within request builders:

```swift
let includeAuth = user.isLoggedIn
let includePremiumFeatures = user.isPremium

let request = HTTPRequest {
    GET("/api/profile")
    
    // Conditional authentication
    if includeAuth {
        BearerAuth(user.token)
        Header("X-User-ID", user.id)
    }
    
    // Conditional premium features
    if includePremiumFeatures {
        QueryParam("include", "premium-features")
        Header("X-Plan", "premium")
    }
}
```

### If-Else Logic

Handle mutually exclusive conditions:

```swift
let request = HTTPRequest {
    GET("/api/data")
    
    // Authentication method based on user type
    if user.isServiceAccount {
        APIKey("X-Service-Key", user.serviceKey)
    } else if user.isLoggedIn {
        BearerAuth(user.token)
    } else {
        // Anonymous access
        Header("X-Anonymous", "true")
    }
    
    // Content type preference
    if userPreferences.prefersJSON {
        AcceptHeader(.json)
    } else {
        AcceptHeader(.xml)
    }
}
```

### Switch Statements

Handle multiple conditions elegantly:

```swift
enum UserRole {
    case admin, moderator, user, guest
}

let request = HTTPRequest {
    GET("/api/content")
    
    switch user.role {
    case .admin:
        Header("X-Admin-Access", "full")
        QueryParam("include_all", "true")
        
    case .moderator:
        Header("X-Moderator-Access", "limited")
        QueryParam("include_moderated", "true")
        
    case .user:
        Header("X-User-Access", "standard")
        
    case .guest:
        Header("X-Guest-Access", "public")
        QueryParam("public_only", "true")
    }
}
```

## Conditional Components

### ConditionalComponent Helper

The ConditionalComponent allows you to conditionally include request components:

```swift
struct ConditionalComponent<Content: RequestComponent>: RequestComponent {
    let condition: Bool
    let content: () -> Content
    
    init(_ condition: Bool, @RequestBuilder content: @escaping () -> Content) {
        self.condition = condition
        self.content = content
    }
    
    func build(into request: inout HTTPRequest) throws {
        if condition {
            try content().build(into: &request)
        }
    }
}
```

Use the built-in conditional component for cleaner code:

```swift
let request = HTTPRequest {
    GET("/api/data")
    
    ConditionalComponent(user.isLoggedIn) {
        BearerAuth(user.token)
        Header("X-User-ID", user.id)
    }
    
    ConditionalComponent(!searchTerm.isEmpty) {
        QueryParam("search", searchTerm)
        QueryParam("highlight", "true")
    }
    
    ConditionalComponent(includeMetadata) {
        QueryParam("include_metadata", "true")
        Header("X-Metadata-Level", "full")
    }
}
```

### Custom Conditional Components

Create reusable conditional logic:

```swift
// Authentication conditional component
struct AuthenticationComponent: RequestComponent {
    let user: User?
    
    func apply(to request: inout HTTPRequest) throws {
        guard let user = user else { return }
        
        if user.isServiceAccount {
            request.headers["X-Service-Key"] = user.serviceKey
        } else if let token = user.accessToken {
            request.headers["Authorization"] = "Bearer \(token)"
        }
        
        request.headers["X-User-ID"] = user.id
    }
}

// Feature flag conditional component
struct FeatureFlagComponent: RequestComponent {
    let flagName: String
    let components: [RequestComponent]
    
    init(_ flagName: String, @RequestBuilder components: () -> [RequestComponent]) {
        self.flagName = flagName
        self.components = components()
    }
    
    func apply(to request: inout HTTPRequest) throws {
        guard FeatureFlags.isEnabled(flagName) else { return }
        
        for component in components {
            try component.apply(to: &request)
        }
    }
}

// Usage
let request = HTTPRequest {
    GET("/api/data")
    AuthenticationComponent(user: currentUser)
    
    FeatureFlagComponent("new-api-features") {
        Header("X-API-Version", "v2")
        QueryParam("use_new_format", "true")
    }
}
```

## Optional Value Handling

### Optional Unwrapping

Handle optional values gracefully:

```swift
let request = HTTPRequest {
    GET("/api/search")
    
    // Optional search parameters
    if let query = searchQuery {
        QueryParam("q", query)
    }
    
    if let location = userLocation {
        QueryParam("lat", "\(location.latitude)")
        QueryParam("lng", "\(location.longitude)")
    }
    
    if let radius = searchRadius {
        QueryParam("radius", "\(radius)")
    }
}
```

### Nil Coalescing

Use default values for optional parameters:

```swift
let request = HTTPRequest {
    GET("/api/data")
    
    QueryParam("page", "\(page ?? 1)")
    QueryParam("limit", "\(limit ?? 25)")
    QueryParam("sort", sortField ?? "created_at")
    QueryParam("order", sortOrder ?? "desc")
    
    // Optional authentication with fallback
    if let token = userToken ?? appToken {
        BearerAuth(token)
    }
}
```

### Compact Map Patterns

Apply multiple optional components:

```swift
struct OptionalQueryParam: RequestComponent {
    let name: String
    let value: String?
    
    func apply(to request: inout HTTPRequest) throws {
        if let value = value {
            // Apply query parameter logic
            var components = URLComponents(url: request.url, resolvingAgainstBaseURL: false)
            var queryItems = components?.queryItems ?? []
            queryItems.append(URLQueryItem(name: name, value: value))
            components?.queryItems = queryItems
            
            if let newURL = components?.url {
                request = HTTPRequest(
                    method: request.method,
                    url: newURL,
                    headers: request.headers,
                    body: request.body,
                    timeout: request.timeout
                )
            }
        }
    }
}

// Usage with multiple optional parameters
let request = HTTPRequest {
    GET("/api/search")
    
    OptionalQueryParam("category", category)
    OptionalQueryParam("tag", selectedTag)
    OptionalQueryParam("author", authorId)
    OptionalQueryParam("since", sinceDate?.iso8601String)
}
```

## Advanced Conditional Patterns

### Environment-Based Configuration

Adapt requests based on environment:

```swift
enum Environment {
    case development, staging, production
    
    static var current: Environment {
        // Determine environment
        return .development
    }
}

let request = HTTPRequest {
    GET("/api/data")
    
    switch Environment.current {
    case .development:
        Header("X-Debug", "true")
        Header("X-Environment", "dev")
        RequestTimeout(60.0) // Longer timeout for debugging
        
    case .staging:
        Header("X-Environment", "staging")
        Header("X-Test-Mode", "true")
        
    case .production:
        Header("X-Environment", "prod")
        // Production-specific headers
    }
}
```

### Platform-Specific Components

Handle platform differences:

```swift
let request = HTTPRequest {
    POST("/api/analytics")
    JSONBody(analyticsData)
    
    #if os(iOS)
    Header("X-Platform", "iOS")
    Header("X-Device-Type", UIDevice.current.userInterfaceIdiom.description)
    #elseif os(macOS)
    Header("X-Platform", "macOS")
    Header("X-App-Kit-Version", NSAppKitVersion.current.rawValue.description)
    #elseif os(watchOS)
    Header("X-Platform", "watchOS")
    Header("X-Watch-Model", WKInterfaceDevice.current().model)
    #elseif os(tvOS)
    Header("X-Platform", "tvOS")
    #endif
    
    // App version based on platform
    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
        Header("X-App-Version", version)
    }
}
```

### Feature Flag Integration

Integrate with feature flag systems:

```swift
// Feature flag service
class FeatureFlags {
    static func isEnabled(_ flag: String) -> Bool {
        // Feature flag implementation
        return UserDefaults.standard.bool(forKey: "feature_\(flag)")
    }
    
    static func getValue<T>(_ flag: String) -> T? {
        return UserDefaults.standard.object(forKey: "feature_\(flag)") as? T
    }
}

// Feature flag components
struct FeatureAwareRequest: RequestComponent {
    func apply(to request: inout HTTPRequest) throws {
        // Beta API features
        if FeatureFlags.isEnabled("beta_api") {
            request.headers["X-Beta-API"] = "true"
            request.headers["X-API-Version"] = "beta"
        }
        
        // Enhanced analytics
        if FeatureFlags.isEnabled("enhanced_analytics") {
            request.headers["X-Analytics-Level"] = "detailed"
        }
        
        // Custom timeout
        if let customTimeout: Double = FeatureFlags.getValue("api_timeout") {
            request.timeout = customTimeout
        }
    }
}
```

### User Preference Adaptation

Adapt requests based on user preferences:

```swift
struct UserPreferences {
    let language: String
    let timezone: String
    let dataUsageMode: DataUsageMode
    let accessibilityNeeds: AccessibilityNeeds
}

enum DataUsageMode {
    case unrestricted, reduced, minimal
}

struct PreferenceAwareComponent: RequestComponent {
    let preferences: UserPreferences
    
    func apply(to request: inout HTTPRequest) throws {
        // Localization
        request.headers["Accept-Language"] = preferences.language
        request.headers["X-Timezone"] = preferences.timezone
        
        // Data usage optimization
        switch preferences.dataUsageMode {
        case .unrestricted:
            request.headers["X-Quality"] = "high"
            request.headers["X-Include-Images"] = "true"
            
        case .reduced:
            request.headers["X-Quality"] = "medium"
            request.headers["X-Compress"] = "true"
            
        case .minimal:
            request.headers["X-Quality"] = "low"
            request.headers["X-Text-Only"] = "true"
        }
        
        // Accessibility
        if preferences.accessibilityNeeds.needsHighContrast {
            request.headers["X-High-Contrast"] = "true"
        }
    }
}
```

## Conditional Body Content

### Dynamic Body Selection

Choose different body content based on conditions:

```swift
struct User: Codable {
    let id: String
    let name: String
    let email: String
    let profileImage: Data?
}

let request = HTTPRequest {
    POST("/api/users")
    
    // Choose serialization format based on data size
    if let imageData = user.profileImage, imageData.count > 1_000_000 {
        // Use multipart for large images
        MultipartBody {
            TextPart("user", JSONEncoder().encode(user))
            DataPart("image", imageData, mimeType: "image/jpeg")
        }
    } else {
        // Use JSON for smaller payloads
        JSONBody(user)
        ContentType(.json)
    }
}
```

### Conditional Encoding

Handle different encoding requirements:

```swift
let request = HTTPRequest {
    PUT("/api/data")
    
    if clientSupportsCompression {
        // Compressed JSON
        let compressedData = try JSONEncoder().encode(data).compressed()
        DataBody(compressedData)
        Header("Content-Encoding", "gzip")
        ContentType(.json)
    } else {
        // Standard JSON
        JSONBody(data)
    }
    
    if requiresEncryption {
        Header("X-Encrypted", "true")
    }
}
```

## Error Handling in Conditional Requests

### Conditional Validation

Add validation based on request configuration:

```swift
struct ConditionalValidation: RequestComponent {
    let strictMode: Bool
    
    func apply(to request: inout HTTPRequest) throws {
        if strictMode {
            // Strict validation
            guard !request.headers.isEmpty else {
                throw RequestError.validationFailed("Headers required in strict mode")
            }
            
            guard request.headers["Authorization"] != nil else {
                throw RequestError.validationFailed("Authentication required in strict mode")
            }
        }
        
        // Always validate URL
        guard request.url.scheme != nil else {
            throw RequestError.invalidURL("URL scheme is required")
        }
    }
}
```

### Fallback Strategies

Implement fallback mechanisms:

```swift
struct FallbackAuthentication: RequestComponent {
    let primaryToken: String?
    let fallbackToken: String?
    let allowAnonymous: Bool
    
    func apply(to request: inout HTTPRequest) throws {
        if let primary = primaryToken {
            request.headers["Authorization"] = "Bearer \(primary)"
        } else if let fallback = fallbackToken {
            request.headers["Authorization"] = "Bearer \(fallback)"
            request.headers["X-Fallback-Auth"] = "true"
        } else if allowAnonymous {
            request.headers["X-Anonymous"] = "true"
        } else {
            throw RequestError.authenticationRequired("No valid authentication available")
        }
    }
}
```

## Testing Conditional Requests

### Test Different Conditions

Create tests for various conditional paths:

```swift
func testConditionalAuthentication() async throws {
    // Test with logged-in user
    let authenticatedRequest = HTTPRequest {
        GET("/api/data")
        ConditionalComponent(true) { // user.isLoggedIn
            BearerAuth("test-token")
        }
    }
    
    XCTAssertEqual(authenticatedRequest.headers["Authorization"], "Bearer test-token")
    
    // Test with anonymous user
    let anonymousRequest = HTTPRequest {
        GET("/api/data")
        ConditionalComponent(false) { // user.isLoggedIn
            BearerAuth("test-token")
        }
    }
    
    XCTAssertNil(anonymousRequest.headers["Authorization"])
}

func testEnvironmentConfiguration() throws {
    // Mock different environments
    let environments = [Environment.development, .staging, .production]
    
    for env in environments {
        let request = HTTPRequest {
            GET("/api/test")
            
            switch env {
            case .development:
                Header("X-Debug", "true")
            case .staging:
                Header("X-Test", "true")
            case .production:
                Header("X-Production", "true")
            }
        }
        
        // Verify appropriate headers are set
        switch env {
        case .development:
            XCTAssertEqual(request.headers["X-Debug"], "true")
        case .staging:
            XCTAssertEqual(request.headers["X-Test"], "true")
        case .production:
            XCTAssertEqual(request.headers["X-Production"], "true")
        }
    }
}
```

## Best Practices

### Conditional Request Guidelines

**Readability:**
- Keep conditional logic simple and clear
- Use descriptive variable names for conditions
- Group related conditional components together

**Performance:**
- Avoid expensive condition evaluation in request building
- Cache computed conditions when possible
- Use early returns in conditional components

**Maintainability:**
- Extract complex conditional logic into custom components
- Use enums instead of magic strings for conditions
- Document complex conditional behavior

**Testing:**
- Test all conditional paths
- Mock external dependencies (feature flags, user state)
- Verify both positive and negative conditions

## See Also

- ``RequestBuilder``
- ``RequestComponent``
- ``HTTPRequest``
- <doc:RequestBuilding>
- <doc:RequestComponents>
- <doc:HTTPMethods>