# Delta Specification: Networking Macros

## ADDED Requirements

### Requirement: Protocol API Definition
The system SHALL allow developers to define REST API clients using Swift protocols annotated with the @API macro, specifying a base URL that applies to all endpoint methods in the protocol.

#### Scenario: Simple API definition
- **WHEN** a developer annotates a protocol with @API(baseURL: "https://api.example.com")
- **THEN** the macro generates an implementation struct conforming to the protocol
- **AND** all generated methods use the specified base URL

#### Scenario: Multiple API protocols
- **WHEN** a developer defines multiple protocols with different @API annotations
- **THEN** each protocol generates an independent implementation with its own base URL
- **AND** implementations do not interfere with each other

### Requirement: GET Endpoint Declaration
The system SHALL support defining GET endpoints using the @GET macro with path templates, automatically generating methods that construct HTTP GET requests and decode JSON responses.

#### Scenario: Simple GET request
- **WHEN** a developer annotates a protocol method with @GET("/users")
- **AND** the method returns a Decodable type
- **THEN** the macro generates an implementation that makes an HTTP GET request to the path
- **AND** automatically decodes the JSON response to the return type

#### Scenario: GET with path parameters
- **WHEN** a developer defines @GET("/users/{id}") with function parameter id: String
- **THEN** the macro extracts "{id}" from the path template
- **AND** generates code substituting the id parameter into the request path
- **AND** validates at compile-time that the parameter exists in the function signature

#### Scenario: GET with query parameters
- **WHEN** a developer defines @GET("/search", queryParameters: ["q", "limit"])
- **AND** the function has parameters q: String? and limit: Int?
- **THEN** the macro generates code appending non-nil parameters as URL query string
- **AND** validates at compile-time that all listed query parameters exist in the function signature

### Requirement: POST Endpoint Declaration
The system SHALL support defining POST endpoints with request bodies using the @POST macro, automatically encoding request bodies and decoding responses.

#### Scenario: POST with JSON body
- **WHEN** a developer defines @POST("/users", body: "user")
- **AND** the function has parameter user: User where User conforms to Encodable
- **THEN** the macro generates code serializing the user parameter to JSON
- **AND** includes it in the HTTP request body with Content-Type: application/json

#### Scenario: POST with path parameters and body
- **WHEN** a developer defines @POST("/orgs/{orgId}/users", body: "user")
- **AND** the function has parameters orgId: String and user: User
- **THEN** the macro generates code substituting orgId into the path
- **AND** serializes user parameter to JSON body
- **AND** validates both parameters exist at compile-time

### Requirement: PUT and PATCH Endpoint Declaration
The system SHALL support defining PUT and PATCH endpoints for update operations using @PUT and @PATCH macros with request body handling identical to POST.

#### Scenario: PUT for full resource update
- **WHEN** a developer defines @PUT("/users/{id}", body: "user")
- **AND** the function has parameters id: String and user: User
- **THEN** the macro generates code making an HTTP PUT request to /users/{id}
- **AND** includes the serialized user in the request body

#### Scenario: PATCH for partial update
- **WHEN** a developer defines @PATCH("/users/{id}", body: "updates")
- **AND** the function has parameter updates: UserUpdates
- **THEN** the macro generates code making an HTTP PATCH request
- **AND** includes the serialized updates in the request body

### Requirement: DELETE Endpoint Declaration
The system SHALL support defining DELETE endpoints using the @DELETE macro for resource deletion operations.

#### Scenario: DELETE resource by ID
- **WHEN** a developer defines @DELETE("/users/{id}")
- **AND** the function returns Void
- **THEN** the macro generates code making an HTTP DELETE request to /users/{id}
- **AND** does not attempt to decode a response body

#### Scenario: DELETE with custom return type
- **WHEN** a developer defines @DELETE("/users/{id}")
- **AND** the function returns a Decodable type
- **THEN** the macro generates code decoding the response as specified
- **AND** handles both empty and non-empty DELETE responses

### Requirement: Default Headers Configuration
The system SHALL support protocol-level default headers using the @DefaultHeaders macro that apply to all endpoint methods in the protocol.

#### Scenario: API version headers
- **WHEN** a developer annotates a protocol with @DefaultHeaders(["X-API-Version": "v1"])
- **THEN** the macro generates code including X-API-Version: v1 in all requests from that protocol
- **AND** headers are sent automatically without per-method configuration

#### Scenario: Multiple default headers
- **WHEN** a developer specifies multiple headers in @DefaultHeaders
- **THEN** all specified headers are included in every request
- **AND** headers can include authentication tokens, accept headers, and custom values

### Requirement: Timeout Configuration
The system SHALL support protocol-level timeout configuration using the @Timeout macro that applies to all endpoint methods.

#### Scenario: Custom timeout
- **WHEN** a developer annotates a protocol with @Timeout(30.0)
- **THEN** the macro generates code configuring a 30-second timeout for all requests
- **AND** requests fail with timeout error if not completed within the specified duration

### Requirement: Path Template Validation
The system SHALL validate path templates at compile-time, ensuring parameter names in {braces} match function parameter names exactly.

