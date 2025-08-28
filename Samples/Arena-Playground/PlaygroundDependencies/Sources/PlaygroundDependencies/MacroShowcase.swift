/// # Swift Macros Showcase for Networking Framework
///
/// This showcase demonstrates the powerful Swift macro system that enables declarative API client generation.
/// The framework provides annotations like @API, @GET, @POST that automatically generate complete
/// implementation structs from protocol definitions.
///
/// ## Key Features Demonstrated
///
/// - **@API** macro for defining base URL and generating implementation
/// - **HTTP Method macros**: @GET, @POST, @PUT, @DELETE, @PATCH
/// - **Parameter annotations**: @Path, @Query, @Body, @Header
/// - **Automatic code generation**: Complete API client implementations
/// - **Type-safe requests**: Compile-time validation of API definitions
/// - **Multiple API patterns**: REST, GraphQL-style, and custom endpoints
///
/// ## Learning Path
///
/// 1. Basic API definition with @GET
/// 2. Parameter binding with @Path, @Query
/// 3. Request body handling with @Body
/// 4. Authentication with @Header
/// 5. Complete CRUD operations
/// 6. Advanced patterns and real-world examples
///
/// Created by: Bruno da Gama Porciuncula
/// Date: 27/08/25

import Foundation
import Networking

// MARK: - Macro Showcase Examples

public struct MacroShowcase {
  /// Display comprehensive macro system overview
  public static func displayOverview() {
    print(
      """

      ╔═══════════════════════════════════════════════════════════════════════╗
      ║                    🚀 SWIFT MACROS SHOWCASE                           ║
      ╚═══════════════════════════════════════════════════════════════════════╝

      The Networking framework provides powerful Swift macros for declarative API development:

      📋 MACRO ANNOTATIONS:
      • @API(baseURL: "...")     - Defines API base URL and generates implementation
      • @GET("/path")           - HTTP GET request with path
      • @POST("/path")          - HTTP POST request with path  
      • @PUT("/path")           - HTTP PUT request with path
      • @DELETE("/path")        - HTTP DELETE request with path
      • @PATCH("/path")         - HTTP PATCH request with path

      🔧 PARAMETER ANNOTATIONS:
      • @Path                   - URL path parameter substitution
      • @Query                  - URL query parameter
      • @Body                   - Request body (JSON serialized)
      • @Header                 - HTTP header value

      ⚡ AUTOMATIC GENERATION:
      The macros automatically generate complete API client implementations with:
      • HTTPRequest building using the DSL
      • Parameter validation and encoding
      • Response decoding and error handling
      • Type-safe Swift interfaces

      🎯 EXAMPLES INCLUDED:
      1. Basic User API (GET, POST, PUT, DELETE)
      2. E-commerce Product API with search and filtering
      3. Social Media API with authentication
      4. File Upload/Download API
      5. GraphQL-style API patterns
      6. Real-world GitHub API integration

      """
    )
  }

  /// Run all macro examples
  public static func runAll() async {
    displayOverview()

    print("\n🚀 Running Macro Examples...\n")

    await basicUserAPIExample()
    await ecommerceProductAPIExample()
    await socialMediaAPIExample()
    await fileAPIExample()
    await graphQLStyleAPIExample()
    await githubAPIIntegrationExample()

    print(
      """

      ✅ All macro examples completed successfully!

      The Swift macro system demonstrates how declarative API definitions can generate
      complete, type-safe client implementations automatically.

      """
    )
  }
}

// MARK: - 1. Basic User API Example

/// Basic user management API demonstrating fundamental macro usage
@API(baseURL: "https://api.example.com/v1")
protocol UserAPI {
  /// Get user by ID with path parameter
  @GET("/users/{id}")
  func getUser(@Path id: Int) async throws -> User

  /// List users with query parameters
  @GET("/users")
  func listUsers(@Query page: Int, @Query limit: Int) async throws -> [User]

  /// Create new user with JSON body
  @POST("/users")
  func createUser(@Body user: CreateUserRequest) async throws -> User

  /// Update existing user
  @PUT("/users/{id}")
  func updateUser(@Path id: Int, @Body user: UpdateUserRequest) async throws -> User

