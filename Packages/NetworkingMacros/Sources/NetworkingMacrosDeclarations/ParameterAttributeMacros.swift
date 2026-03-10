/// Marks which function parameter contains the request body for POST/PUT/PATCH operations.
///
/// The macro validates that:
/// - The named parameter exists in the function signature
/// - The parameter type conforms to Encodable
/// - Only one @Body macro is applied per function
///
/// ## Usage
///
/// ```swift
/// @POST("/users")
/// @Body("user")
/// func createUser(user: CreateUserRequest) async throws -> User
/// ```
///
/// The macro will generate code that encodes the `user` parameter as JSON
/// and includes it in the HTTP request body.
///
/// ## Validation
///
/// The macro performs compile-time validation:
/// - **Parameter existence**: Verifies the named parameter exists
/// - **Type safety**: Ensures the parameter type is Encodable
/// - **Single body**: Only one @Body allowed per function
///
/// ## Examples
///
/// ```swift
/// // Simple POST with body
/// @POST("/repos")
/// @Body("repo")
/// func createRepo(repo: CreateRepoRequest) async throws -> Repo
///
/// // POST with path parameters and body
/// @POST("/orgs/{org}/repos")
/// @Body("repo")
/// func createOrgRepo(org: String, repo: CreateRepoRequest) async throws -> Repo
///
/// // PUT with body
/// @PUT("/users/{id}")
/// @Body("updates")
/// func updateUser(id: String, updates: UserUpdates) async throws -> User
/// ```
///
/// - Parameter parameterName: The name of the function parameter containing the request body
@attached(peer)
public macro Body(_ parameterName: ParameterReference) =
  #externalMacro(
    module: "NetworkingMacrosPlugin",
    type: "BodyMacro"
  )

/// Defines custom HTTP headers using result builder syntax.
///
/// Headers can use literal values or reference function parameters:
/// - **Literal**: `H("Content-Type", "application/json")`
/// - **Parameter**: `H("Authorization", "token")` where `token` is a function parameter
///
/// The macro validates that:
/// - All parameter references exist in the function signature
/// - Header names don't contain CRLF characters (injection prevention)
///
/// ## Usage
///
/// ```swift
/// @GET("/user")
/// @Headers {
///     H("Authorization", "token")
///     H("Accept", "application/json")
/// }
/// func getUser(token: String) async throws -> User
/// ```
///
/// ## Security
///
/// The macro prevents HTTP header injection attacks by:
/// - Validating header names don't contain `\r` or `\n` characters
/// - Checking parameter references at compile-time
/// - Following OWASP A03:2021 Injection prevention guidelines
///
/// ## Examples
///
/// ```swift
/// // GET with authentication header
/// @GET("/user/repos")
/// @Headers {
///     H("Authorization", "token")
/// }
/// func getUserRepos(token: String) async throws -> [Repo]
///
/// // POST with multiple headers
/// @POST("/users")
/// @Body("user")
/// @Headers {
///     H("X-API-Key", "apiKey")
///     H("Content-Type", "application/json")
///     H("Accept", "application/json")
/// }
/// func createUser(user: User, apiKey: String) async throws -> User
///
/// // Mix of literal and parameter values
/// @GET("/data")
/// @Headers {
///     H("Authorization", "token")           // From parameter
///     H("X-Client-Version", "1.0.0")         // Literal
///     H("Accept-Language", "en-US")          // Literal
/// }
/// func getData(token: String) async throws -> Data
/// ```
///
/// - Parameter headers: Result builder closure returning header components
@attached(peer)
public macro Headers(
  @HeaderBuilder _ headers: () -> [HeaderComponent]
) =
  #externalMacro(
    module: "NetworkingMacrosPlugin",
    type: "HeadersMacro"
  )
