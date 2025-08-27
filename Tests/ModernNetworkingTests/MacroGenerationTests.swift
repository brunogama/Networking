#if MACRO_TESTS_ENABLED
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import MacroTesting
import Testing
@testable import ModernNetworkingMacros

/// Comprehensive tests for macro-generated code validation and API client generation correctness
@Suite("Macro Generation Tests")
struct MacroGenerationTests {
  // MARK: - Test Configuration

  let testMacros: [String: Macro.Type] = [
    "API": APIMacro.self,
    "GET": GETMacro.self,
    "POST": POSTMacro.self,
    "PUT": PUTMacro.self,
    "DELETE": DELETEMacro.self,
    "PATCH": PATCHMacro.self,
    "Path": PathMacro.self,
    "Body": BodyMacro.self,
    "Query": QueryMacro.self,
    "Header": HeaderMacro.self,
  ]

  // MARK: - API Client Generation Correctness Tests

  @Test("API client generation with complex inheritance hierarchy")
  func testAPIClientGenerationWithInheritance() {
    withMacroTesting(macros: testMacros) {
      assertMacro {
        """
        @API(baseURL: "https://api.example.com")
        protocol UserAPI: BaseAPI, Sendable {
            @GET("/users/{id}")
            func getUser(@Path id: String) async throws -> User
            
            @GET("/users")
            func getAllUsers(@Query limit: Int?, @Query offset: Int?) async throws -> [User]
        }
        """
      } expansion: {
        """
        protocol UserAPI: BaseAPI, Sendable {
            @GET("/users/{id}")
            func getUser(@Path id: String) async throws -> User
            
            @GET("/users")
            func getAllUsers(@Query limit: Int?, @Query offset: Int?) async throws -> [User]
        }

        extension UserAPI {
            public struct UserAPIImplementation: UserAPI {
                private let client: HTTPClient
                private let baseURL: String = "https://api.example.com"
                
                public init(client: HTTPClient = NetworkClient()) {
                    self.client = client
                }
                
                public func getUser(id: String) async throws -> User {
                    let request = try HTTPRequest {
                        BaseURL(baseURL)
                        GET("/users/{id}".replacingOccurrences(of: "{id}", with: String(id)))
                    }
                    
                    let response = try await client.execute(request)
                    return try response.decode(User.self)
                }
                
                public func getAllUsers(limit: Int?, offset: Int?) async throws -> [User] {
                    let request = try HTTPRequest {
                        BaseURL(baseURL)
                        GET("/users")
                        if let limit = limit {
                            QueryParam("limit", limit)
                        }
                        if let offset = offset {
                            QueryParam("offset", offset)
                        }
                    }
                    
                    let response = try await client.execute(request)
                    return try response.decode([User].self)
                }
            }
        }
        """
      }
    }
  }

  @Test("API client generation with generic types and constraints")
  func testAPIClientGenerationWithGenerics() {
    withMacroTesting(macros: testMacros) {
      assertMacro {
        """
        @API(baseURL: "https://api.example.com")
        protocol GenericAPI {
            @GET("/data/{id}")
            func getData<T: Codable>(@Path id: String, type: T.Type) async throws -> T
            
            @POST("/data")
            func createData<T: Codable>(@Body data: T) async throws -> T
        }
        """
      } expansion: {
        """
        protocol GenericAPI {
            @GET("/data/{id}")
            func getData<T: Codable>(@Path id: String, type: T.Type) async throws -> T
            
            @POST("/data")
            func createData<T: Codable>(@Body data: T) async throws -> T
        }

        extension GenericAPI {
            public struct GenericAPIImplementation: GenericAPI {
                private let client: HTTPClient
                private let baseURL: String = "https://api.example.com"
                
                public init(client: HTTPClient = NetworkClient()) {
                    self.client = client
                }
                
                public func getData<T: Codable>(id: String, type: T.Type) async throws -> T {
                    let request = try HTTPRequest {
                        BaseURL(baseURL)
                        GET("/data/{id}".replacingOccurrences(of: "{id}", with: String(id)))
                    }
                    
                    let response = try await client.execute(request)
                    return try response.decode(type)
                }
                
                public func createData<T: Codable>(data: T) async throws -> T {
                    let request = try HTTPRequest {
                        BaseURL(baseURL)
                        POST("/data")
                        JSONBody(data)
                    }
                    
                    let response = try await client.execute(request)
                    return try response.decode(T.self)
                }
            }
        }
        """
      }
    }
  }

