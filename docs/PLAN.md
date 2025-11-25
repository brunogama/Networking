# Plan: Create Sample App Using ModernNetworking Macros

## Overview

Create a sample macOS application demonstrating the ModernNetworking library's macro-based API declaration system using `@API`, `@GET`, `@POST`, `@Path`, `@Query`, `@Header`, and `@Body` macros.

## Pre-Implementation Fixes Required

Before the sample app can work, the macro-generated code has gaps that need to be addressed:

### Issue 1: Missing `BaseURL` RequestComponent

The APIMacro generates:
```swift
let request = try HTTPRequest {
    BaseURL(baseURL)  // <-- This doesn't exist!
    GET("/path")
    ...
}
```

**Solution:** Add a `BaseURL` RequestComponent to `RequestBuilder.swift`:
```swift
public struct BaseURL: RequestComponent {
    private let urlString: String

    public init(_ urlString: String) {
        self.urlString = urlString
    }

    public func apply(to request: inout RequestBuilder.PartialRequest) throws {
        guard let url = URL(string: urlString) else {
            throw HTTPError(category: .configuration("Invalid base URL: \(urlString)"))
        }
        request.url = url
    }
}
```

### Issue 2: `QueryParam` Only Accepts Strings

The macro generates `QueryParam("name", intValue)` but `QueryParam` only accepts `String` values.

**Solution:** Add generic initializers to `QueryParam`:
```swift
public init<T: CustomStringConvertible>(_ name: String, _ value: T) {
    self.name = name
    self.value = String(describing: value)
}
```

### Issue 3: HTTP Method Components Use `appendingPathComponent`

The current GET/POST/etc components use `appendingPathComponent(path)` which doesn't handle paths starting with `/` correctly when combined with a base URL.

**Solution:** Update HTTP method components to handle full paths properly.

---

## Implementation Steps

### Step 1: Fix Missing RequestComponents

**Files to modify:**
- `Sources/Networking/RequestBuilder.swift` - Add `BaseURL` component
- `Sources/Networking/BodyComponents.swift` - Add generic `QueryParam` initializers

### Step 2: Update APIMacro Code Generation (if needed)

**File:** `Sources/NetworkingMacros/APIMacro.swift`

Verify the generated code pattern works with the fixed components.

### Step 3: Create Example Directory Structure

```
Examples/
└── MacroSampleApp/
    ├── Package.swift
    └── Sources/
        └── MacroSampleApp/
            ├── main.swift
            ├── API/
            │   ├── GitHubAPI.swift
            │   └── JSONPlaceholderAPI.swift
            └── Models/
                ├── User.swift
                ├── Repository.swift
                ├── Post.swift
                └── SearchResult.swift
```

### Step 4: Create Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacroSampleApp",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../../")
    ],
    targets: [
        .executableTarget(
            name: "MacroSampleApp",
            dependencies: [
                .product(name: "Networking", package: "ModernNetworking")
            ]
        )
    ]
)
```

### Step 5: Create Domain Models

**User.swift:**
```swift
struct User: Codable, Sendable {
    let id: Int
    let login: String
    let avatarUrl: String
    let name: String?

    enum CodingKeys: String, CodingKey {
        case id, login, name
        case avatarUrl = "avatar_url"
    }
}
```

**Repository.swift:**
```swift
struct Repository: Codable, Sendable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let stargazersCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case fullName = "full_name"
        case stargazersCount = "stargazers_count"
    }
}
```

**Post.swift:**
```swift
struct Post: Codable, Sendable {
    let id: Int?
    let userId: Int
    let title: String
    let body: String

    enum CodingKeys: String, CodingKey {
        case id, title, body
        case userId = "user_id"
    }
}
```

**SearchResult.swift:**
```swift
struct SearchResult<T: Codable & Sendable>: Codable, Sendable {
    let totalCount: Int
    let incompleteResults: Bool
    let items: [T]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case incompleteResults = "incomplete_results"
        case items
    }
}
```

### Step 6: Create GitHubAPI Protocol

```swift
import Networking

@API(baseURL: "https://api.github.com")
protocol GitHubAPI {
    @GET("/users/{username}")
    func getUser(@Path username: String) async throws -> User

    @GET("/search/repositories")
    func searchRepositories(
        @Query("q") searchQuery: String,
        @Query("per_page") perPage: Int,
        @Query page: Int
    ) async throws -> SearchResult<Repository>

    @GET("/repos/{owner}/{repo}")
    func getRepository(
        @Path owner: String,
        @Path repo: String
    ) async throws -> Repository
}
```

### Step 7: Create JSONPlaceholderAPI Protocol

```swift
import Networking

@API(baseURL: "https://jsonplaceholder.typicode.com")
protocol JSONPlaceholderAPI {
    @GET("/posts")
    func getPosts() async throws -> [Post]

    @GET("/posts/{id}")
    func getPost(@Path id: Int) async throws -> Post

    @POST("/posts")
    func createPost(@Body post: Post) async throws -> Post
}
```

### Step 8: Create main.swift

```swift
import Foundation
import Networking

@main
struct MacroSampleApp {
    static func main() async {
        let github = GitHubAPI.Implementation()
        let jsonPlaceholder = JSONPlaceholderAPI.Implementation()

        do {
            print("=== GitHub API Demo ===\n")
            let user = try await github.getUser(username: "apple")
            print("User: \(user.login)")

            print("\n=== JSONPlaceholder API Demo ===\n")
            let posts = try await jsonPlaceholder.getPosts()
            print("Total posts: \(posts.count)")
        } catch {
            print("Error: \(error)")
        }
    }
}
```

### Step 9: Build and Test

```bash
cd Examples/MacroSampleApp && swift build
cd Examples/MacroSampleApp && swift run
```

---

## Verification Checklist

- [ ] `BaseURL` RequestComponent added and working
- [ ] `QueryParam` accepts non-String types
- [ ] HTTP method components handle full paths correctly
- [ ] Package.swift references parent package correctly
- [ ] Models conform to `Codable` and `Sendable`
- [ ] API protocols compile with macro expansion
- [ ] `swift build` succeeds without errors
- [ ] `swift run` produces expected API response output

---

## Key Notes

1. **Macro generates `{ProtocolName}Implementation` struct** - NOT `{ProtocolName}Impl`
2. **Custom parameter names** use `@Query("api_name")` or `@Path("api_name")`
3. **Path substitution** uses `{paramName}` syntax matched to `@Path` parameters
4. **Generated methods** are `async throws` - wrap in do-catch
