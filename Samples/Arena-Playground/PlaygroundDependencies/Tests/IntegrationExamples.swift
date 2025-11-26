import Foundation
import Combine
import Networking

#if canImport(SwiftUI)
import SwiftUI
#endif

/// Real-world integration examples for production applications
/// Demonstrates complete patterns that can be directly adapted for real applications
public struct IntegrationExamples {
  // MARK: - Main Entry Point

  /// Run all integration examples
  public static func runAll() async {
    print("🚀 Running Integration Examples - Real-World Patterns")
    print("=" * 60)

    await restAPIClient()
    await swiftUIIntegration()
    await fileOperations()
    await backgroundTasks()
    await combineIntegration()
    await authenticationFlows()
    await offlineSync()

    print("✅ All integration examples completed!")
  }

  // MARK: - REST API Client Implementation

  /// Complete REST API client with CRUD operations
  public static func restAPIClient() async {
    print("\n📡 REST API Client Integration")
    print("-" * 40)

    // Complete API client architecture
    let apiClient = ProductAPIClient()

    do {
      // Create operation
      let newProduct = Product(id: nil, name: "iPhone 15", price: 999.99, category: "Electronics")
      let created = try await apiClient.createProduct(newProduct)
      print("✅ Created product: \(created.name) with ID: \(created.id!)")

      // Read operations
      let products = try await apiClient.getAllProducts()
      print("✅ Fetched \(products.count) products")

      let product = try await apiClient.getProduct(id: created.id!)
      print("✅ Retrieved product: \(product.name)")

      // Update operation
      var updatedProduct = product
      updatedProduct.price = 899.99
      let updated = try await apiClient.updateProduct(updatedProduct)
      print("✅ Updated product price: $\(updated.price)")

      // Delete operation
      try await apiClient.deleteProduct(id: updated.id!)
      print("✅ Deleted product successfully")
    } catch {
      print("❌ API Error: \(error)")
    }
  }

  // MARK: - SwiftUI Integration Patterns

  /// SwiftUI integration with reactive networking
  public static func swiftUIIntegration() async {
    print("\n🎨 SwiftUI Integration Patterns")
    print("-" * 40)

    #if canImport(SwiftUI)
    // Demonstrate SwiftUI view models with networking
    let viewModel = ProductListViewModel()

    // Simulate SwiftUI lifecycle
    print("🔄 Loading products in SwiftUI...")
    await viewModel.loadProducts()

    print("📱 SwiftUI State Updates:")
    print("  - Loading: \(viewModel.isLoading)")
    print("  - Products: \(viewModel.products.count)")
    print("  - Error: \(viewModel.errorMessage ?? "None")")

    // Simulate user interactions
    await viewModel.refreshProducts()
    await viewModel.searchProducts(query: "iPhone")
    #else
    print("⚠️ SwiftUI not available in this environment")
    #endif
  }

  // MARK: - File Operations with Progress

  /// File upload/download with progress tracking
  public static func fileOperations() async {
    print("\n📁 File Operations Integration")
    print("-" * 40)

    let fileClient = FileOperationsClient()

    // Simulate file upload with progress
    print("📤 Uploading file...")
    do {
      let uploadResult = try await fileClient.uploadFile(
        data: "Sample file content for testing upload".data(using: .utf8)!,
        fileName: "test.txt",
        mimeType: "text/plain"
      ) { progress in
        let percentage = Int(progress * 100)
        print("📊 Upload progress: \(percentage)%")
      }
      print("✅ File uploaded: \(uploadResult.fileURL)")

      // Simulate file download with progress
      print("\n📥 Downloading file...")
      let downloadedData = try await fileClient.downloadFile(
        url: uploadResult.fileURL
      ) { progress in
        let percentage = Int(progress * 100)
        print("📊 Download progress: \(percentage)%")
      }
      print("✅ Downloaded \(downloadedData.count) bytes")
    } catch {
      print("❌ File operation error: \(error)")
    }
  }

  // MARK: - Background Tasks Integration

  /// Background networking tasks
  public static func backgroundTasks() async {
    print("\n⏱️ Background Tasks Integration")
    print("-" * 40)

    let backgroundClient = BackgroundSyncClient()

    // Long-running sync operation
    print("🔄 Starting background sync...")
    let syncTask = Task {
      do {
        let result = try await backgroundClient.performBackgroundSync()
        print("✅ Background sync completed: \(result.syncedItems) items")
        return result
      } catch {
        print("❌ Background sync failed: \(error)")
        throw error
      }
    }

    // Simulate app backgrounding
    print("📱 App entering background mode...")

    // Wait for completion or timeout
    do {
      let result = try await withTimeout(seconds: 10) {
        try await syncTask.value
      }
      print("✅ Sync completed successfully")
    } catch {
      print("⚠️ Sync timeout or cancelled")
      syncTask.cancel()
    }
  }

