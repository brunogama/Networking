#if MACRO_TESTS_ENABLED
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import MacroTesting
@testable import NetworkingMacros

final class MacroExpansionTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(isRecording: false, macros: testMacros) {
      super.invokeTest()
    }
  }

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

  // MARK: - API Macro Tests

  func testBasicAPIGeneration() {
    assertMacro {
      """
      @API(baseURL: "https://api.example.com")
      protocol UserAPI {
          @GET("/users/{id}")
          func getUser(@Path id: String) async throws -> User
      }
      """
    } expansion: {
      """
      protocol UserAPI {
          @GET("/users/{id}")
          func getUser(@Path id: String) async throws -> User
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
                      GET("/users/{id}").replacingOccurrences(of: "{id}", with: String(id))
                  }

                  let response = try await client.execute(request)
                  return try response.decode(User.self)
              }
          }
      }
      """
    }
  }

  func testPOSTWithBodyGeneration() {
    assertMacro {
      """
      @API(baseURL: "https://api.example.com")
      protocol UserAPI {
          @POST("/users")
          func createUser(@Body user: User) async throws -> User
      }
      """
    } expansion: {
      """
      protocol UserAPI {
          @POST("/users")
          func createUser(@Body user: User) async throws -> User
      }

      extension UserAPI {
          public struct UserAPIImplementation: UserAPI {
              private let client: HTTPClient
              private let baseURL: String = "https://api.example.com"

              public init(client: HTTPClient = NetworkClient()) {
                  self.client = client
              }

              public func createUser(user: User) async throws -> User {
                  let request = try HTTPRequest {
                      BaseURL(baseURL)
                      POST("/users")
                      JSONBody(user)
                  }

                  let response = try await client.execute(request)
                  return try response.decode(User.self)
              }
          }
      }
      """
    }
  }

  func testComplexAPIWithMultipleParameters() {
    assertMacro {
      """
      @API(baseURL: "https://api.example.com")
      protocol ProductAPI {
          @PUT("/products/{id}")
          func updateProduct(@Path id: String, @Body product: Product, @Query force: Bool, @Header("Authorization") authorization: String) async throws -> Product
      }
      """
    } expansion: {
      """
      protocol ProductAPI {
          @PUT("/products/{id}")
          func updateProduct(@Path id: String, @Body product: Product, @Query force: Bool, @Header("Authorization") authorization: String) async throws -> Product
      }

      extension ProductAPI {
          public struct ProductAPIImplementation: ProductAPI {
              private let client: HTTPClient
              private let baseURL: String = "https://api.example.com"

              public init(client: HTTPClient = NetworkClient()) {
                  self.client = client
              }

              public func updateProduct(id: String, product: Product, force: Bool, authorization: String) async throws -> Product {
                  let request = try HTTPRequest {
                      BaseURL(baseURL)
                      PUT("/products/{id}").replacingOccurrences(of: "{id}", with: String(id))
                      QueryParam("force", force)
                      Header("Authorization", authorization)
                      JSONBody(product)
                  }

                  let response = try await client.execute(request)
                  return try response.decode(Product.self)
              }
          }
      }
      """
    }
  }

  func testVoidReturnType() {
    assertMacro {
      """
      @API(baseURL: "https://api.example.com")
      protocol UserAPI {
          @DELETE("/users/{id}")
          func deleteUser(@Path id: String) async throws
      }
      """
    } expansion: {
      """
      protocol UserAPI {
          @DELETE("/users/{id}")
          func deleteUser(@Path id: String) async throws
      }

      extension UserAPI {
          public struct UserAPIImplementation: UserAPI {
              private let client: HTTPClient
              private let baseURL: String = "https://api.example.com"

              public init(client: HTTPClient = NetworkClient()) {
                  self.client = client
              }

              public func deleteUser(id: String) async throws {
                  let request = try HTTPRequest {
                      BaseURL(baseURL)
                      DELETE("/users/{id}").replacingOccurrences(of: "{id}", with: String(id))
                  }

                  let response = try await client.execute(request)
                  return
              }
          }
      }
      """
    }
  }

  func testPATCHMethod() {
    assertMacro {
      """
      @API(baseURL: "https://api.example.com")
      protocol UserAPI {
          @PATCH("/users/{id}")
          func updateUserPartial(@Path id: String, @Body updates: UserUpdates) async throws -> User
      }
      """
    } expansion: {
      """
      protocol UserAPI {
          @PATCH("/users/{id}")
          func updateUserPartial(@Path id: String, @Body updates: UserUpdates) async throws -> User
      }

      extension UserAPI {
          public struct UserAPIImplementation: UserAPI {
              private let client: HTTPClient
              private let baseURL: String = "https://api.example.com"

              public init(client: HTTPClient = NetworkClient()) {
                  self.client = client
              }

              public func updateUserPartial(id: String, updates: UserUpdates) async throws -> User {
                  let request = try HTTPRequest {
                      BaseURL(baseURL)
                      PATCH("/users/{id}").replacingOccurrences(of: "{id}", with: String(id))
                      JSONBody(updates)
                  }

                  let response = try await client.execute(request)
                  return try response.decode(User.self)
              }
          }
      }
      """
    }
  }

  func testMultiplePathParameters() {
    assertMacro {
      """
      @API(baseURL: "https://api.example.com")
      protocol OrderAPI {
          @GET("/users/{userId}/orders/{orderId}")
          func getUserOrder(@Path userId: String, @Path orderId: String) async throws -> Order
      }
      """
    } expansion: {
      """
      protocol OrderAPI {
          @GET("/users/{userId}/orders/{orderId}")
          func getUserOrder(@Path userId: String, @Path orderId: String) async throws -> Order
      }

      extension OrderAPI {
          public struct OrderAPIImplementation: OrderAPI {
              private let client: HTTPClient
              private let baseURL: String = "https://api.example.com"

              public init(client: HTTPClient = NetworkClient()) {
                  self.client = client
              }

              public func getUserOrder(userId: String, orderId: String) async throws -> Order {
                  let request = try HTTPRequest {
                      BaseURL(baseURL)
                      GET("/users/{userId}/orders/{orderId}").replacingOccurrences(of: "{userId}", with: String(userId)).replacingOccurrences(of: "{orderId}", with: String(orderId))
                  }

                  let response = try await client.execute(request)
                  return try response.decode(Order.self)
              }
          }
      }
      """
    }
  }

  // MARK: - Error Cases Tests

  func testAPIOnNonProtocol() {
    assertMacro {
      """
      @API(baseURL: "https://api.example.com")
      struct NotAProtocol {
          func someMethod() {}
      }
      """
    } diagnostics: {
      """
      @API(baseURL: "https://api.example.com")
      ┬───────────────────────────────────
      ╰─ 🛑 Invalid macro usage: @API can only be applied to protocols
      struct NotAProtocol {
          func someMethod() {}
      }
      """
    }
  }

  func testMissingBaseURL() {
    assertMacro {
      """
      @API
      protocol UserAPI {
          @GET("/users")
          func getUsers() async throws -> [User]
      }
      """
    } diagnostics: {
      """
      @API
      ┬───
      ╰─ 🛑 Missing required annotation: @API requires a baseURL parameter
      protocol UserAPI {
          @GET("/users")
          func getUsers() async throws -> [User]
      }
      """
    }
  }

  func testMissingHTTPMethodAnnotation() {
    assertMacro {
      """
      @API(baseURL: "https://api.example.com")
      protocol UserAPI {
          func getUsers() async throws -> [User]
      }
      """
    } diagnostics: {
      """
      @API(baseURL: "https://api.example.com")
      protocol UserAPI {
          func getUsers() async throws -> [User]
          ┬──────────────────────────────────────
          ╰─ 🛑 Missing required annotation: Method must have HTTP method annotation (@GET, @POST, etc.)
      }
      """
    }
  }

  // MARK: - Parameter Macro Tests

  func testParameterMacrosAreInformational() {
    // Parameter macros should not generate any peer declarations
    assertMacro {
      """
      func testMethod(@Path id: String) {}
      """
    } expansion: {
      """
      func testMethod(@Path id: String) {}
      """
    }

    assertMacro {
      """
      func testMethod(@Body user: User) {}
      """
    } expansion: {
      """
      func testMethod(@Body user: User) {}
      """
    }

    assertMacro {
      """
      func testMethod(@Query filter: String) {}
      """
    } expansion: {
      """
      func testMethod(@Query filter: String) {}
      """
    }

    assertMacro {
      """
      func testMethod(@Header("X-Auth") auth: String) {}
      """
    } expansion: {
      """
      func testMethod(@Header("X-Auth") auth: String) {}
      """
    }
  }

  // MARK: - Custom Name Parameter Tests

  func testPathWithCustomName() {
    assertMacro {
      """
      @API(baseURL: "https://api.example.com")
      protocol UserAPI {
          @GET("/users/{user_id}")
          func getUser(@Path("user_id") userId: String) async throws -> User
      }
      """
    } expansion: {
      """
      protocol UserAPI {
          @GET("/users/{user_id}")
          func getUser(@Path("user_id") userId: String) async throws -> User
      }

      extension UserAPI {
          public struct UserAPIImplementation: UserAPI {
              private let client: HTTPClient
              private let baseURL: String = "https://api.example.com"

              public init(client: HTTPClient = NetworkClient()) {
                  self.client = client
              }

              public func getUser(userId: String) async throws -> User {
                  let request = try HTTPRequest {
                      BaseURL(baseURL)
                      GET("/users/{user_id}").replacingOccurrences(of: "{user_id}", with: String(userId))
                  }

                  let response = try await client.execute(request)
                  return try response.decode(User.self)
              }
          }
      }
      """
    }
  }

  func testQueryWithCustomName() {
    assertMacro {
      """
      @API(baseURL: "https://api.example.com")
      protocol SearchAPI {
          @GET("/search")
          func search(@Query("page_size") pageSize: Int) async throws -> SearchResults
      }
      """
    } expansion: {
      """
      protocol SearchAPI {
          @GET("/search")
          func search(@Query("page_size") pageSize: Int) async throws -> SearchResults
      }

      extension SearchAPI {
          public struct SearchAPIImplementation: SearchAPI {
              private let client: HTTPClient
              private let baseURL: String = "https://api.example.com"

              public init(client: HTTPClient = NetworkClient()) {
                  self.client = client
              }

              public func search(pageSize: Int) async throws -> SearchResults {
                  let request = try HTTPRequest {
                      BaseURL(baseURL)
                      GET("/search")
                      QueryParam("page_size", pageSize)
                  }

                  let response = try await client.execute(request)
                  return try response.decode(SearchResults.self)
              }
          }
      }
      """
    }
  }

  func testHeaderWithCustomName() {
    assertMacro {
      """
      @API(baseURL: "https://api.example.com")
      protocol UserAPI {
          @GET("/users")
          func getUsers(@Header("X-Request-ID") requestId: String) async throws -> [User]
      }
      """
    } expansion: {
      """
      protocol UserAPI {
          @GET("/users")
          func getUsers(@Header("X-Request-ID") requestId: String) async throws -> [User]
      }

      extension UserAPI {
          public struct UserAPIImplementation: UserAPI {
              private let client: HTTPClient
              private let baseURL: String = "https://api.example.com"

              public init(client: HTTPClient = NetworkClient()) {
                  self.client = client
              }

              public func getUsers(requestId: String) async throws -> [User] {
                  let request = try HTTPRequest {
                      BaseURL(baseURL)
                      GET("/users")
                      Header("X-Request-ID", requestId)
                  }

                  let response = try await client.execute(request)
                  return try response.decode([User].self)
              }
          }
      }
      """
    }
  }

  func testMixedCustomAndDefaultNames() {
    assertMacro {
      """
      @API(baseURL: "https://api.example.com")
      protocol OrderAPI {
          @GET("/users/{user_id}/orders")
          func getUserOrders(@Path("user_id") userId: String, @Query status: String, @Query("page_size") pageSize: Int, @Header("Authorization") auth: String) async throws -> [Order]
      }
      """
    } expansion: {
      """
      protocol OrderAPI {
          @GET("/users/{user_id}/orders")
          func getUserOrders(@Path("user_id") userId: String, @Query status: String, @Query("page_size") pageSize: Int, @Header("Authorization") auth: String) async throws -> [Order]
      }

      extension OrderAPI {
          public struct OrderAPIImplementation: OrderAPI {
              private let client: HTTPClient
              private let baseURL: String = "https://api.example.com"

              public init(client: HTTPClient = NetworkClient()) {
                  self.client = client
              }

              public func getUserOrders(userId: String, status: String, pageSize: Int, auth: String) async throws -> [Order] {
                  let request = try HTTPRequest {
                      BaseURL(baseURL)
                      GET("/users/{user_id}/orders").replacingOccurrences(of: "{user_id}", with: String(userId))
                      QueryParam("status", status)
                      QueryParam("page_size", pageSize)
                      Header("Authorization", auth)
                  }

                  let response = try await client.execute(request)
                  return try response.decode([Order].self)
              }
          }
      }
      """
    }
  }

  func testHeaderMissingRequiredName() {
    assertMacro {
      """
      @API(baseURL: "https://api.example.com")
      protocol UserAPI {
          @GET("/users")
          func getUsers(@Header auth: String) async throws -> [User]
      }
      """
    } diagnostics: {
      """
      @API(baseURL: "https://api.example.com")
      protocol UserAPI {
          @GET("/users")
          func getUsers(@Header auth: String) async throws -> [User]
          ┬─────────────────────────────────────────────────────────────
          ╰─ 🛑 Missing required annotation: @Header requires a non-empty string argument
      }
      """
    }
  }

  // MARK: - HTTP Method Macro Tests

  func testHTTPMethodMacrosAreInformational() {
    // HTTP method macros should not generate any peer declarations
    assertMacro {
      """
      @GET("/users")
      func getUsers() {}
      """
    } expansion: {
      """
      @GET("/users")
      func getUsers() {}
      """
    }

    assertMacro {
      """
      @POST("/users")
      func createUser() {}
      """
    } expansion: {
      """
      @POST("/users")
      func createUser() {}
      """
    }

    assertMacro {
      """
      @PUT("/users/1")
      func updateUser() {}
      """
    } expansion: {
      """
      @PUT("/users/1")
      func updateUser() {}
      """
    }

    assertMacro {
      """
      @DELETE("/users/1")
      func deleteUser() {}
      """
    } expansion: {
      """
      @DELETE("/users/1")
      func deleteUser() {}
      """
    }

    assertMacro {
      """
      @PATCH("/users/1")
      func patchUser() {}
      """
    } expansion: {
      """
      @PATCH("/users/1")
      func patchUser() {}
      """
    }
  }

  // MARK: - Edge Cases

  func testEmptyProtocol() {
    assertMacro {
      """
      @API(baseURL: "https://api.example.com")
      protocol EmptyAPI {
      }
      """
    } expansion: {
      """
      protocol EmptyAPI {
      }

      extension EmptyAPI {
          public struct EmptyAPIImplementation: EmptyAPI {
              private let client: HTTPClient
              private let baseURL: String = "https://api.example.com"

              public init(client: HTTPClient = NetworkClient()) {
                  self.client = client
              }


          }
      }
      """
    }
  }

  func testComplexReturnTypes() {
    assertMacro {
      """
      @API(baseURL: "https://api.example.com")
      protocol DataAPI {
          @GET("/data")
          func getData() async throws -> [String: [UserData]]
      }
      """
    } expansion: {
      """
      protocol DataAPI {
          @GET("/data")
          func getData() async throws -> [String: [UserData]]
      }

      extension DataAPI {
          public struct DataAPIImplementation: DataAPI {
              private let client: HTTPClient
              private let baseURL: String = "https://api.example.com"

              public init(client: HTTPClient = NetworkClient()) {
                  self.client = client
              }

              public func getData() async throws -> [String: [UserData]] {
                  let request = try HTTPRequest {
                      BaseURL(baseURL)
                      GET("/data")
                  }

                  let response = try await client.execute(request)
                  return try response.decode([String: [UserData]].self)
              }
          }
      }
      """
    }
  }

  func testDefaultQueryParameters() {
    assertMacro {
      """
      @API(baseURL: "https://api.example.com")
      protocol SearchAPI {
          @GET("/search")
          func search(query: String, limit: Int) async throws -> SearchResults
      }
      """
    } expansion: {
      """
      protocol SearchAPI {
          @GET("/search")
          func search(query: String, limit: Int) async throws -> SearchResults
      }

      extension SearchAPI {
          public struct SearchAPIImplementation: SearchAPI {
              private let client: HTTPClient
              private let baseURL: String = "https://api.example.com"

              public init(client: HTTPClient = NetworkClient()) {
                  self.client = client
              }

              public func search(query: String, limit: Int) async throws -> SearchResults {
                  let request = try HTTPRequest {
                      BaseURL(baseURL)
                      GET("/search")
                      QueryParam("query", query)
                      QueryParam("limit", limit)
                  }

                  let response = try await client.execute(request)
                  return try response.decode(SearchResults.self)
              }
          }
      }
      """
    }
  }
}

// MARK: - Test Helper Types

struct User: Codable {
  let id: String
  let name: String
  let email: String
}

struct Product: Codable {
  let id: String
  let name: String
  let price: Double
}

struct UserUpdates: Codable {
  let name: String?
  let email: String?
}

struct Order: Codable {
  let id: String
  let userId: String
  let products: [Product]
}

struct UserData: Codable {
  let id: String
  let metadata: [String: String]
}

struct SearchResults: Codable {
  let items: [String]
  let total: Int
}
#endif