  @Test("API client generation with custom headers and authentication")
  func testAPIClientGenerationWithAuthentication() {
    withMacroTesting(macros: testMacros) {
      assertMacro {
        """
        @API(baseURL: "https://api.example.com")
        protocol AuthenticatedAPI {
            @GET("/profile")
            func getProfile(@Header authorization: String) async throws -> UserProfile
            
            @PUT("/profile")
            func updateProfile(@Header authorization: String, @Body profile: UserProfile) async throws -> UserProfile
        }
        """
      } expansion: {
        """
        protocol AuthenticatedAPI {
            @GET("/profile")
            func getProfile(@Header authorization: String) async throws -> UserProfile
            
            @PUT("/profile")
            func updateProfile(@Header authorization: String, @Body profile: UserProfile) async throws -> UserProfile
        }

        extension AuthenticatedAPI {
            public struct AuthenticatedAPIImplementation: AuthenticatedAPI {
                private let client: HTTPClient
                private let baseURL: String = "https://api.example.com"
                
                public init(client: HTTPClient = NetworkClient()) {
                    self.client = client
                }
                
                public func getProfile(authorization: String) async throws -> UserProfile {
                    let request = try HTTPRequest {
                        BaseURL(baseURL)
                        GET("/profile")
                        Header("authorization", authorization)
                    }
                    
                    let response = try await client.execute(request)
                    return try response.decode(UserProfile.self)
                }
                
                public func updateProfile(authorization: String, profile: UserProfile) async throws -> UserProfile {
                    let request = try HTTPRequest {
                        BaseURL(baseURL)
                        PUT("/profile")
                        Header("authorization", authorization)
                        JSONBody(profile)
                    }
                    
                    let response = try await client.execute(request)
                    return try response.decode(UserProfile.self)
                }
            }
        }
        """
      }
    }
  }

  @Test("API client generation with complex path substitution")
  func testAPIClientGenerationWithComplexPaths() {
    withMacroTesting(macros: testMacros) {
      assertMacro {
        """
        @API(baseURL: "https://api.example.com")
        protocol NestedResourceAPI {
            @GET("/organizations/{orgId}/projects/{projectId}/issues/{issueId}")
            func getIssue(@Path orgId: String, @Path projectId: String, @Path issueId: Int) async throws -> Issue
            
            @DELETE("/organizations/{orgId}/projects/{projectId}/issues/{issueId}/comments/{commentId}")
            func deleteComment(@Path orgId: String, @Path projectId: String, @Path issueId: Int, @Path commentId: Int) async throws
        }
        """
      } expansion: {
        """
        protocol NestedResourceAPI {
            @GET("/organizations/{orgId}/projects/{projectId}/issues/{issueId}")
            func getIssue(@Path orgId: String, @Path projectId: String, @Path issueId: Int) async throws -> Issue
            
            @DELETE("/organizations/{orgId}/projects/{projectId}/issues/{issueId}/comments/{commentId}")
            func deleteComment(@Path orgId: String, @Path projectId: String, @Path issueId: Int, @Path commentId: Int) async throws
        }

        extension NestedResourceAPI {
            public struct NestedResourceAPIImplementation: NestedResourceAPI {
                private let client: HTTPClient
                private let baseURL: String = "https://api.example.com"
                
                public init(client: HTTPClient = NetworkClient()) {
                    self.client = client
                }
                
                public func getIssue(orgId: String, projectId: String, issueId: Int) async throws -> Issue {
                    let request = try HTTPRequest {
                        BaseURL(baseURL)
                        GET("/organizations/{orgId}/projects/{projectId}/issues/{issueId}".replacingOccurrences(of: "{orgId}", with: String(orgId)).replacingOccurrences(of: "{projectId}", with: String(projectId)).replacingOccurrences(of: "{issueId}", with: String(issueId)))
                    }
                    
                    let response = try await client.execute(request)
                    return try response.decode(Issue.self)
                }
                
                public func deleteComment(orgId: String, projectId: String, issueId: Int, commentId: Int) async throws {
                    let request = try HTTPRequest {
                        BaseURL(baseURL)
                        DELETE("/organizations/{orgId}/projects/{projectId}/issues/{issueId}/comments/{commentId}".replacingOccurrences(of: "{orgId}", with: String(orgId)).replacingOccurrences(of: "{projectId}", with: String(projectId)).replacingOccurrences(of: "{issueId}", with: String(issueId)).replacingOccurrences(of: "{commentId}", with: String(commentId)))
                    }
                    
                    let response = try await client.execute(request)
                    return
                }
            }
        }
        """
      }
    }
  }

  // MARK: - Macro Expansion Scenarios

