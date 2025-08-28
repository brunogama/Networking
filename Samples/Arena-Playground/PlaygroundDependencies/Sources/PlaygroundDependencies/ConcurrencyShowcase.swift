/// # Swift 6 Concurrency Showcase
///
/// This file demonstrates modern Swift 6 concurrency patterns for networking applications,
/// showcasing structured concurrency, async sequences, actors, and advanced async/await patterns.
/// These examples emphasize data race safety, proper cancellation, and performance optimization.

import Foundation
import Networking

/// Collection of Swift 6 concurrency examples demonstrating modern async networking patterns
///
/// ## Key Concepts Demonstrated
///
/// - **Structured Concurrency**: TaskGroup for parallel operations
/// - **AsyncSequence**: Streaming data processing and pagination
/// - **Actors**: Thread-safe networking components
/// - **AsyncStream**: Real-time progress and server-sent events
/// - **Cancellation**: Proper cleanup and cancellation propagation
/// - **Sendable Types**: Data race-free networking operations
/// - **async let**: Concurrent independent requests
///
/// ## Swift 6 Safety Features
///
/// All examples are designed with Swift 6's strict concurrency checking in mind,
/// ensuring complete data race safety and proper isolation.
public struct ConcurrencyShowcase {
  // MARK: - Public Interface

  /// Runs all concurrency examples showcasing Swift 6 patterns
  public static func runAll() async {
    print("\n⚡ Swift 6 Concurrency Showcase")
    print("-" * 40)

    await structuredConcurrency()
    await asyncSequencePatterns()
    await actorIntegration()
    await asyncStreamExamples()
    await cancellationHandling()
    await performanceBenefits()
  }

  // MARK: - Structured Concurrency

  /// Demonstrates structured concurrency with TaskGroup for parallel networking
  ///
  /// Shows:
  /// - TaskGroup for parallel requests
  /// - Proper error handling across tasks
  /// - Result aggregation from multiple sources
  /// - Automatic cleanup on cancellation
  public static func structuredConcurrency() async {
    print("🔹 Structured Concurrency with TaskGroup")

    let startTime = ContinuousClock().now

    do {
      // Parallel API requests using TaskGroup
      let results = try await withThrowingTaskGroup(
        of: APIResponse.self,
        returning: [APIResponse].self
      ) { group in
        let endpoints = [
          "https://httpbin.org/delay/1",
          "https://httpbin.org/json",
          "https://httpbin.org/uuid",
          "https://httpbin.org/user-agent",
        ]

        // Add tasks to the group
        for (index, endpoint) in endpoints.enumerated() {
          group.addTask {
            let client = HTTPClient()
            let request = HTTPRequest.get(endpoint)
            let response = try await client.send(request)
            return APIResponse(
              id: index,
              endpoint: endpoint,
              status: response.status.rawValue,
              dataSize: response.body?.count ?? 0
            )
          }
        }

        // Collect all results
        var responses: [APIResponse] = []
        for try await response in group {
          responses.append(response)
        }
        return responses.sorted { $0.id < $1.id }
      }

      let duration = ContinuousClock().now - startTime
      print("   ✅ Completed \(results.count) parallel requests")
      print("   ⏱️  Total time: \(duration.formatted())")

      for result in results {
        print("   📊 ID \(result.id): Status \(result.status), Size: \(result.dataSize) bytes")
      }

    } catch {
      print("   ❌ TaskGroup error: \(error)")
    }
  }

  // MARK: - AsyncSequence Patterns

  /// Demonstrates AsyncSequence for streaming and paginated data
  ///
  /// Shows:
  /// - Custom AsyncSequence implementation
  /// - Streaming JSON processing
  /// - Paginated API consumption
  /// - Lazy async iteration
  public static func asyncSequencePatterns() async {
    print("🔹 AsyncSequence for Streaming Data")

    do {
      // Example 1: Streaming paginated data
      let paginator = PaginatedAPISequence(baseURL: "https://httpbin.org/json")
      var itemCount = 0

      for try await item in paginator.prefix(3) {
        itemCount += 1
        print("   📄 Page \(itemCount): \(item.summary)")
      }

      // Example 2: Async transformation pipeline
      let transformedData =
        paginator
        .prefix(5)
        .compactMap { response in
          response.dataSize > 100 ? response : nil
        }

      var filteredCount = 0
      for try await item in transformedData {
        filteredCount += 1
        print("   🔍 Filtered item \(filteredCount): \(item.dataSize) bytes")
      }

    } catch {
      print("   ❌ AsyncSequence error: \(error)")
    }
  }

