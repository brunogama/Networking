# ModernNetworking - Quick Start Guide

Get up and running with ModernNetworking in minutes.

---

## Prerequisites

- **macOS 13.0+**
- **Xcode 16.0+** (includes Swift 6.2.1+)
- **Git 2.x+**

---

## 1. Clone and Setup

```bash
# Clone repository
git clone https://github.com/brunogama/Networking.git ModernNetworking
cd ModernNetworking

# Checkout development branch
git checkout dev

# Resolve dependencies
swift package resolve
```

---

## 2. Build

```bash
# Clean build
rm -rf .build/

# Build all targets
swift build

# Verify build succeeds
echo "Build successful!"
```

---

## 3. Run Tests

```bash
# Run all tests
swift test

# Expected output: All tests should pass
# ✓ Test Suite 'All tests' passed
```

---

## 4. Open in Xcode

```bash
# Open package in Xcode
xed .

# Or generate Xcode project (optional)
swift package generate-xcodeproj
open Networking.xcodeproj
```

---

## 5. Try the Playground

```bash
# Navigate to playground
cd Samples/Arena-Playground

# Open in Xcode
open Content.playground
```

---

## 6. Quick Test

Create a test file to verify the framework works:

```swift
import Networking

// Create a client
let client = NetworkClient {
    BaseURL("https://api.github.com")
    EnableLogging()
    DefaultHeader("User-Agent", "ModernNetworking/1.0")
}

// Make a request
Task {
    do {
        let response = try await client.execute {
            GET("/users/brunogama")
            Timeout(15.0)
        }
        print("✅ Success! Status: \(response.statusCode)")
    } catch {
        print("❌ Error: \(error)")
    }
}
```

---

## 7. Using Interceptors

ModernNetworking includes a powerful interceptor system for cross-cutting concerns:

### Basic Interceptor Usage

```swift
import Networking

// Create interceptors
let auth = AuthenticationInterceptor {
    return try await getAccessToken()
}
let retry = RetryInterceptor(maxAttempts: 3)
let cache = CachingInterceptor(ttl: 300)

// Chain interceptors (order matters!)
let chain = InterceptorChain(
    requestInterceptors: [auth, rateLimit],
    responseInterceptors: [cache, retry]
)
```

### Common Interceptors

**Authentication** - Add auth headers:
```swift
// Dynamic token
let auth = AuthenticationInterceptor {
    return try await tokenProvider.getToken()
}

// Static token (for testing)
let auth = AuthenticationInterceptor.bearer("your-token")
```

**Retry** - Automatic retry with exponential backoff:
```swift
let retry = RetryInterceptor(maxAttempts: 3, baseDelay: 0.5)
```

**Caching** - Response caching:
```swift
let cache = CachingInterceptor(ttl: 300, maxEntries: 100)
```

**Rate Limiting** - Prevent API abuse:
```swift
let rateLimit = RateLimitInterceptor.lenient  // 100 req/min
// Or custom:
let custom = RateLimitInterceptor(
    requestsPerWindow: 50,
    windowDuration: 60.0,
    strategy: .delay
)
```

**Logging** - Request/response logging:
```swift
let logging = LoggingInterceptor(level: .basic) { message in
    print(message)
}
```

**Token Refresh** - Automatic token refresh on 401:
```swift
let tokenRefresh = TokenRefreshInterceptor(
    refreshHandler: { refreshToken in
        return try await refreshAccessToken(refreshToken)
    },
    tokenUpdateHandler: { accessToken, refreshToken in
        await tokenStore.save(accessToken, refreshToken)
    }
)
```

### Full Example

```swift
// Create complete interceptor chain
let auth = AuthenticationInterceptor.bearer("token")
let retry = RetryInterceptor(maxAttempts: 3)
let cache = CachingInterceptor(ttl: 300)
let rateLimit = RateLimitInterceptor.lenient
let logging = LoggingInterceptor(level: .basic) { print($0) }

let chain = InterceptorChain(
    requestInterceptors: [logging, auth, rateLimit],
    responseInterceptors: [logging, cache, retry]
)

// Use with your requests
var request = HTTPRequest(method: .get, path: "/api/data", baseURL: baseURL)
let context = InterceptorContext(path: "/api/data", method: .get)

let requestResult = try await chain.executeRequestInterceptors(
    request: &request,
    context: context
)

// Execute network call...
let response = try await execute(request)

let responseResult = try await chain.executeResponseInterceptors(
    response: response,
    context: context
)
```

---

## 8. Optional Development Tools

```bash
# Install pre-commit hooks
brew install pre-commit
pre-commit install

# Install formatting and linting tools
brew install swift-format swiftlint
```

---

## 9. Common Commands

### Build
```bash
swift build                                    # Build framework
swift build -c release                         # Release build
swift build -Xswiftc -warnings-as-errors      # Build with warnings as errors
```

### Test
```bash
swift test                                     # Run all tests
swift test -v                                  # Verbose output
swift test --filter NetworkingTests           # Run specific test target
```

### Format and Lint
```bash
swift-format -i -r Sources/ Tests/            # Format code
swiftlint --fix --config .swiftlint.yml       # Lint with auto-fix
```

### Clean
```bash
rm -rf .build/                                # Clean build artifacts
swift package clean                            # Clean package
```

---

## 10. Quick Reference

### Project Structure
```
ModernNetworking/
├── Sources/Networking/          # Framework source
├── Sources/NetworkingMacros/    # Macro implementations
├── Tests/NetworkingTests/       # Test suite
├── Samples/Arena-Playground/    # Interactive examples
└── Package.swift                # Package manifest
```

### Key Files
- `Sources/Networking/NetworkClient.swift` - Main client implementation
- `Sources/Networking/RequestBuilder.swift` - Fluent DSL
- `Sources/NetworkingMacros/Plugin.swift` - Macro plugin
- `Package.swift` - Dependencies and targets

### Documentation
- `README.md` - Project overview
- `ONBOARDING.md` - Comprehensive onboarding guide
- `CHANGELOG.md` - Version history
- `Documentation.docc/` - DocC documentation

---

## 11. Troubleshooting

### Swift Version Error
```bash
# Error: "package requires minimum Swift version 6.0"
# Solution: Update Xcode to 16.0+
xcode-select --install
```

### Build Fails
```bash
# Clean and rebuild
rm -rf .build/
swift build
```

### Tests Fail
```bash
# Run with verbose output to see details
swift test -v
```

---

## 12. Next Steps

1. **Read** `ONBOARDING.md` for comprehensive documentation
2. **Explore** `Samples/Arena-Playground/` for examples
3. **Review** `docs/project-overview.md` for architecture details
4. **Check** open issues on GitHub for contribution opportunities

---

## 13. Support

- **Documentation**: See `ONBOARDING.md`
- **Issues**: https://github.com/brunogama/Networking/issues
- **Maintainer**: Bruno Gama (@brunogama)

---

**You're ready to go! 🚀**