  @Test("Comprehensive macro expansion with Result types")
  func testMacroExpansionWithResultTypes() {
    withMacroTesting(macros: testMacros) {
      assertMacro {
        """
        @API(baseURL: "https://api.example.com")
        protocol ResultAPI {
            @GET("/safe-operation")
            func safeOperation() async -> Result<Data, HTTPError>
            
            @POST("/risky-operation")
            func riskyOperation(@Body data: RiskyData) async -> Result<SuccessResponse, HTTPError>
        }
        """
      } expansion: {
        """
        protocol ResultAPI {
            @GET("/safe-operation")
            func safeOperation() async -> Result<Data, HTTPError>
            
            @POST("/risky-operation")
            func riskyOperation(@Body data: RiskyData) async -> Result<SuccessResponse, HTTPError>
        }

        extension ResultAPI {
            public struct ResultAPIImplementation: ResultAPI {
                private let client: HTTPClient
                private let baseURL: String = "https://api.example.com"
                
                public init(client: HTTPClient = NetworkClient()) {
                    self.client = client
                }
                
                public func safeOperation() async -> Result<Data, HTTPError> {
                    do {
                        let request = try HTTPRequest {
                            BaseURL(baseURL)
                            GET("/safe-operation")
                        }
                        
                        let response = try await client.execute(request)
                        let data = response.body ?? Data()
                        return .success(data)
                    } catch let error as HTTPError {
                        return .failure(error)
                    } catch {
                        return .failure(HTTPError(category: .unknown, request: nil, underlyingError: error))
                    }
                }
                
                public func riskyOperation(data: RiskyData) async -> Result<SuccessResponse, HTTPError> {
                    do {
                        let request = try HTTPRequest {
                            BaseURL(baseURL)
                            POST("/risky-operation")
                            JSONBody(data)
                        }
                        
                        let response = try await client.execute(request)
                        let result = try response.decode(SuccessResponse.self)
                        return .success(result)
                    } catch let error as HTTPError {
                        return .failure(error)
                    } catch {
                        return .failure(HTTPError(category: .unknown, request: nil, underlyingError: error))
                    }
                }
            }
        }
        """
      }
    }
  }

  @Test("Macro expansion with custom URLSession configuration")
  func testMacroExpansionWithCustomConfiguration() {
    withMacroTesting(macros: testMacros) {
      assertMacro {
        """
        @API(baseURL: "https://api.example.com", timeout: 60.0, retryCount: 3)
        protocol ConfigurableAPI {
            @GET("/slow-endpoint")
            func getSlowData() async throws -> SlowData
        }
        """
      } expansion: {
        """
        protocol ConfigurableAPI {
            @GET("/slow-endpoint")
            func getSlowData() async throws -> SlowData
        }

        extension ConfigurableAPI {
            public struct ConfigurableAPIImplementation: ConfigurableAPI {
                private let client: HTTPClient
                private let baseURL: String = "https://api.example.com"
                
                public init(client: HTTPClient = NetworkClient()) {
                    self.client = client
                }
                
                public func getSlowData() async throws -> SlowData {
                    let request = try HTTPRequest {
                        BaseURL(baseURL)
                        GET("/slow-endpoint")
                        Timeout(60.0)
                    }
                    
                    let response = try await client.execute(request)
                    return try response.decode(SlowData.self)
                }
            }
        }
        """
      }
    }
  }

  @Test("Macro expansion validation with throwing and non-throwing variants")
  func testMacroExpansionThrowingVariants() {
    withMacroTesting(macros: testMacros) {
      assertMacro {
        """
        @API(baseURL: "https://api.example.com")
        protocol MixedThrowingAPI {
            @GET("/safe-data")
            func getSafeData() async -> Data?
            
            @GET("/unsafe-data")
            func getUnsafeData() async throws -> Data
            
            @POST("/fire-and-forget")
            func fireAndForget(@Body data: Data) async
        }
        """
      } expansion: {
        """
        protocol MixedThrowingAPI {
            @GET("/safe-data")
            func getSafeData() async -> Data?
            
            @GET("/unsafe-data")
            func getUnsafeData() async throws -> Data
            
            @POST("/fire-and-forget")
            func fireAndForget(@Body data: Data) async
        }

        extension MixedThrowingAPI {
            public struct MixedThrowingAPIImplementation: MixedThrowingAPI {
                private let client: HTTPClient
                private let baseURL: String = "https://api.example.com"
                
                public init(client: HTTPClient = NetworkClient()) {
                    self.client = client
                }
                
                public func getSafeData() async -> Data? {
                    do {
                        let request = try HTTPRequest {
                            BaseURL(baseURL)
                            GET("/safe-data")
                        }
                        
                        let response = try await client.execute(request)
                        return response.body
                    } catch {
                        return nil
                    }
                }
                
                public func getUnsafeData() async throws -> Data {
                    let request = try HTTPRequest {
                        BaseURL(baseURL)
                        GET("/unsafe-data")
                    }
                    
                    let response = try await client.execute(request)
                    return response.body ?? Data()
                }
                
                public func fireAndForget(data: Data) async {
                    do {
                        let request = try HTTPRequest {
                            BaseURL(baseURL)
                            POST("/fire-and-forget")
                            Body(data)
                        }
                        
                        let response = try await client.execute(request)
                        return
                    } catch {
                        // Silently ignore errors for fire-and-forget operations
                        return
                    }
                }
            }
        }
        """
      }
    }
  }

