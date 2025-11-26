# Proposal: Attached Macros with Result Builder for Headers and Body

## Why

Currently, the API macro system uses string-based parameters in macro attributes to specify request body and headers:

```swift
@POST("/users", body: "user", headers: ["X-API-Key": "key123"])
func createUser(user: CreateUserRequest, apiKey: String) async throws -> User
```

This approach has several limitations:
1. **Verbosity**: Headers as dictionary literals in macro arguments is verbose
2. **Readability**: All configuration cramped into one line
3. **Discoverability**: Not clear which parameters are headers vs body vs path
4. **Type safety**: String parameter names prone to typos
5. **Flexibility**: Can't easily compose or reuse header configurations

A result builder-based approach with attached macros (`@Body`, `@Headers`) would provide:
- Clear visual separation of concerns
- Type-safe parameter references
- Familiar Swift syntax (like SwiftUI)
- Better IDE autocomplete and error messages

## What Changes

Add two new attached macros that use result builder syntax:

1. **@Body(parameterName)**: Marks which function parameter is the request body
2. **@Headers { ... }**: Result builder for defining custom headers with parameter references

### New API Style

```swift
@API(baseURL: "https://api.github.com")
protocol GitHubAPI {
    // Simple GET - no body or custom headers
    @GET("/users/{username}")
    func getUser(username: String) async throws -> User

    // POST with body
    @POST("/repos/{owner}/{repo}/issues")
    @Body("issue")
    func createIssue(
        owner: String,
        repo: String,
        issue: CreateIssueRequest
    ) async throws -> Issue

    // GET with custom headers
    @GET("/user")
    @Headers {
        Header("Authorization", "token")
        Header("X-GitHub-Api-Version", "apiVersion")
    }
    func getCurrentUser(
        token: String,
        apiVersion: String
    ) async throws -> User

    // POST with body and headers
    @POST("/orgs/{org}/repos")
    @Body("repo")
    @Headers {
        Header("Accept", "accept")
        Header("X-GitHub-Api-Version", "2022-11-28")  // Literal value
    }
    func createRepo(
        org: String,
        repo: CreateRepoRequest,
        accept: String
    ) async throws -> Repository

    // Headers with default values
    @POST("/users")
    @Body("user")
    @Headers {
        Header("Content-Type", "application/json")  // Literal
        Header("X-Request-ID", "requestId")  // From parameter
    }
    func createUser(
        user: CreateUserRequest,
        requestId: String = UUID().uuidString
    ) async throws -> User
}
```

### Result Builder Implementation

```swift
// Result builder for headers
@resultBuilder
public struct HeaderBuilder {
    public static func buildBlock(_ components: HeaderComponent...) -> [HeaderComponent] {
        components
    }
}

// Header component type
public struct HeaderComponent {
    let name: String
    let valueSource: ValueSource

    enum ValueSource {
        case parameter(String)  // Reference to function parameter
        case literal(String)     // Literal string value
    }
}

// DSL function for headers
public func Header(_ name: String, _ value: String) -> HeaderComponent {
    HeaderComponent(name: name, valueSource: .parameter(value))
}
```

### Macro Declarations

```swift
/// Marks which function parameter contains the request body.
///
/// Usage:
/// ```swift
/// @POST("/users")
/// @Body("user")
/// func createUser(user: CreateUserRequest) async throws -> User
/// ```
@attached(peer)
public macro Body(_ parameterName: String) = #externalMacro(
    module: "NetworkingMacros",
    type: "BodyMacro"
)

/// Defines custom HTTP headers using result builder syntax.
///
/// Usage:
/// ```swift
/// @GET("/user")
/// @Headers {
///     Header("Authorization", "token")
///     Header("Accept", "application/json")
/// }
/// func getUser(token: String) async throws -> User
/// ```
@attached(peer)
public macro Headers(
    @HeaderBuilder _ headers: () -> [HeaderComponent]
) = #externalMacro(
    module: "NetworkingMacros",
    type: "HeadersMacro"
)
```

### How It Works

1. **@Body("paramName")** macro:
   - Validates parameter exists in function signature
   - Validates parameter type conforms to Encodable
   - Passes parameter name to HTTP method macro

2. **@Headers { ... }** macro:
   - Parses result builder closure
   - Extracts header names and value sources
   - Validates referenced parameters exist
   - Passes header configuration to HTTP method macro

3. **HTTP method macros** (GET, POST, etc.):
   - Check for `@Body` and `@Headers` attributes on same function
   - Generate code with headers and body from detected macros
   - Maintain backward compatibility with old syntax

### Generated Code Example

```swift
// Source:
@POST("/users")
@Body("user")
@Headers {
    Header("X-API-Key", "apiKey")
    Header("Content-Type", "application/json")
}
func createUser(user: User, apiKey: String) async throws -> User