  /// Delete user
  @DELETE("/users/{id}")
  func deleteUser(@Path id: Int) async throws

  /// Search users with multiple query parameters
  @GET("/users/search")
  func searchUsers(
    @Query q: String,
    @Query role: String?,
    @Query active: Bool?
  ) async throws -> [User]
}

// Supporting types for User API
public struct User: Codable {
  let id: Int
  let name: String
  let email: String
  let role: String
  let isActive: Bool
  let createdAt: Date
}

public struct CreateUserRequest: Codable {
  let name: String
  let email: String
  let role: String
}

public struct UpdateUserRequest: Codable {
  let name: String?
  let email: String?
  let role: String?
  let isActive: Bool?
}

extension MacroShowcase {
  /// Demonstrate basic User API with macro-generated implementation
  public static func basicUserAPIExample() async {
    print(
      """
      ═══════════════════════════════════════════════════════════════
      📋 EXAMPLE 1: Basic User API with Swift Macros
      ═══════════════════════════════════════════════════════════════

      PROTOCOL DEFINITION:
      @API(baseURL: "https://api.example.com/v1")
      protocol UserAPI {
          @GET("/users/{id}")
          func getUser(@Path id: Int) async throws -> User
          
          @POST("/users") 
          func createUser(@Body user: CreateUserRequest) async throws -> User
      }

      GENERATED IMPLEMENTATION:
      The macro automatically generates UserAPIImplementation struct with:
      • HTTPRequest building using the DSL
      • Path parameter substitution: /users/123
      • JSON body encoding for CreateUserRequest
      • Response decoding to User type
      • Proper error handling

      """
    )

    print("🔍 The macro system automatically generates UserAPIImplementation:")
    print("• GET /users/123 - Fetch user by ID")
    print("• POST /users - Create new user")
    print("• PUT /users/123 - Update user")
    print("• DELETE /users/123 - Delete user")
    print("• GET /users/search?q=john&role=admin - Search users")
    print("")
    print("✨ Generated code creates:")
    print("  - HTTPRequest building using DSL")
    print("  - Path parameter substitution")
    print("  - JSON body encoding/decoding")
    print("  - Type-safe response handling")
    print("  - Automatic error propagation")
  }
}

// MARK: - 2. E-commerce Product API Example

/// E-commerce API with advanced parameter handling and filtering
@API(baseURL: "https://api.shop.com/v2")
protocol ProductAPI {
  /// Get product details with optional fields
  @GET("/products/{id}")
  func getProduct(@Path id: String, @Query fields: String?) async throws -> Product

  /// Search products with multiple filters
  @GET("/products/search")
  func searchProducts(
    @Query q: String,
    @Query category: String?,
    @Query minPrice: Double?,
    @Query maxPrice: Double?,
    @Query inStock: Bool?,
    @Query sortBy: String?,
    @Query page: Int,
    @Query limit: Int
  ) async throws -> ProductSearchResult

  /// Get products by category with pagination
  @GET("/categories/{categoryId}/products")
  func getProductsByCategory(
    @Path categoryId: String,
    @Query page: Int,
    @Query limit: Int,
    @Query sortBy: String?
  ) async throws -> ProductSearchResult

  /// Create new product (admin only)
  @POST("/products")
  func createProduct(
    @Header("Authorization") token: String,
    @Body product: CreateProductRequest
  ) async throws -> Product

  /// Update product inventory
  @PATCH("/products/{id}/inventory")
  func updateInventory(
    @Path id: String,
    @Header("Authorization") token: String,
    @Body inventory: UpdateInventoryRequest
  ) async throws -> Product
}

// Supporting types for Product API
public struct Product: Codable {
  let id: String
  let name: String
  let description: String
  let price: Double
  let category: String
  let inStock: Bool
  let stockCount: Int
  let imageUrls: [String]
  let tags: [String]
}

public struct ProductSearchResult: Codable {
  let products: [Product]
  let totalCount: Int
  let page: Int
  let limit: Int
  let hasMore: Bool
}

public struct CreateProductRequest: Codable {
  let name: String
  let description: String
  let price: Double
  let categoryId: String
  let stockCount: Int
  let imageUrls: [String]
  let tags: [String]
}

public struct UpdateInventoryRequest: Codable {
  let stockCount: Int
  let inStock: Bool?
}