  // MARK: - Actor Integration

  /// Demonstrates actors for thread-safe networking components
  ///
  /// Shows:
  /// - Actor-based request caching
  /// - Thread-safe connection pooling
  /// - Isolated state management
  /// - Actor re-entrancy handling
  public static func actorIntegration() async {
    print("🔹 Actor-Based Thread-Safe Networking")

    let cache = NetworkCache()
    let connectionPool = ConnectionPool()

    do {
      // Demonstrate concurrent cache access
      async let response1 = cache.get(url: "https://httpbin.org/json")
      async let response2 = cache.get(url: "https://httpbin.org/uuid")
      async let response3 = cache.get(url: "https://httpbin.org/json")  // Should hit cache

      let results = try await [response1, response2, response3]

      for (index, result) in results.enumerated() {
        print("   🎯 Request \(index + 1): \(result.fromCache ? "Cache HIT" : "Cache MISS")")
        print("      Size: \(result.dataSize) bytes")
      }

      // Demonstrate connection pooling
      let poolStats = await connectionPool.getStats()
      print("   🔌 Active connections: \(poolStats.activeConnections)")
      print("   📈 Total requests: \(poolStats.totalRequests)")

    } catch {
      print("   ❌ Actor integration error: \(error)")
    }
  }

  // MARK: - AsyncStream Examples

  /// Demonstrates AsyncStream for real-time progress and events
  ///
  /// Shows:
  /// - Progress tracking with AsyncStream
  /// - Server-sent events simulation
  /// - Real-time data updates
  /// - Stream cancellation handling
  public static func asyncStreamExamples() async {
    print("🔹 AsyncStream for Real-Time Updates")

    // Example 1: Download progress tracking
    let progressStream = createProgressStream()

    print("   📥 Simulating file download with progress...")
    for await progress in progressStream {
      let percentage = Int(progress * 100)
      let progressBar =
        String(repeating: "█", count: percentage / 5)
        + String(repeating: "░", count: 20 - percentage / 5)
      print("   [\(progressBar)] \(percentage)%", terminator: "\r")

      if progress >= 1.0 {
        print("\n   ✅ Download complete!")
        break
      }
    }

    // Example 2: Server-sent events simulation
    print("   📡 Simulating server-sent events...")
    let eventStream = createServerEventStream()
    var eventCount = 0

    for await event in eventStream {
      eventCount += 1
      print("   🎪 Event \(eventCount): \(event.type) - \(event.data)")

      if eventCount >= 5 {
        break
      }
    }
  }

  // MARK: - Cancellation Handling

  /// Demonstrates proper cancellation handling and cleanup
  ///
  /// Shows:
  /// - Task cancellation propagation
  /// - Resource cleanup on cancellation
  /// - Cooperative cancellation checking
  /// - Timeout handling with cancellation
  public static func cancellationHandling() async {
    print("🔹 Cancellation and Cleanup Patterns")

    // Example 1: Cancellable long-running task
    let task = Task {
      try await performLongRunningOperation()
    }

    // Simulate cancellation after 2 seconds
    Task {
      try await Task.sleep(for: .seconds(2))
      task.cancel()
      print("   🚫 Task cancelled after 2 seconds")
    }

    do {
      let result = try await task.value
      print("   ✅ Task completed: \(result)")
    } catch is CancellationError {
      print("   ⚠️  Task was properly cancelled")
    } catch {
      print("   ❌ Task failed: \(error)")
    }

    // Example 2: Timeout with automatic cancellation
    do {
      let result = try await withTimeout(seconds: 3) {
        try await simulateSlowNetworkCall()
      }
      print("   ⏱️  Operation completed within timeout: \(result)")
    } catch is TimeoutError {
      print("   ⏰ Operation timed out and was cancelled")
    } catch {
      print("   ❌ Operation failed: \(error)")
    }
  }

  // MARK: - Performance Benefits