  // MARK: - Combine Integration

  /// Reactive programming with Combine publishers
  public static func combineIntegration() async {
    print("\n🔄 Combine Integration Patterns")
    print("-" * 40)

    let reactiveClient = ReactiveNetworkingClient()

    // Create a subject for search queries
    let searchSubject = PassthroughSubject<String, Never>()

    // Set up reactive pipeline
    let cancellables = Set<AnyCancellable>()

    await withCheckedContinuation { continuation in
      // Search pipeline with debouncing and deduplication
      searchSubject
        .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
        .removeDuplicates()
        .flatMap { query in
          reactiveClient.searchProducts(query: query)
            .catch { error in
              print("❌ Search error: \(error)")
              return Just([])
            }
        }
        .sink { products in
          print("🔍 Found \(products.count) products")
          continuation.resume()
        }
        .store(in: &cancellables)

      // Simulate user typing
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        searchSubject.send("iPhone")
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
        searchSubject.send("iPad")
      }
    }

    // Real-time data stream
    print("\n📡 Real-time data streaming...")
    let streamCancellable = reactiveClient.connectToRealTimeUpdates()
      .sink(
        receiveCompletion: { completion in
          print("📡 Stream completed: \(completion)")
        },
        receiveValue: { update in
          print("📨 Real-time update: \(update.type) - \(update.data)")
        }
      )

    // Simulate some real-time updates
    try? await Task.sleep(nanoseconds: 2_000_000_000)
    streamCancellable.cancel()
  }

  // MARK: - Authentication Flows

  /// Complete authentication integration
  public static func authenticationFlows() async {
    print("\n🔐 Authentication Flow Integration")
    print("-" * 40)

    let authClient = AuthenticationClient()

    do {
      // Login flow
      print("📝 Performing login...")
      let loginResult = try await authClient.login(
        email: "user@example.com",
        password: "securepassword"
      )
      print("✅ Login successful: \(loginResult.user.name)")

      // Token refresh
      print("🔄 Refreshing token...")
      let newToken = try await authClient.refreshToken()
      print("✅ Token refreshed successfully")

      // Authenticated API call
      print("🔒 Making authenticated request...")
      let userProfile = try await authClient.getUserProfile()
      print("✅ Profile loaded: \(userProfile.name)")

      // Logout
      print("👋 Logging out...")
      try await authClient.logout()
      print("✅ Logout successful")
    } catch {
      print("❌ Authentication error: \(error)")
    }
  }

  // MARK: - Offline Support & Synchronization

  /// Offline/online synchronization patterns
  public static func offlineSync() async {
    print("\n📴 Offline/Online Synchronization")
    print("-" * 40)

    let syncManager = OfflineSyncManager()

    // Simulate offline operations
    print("📴 Going offline...")
    syncManager.setNetworkStatus(.offline)

    // Queue operations while offline
    await syncManager.queueOfflineOperation(.create, data: ["name": "Offline Product"])
    await syncManager.queueOfflineOperation(.update, data: ["id": "123", "price": 799.99])
    await syncManager.queueOfflineOperation(.delete, data: ["id": "456"])

    print("📦 Queued \(syncManager.pendingOperations.count) offline operations")

    // Go back online and sync
    print("🌐 Going online...")
    syncManager.setNetworkStatus(.online)

    let syncResult = await syncManager.performSync()
    print("✅ Sync completed:")
    print("  - Successful: \(syncResult.successful)")
    print("  - Failed: \(syncResult.failed)")
    print("  - Conflicts: \(syncResult.conflicts)")

    // Handle conflicts
    if !syncResult.conflicts.isEmpty {
      print("⚠️ Resolving conflicts...")
      for conflict in syncResult.conflicts {
        let resolution = await syncManager.resolveConflict(conflict, strategy: .serverWins)
        print("✅ Conflict resolved: \(resolution.strategy)")
      }
    }
  }
}

// MARK: - Supporting Models and Clients

// MARK: Product Models
public struct Product: Codable, Identifiable {
  public let id: String?
  public var name: String
  public var price: Double
  public var category: String

  public init(id: String? = nil, name: String, price: Double, category: String) {
    self.id = id
    self.name = name
    self.price = price
    self.category = category
  }
}