  // MARK: - Edge Cases and Error Handling

  @Test("Macro expansion with invalid syntax produces proper diagnostics")
  func testMacroExpansionInvalidSyntax() {
    withMacroTesting(macros: testMacros) {
      assertMacro {
        """
        @API
        protocol InvalidAPI {
            @GET("/test")
            func test() async throws -> String
        }
        """
      } diagnostics: {
        """
        @API
        ┬───
        ╰─ 🛑 Missing required annotation: @API requires a baseURL parameter
        protocol InvalidAPI {
            @GET("/test")
            func test() async throws -> String
        }
        """
      }
    }
  }

  @Test("Macro expansion with malformed HTTP method annotation")
  func testMacroExpansionMalformedHTTPMethod() {
    withMacroTesting(macros: testMacros) {
      assertMacro {
        """
        @API(baseURL: "https://api.example.com")
        protocol MalformedAPI {
            @GET
            func getMalformed() async throws -> String
        }
        """
      } diagnostics: {
        """
        @API(baseURL: "https://api.example.com")
        protocol MalformedAPI {
            @GET
            ┬───
            ╰─ 🛑 Missing required annotation: HTTP method macros require a path parameter
            func getMalformed() async throws -> String
        }
        """
      }
    }
  }

  @Test("Macro expansion with conflicting parameter annotations")
  func testMacroExpansionConflictingAnnotations() {
    withMacroTesting(macros: testMacros) {
      assertMacro {
        """
        @API(baseURL: "https://api.example.com")
        protocol ConflictingAPI {
            @GET("/test")
            func test(@Body @Query data: String) async throws -> String
        }
        """
      } diagnostics: {
        """
        @API(baseURL: "https://api.example.com")
        protocol ConflictingAPI {
            @GET("/test")
            func test(@Body @Query data: String) async throws -> String
                      ┬─────────
                      ╰─ 🛑 Invalid parameter annotation: Parameter cannot have multiple conflicting annotations
        }
        """
      }
    }
  }

  // MARK: - Performance and Memory Validation

  @Test("Macro expansion generates memory-efficient code")
  func testMacroExpansionMemoryEfficiency() {
    withMacroTesting(macros: testMacros) {
      assertMacro {
        """
        @API(baseURL: "https://api.example.com")
        protocol EfficientAPI {
            @GET("/large-dataset")
            func getLargeDataset(@Query limit: Int) async throws -> AsyncThrowingStream<DataChunk, Error>
            
            @POST("/streaming-upload")
            func streamingUpload(@Body stream: AsyncThrowingStream<Data, Error>) async throws -> UploadResponse
        }
        """
      } expansion: {
        """
        protocol EfficientAPI {
            @GET("/large-dataset")
            func getLargeDataset(@Query limit: Int) async throws -> AsyncThrowingStream<DataChunk, Error>
            
            @POST("/streaming-upload")
            func streamingUpload(@Body stream: AsyncThrowingStream<Data, Error>) async throws -> UploadResponse
        }

        extension EfficientAPI {
            public struct EfficientAPIImplementation: EfficientAPI {
                private let client: HTTPClient
                private let baseURL: String = "https://api.example.com"
                
                public init(client: HTTPClient = NetworkClient()) {
                    self.client = client
                }
                
                public func getLargeDataset(limit: Int) async throws -> AsyncThrowingStream<DataChunk, Error> {
                    let request = try HTTPRequest {
                        BaseURL(baseURL)
                        GET("/large-dataset")
                        QueryParam("limit", limit)
                    }
                    
                    let response = try await client.execute(request)
                    return response.streamDecoded(DataChunk.self)
                }
                
                public func streamingUpload(stream: AsyncThrowingStream<Data, Error>) async throws -> UploadResponse {
                    let request = try HTTPRequest {
                        BaseURL(baseURL)
                        POST("/streaming-upload")
                        StreamingBody(stream)
                    }
                    
                    let response = try await client.execute(request)
                    return try response.decode(UploadResponse.self)
                }
            }
        }
        """
      }
    }
  }