extension MacroShowcase {
  /// Demonstrate e-commerce API with complex parameter handling
  public static func ecommerceProductAPIExample() async {
    print(
      """
      ═══════════════════════════════════════════════════════════════
      🛒 EXAMPLE 2: E-commerce Product API with Advanced Parameters
      ═══════════════════════════════════════════════════════════════

      PROTOCOL DEFINITION:
      @API(baseURL: "https://api.shop.com/v2")
      protocol ProductAPI {
          @GET("/products/search")
          func searchProducts(
              @Query q: String,
              @Query category: String?,
              @Query minPrice: Double?,
              @Query maxPrice: Double?,
              @Query inStock: Bool?,
              @Query sortBy: String?,
              @Query page: Int,
              @Query limit: Int
          ) async throws -> ProductSearchResult
      }

      GENERATED REQUEST BUILDING:
      let request = try HTTPRequest {
          BaseURL("https://api.shop.com/v2")
          GET("/products/search")
          QueryParam("q", q)
          QueryParam("category", category)
          QueryParam("minPrice", minPrice)
          QueryParam("maxPrice", maxPrice)
          QueryParam("inStock", inStock)
          QueryParam("sortBy", sortBy)
          QueryParam("page", page)
          QueryParam("limit", limit)
      }

      """
    )

    print("🔍 Simulating E-commerce API operations:")
    print("• GET /products/search?q=laptop&category=electronics&minPrice=500")
    print("• GET /categories/electronics/products?page=1&limit=20")
    print("• POST /products - Create new product (with auth header)")
    print("• PATCH /products/abc123/inventory - Update stock levels")
    print("")
    print("✨ Macro benefits:")
    print("  - Multiple query parameters handled automatically")
    print("  - Optional parameters properly encoded")
    print("  - Authentication headers integrated seamlessly")
    print("  - Complex request structures simplified")
  }
}

// MARK: - 3. Social Media API Example

/// Social media API demonstrating authentication and nested resources
@API(baseURL: "https://api.social.com/v1")
protocol SocialMediaAPI {
  /// Get current user profile
  @GET("/me")
  func getProfile(@Header("Authorization") token: String) async throws -> Profile

  /// Update profile
  @PUT("/me")
  func updateProfile(
    @Header("Authorization") token: String,
    @Body profile: UpdateProfileRequest
  ) async throws -> Profile

  /// Get user's posts with pagination
  @GET("/users/{userId}/posts")
  func getUserPosts(
    @Path userId: String,
    @Header("Authorization") token: String,
    @Query page: Int,
    @Query limit: Int
  ) async throws -> PostsResponse

  /// Create new post
  @POST("/posts")
  func createPost(
    @Header("Authorization") token: String,
    @Header("X-Client-Version") clientVersion: String,
    @Body post: CreatePostRequest
  ) async throws -> Post

  /// Like a post
  @POST("/posts/{postId}/like")
  func likePost(
    @Path postId: String,
    @Header("Authorization") token: String
  ) async throws

  /// Get post comments
  @GET("/posts/{postId}/comments")
  func getComments(
    @Path postId: String,
    @Query page: Int,
    @Query limit: Int
  ) async throws -> CommentsResponse

  /// Add comment to post
  @POST("/posts/{postId}/comments")
  func addComment(
    @Path postId: String,
    @Header("Authorization") token: String,
    @Body comment: CreateCommentRequest
  ) async throws -> Comment
}

// Supporting types for Social Media API
public struct Profile: Codable {
  let id: String
  let username: String
  let displayName: String
  let bio: String?
  let avatarUrl: String?
  let followersCount: Int
  let followingCount: Int
}

public struct UpdateProfileRequest: Codable {
  let displayName: String?
  let bio: String?
  let avatarUrl: String?
}

public struct Post: Codable {
  let id: String
  let userId: String
  let content: String
  let imageUrls: [String]
  let likesCount: Int
  let commentsCount: Int
  let createdAt: Date
}

public struct PostsResponse: Codable {
  let posts: [Post]
  let pagination: Pagination
}

public struct CreatePostRequest: Codable {
  let content: String
  let imageUrls: [String]?
  let tags: [String]?
}