  /// Demonstrates performance benefits of concurrent networking
  ///
  /// Shows:
  /// - Sequential vs concurrent request comparison
  /// - Throughput improvements
  /// - Resource utilization benefits
  /// - Performance metrics collection
  public static func performanceBenefits() async {
    print("🔹 Performance: Sequential vs Concurrent")

    let endpoints = [
      "https://httpbin.org/delay/1",
      "https://httpbin.org/delay/1",
      "https://httpbin.org/delay/1",
      "https://httpbin.org/delay/1",
    ]

    // Sequential execution
    let sequentialStart = ContinuousClock().now
    var sequentialResults: [HTTPResponse] = []

    for endpoint in endpoints {
      do {
        let client = HTTPClient()
        let request = HTTPRequest.get(endpoint)
        let response = try await client.send(request)
        sequentialResults.append(response)
      } catch {
        print("   ❌ Sequential request failed: \(error)")
      }
    }

    let sequentialDuration = ContinuousClock().now - sequentialStart

    // Concurrent execution
    let concurrentStart = ContinuousClock().now

    let concurrentResults = await withTaskGroup(
      of: HTTPResponse?.self,
      returning: [HTTPResponse].self
    ) { group in
      for endpoint in endpoints {
        group.addTask {
          do {
            let client = HTTPClient()
            let request = HTTPRequest.get(endpoint)
            return try await client.send(request)
          } catch {
            print("   ❌ Concurrent request failed: \(error)")
            return nil
          }
        }
      }

      var results: [HTTPResponse] = []
      for await result in group {
        if let result = result {
          results.append(result)
        }
      }
      return results
    }

    let concurrentDuration = ContinuousClock().now - concurrentStart

    // Performance comparison
    let improvement = sequentialDuration.timeInterval / concurrentDuration.timeInterval

    print("   📊 Performance Results:")
    print(
      "      Sequential: \(sequentialDuration.formatted()) (\(sequentialResults.count) requests)"
    )
    print(
      "      Concurrent: \(concurrentDuration.formatted()) (\(concurrentResults.count) requests)"
    )
    print("      🚀 Speedup: \(String(format: "%.2f", improvement))x faster")
  }
}

// MARK: - Supporting Types and Actors

/// Sendable response type for safe concurrent operations
public struct APIResponse: Sendable {
  let id: Int
  let endpoint: String
  let status: Int
  let dataSize: Int
  let fromCache: Bool
  let timestamp: Date

  init(id: Int, endpoint: String, status: Int, dataSize: Int, fromCache: Bool = false) {
    self.id = id
    self.endpoint = endpoint
    self.status = status
    self.dataSize = dataSize
    self.fromCache = fromCache
    self.timestamp = Date()
  }

  var summary: String {
    "Status \(status), \(dataSize) bytes"
  }
}

/// AsyncSequence for paginated API consumption
public struct PaginatedAPISequence: AsyncSequence {
  public typealias Element = APIResponse

  private let baseURL: String

  init(baseURL: String) {
    self.baseURL = baseURL
  }

  public func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(baseURL: baseURL)
  }

  public struct AsyncIterator: AsyncIteratorProtocol {
    private let baseURL: String
    private var currentPage = 0
    private let client = HTTPClient()

    init(baseURL: String) {
      self.baseURL = baseURL
    }

    public mutating func next() async throws -> APIResponse? {
      // Simulate pagination limit
      guard currentPage < 10 else { return nil }

      currentPage += 1

      // Add artificial delay to simulate real pagination
      try await Task.sleep(for: .milliseconds(100))

      let request = HTTPRequest.get("\(baseURL)?page=\(currentPage)")
      let response = try await client.send(request)

      return APIResponse(
        id: currentPage,
        endpoint: baseURL,
        status: response.status.rawValue,
        dataSize: response.body?.count ?? 0
      )
    }
  }
}

/// Thread-safe network cache using actor
@MainActor
public class NetworkCache {
  private var cache: [String: CacheEntry] = [:]
  private let maxAge: TimeInterval = 300  // 5 minutes

  struct CacheEntry: Sendable {
    let response: APIResponse
    let timestamp: Date

    var isExpired: Bool {
      Date().timeIntervalSince(timestamp) > 300
    }
  }

