# HTTP Methods

Comprehensive HTTP method support with type-safe method definitions and custom method capabilities.

## Overview

The Networking framework provides complete support for HTTP methods through the ``HTTPMethod`` type and dedicated request components. This includes all standard HTTP methods as well as support for custom methods when needed.

The HTTP method system consists of:
- **HTTPMethod Type**: Type-safe representation of HTTP methods
- **Method Components**: Declarative components for each standard method
- **Custom Method Support**: Ability to use non-standard HTTP methods
- **Method Validation**: Runtime validation for method appropriateness

## HTTPMethod Type

### Standard Methods

The framework provides predefined constants for all standard HTTP methods:

```swift
/// Standard HTTP methods
public static let get = HTTPMethod("GET")
public static let post = HTTPMethod("POST") 
public static let put = HTTPMethod("PUT")
public static let delete = HTTPMethod("DELETE")
public static let patch = HTTPMethod("PATCH")
public static let head = HTTPMethod("HEAD")
public static let options = HTTPMethod("OPTIONS")
public static let trace = HTTPMethod("TRACE")
public static let connect = HTTPMethod("CONNECT")
```

### Method Properties

HTTPMethod provides useful properties for method classification:

```swift
let method = HTTPMethod.post

// Check method characteristics
if method.isIdempotent {
    print("Method is idempotent")
}

if method.isBodyAllowed {
    print("Method allows request body")
}

if method.isResponseBodyExpected {
    print("Method typically returns response body")
}
```

### Creating Custom Methods

Support for non-standard HTTP methods:

```swift
// Custom method for specific APIs
let customMethod = HTTPMethod("PATCH-MERGE")
let webdavMethod = HTTPMethod("PROPFIND")
let calDavMethod = HTTPMethod("REPORT")

let request = HTTPRequest(
    method: customMethod,
    url: URL(string: "https://api.example.com/custom")!
)
```

## Method Components

### GET Requests

Use GET for retrieving data without side effects:

```swift
// Simple GET request
let request = HTTPRequest {
    GET("/api/users")
}

// GET with query parameters
let request = HTTPRequest {
    GET("/api/search")
    QueryParam("q", "swift")
    QueryParam("limit", "10")
}

// GET with authentication
let request = HTTPRequest {
    GET("/api/protected")
    BearerAuth(token)
    Header("Accept", "application/json")
}
```

**When to use GET:**
- Retrieving data
- Search operations
- Resource listing
- Public endpoints
- Cacheable requests

### POST Requests

Use POST for creating new resources or operations with side effects:

```swift
// POST with JSON body
struct User: Codable {
    let name: String
    let email: String
}

let request = HTTPRequest {
    POST("/api/users")
    JSONBody(User(name: "John", email: "john@example.com"))
    ContentType(.json)
}

// POST with form data
let request = HTTPRequest {
    POST("/api/form")
    FormBody([
        "username": "john_doe",
        "password": "secure123",
        "remember": "true"
    ])
}

// POST with file upload
let request = HTTPRequest {
    POST("/api/upload")
    DataBody(fileData)
    ContentType(.octetStream)
    Header("Content-Length", "\(fileData.count)")
}
```

**When to use POST:**
- Creating new resources
- Form submissions
- File uploads
- Non-idempotent operations
- Operations with side effects

### PUT Requests

Use PUT for creating or completely replacing resources:

```swift
// PUT to update entire resource
let request = HTTPRequest {
    PUT("/api/users/123")
    JSONBody(updatedUser)
    ContentType(.json)
    Header("If-Match", etag)
}

// PUT to create resource with known ID
let request = HTTPRequest {
    PUT("/api/documents/new-doc-id")
    JSONBody(document)
    ContentType(.json)
}

// PUT with conditional headers
let request = HTTPRequest {
    PUT("/api/config")
    JSONBody(configuration)
    Header("If-None-Match", "*") // Only create, don't update
}
```

**When to use PUT:**
- Complete resource replacement
- Creating resources with known IDs
- Idempotent updates
- Configuration changes

### PATCH Requests

Use PATCH for partial resource updates:

```swift
// PATCH for partial update
struct UserUpdate: Codable {
    let name: String?
    let email: String?
}

let request = HTTPRequest {
    PATCH("/api/users/123")
    JSONBody(UserUpdate(name: "New Name", email: nil))
    ContentType(.json)
    Header("If-Match", etag)
}

// PATCH with JSON Patch format
let jsonPatch = [
    ["op": "replace", "path": "/name", "value": "New Name"],
    ["op": "remove", "path": "/temporary_field"]
]

let request = HTTPRequest {
    PATCH("/api/users/123")
    JSONBody(jsonPatch)
    ContentType("application/json-patch+json")
}
```

**When to use PATCH:**
- Partial resource updates
- Optimistic updates
- Bandwidth-efficient updates
- JSON Patch operations

### DELETE Requests

Use DELETE for removing resources:

```swift
// Simple DELETE
let request = HTTPRequest {
    DELETE("/api/users/123")
    BearerAuth(token)
}

// DELETE with confirmation
let request = HTTPRequest {
    DELETE("/api/users/123")
    Header("X-Confirm-Delete", "true")
    BearerAuth(token)
}

// Soft delete with body
let request = HTTPRequest {
    DELETE("/api/users/123")
    JSONBody(["reason": "User requested account deletion"])
    ContentType(.json)
}
```

**When to use DELETE:**
- Resource removal
- Cleanup operations
- Account deletion
- File removal

### HEAD Requests

Use HEAD for metadata without response body:

```swift
// Check if resource exists
let request = HTTPRequest {
    HEAD("/api/users/123")
}

// Get file metadata
let request = HTTPRequest {
    HEAD("/api/files/document.pdf")
}

// Check cache freshness
let request = HTTPRequest {
    HEAD("/api/data")
    Header("If-Modified-Since", lastModified)
}
```