public struct Comment: Codable {
  let id: String
  let postId: String
  let userId: String
  let content: String
  let createdAt: Date
}

public struct CommentsResponse: Codable {
  let comments: [Comment]
  let pagination: Pagination
}

public struct CreateCommentRequest: Codable {
  let content: String
}

public struct Pagination: Codable {
  let page: Int
  let limit: Int
  let totalCount: Int
  let hasMore: Bool
}

extension MacroShowcase {
  /// Demonstrate social media API with authentication patterns
  public static func socialMediaAPIExample() async {
    print(
      """
      ═══════════════════════════════════════════════════════════════
      📱 EXAMPLE 3: Social Media API with Authentication
      ═══════════════════════════════════════════════════════════════

      PROTOCOL DEFINITION:
      @API(baseURL: "https://api.social.com/v1")
      protocol SocialMediaAPI {
          @GET("/me")
          func getProfile(@Header("Authorization") token: String) async throws -> Profile
          
          @POST("/posts")
          func createPost(
              @Header("Authorization") token: String,
              @Header("X-Client-Version") clientVersion: String,
              @Body post: CreatePostRequest
          ) async throws -> Post
      }

      GENERATED AUTHENTICATION HANDLING:
      let request = try HTTPRequest {
          BaseURL("https://api.social.com/v1")
          POST("/posts")
          Header("Authorization", token)
          Header("X-Client-Version", clientVersion)
          JSONBody(post)
      }

      """
    )

    print("🔍 Generated API implementation provides:")

    print("🔍 Simulating Social Media API operations:")
    print("• GET /me - Get authenticated user profile")
    print("• POST /posts - Create new post with auth headers")
    print("• POST /posts/{id}/like - Like a post")
    print("• GET /posts/{id}/comments - Get post comments")
    print("• POST /posts/{id}/comments - Add comment")
  }
}

// MARK: - 4. File Upload/Download API Example

/// File management API demonstrating binary data handling
@API(baseURL: "https://files.example.com/api")
protocol FileAPI {
  /// Upload file with metadata
  @POST("/files")
  func uploadFile(
    @Header("Authorization") token: String,
    @Header("Content-Type") contentType: String,
    @Body fileData: Data
  ) async throws -> FileUploadResponse

  /// Get file metadata
  @GET("/files/{fileId}")
  func getFileInfo(@Path fileId: String) async throws -> FileInfo

  /// Download file content
  @GET("/files/{fileId}/download")
  func downloadFile(
    @Path fileId: String,
    @Header("Authorization") token: String?
  ) async throws -> Data

  /// List user's files
  @GET("/files")
  func listFiles(
    @Header("Authorization") token: String,
    @Query folder: String?,
    @Query type: String?,
    @Query page: Int,
    @Query limit: Int
  ) async throws -> FilesListResponse

  /// Delete file
  @DELETE("/files/{fileId}")
  func deleteFile(
    @Path fileId: String,
    @Header("Authorization") token: String
  ) async throws

  /// Update file metadata
  @PATCH("/files/{fileId}")
  func updateFileInfo(
    @Path fileId: String,
    @Header("Authorization") token: String,
    @Body update: UpdateFileRequest
  ) async throws -> FileInfo
}

// Supporting types for File API
public struct FileUploadResponse: Codable {
  let fileId: String
  let fileName: String
  let fileSize: Int
  let contentType: String
  let uploadUrl: String
  let downloadUrl: String
}

public struct FileInfo: Codable {
  let id: String
  let fileName: String
  let fileSize: Int
  let contentType: String
  let folder: String?
  let tags: [String]
  let createdAt: Date
  let modifiedAt: Date
}

public struct FilesListResponse: Codable {
  let files: [FileInfo]
  let pagination: Pagination
}

public struct UpdateFileRequest: Codable {
  let fileName: String?
  let folder: String?
  let tags: [String]?
}