// MARK: - API Client Implementation
public class ProductAPIClient {
  private let baseURL = "https://api.example.com/v1"

  public init() {}

  public func getAllProducts() async throws -> [Product] {
    // Simulate API call
    try await Task.sleep(nanoseconds: 500_000_000)
    return [
      Product(id: "1", name: "iPhone 14", price: 899.99, category: "Electronics"),
      Product(id: "2", name: "iPad Air", price: 599.99, category: "Electronics"),
    ]
  }

  public func getProduct(id: String) async throws -> Product {
    try await Task.sleep(nanoseconds: 300_000_000)
    return Product(id: id, name: "iPhone 15", price: 999.99, category: "Electronics")
  }

  public func createProduct(_ product: Product) async throws -> Product {
    try await Task.sleep(nanoseconds: 400_000_000)
    var created = product
    created = Product(
      id: UUID().uuidString,
      name: created.name,
      price: created.price,
      category: created.category
    )
    return created
  }

  public func updateProduct(_ product: Product) async throws -> Product {
    try await Task.sleep(nanoseconds: 350_000_000)
    return product
  }

  public func deleteProduct(id: String) async throws {
    try await Task.sleep(nanoseconds: 200_000_000)
  }
}

// MARK: - SwiftUI Integration
#if canImport(SwiftUI)
@MainActor
public class ProductListViewModel: ObservableObject {
  @Published public var products: [Product] = []
  @Published public var isLoading = false
  @Published public var errorMessage: String?

  private let apiClient = ProductAPIClient()

  public init() {}

  public func loadProducts() async {
    isLoading = true
    errorMessage = nil

    do {
      products = try await apiClient.getAllProducts()
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  public func refreshProducts() async {
    await loadProducts()
  }

  public func searchProducts(query: String) async {
    isLoading = true

    // Simulate search
    try? await Task.sleep(nanoseconds: 500_000_000)

    let allProducts = try? await apiClient.getAllProducts()
    products = allProducts?.filter { $0.name.localizedCaseInsensitiveContains(query) } ?? []

    isLoading = false
  }
}
#endif

// MARK: - File Operations Client
public class FileOperationsClient {
  public struct UploadResult {
    public let fileURL: URL
    public let fileId: String
  }

  public init() {}

  public func uploadFile(
    data: Data,
    fileName: String,
    mimeType: String,
    progressHandler: @escaping (Double) -> Void
  ) async throws -> UploadResult {
    // Simulate upload progress
    for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
      try await Task.sleep(nanoseconds: 100_000_000)
      progressHandler(progress)
    }

    return UploadResult(
      fileURL: URL(string: "https://cdn.example.com/files/\(fileName)")!,
      fileId: UUID().uuidString
    )
  }

  public func downloadFile(
    url: URL,
    progressHandler: @escaping (Double) -> Void
  ) async throws -> Data {
    // Simulate download progress
    for progress in stride(from: 0.0, through: 1.0, by: 0.15) {
      try await Task.sleep(nanoseconds: 150_000_000)
      progressHandler(progress)
    }

    return "Downloaded file content".data(using: .utf8)!
  }
}

// MARK: - Background Sync Client
public class BackgroundSyncClient {
  public struct SyncResult {
    public let syncedItems: Int
    public let timestamp: Date
  }

  public init() {}

  public func performBackgroundSync() async throws -> SyncResult {
    print("🔄 Syncing data in background...")

    // Simulate long-running sync
    for i in 1...5 {
      try await Task.sleep(nanoseconds: 1_000_000_000)
      print("📊 Sync progress: \(i)/5 batches completed")

      // Check if cancelled
      try Task.checkCancellation()
    }

    return SyncResult(syncedItems: 250, timestamp: Date())
  }
}

// MARK: - Reactive Networking Client
public class ReactiveNetworkingClient {
  public struct RealTimeUpdate {
    public let type: String
    public let data: [String: Any]
    public let timestamp: Date
  }

  public init() {}

  public func searchProducts(query: String) -> AnyPublisher<[Product], Error> {
    Future { promise in
      Task {
        try await Task.sleep(nanoseconds: 200_000_000)

        let results = [
          Product(id: "1", name: "\(query) Pro", price: 999.99, category: "Electronics"),
          Product(id: "2", name: "\(query) Mini", price: 599.99, category: "Electronics"),
        ]

        promise(.success(results))
      }
    }
    .eraseToAnyPublisher()
  }