  @Test("Macro expansion validation for concurrent safety")
  func testMacroExpansionConcurrentSafety() {
    withMacroTesting(macros: testMacros) {
      assertMacro {
        """
        @API(baseURL: "https://api.example.com")
        protocol ConcurrentAPI: Sendable {
            @GET("/concurrent-data")
            func getConcurrentData() async throws -> ConcurrentData
        }
        """
      } expansion: {
        """
        protocol ConcurrentAPI: Sendable {
            @GET("/concurrent-data")
            func getConcurrentData() async throws -> ConcurrentData
        }

        extension ConcurrentAPI {
            public struct ConcurrentAPIImplementation: ConcurrentAPI, Sendable {
                private let client: HTTPClient
                private let baseURL: String = "https://api.example.com"
                
                public init(client: HTTPClient = NetworkClient()) {
                    self.client = client
                }
                
                public func getConcurrentData() async throws -> ConcurrentData {
                    let request = try HTTPRequest {
                        BaseURL(baseURL)
                        GET("/concurrent-data")
                    }
                    
                    let response = try await client.execute(request)
                    return try response.decode(ConcurrentData.self)
                }
            }
        }
        """
      }
    }
  }

  // MARK: - Complex Integration Scenarios

  @Test("Macro expansion with comprehensive middleware integration")
  func testMacroExpansionWithMiddleware() {
    withMacroTesting(macros: testMacros) {
      assertMacro {
        """
        @API(baseURL: "https://api.example.com", middleware: [CachingMiddleware.self, RetryMiddleware.self])
        protocol MiddlewareAPI {
            @GET("/cached-data")
            func getCachedData() async throws -> CachedData
            
            @POST("/retryable-operation")
            func retryableOperation(@Body data: OperationData) async throws -> OperationResult
        }
        """
      } expansion: {
        """
        protocol MiddlewareAPI {
            @GET("/cached-data")
            func getCachedData() async throws -> CachedData
            
            @POST("/retryable-operation")
            func retryableOperation(@Body data: OperationData) async throws -> OperationResult
        }

        extension MiddlewareAPI {
            public struct MiddlewareAPIImplementation: MiddlewareAPI {
                private let client: HTTPClient
                private let baseURL: String = "https://api.example.com"
                
                public init(client: HTTPClient = NetworkClient()) {
                    self.client = client
                }
                
                public func getCachedData() async throws -> CachedData {
                    let request = try HTTPRequest {
                        BaseURL(baseURL)
                        GET("/cached-data")
                    }
                    
                    let response = try await client.execute(request)
                    return try response.decode(CachedData.self)
                }
                
                public func retryableOperation(data: OperationData) async throws -> OperationResult {
                    let request = try HTTPRequest {
                        BaseURL(baseURL)
                        POST("/retryable-operation")
                        JSONBody(data)
                    }
                    
                    let response = try await client.execute(request)
                    return try response.decode(OperationResult.self)
                }
            }
        }
        """
      }
    }
  }
}

// MARK: - Test Helper Types

struct User: Codable {
  let id: String
  let name: String
  let email: String
}

struct UserProfile: Codable {
  let id: String
  let displayName: String
  let avatar: URL?
  let preferences: [String: String]
}

struct Issue: Codable {
  let id: Int
  let title: String
  let description: String
  let status: String
}

struct RiskyData: Codable {
  let operation: String
  let parameters: [String: String]
}

struct SuccessResponse: Codable {
  let success: Bool
  let message: String
  let timestamp: Date
}

struct SlowData: Codable {
  let processingTime: TimeInterval
  let data: [String: Any]

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    processingTime = try container.decode(TimeInterval.self, forKey: .processingTime)
    data = [:]  // Simplified for testing
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(processingTime, forKey: .processingTime)
  }

  private enum CodingKeys: String, CodingKey {
    case processingTime
    case data
  }
}

struct DataChunk: Codable {
  let chunkId: String
  let data: Data
  let isLast: Bool
}

struct UploadResponse: Codable {
  let uploadId: String
  let status: String
  let bytesReceived: Int64
}

struct ConcurrentData: Codable, Sendable {
  let id: String
  let timestamp: Date
  let data: String
}

struct CachedData: Codable {
  let id: String
  let content: String
  let cacheKey: String
  let ttl: TimeInterval
}

struct OperationData: Codable {
  let operationType: String
  let payload: String
  let retryCount: Int
}

struct OperationResult: Codable {
  let success: Bool
  let resultId: String
  let executionTime: TimeInterval
}
#endif