extension MacroShowcase {
  /// Demonstrate file API with binary data handling
  public static func fileAPIExample() async {
    print(
      """
      ═══════════════════════════════════════════════════════════════
      📁 EXAMPLE 4: File Upload/Download API
      ═══════════════════════════════════════════════════════════════

      PROTOCOL DEFINITION:
      @API(baseURL: "https://files.example.com/api")
      protocol FileAPI {
          @POST("/files")
          func uploadFile(
              @Header("Authorization") token: String,
              @Header("Content-Type") contentType: String,
              @Body fileData: Data
          ) async throws -> FileUploadResponse
          
          @GET("/files/{fileId}/download")
          func downloadFile(@Path fileId: String) async throws -> Data
      }

      GENERATED BINARY DATA HANDLING:
      let request = try HTTPRequest {
          BaseURL("https://files.example.com/api")
          POST("/files")
          Header("Authorization", token)
          Header("Content-Type", contentType)
          RawBody(fileData)  // Binary data upload
      }

      """
    )

    print("🔍 Generated API implementation provides:")

    print("🔍 Simulating File API operations:")
    print("• POST /files - Upload binary file data")
    print("• GET /files/{id} - Get file metadata")
    print("• GET /files/{id}/download - Download file content")
    print("• GET /files?folder=documents&type=pdf - List files with filters")
    print("• PATCH /files/{id} - Update file metadata")
  }
}

// MARK: - 5. GraphQL-Style API Example

/// GraphQL-style API demonstrating flexible field selection
@API(baseURL: "https://graphql-api.example.com")
protocol GraphQLStyleAPI {
  /// Query with field selection (GraphQL-inspired)
  @POST("/graphql")
  func queryUser(@Body query: GraphQLQuery) async throws -> GraphQLResponse<User>

  /// Mutation with variables
  @POST("/graphql")
  func mutateUser(@Body mutation: GraphQLMutation) async throws -> GraphQLResponse<User>

  /// REST-style endpoint with field selection
  @GET("/users/{id}")
  func getUser(
    @Path id: String,
    @Query fields: String?,
    @Query include: String?
  ) async throws -> User

  /// Bulk operations
  @POST("/bulk")
  func bulkOperations(
    @Body operations: BulkOperationsRequest
  ) async throws -> BulkOperationsResponse
}

// Supporting types for GraphQL-style API
public struct GraphQLQuery: Codable {
  let query: String
  let variables: [String: Any]?

  enum CodingKeys: String, CodingKey {
    case query, variables
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(query, forKey: .query)
    // Note: Simplified for demo - real implementation would handle Any properly
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    query = try container.decode(String.self, forKey: .query)
    variables = nil  // Simplified for demo
  }
}

public struct GraphQLMutation: Codable {
  let mutation: String
  let variables: [String: String]?
}

public struct GraphQLResponse<T: Codable>: Codable {
  let data: T?
  let errors: [GraphQLError]?
}

public struct GraphQLError: Codable {
  let message: String
  let path: [String]?
  let extensions: [String: String]?
}

public struct BulkOperationsRequest: Codable {
  let operations: [BulkOperation]
}

public struct BulkOperation: Codable {
  let type: String  // "CREATE", "UPDATE", "DELETE"
  let resource: String
  let data: [String: String]?
}

public struct BulkOperationsResponse: Codable {
  let results: [BulkOperationResult]
  let successCount: Int
  let errorCount: Int
}

public struct BulkOperationResult: Codable {
  let success: Bool
  let resourceId: String?
  let error: String?
}

extension MacroShowcase {
  /// Demonstrate GraphQL-style API patterns
  public static func graphQLStyleAPIExample() async {
    print(
      """
      ═══════════════════════════════════════════════════════════════
      🕸️ EXAMPLE 5: GraphQL-Style API Patterns
      ═══════════════════════════════════════════════════════════════

      PROTOCOL DEFINITION:
      @API(baseURL: "https://graphql-api.example.com")
      protocol GraphQLStyleAPI {
          @POST("/graphql")
          func queryUser(@Body query: GraphQLQuery) async throws -> GraphQLResponse<User>
          
          @GET("/users/{id}")
          func getUser(
              @Path id: String,
              @Query fields: String?,
              @Query include: String?
          ) async throws -> User
      }

      GENERATED FLEXIBLE QUERYING:
      • GraphQL queries as JSON body
      • Field selection via query parameters
      • Bulk operations support
      • Nested resource inclusion

      """
    )

    print("🔍 Generated API implementation provides:")

    print("🔍 Simulating GraphQL-Style API operations:")
    print("• POST /graphql - Execute GraphQL query")
    print("• GET /users/{id}?fields=id,name,email&include=profile,posts")
    print("• POST /bulk - Execute bulk operations")
  }
}