  public func get(url: String) async throws -> APIResponse {
    // Check cache first
    if let entry = cache[url], !entry.isExpired {
      return APIResponse(
        id: entry.response.id,
        endpoint: entry.response.endpoint,
        status: entry.response.status,
        dataSize: entry.response.dataSize,
        fromCache: true
      )
    }

    // Cache miss - fetch from network
    let client = HTTPClient()
    let request = HTTPRequest.get(url)
    let response = try await client.send(request)

    let apiResponse = APIResponse(
      id: Int.random(in: 1...1000),
      endpoint: url,
      status: response.status.rawValue,
      dataSize: response.body?.count ?? 0
    )

    // Store in cache
    cache[url] = CacheEntry(response: apiResponse, timestamp: Date())

    return apiResponse
  }

  public func clearCache() {
    cache.removeAll()
  }
}

/// Thread-safe connection pool using actor
public actor ConnectionPool {
  private var activeConnections: Int = 0
  private var totalRequests: Int = 0
  private let maxConnections: Int = 10

  public struct PoolStats: Sendable {
    let activeConnections: Int
    let totalRequests: Int
    let maxConnections: Int
  }

  public func getStats() -> PoolStats {
    PoolStats(
      activeConnections: activeConnections,
      totalRequests: totalRequests,
      maxConnections: maxConnections
    )
  }

  public func acquireConnection() -> Bool {
    guard activeConnections < maxConnections else {
      return false
    }

    activeConnections += 1
    totalRequests += 1
    return true
  }

  public func releaseConnection() {
    if activeConnections > 0 {
      activeConnections -= 1
    }
  }
}

/// Server-sent event type
public struct ServerEvent: Sendable {
  let type: String
  let data: String
  let timestamp: Date

  init(type: String, data: String) {
    self.type = type
    self.data = data
    self.timestamp = Date()
  }
}

// MARK: - Helper Functions

/// Creates an AsyncStream for download progress
private func createProgressStream() -> AsyncStream<Double> {
  AsyncStream { continuation in
    Task {
      for i in 0...100 {
        let progress = Double(i) / 100.0
        continuation.yield(progress)

        try? await Task.sleep(for: .milliseconds(50))

        if Task.isCancelled {
          continuation.finish()
          return
        }
      }
      continuation.finish()
    }
  }
}

/// Creates an AsyncStream for server-sent events
private func createServerEventStream() -> AsyncStream<ServerEvent> {
  AsyncStream { continuation in
    Task {
      let eventTypes = [
        "user-action", "system-update", "notification", "data-sync", "status-change",
      ]

      for i in 1...20 {
        let eventType = eventTypes.randomElement() ?? "unknown"
        let event = ServerEvent(
          type: eventType,
          data: "Event data #\(i)"
        )

        continuation.yield(event)

        try? await Task.sleep(for: .milliseconds(200))

        if Task.isCancelled {
          continuation.finish()
          return
        }
      }
      continuation.finish()
    }
  }
}

/// Simulates a long-running operation with cancellation support
private func performLongRunningOperation() async throws -> String {
  for i in 1...50 {
    try Task.checkCancellation()

    // Simulate work
    try await Task.sleep(for: .milliseconds(100))

    if i % 10 == 0 {
      print("   📊 Progress: \(i * 2)%")
    }
  }

  return "Operation completed successfully"
}

/// Simulates a slow network call
private func simulateSlowNetworkCall() async throws -> String {
  try await Task.sleep(for: .seconds(5))
  return "Slow operation result"
}

/// Timeout error type
public struct TimeoutError: Error, Sendable {
  let duration: Duration
}

/// Executes an operation with timeout
private func withTimeout<T: Sendable>(
  seconds: Double,
  operation: @escaping @Sendable () async throws -> T
) async throws -> T {
  try await withThrowingTaskGroup(of: T.self) { group in
    // Add the main operation
    group.addTask {
      try await operation()
    }

    // Add timeout task
    group.addTask {
      try await Task.sleep(for: .seconds(seconds))
      throw TimeoutError(duration: .seconds(seconds))
    }

    // Return first completed result and cancel the other
    defer { group.cancelAll() }
    return try await group.next()!
  }
}

// MARK: - Helper Extensions

private extension String {
  static func * (string: String, count: Int) -> String {
    String(repeating: string, count: count)
  }
}

private extension Duration {
  func formatted() -> String {
    let seconds =
      Double(self.components.seconds) + Double(self.components.attoseconds)
      / 1_000_000_000_000_000_000
    return String(format: "%.3fs", seconds)
  }

  var timeInterval: TimeInterval {
    Double(self.components.seconds) + Double(self.components.attoseconds)
      / 1_000_000_000_000_000_000
  }
}