#### Scenario: Path parameter mismatch
- **WHEN** a developer defines @GET("/users/{userId}") with function parameter id: String
- **THEN** the macro emits a compile-time error indicating parameter mismatch
- **AND** the error message lists required parameters and available parameters
- **AND** suggests the correct parameter name

#### Scenario: Invalid path template syntax
- **WHEN** a developer defines a path with unmatched braces like "/users/{id"
- **THEN** the macro emits a compile-time error indicating invalid path syntax
- **AND** provides a suggestion for the correct format

### Requirement: Type Safety Validation
The system SHALL validate at compile-time that return types conform to Decodable and body parameters conform to Encodable.

#### Scenario: Non-Decodable return type
- **WHEN** a developer defines a GET method returning a type not conforming to Decodable
- **THEN** the macro emits a compile-time error
- **AND** suggests adding Decodable conformance

#### Scenario: Non-Encodable body parameter
- **WHEN** a developer specifies a body parameter with type not conforming to Encodable
- **THEN** the macro emits a compile-time error
- **AND** suggests adding Encodable conformance

### Requirement: Async/Throws Enforcement
The system SHALL require all API endpoint methods to be declared as async throws, emitting compile-time errors for methods missing these keywords.

#### Scenario: Missing async keyword
- **WHEN** a developer defines a method without the async keyword
- **THEN** the macro emits a compile-time error
- **AND** provides a Fix-It suggestion to add async

#### Scenario: Missing throws keyword
- **WHEN** a developer defines a method without the throws keyword
- **THEN** the macro emits a compile-time error
- **AND** provides a Fix-It suggestion to add throws

### Requirement: NetworkClient Integration
The system SHALL generate implementations that use the existing NetworkClient from the Networking framework, inheriting all middleware, security features, and configuration.

#### Scenario: Middleware inheritance
- **WHEN** a generated API implementation makes a request
- **THEN** the request passes through all configured NetworkClient middleware (authentication, retry, logging, caching)
- **AND** middleware behavior is identical to hand-written NetworkClient code

#### Scenario: Dependency injection
- **WHEN** a developer creates an instance of a generated API implementation
- **THEN** they can optionally provide a custom NetworkClient instance
- **AND** the default uses NetworkClient.shared
- **AND** this enables testing with MockNetworkClient

### Requirement: Sendable Conformance
The system SHALL generate implementation structs that conform to Sendable, ensuring Swift 6 strict concurrency compliance.

#### Scenario: Generated struct is Sendable
- **WHEN** the macro generates an API implementation struct
- **THEN** the struct is marked as conforming to Sendable
- **AND** the code compiles without warnings under Swift 6 strict concurrency

#### Scenario: No data races
- **WHEN** multiple tasks concurrently access a generated API implementation
- **THEN** no data races occur
- **AND** all state is immutable or properly isolated

### Requirement: Error Handling
The system SHALL generate methods that throw typed errors for HTTP failures (APIClientError.httpError), network failures (APIClientError.networkError), and JSON decoding failures (APIClientError.decodingError).

#### Scenario: HTTP error response
- **WHEN** an API returns a 404 status code
- **THEN** the generated method throws APIClientError.httpError(statusCode: 404, response: ...)
- **AND** the error includes the full HTTPResponse for inspection

#### Scenario: Network connectivity failure
- **WHEN** a network request fails due to connectivity issues
- **THEN** the generated method throws APIClientError.networkError wrapping the underlying error
- **AND** developers can inspect the underlying error for details

#### Scenario: JSON decoding failure
- **WHEN** a response body cannot be decoded to the expected type
- **THEN** the generated method throws APIClientError.decodingError with the decoding error and raw data
- **AND** developers can inspect the raw data for debugging

### Requirement: Optional Parameter Support
The system SHALL support optional parameters for query parameters and headers, only including them in requests when non-nil values are provided.

#### Scenario: Optional query parameters
- **WHEN** a developer defines query parameters with optional types
- **AND** calls the method with some parameters as nil
- **THEN** the generated code only includes non-nil parameters in the query string
- **AND** nil parameters are omitted from the request

### Requirement: Performance
The system SHALL generate code that performs identically to equivalent hand-written NetworkClient code, with macro expansion completing in under 5 seconds for protocols with 20 endpoints.

#### Scenario: Zero runtime overhead
- **WHEN** a generated API method executes
- **THEN** the performance is identical to hand-written NetworkClient code
- **AND** there is no additional overhead from macro-generated code

#### Scenario: Fast compilation
- **WHEN** compiling a protocol with 20 endpoint methods
- **THEN** macro expansion completes in under 5 seconds
- **AND** does not significantly impact total build time

### Requirement: Diagnostic Quality
The system SHALL provide clear, actionable error messages with Fix-It suggestions for all compile-time validation failures.

#### Scenario: Parameter mismatch with Fix-It
- **WHEN** a parameter validation error occurs
- **THEN** the error message shows the mismatch clearly
- **AND** includes a Fix-It suggestion with the correct parameter name

#### Scenario: Multiple errors reported
- **WHEN** multiple validation errors exist in a single protocol
- **THEN** all errors are reported in a single compilation
- **AND** each error includes location and suggested fix