**When to use HEAD:**
- Resource existence checks
- Metadata retrieval
- Cache validation
- Bandwidth conservation

### OPTIONS Requests

Use OPTIONS for capability discovery:

```swift
// CORS preflight
let request = HTTPRequest {
    OPTIONS("/api/users")
    Header("Access-Control-Request-Method", "POST")
    Header("Access-Control-Request-Headers", "Content-Type")
}

// API capability discovery
let request = HTTPRequest {
    OPTIONS("/api/endpoint")
}
```

**When to use OPTIONS:**
- CORS preflight requests
- API capability discovery
- Method validation

## Method Validation

### Automatic Validation

The framework provides automatic method validation:

```swift
// This will validate method appropriateness
let request = HTTPRequest {
    GET("/api/data")
    JSONBody(data) // Warning: GET typically shouldn't have body
}

// Framework validates method-body combinations
let request = HTTPRequest {
    HEAD("/api/resource")
    // Response body will be automatically ignored for HEAD
}
```

### Custom Validation

Implement custom method validation:

```swift
struct ValidatedMethod: RequestComponent {
    let method: HTTPMethod
    let allowedMethods: Set<HTTPMethod>
    
    init(_ method: HTTPMethod, allowedMethods: Set<HTTPMethod>) throws {
        guard allowedMethods.contains(method) else {
            throw RequestError.methodNotAllowed(method.rawValue)
        }
        self.method = method
    }
    
    func apply(to request: inout HTTPRequest) throws {
        // Apply validated method
    }
}

// Usage
let request = HTTPRequest {
    try ValidatedMethod(.post, allowedMethods: [.get, .post])
    Path("/api/endpoint")
}
```

## Advanced Method Usage

### Method Overrides

Handle servers that don't support all methods:

```swift
// Method override for limited servers
let request = HTTPRequest {
    POST("/api/users/123") // Actual transport method
    Header("X-HTTP-Method-Override", "PUT") // Intended method
    JSONBody(updatedUser)
}
```

### WebDAV Methods

Support for WebDAV extensions:

```swift
// WebDAV PROPFIND
let request = HTTPRequest {
    Method("PROPFIND")
    Path("/webdav/folder")
    XMLBody(propfindXML)
    ContentType("application/xml")
    Header("Depth", "1")
}

// WebDAV MKCOL
let request = HTTPRequest {
    Method("MKCOL")
    Path("/webdav/new-collection")
}
```

### CalDAV/CardDAV Methods

Support for calendar and contact protocols:

```swift
// CalDAV REPORT
let request = HTTPRequest {
    Method("REPORT")
    Path("/calendar/user/calendar")
    XMLBody(reportQuery)
    ContentType("application/xml")
    Header("Depth", "1")
}

// CardDAV PROPFIND
let request = HTTPRequest {
    Method("PROPFIND")
    Path("/contacts/user/addressbook")
    XMLBody(propfindXML)
    Header("Depth", "1")
}
```

## Method Guidelines

### HTTP Method Selection Guide

| Operation | Idempotent | Safe | Method | Body | Response Body |
|-----------|------------|------|--------|------|---------------|
| Retrieve data | ✅ | ✅ | GET | ❌ | ✅ |
| Create resource | ❌ | ❌ | POST | ✅ | ✅ |
| Replace resource | ✅ | ❌ | PUT | ✅ | ✅ |
| Update resource | ❌ | ❌ | PATCH | ✅ | ✅ |
| Delete resource | ✅ | ❌ | DELETE | Optional | Optional |
| Get metadata | ✅ | ✅ | HEAD | ❌ | ❌ |
| Check capabilities | ✅ | ✅ | OPTIONS | ❌ | ✅ |

### Best Practices

**Method Selection:**
- Use GET for data retrieval
- Use POST for creation and non-idempotent operations
- Use PUT for complete resource replacement
- Use PATCH for partial updates
- Use DELETE for resource removal
- Use HEAD for existence checks

**Security Considerations:**
- Never use GET for operations with side effects
- Be cautious with PUT/PATCH on publicly accessible endpoints
- Validate method permissions on the server
- Use appropriate authentication for destructive operations

**Performance Optimization:**
- Use HEAD to check resource existence before downloading
- Prefer PATCH over PUT for large resources
- Use conditional headers with PUT/PATCH
- Cache GET responses appropriately

## Error Handling

### Method-Specific Errors

Handle method-specific error scenarios:

```swift
do {
    let response = try await client.execute {
        PUT("/api/users/123")
        JSONBody(user)
    }
} catch let error as HTTPError {
    switch error.category {
    case .http(let status) where status.code == 405:
        // Method Not Allowed
        print("PUT not supported for this endpoint")
    case .http(let status) where status.code == 409:
        // Conflict (common with PUT/PATCH)
        print("Resource conflict, check current state")
    case .http(let status) where status.code == 412:
        // Precondition Failed (conditional headers)
        print("Precondition failed, resource may have changed")
    default:
        print("Request failed: \(error.userFriendlyDescription)")
    }
}
```

### Method Override Errors

Handle method override scenarios:

```swift
extension HTTPError {
    var suggestedMethodOverride: HTTPMethod? {
        guard case .http(let status) = category,
              status.code == 405,
              let allowedMethods = response?.headers["Allow"] else {
            return nil
        }
        
        // Suggest appropriate method based on Allow header
        if allowedMethods.contains("POST") {
            return .post
        }
        return nil
    }
}
```

## See Also

- ``HTTPMethod``
- ``RequestBuilder``
- ``HTTPRequest``
- <doc:RequestBuilding>
- <doc:RequestComponents>
- <doc:HTTPPrimitives>