  public func connectToRealTimeUpdates() -> AnyPublisher<RealTimeUpdate, Error> {
    Timer.publish(every: 0.5, on: .main, in: .common)
      .autoconnect()
      .map { _ in
        RealTimeUpdate(
          type: "product_update",
          data: ["id": UUID().uuidString, "action": "updated"],
          timestamp: Date()
        )
      }
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
  }
}

// MARK: - Authentication Client
public class AuthenticationClient {
  public struct LoginResult {
    public let user: User
    public let token: String
    public let refreshToken: String
  }

  public struct User {
    public let id: String
    public let name: String
    public let email: String
  }

  public init() {}

  public func login(email: String, password: String) async throws -> LoginResult {
    try await Task.sleep(nanoseconds: 800_000_000)

    return LoginResult(
      user: User(id: "user123", name: "John Doe", email: email),
      token: "jwt_token_here",
      refreshToken: "refresh_token_here"
    )
  }

  public func refreshToken() async throws -> String {
    try await Task.sleep(nanoseconds: 300_000_000)
    return "new_jwt_token_here"
  }

  public func getUserProfile() async throws -> User {
    try await Task.sleep(nanoseconds: 400_000_000)
    return User(id: "user123", name: "John Doe", email: "user@example.com")
  }

  public func logout() async throws {
    try await Task.sleep(nanoseconds: 200_000_000)
  }
}

// MARK: - Offline Sync Manager
public class OfflineSyncManager {
  public enum NetworkStatus {
    case online, offline
  }

  public enum OperationType {
    case create, update, delete
  }

  public struct OfflineOperation {
    public let id: String
    public let type: OperationType
    public let data: [String: Any]
    public let timestamp: Date
  }

  public struct SyncResult {
    public let successful: Int
    public let failed: Int
    public let conflicts: [SyncConflict]
  }

  public struct SyncConflict {
    public let operationId: String
    public let localData: [String: Any]
    public let serverData: [String: Any]
  }

  public struct ConflictResolution {
    public let strategy: ConflictStrategy
    public let resolvedData: [String: Any]
  }

  public enum ConflictStrategy {
    case clientWins, serverWins, merge
  }

  public private(set) var networkStatus: NetworkStatus = .online
  public private(set) var pendingOperations: [OfflineOperation] = []

  public init() {}

  public func setNetworkStatus(_ status: NetworkStatus) {
    networkStatus = status
  }

  public func queueOfflineOperation(_ type: OperationType, data: [String: Any]) async {
    let operation = OfflineOperation(
      id: UUID().uuidString,
      type: type,
      data: data,
      timestamp: Date()
    )
    pendingOperations.append(operation)
  }

  public func performSync() async -> SyncResult {
    var successful = 0
    var failed = 0
    var conflicts: [SyncConflict] = []

    for operation in pendingOperations {
      do {
        // Simulate network sync
        try await Task.sleep(nanoseconds: 300_000_000)

        // Simulate conflict detection (20% chance)
        if Int.random(in: 1...100) <= 20 {
          let conflict = SyncConflict(
            operationId: operation.id,
            localData: operation.data,
            serverData: ["server_version": "2.0", "updated_at": Date()]
          )
          conflicts.append(conflict)
        } else {
          successful += 1
        }
      } catch {
        failed += 1
      }
    }

    // Clear successful operations
    pendingOperations.removeAll { operation in
      !conflicts.contains { $0.operationId == operation.id }
    }

    return SyncResult(successful: successful, failed: failed, conflicts: conflicts)
  }

  public func resolveConflict(
    _ conflict: SyncConflict,
    strategy: ConflictStrategy
  ) async -> ConflictResolution {
    try? await Task.sleep(nanoseconds: 200_000_000)

    let resolvedData: [String: Any]

    switch strategy {
    case .clientWins:
      resolvedData = conflict.localData

    case .serverWins:
      resolvedData = conflict.serverData

    case .merge:
      resolvedData = conflict.localData.merging(conflict.serverData) { local, _ in local }
    }

    return ConflictResolution(strategy: strategy, resolvedData: resolvedData)
  }
}

// MARK: - Utility Functions
public func withTimeout<T>(
  seconds: TimeInterval,
  operation: @escaping () async throws -> T
) async throws -> T {
  try await withThrowingTaskGroup(of: T.self) { group in
    group.addTask {
      try await operation()
    }

    group.addTask {
      try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
      throw TimeoutError()
    }

    let result = try await group.next()!
    group.cancelAll()
    return result
  }
}

public struct TimeoutError: Error {
  public let message = "Operation timed out"
}

// String multiplication for formatting
private extension String {
  static func * (string: String, count: Int) -> String {
    String(repeating: string, count: count)
  }
}