// MARK: - 6. Real-World GitHub API Integration

/// Real GitHub API integration demonstrating production patterns
@API(baseURL: "https://api.github.com")
protocol GitHubAPI {
  /// Get authenticated user
  @GET("/user")
  func getAuthenticatedUser(@Header("Authorization") token: String) async throws -> GitHubUser

  /// List user repositories
  @GET("/user/repos")
  func listRepositories(
    @Header("Authorization") token: String,
    @Query type: String?,
    @Query sort: String?,
    @Query direction: String?,
    @Query per_page: Int?,
    @Query page: Int?
  ) async throws -> [Repository]

  /// Get repository details
  @GET("/repos/{owner}/{repo}")
  func getRepository(@Path owner: String, @Path repo: String) async throws -> Repository

  /// Create repository
  @POST("/user/repos")
  func createRepository(
    @Header("Authorization") token: String,
    @Body repository: CreateRepositoryRequest
  ) async throws -> Repository

  /// List repository issues
  @GET("/repos/{owner}/{repo}/issues")
  func listIssues(
    @Path owner: String,
    @Path repo: String,
    @Query state: String?,
    @Query labels: String?,
    @Query sort: String?,
    @Query direction: String?,
    @Query per_page: Int?
  ) async throws -> [Issue]

  /// Create issue
  @POST("/repos/{owner}/{repo}/issues")
  func createIssue(
    @Path owner: String,
    @Path repo: String,
    @Header("Authorization") token: String,
    @Body issue: CreateIssueRequest
  ) async throws -> Issue

  /// Search repositories
  @GET("/search/repositories")
  func searchRepositories(
    @Query q: String,
    @Query sort: String?,
    @Query order: String?,
    @Query per_page: Int?
  ) async throws -> SearchResult<Repository>
}

// Supporting types for GitHub API
public struct GitHubUser: Codable {
  let id: Int
  let login: String
  let name: String?
  let email: String?
  let avatarUrl: String
  let publicRepos: Int
  let followers: Int
  let following: Int

  enum CodingKeys: String, CodingKey {
    case id, login, name, email, followers, following
    case avatarUrl = "avatar_url"
    case publicRepos = "public_repos"
  }
}

public struct Repository: Codable {
  let id: Int
  let name: String
  let fullName: String
  let description: String?
  let isPrivate: Bool
  let htmlUrl: String
  let cloneUrl: String
  let stargazersCount: Int
  let forksCount: Int
  let language: String?
  let createdAt: Date
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case id, name, description, language
    case fullName = "full_name"
    case isPrivate = "private"
    case htmlUrl = "html_url"
    case cloneUrl = "clone_url"
    case stargazersCount = "stargazers_count"
    case forksCount = "forks_count"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}

public struct CreateRepositoryRequest: Codable {
  let name: String
  let description: String?
  let isPrivate: Bool
  let hasIssues: Bool
  let hasWiki: Bool
  let autoInit: Bool

  enum CodingKeys: String, CodingKey {
    case name, description
    case isPrivate = "private"
    case hasIssues = "has_issues"
    case hasWiki = "has_wiki"
    case autoInit = "auto_init"
  }
}

public struct Issue: Codable {
  let id: Int
  let number: Int
  let title: String
  let body: String?
  let state: String
  let user: GitHubUser
  let createdAt: Date
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case id, number, title, body, state, user
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}

public struct CreateIssueRequest: Codable {
  let title: String
  let body: String?
  let labels: [String]?
  let assignees: [String]?
}

public struct SearchResult<T: Codable>: Codable {
  let totalCount: Int
  let items: [T]

  enum CodingKeys: String, CodingKey {
    case items
    case totalCount = "total_count"
  }
}