// Generated:
func createUser(user: User, apiKey: String) async throws -> User {
    var request = HTTPRequest(method: .post, path: "/users", baseURL: baseURL)

    // From @Body
    request.setBody(try JSONEncoder().encode(user))

    // From @Headers
    request.addHeader(name: "X-API-Key", value: apiKey)
    request.addHeader(name: "Content-Type", value: "application/json")

    let response = try await client.execute(request)
    return try JSONDecoder().decode(User.self, from: response.data)
}
```

## Impact

### Affected Specs
- **networking-macros**: MODIFIED - Add @Body and @Headers attached macros

### Affected Code
- `Sources/Networking/Macros/` - Add `BodyMacro.swift`, `HeadersMacro.swift`, `HeaderBuilder.swift`
- `Sources/NetworkingMacros/` - Add `BodyMacro.swift`, `HeadersMacro.swift` implementations
- `Sources/NetworkingMacros/HTTP/` - Update all HTTP method macros to detect attached macros
- `Sources/NetworkingMacros/Shared/MacroHelpers.swift` - Add attached macro detection utilities
- `Tests/NetworkingTests/Macros/` - Add ~60 new tests

### Dependencies
- SwiftSyntax 600.0.0+ (already dependency)
- No new external dependencies

### Migration Path

**Backward Compatibility**: OLD syntax continues to work (deprecated)

```swift
// OLD (deprecated but works)
@POST("/users", body: "user", headers: ["X-API-Key": "key"])
func createUser(user: User, apiKey: String) async throws -> User

// NEW (recommended)
@POST("/users")
@Body("user")
@Headers {
    Header("X-API-Key", "apiKey")
}
func createUser(user: User, apiKey: String) async throws -> User
```

Migration steps:
1. Add deprecation warnings to old syntax
2. Provide migration guide
3. Remove old syntax in v2.0.0

### Performance Implications
- Compile-time: +1-2 seconds for macro expansion (result builder parsing)
- Runtime: Zero impact (generates identical code)

### Testing Requirements
- @Body macro tests (15 tests)
- @Headers macro tests (20 tests)
- HeaderBuilder tests (10 tests)
- Integration with HTTP method macros (20 tests)
- Backward compatibility tests (15 tests)
- Error handling tests (20 tests)
- Total: ~100 new tests

## Breaking Changes

**None** - This is additive functionality with deprecation path for old syntax.

## Design Decisions

### Why @attached(peer) not @attached(parameter)?

Swift macros don't support `@attached(parameter)` yet. Using `@attached(peer)` on the function with parameter name strings is the best available approach.

### Why Result Builder for Headers?

1. **Familiar**: Developers know this from SwiftUI
2. **Extensible**: Easy to add more header configurations
3. **Type-safe**: Compiler validates at macro expansion
4. **Readable**: Clear visual structure

### Literal vs Parameter Values

Headers can use either:
- **Literal**: `Header("Content-Type", "application/json")` - always this value
- **Parameter**: `Header("X-API-Key", "apiKey")` - value from function parameter

The macro determines this by:
1. Checking if second argument matches a function parameter name → parameter reference
2. Otherwise → literal value

### Alternative Considered: Reflection

Could use Swift's Mirror API at runtime to inspect parameters, but:
- ❌ Requires runtime overhead
- ❌ Loses compile-time safety
- ❌ Harder to debug

Result builder approach is purely compile-time.

## Open Questions

1. **Should we support computed headers?**
   ```swift
   @Headers {
       Header("X-Request-ID") { UUID().uuidString }
   }
   ```
   **Recommendation**: No, keep simple. Use parameter with default value instead.

2. **Should @Query use same builder pattern?**
   ```swift
   @Query {
       Param("q", "searchTerm")
       Param("limit", "10")
   }
   ```
   **Recommendation**: Yes, for consistency. Add in same change.

3. **Multiple @Body on same function?**
   **Recommendation**: Compile error - only one body allowed.

4. **@Headers without any Header() calls?**
   ```swift
   @Headers { }  // Empty
   ```
   **Recommendation**: Allow but warn - probably developer mistake.

5. **Can @Headers reference other @Headers?**
   ```swift
   let commonHeaders = Headers {
       Header("Accept", "application/json")
   }

   @Headers(commonHeaders)
   ```
   **Recommendation**: Not in v1 - too complex. Future enhancement.