extension MacroShowcase {
  /// Demonstrate real-world GitHub API integration
  public static func githubAPIIntegrationExample() async {
    print(
      """
      ═══════════════════════════════════════════════════════════════
      🐙 EXAMPLE 6: Real-World GitHub API Integration
      ═══════════════════════════════════════════════════════════════

      PROTOCOL DEFINITION:
      @API(baseURL: "https://api.github.com")
      protocol GitHubAPI {
          @GET("/user")
          func getAuthenticatedUser(@Header("Authorization") token: String) async throws -> GitHubUser
          
          @GET("/repos/{owner}/{repo}")
          func getRepository(@Path owner: String, @Path repo: String) async throws -> Repository
          
          @GET("/search/repositories")
          func searchRepositories(
              @Query q: String,
              @Query sort: String?,
              @Query order: String?
          ) async throws -> SearchResult<Repository>
      }

      REAL-WORLD PATTERNS DEMONSTRATED:
      • Bearer token authentication
      • Snake_case to camelCase property mapping
      • Date parsing from ISO strings  
      • Pagination with per_page/page parameters
      • Complex search queries with multiple filters
      • Nested JSON response decoding

      """
    )

    print("🔍 Generated API implementation provides:")

    print("🔍 Simulating GitHub API operations:")
    print("• GET /user - Get authenticated user profile")
    print("• GET /user/repos?type=owner&sort=updated - List user repositories")
    print("• GET /repos/apple/swift - Get Swift repository details")
    print("• GET /search/repositories?q=swift+networking - Search repositories")
    print("• POST /user/repos - Create new repository")
    print("• GET /repos/owner/repo/issues - List repository issues")
  }
}

// MARK: - Macro System Learning and Exploration

extension MacroShowcase {
  /// Interactive exploration of macro capabilities
  public static func runInteractiveMacroExploration() async {
    print(
      """
      ═══════════════════════════════════════════════════════════════
      🎯 INTERACTIVE MACRO EXPLORATION
      ═══════════════════════════════════════════════════════════════

      Explore the macro system interactively:

      1. Basic annotations (@GET, @POST, etc.)
      2. Parameter binding (@Path, @Query, @Body, @Header)
      3. Generated code inspection
      4. Error handling and validation
      5. Performance characteristics
      6. Best practices and patterns

      """
    )

    // This would be interactive in a real implementation
    await basicUserAPIExample()
  }

  /// Show generated code examples
  public static func showGeneratedCodeExamples() {
    print(
      """
      ═══════════════════════════════════════════════════════════════
      🔧 GENERATED CODE EXAMPLES
      ═══════════════════════════════════════════════════════════════

      When you define:
      @API(baseURL: "https://api.example.com")
      protocol UserAPI {
          @GET("/users/{id}")
          func getUser(@Path id: Int) async throws -> User
      }

      The macro generates:
      extension UserAPI {
          public struct UserAPIImplementation: UserAPI {
              private let client: HTTPClient
              private let baseURL: String = "https://api.example.com"
              
              public init(client: HTTPClient = NetworkClient()) {
                  self.client = client
              }
              
              public func getUser(id: Int) async throws -> User {
                  let request = try HTTPRequest {
                      BaseURL(baseURL)
                      GET("/users/{id}".replacingOccurrences(of: "{id}", with: String(id)))
                  }
                  
                  let response = try await client.execute(request)
                  return try response.decode(User.self)
              }
          }
      }

      KEY FEATURES OF GENERATED CODE:
      • Uses the framework's RequestBuilder DSL
      • Automatic parameter substitution
      • Type-safe response decoding
      • Proper async/await support
      • Error propagation

      """
    )
  }

  /// Display macro performance characteristics
  public static func showPerformanceCharacteristics() {
    print(
      """
      ═══════════════════════════════════════════════════════════════
      ⚡ MACRO PERFORMANCE CHARACTERISTICS
      ═══════════════════════════════════════════════════════════════

      COMPILE-TIME BENEFITS:
      • Zero runtime overhead - all generation happens at compile time
      • Type safety validation during compilation
      • Automatic API contract verification
      • Dead code elimination for unused endpoints

      RUNTIME BENEFITS:
      • No reflection or dynamic dispatch
      • Optimal code paths for each endpoint
      • Minimal memory allocation
      • Full compiler optimizations applied

      DEVELOPMENT BENEFITS:
      • Auto-completion for all generated methods
      • Compile-time error checking
      • Refactoring safety across API changes
      • Documentation generation from protocol definitions

      """
    )
  }
}
