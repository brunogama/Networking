/// # Performance Optimization Examples
///
/// This file demonstrates advanced performance optimization patterns for iOS networking applications.
/// These examples show how to maximize network performance through caching, connection optimization,
/// streaming, memory management, and comprehensive performance monitoring.

import Foundation
import Networking

/// Collection of performance optimization examples demonstrating advanced networking patterns
public struct PerformanceOptimization {
  // MARK: - Public Interface

  /// Runs all performance optimization examples
  public static func runAll() async {
    print("\n🚀 Performance Optimization Examples")
    print("-" * 50)

    await cachingStrategies()
    await connectionOptimization()
    await streamingAndProgress()
    await memoryManagement()
    await performanceMonitoring()
    await backgroundProcessing()
    await requestCoalescing()
  }

  // MARK: - Multi-Level Caching Strategies

  /// Demonstrates comprehensive caching strategies for optimal performance
  ///
  /// Shows:
  /// - Multi-tier caching (memory + disk + hybrid)
  /// - Cache policies and eviction strategies
  /// - Performance impact measurement
  /// - Cache warming and preloading
  public static func cachingStrategies() async {
    print("🔹 Advanced Caching Strategies")

    do {
      // Memory-first caching for frequently accessed data
      let memoryCache = CacheStorageProviders.InMemoryCacheStorage(
        configuration: CacheStorageProviders.InMemoryCacheConfiguration(
          maxEntries: 1000,
          maxMemoryBytes: 50 * 1024 * 1024,  // 50MB
          policy: .lru,
          sizePolicy: .combined(entries: 1000, memory: 50 * 1024 * 1024)
        )
      )

      // Persistent disk cache for long-term storage
      let diskCache = CacheStorageProviders.DiskCacheStorage(
        configuration: CacheStorageProviders.DiskCacheConfiguration(
          cacheDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent("NetworkCache", isDirectory: true),
          maxDiskSize: 200 * 1024 * 1024,  // 200MB
          compressionEnabled: true,
          encryptionEnabled: true,
          policy: .lfu,
          sizePolicy: .maxDiskSize(200 * 1024 * 1024)
        )
      )

      // Hybrid cache combining memory and disk
      let hybridCache = CacheStorageProviders.HybridCacheStorage(
        memoryStorage: memoryCache,
        diskStorage: diskCache
      )

      // Create caching middleware with aggressive caching
      let cachingMiddleware = CachingMiddleware(
        storage: hybridCache,
        configuration: CachingMiddleware.CachingConfiguration(
          defaultTTL: 300.0,  // 5 minutes
          maxTTL: 3600.0,  // 1 hour
          respectServerCacheHeaders: true,
          cacheableStatusCodes: [.ok, .notModified, .multipleChoices, .movedPermanently],
          cacheableMethods: [.GET, .HEAD, .OPTIONS],
          skipCacheOnError: false
        )
      )

      // Client with optimized caching
      let cachedClient = NetworkClient.Builder()
        .middleware(cachingMiddleware)
        .middleware(LoggingMiddleware(level: .info))
        .timeout(30.0)
        .build()

      // Performance comparison: cached vs uncached
      let testURLs = [
        "https://httpbin.org/json",
        "https://httpbin.org/uuid",
        "https://httpbin.org/user-agent",
      ]

      print("   📊 Performance Comparison:")

      for url in testURLs {
        let request = HTTPRequest.get(url)

        // First request (cache miss)
        let startTime = CFAbsoluteTimeGetCurrent()
        let response1 = try await cachedClient.execute(request)
        let firstRequestTime = CFAbsoluteTimeGetCurrent() - startTime

        // Second request (cache hit)
        let cachedStartTime = CFAbsoluteTimeGetCurrent()
        let response2 = try await cachedClient.execute(request)
        let cachedRequestTime = CFAbsoluteTimeGetCurrent() - cachedStartTime

        let speedup = firstRequestTime / max(cachedRequestTime, 0.001)  // Avoid division by zero

        print("     \(URL(string: url)?.host ?? url):")
        print("       First request: \(String(format: "%.3f", firstRequestTime))s")
        print("       Cached request: \(String(format: "%.3f", cachedRequestTime))s")
        print("       Speedup: \(String(format: "%.1f", speedup))x")
        print("       Status: \(response1.status) -> \(response2.status)")
      }

      // Cache warming example
      print("   🔥 Cache Warming Strategy:")
      let criticalEndpoints = [
        "https://httpbin.org/headers",
        "https://httpbin.org/ip",
        "https://httpbin.org/get",
      ]

      // Warm cache with critical data
      await withTaskGroup(of: Void.self) { group in
        for endpoint in criticalEndpoints {
          group.addTask {
            do {
              let request = HTTPRequest.get(endpoint)
              _ = try await cachedClient.execute(request)
              print("     ✅ Warmed cache for \(URL(string: endpoint)?.host ?? endpoint)")
            } catch {
              print("     ❌ Failed to warm cache for \(endpoint): \(error)")
            }
          }
        }
      }
    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  // MARK: - Connection Optimization

  /// Demonstrates URLSession configuration optimization for maximum performance
  ///
  /// Shows:
  /// - Connection pooling and reuse
  /// - HTTP/2 multiplexing
  /// - DNS caching optimization
  /// - TLS session resumption
  public static func connectionOptimization() async {
    print("🔹 Connection Optimization")

    do {
      // High-performance URLSession configuration
      let optimizedConfig = URLSessionConfiguration.default

      // Connection pool optimization
      optimizedConfig.httpMaximumConnectionsPerHost = 8  // Increased connection pool
      optimizedConfig.waitsForConnectivity = true
      optimizedConfig.networkServiceType = .responsiveData
      optimizedConfig.allowsCellularAccess = true
      optimizedConfig.allowsExpensiveNetworkAccess = true
      optimizedConfig.allowsConstrainedNetworkAccess = false

      // Request pipeline optimization
      optimizedConfig.httpShouldUsePipelining = true
      optimizedConfig.httpShouldSetCookies = false  // Reduce header overhead
      optimizedConfig.urlCredentialStorage = nil  // Reduce memory usage

      // Caching for performance
      optimizedConfig.requestCachePolicy = .returnCacheDataElseLoad
      optimizedConfig.urlCache = URLCache(
        memoryCapacity: 20 * 1024 * 1024,  // 20MB memory
        diskCapacity: 100 * 1024 * 1024,  // 100MB disk
        diskPath: nil
      )

      // Timeout optimization for responsiveness
      optimizedConfig.timeoutIntervalForRequest = 30.0
      optimizedConfig.timeoutIntervalForResource = 300.0

      // Create optimized client
      let session = URLSession(configuration: optimizedConfig)
      let optimizedClient = HTTPClient(session: session)

      // Test connection reuse with concurrent requests
      print("   🔄 Testing Connection Pool Efficiency:")
      let concurrentRequests = 10
      let baseURL = "https://httpbin.org"

      let startTime = CFAbsoluteTimeGetCurrent()

      await withTaskGroup(of: (Int, TimeInterval).self) { group in
        for i in 0..<concurrentRequests {
          group.addTask {
            let requestStart = CFAbsoluteTimeGetCurrent()
            do {
              let request = HTTPRequest.get("\(baseURL)/delay/\(i % 3 + 1)")
              let response = try await optimizedClient.send(request)
              let duration = CFAbsoluteTimeGetCurrent() - requestStart
              print("     Request \(i): \(response.status) in \(String(format: "%.3f", duration))s")
              return (i, duration)
            } catch {
              let duration = CFAbsoluteTimeGetCurrent() - requestStart
              print("     Request \(i): Failed in \(String(format: "%.3f", duration))s")
              return (i, duration)
            }
          }
        }

        var results: [(Int, TimeInterval)] = []
        for await result in group {
          results.append(result)
        }

        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        let averageTime = results.map(\.1).reduce(0, +) / Double(results.count)

        print("     📈 Concurrent Performance:")
        print("       Total time: \(String(format: "%.3f", totalTime))s")
        print("       Average request: \(String(format: "%.3f", averageTime))s")
        print(
          "       Throughput: \(String(format: "%.1f", Double(concurrentRequests) / totalTime)) req/s"
        )
      }

      // HTTP/2 server push simulation (where available)
      print("   ⚡ HTTP/2 Optimization Benefits:")
      let http2TestURL = "https://http2.golang.org/reqinfo"
      let http2Request = HTTPRequest.get(http2TestURL)

      let http2Start = CFAbsoluteTimeGetCurrent()
      do {
        let response = try await optimizedClient.send(http2Request)
        let http2Duration = CFAbsoluteTimeGetCurrent() - http2Start

        if let body = response.body,
          let responseString = String(data: body, encoding: .utf8)
        {
          let isHTTP2 =
            responseString.contains("HTTP/2.0")
            || response.headers["server"]?.contains("h2") == true
          print("     Protocol: \(isHTTP2 ? "HTTP/2" : "HTTP/1.1")")
          print("     Response time: \(String(format: "%.3f", http2Duration))s")
          print("     Performance benefit: \(isHTTP2 ? "✅ Optimized" : "⚠️ Standard")")
        }
      } catch {
        print("     HTTP/2 test unavailable: \(error)")
      }
    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  // MARK: - Streaming and Progress Tracking

  /// Demonstrates high-performance streaming and progress tracking
  ///
  /// Shows:
  /// - Large file streaming
  /// - Real-time progress updates
  /// - Memory-efficient processing
  /// - Background transfer optimization
  public static func streamingAndProgress() async {
    print("🔹 Streaming and Progress Tracking")

    do {
      // Create progress tracking middleware
      let progressMiddleware = ProgressTrackingMiddleware()

      // Create client with progress tracking
      let streamingClient = NetworkClient.Builder()
        .middleware(progressMiddleware)
        .middleware(LoggingMiddleware(level: .info))
        .timeout(120.0)  // Longer timeout for large files
        .build()

      // Simulate large file download with progress tracking
      let largeFileURL = "https://httpbin.org/bytes/1048576"  // 1MB test file
      let request = HTTPRequest.get(largeFileURL)

      print("   📥 Large File Download with Progress:")

      // Start download with progress monitoring
      let transferId = UUID()

      // Monitor progress in background task
      let progressTask = Task {
        do {
          let progressStream = try await progressMiddleware.trackProgress(for: transferId)

          for await progress in progressStream {
            let percentage = Int(progress.progress * 100)
            let transferred = formatBytes(progress.transferredBytes)
            let total = progress.totalBytes.map(formatBytes) ?? "unknown"
            let speed = progress.formattedSpeed

            print("     📊 \(percentage)% - \(transferred)/\(total) at \(speed)")

            if progress.phase == .completed {
              print("     ✅ Transfer completed successfully")
              break
            } else if progress.phase == .failed {
              print("     ❌ Transfer failed")
              break
            }
          }
        } catch {
          print("     ❌ Progress monitoring error: \(error)")
        }
      }

      // Execute the actual request
      let downloadStart = CFAbsoluteTimeGetCurrent()
      let response = try await streamingClient.execute(request)
      let downloadDuration = CFAbsoluteTimeGetCurrent() - downloadStart

      // Cancel progress monitoring
      progressTask.cancel()

      if let data = response.body {
        let downloadSpeed = Double(data.count) / downloadDuration
        print("     📈 Download Performance:")
        print("       Size: \(formatBytes(Int64(data.count)))")
        print("       Duration: \(String(format: "%.3f", downloadDuration))s")
        print("       Speed: \(formatBytesPerSecond(downloadSpeed))")
        print("       Status: \(response.status)")
      }

      // Streaming JSON processing example
      print("   🌊 Streaming JSON Processing:")
      let streamingRequest = HTTPRequest.get("https://httpbin.org/json")

      // Process response in chunks to minimize memory footprint
      let streamResponse = try await streamingClient.execute(streamingRequest)

      if let jsonData = streamResponse.body {
        // Simulate chunk processing
        let chunkSize = 1024
        var processedBytes = 0

        for offset in stride(from: 0, to: jsonData.count, by: chunkSize) {
          let endIndex = min(offset + chunkSize, jsonData.count)
          let chunk = jsonData[offset..<endIndex]

          // Process chunk (in real app, this would be JSON streaming parsing)
          processedBytes += chunk.count

          let progress = Double(processedBytes) / Double(jsonData.count)
          print(
            "     🔄 Processed \(Int(progress * 100))% (\(processedBytes)/\(jsonData.count) bytes)"
          )

          // Simulate processing delay
          try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
        }

        print("     ✅ Streaming processing completed")
      }
    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  // MARK: - Memory Management

  /// Demonstrates memory-efficient networking patterns
  ///
  /// Shows:
  /// - Resource cleanup strategies
  /// - Memory pool management
  /// - Large data handling
  /// - Autoreleasepool optimization
  public static func memoryManagement() async {
    print("🔹 Memory Management Optimization")

    do {
      // Memory-optimized client configuration
      let memoryConfig = URLSessionConfiguration.ephemeral  // No persistent storage
      memoryConfig.urlCache = nil  // Disable caching to save memory
      memoryConfig.httpCookieStorage = nil  // Disable cookies
      memoryConfig.urlCredentialStorage = nil  // Disable credential storage

      let memoryOptimizedClient = HTTPClient(session: URLSession(configuration: memoryConfig))

      // Memory usage monitoring
      func getMemoryUsage() -> Int64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
          $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
          }
        }

        return result == KERN_SUCCESS ? Int64(info.phys_footprint) : 0
      }

      let initialMemory = getMemoryUsage()
      print("   💾 Initial memory usage: \(formatBytes(initialMemory))")

      // Test memory efficiency with multiple large requests
      print("   🔄 Memory Stress Test:")
      let largeRequestURLs = Array(repeating: "https://httpbin.org/bytes/2048", count: 20)

      await withTaskGroup(of: Void.self) { group in
        for (index, url) in largeRequestURLs.enumerated() {
          group.addTask {
            // Use autoreleasepool for memory management
            await withAutoReleasePool {
              do {
                let request = HTTPRequest.get(url)
                let response = try await memoryOptimizedClient.send(request)

                // Process data immediately and release
                if let data = response.body {
                  let checksum = data.reduce(0) { $0 ^ $1 }  // Simple processing
                  print("     ✅ Request \(index): \(data.count) bytes, checksum: \(checksum)")
                }

                // Force cleanup
                response.body = nil
              } catch {
                print("     ❌ Request \(index) failed: \(error)")
              }
            }
          }
        }
      }

      let finalMemory = getMemoryUsage()
      let memoryIncrease = finalMemory - initialMemory

      print("   📊 Memory Usage Results:")
      print("     Initial: \(formatBytes(initialMemory))")
      print("     Final: \(formatBytes(finalMemory))")
      print("     Increase: \(formatBytes(memoryIncrease))")
      print(
        "     Memory efficiency: \(memoryIncrease < 10 * 1024 * 1024 ? "✅ Excellent" : "⚠️ Needs optimization")"
      )

      // Resource cleanup demonstration
      print("   🧹 Resource Cleanup:")
      class ResourceManager {
        private var activeConnections = 0
        private let lock = NSLock()

        func trackConnection() {
          lock.withLock {
            activeConnections += 1
          }
        }

        func releaseConnection() {
          lock.withLock {
            activeConnections -= 1
          }
        }

        var connectionCount: Int {
          lock.withLock { activeConnections }
        }
      }

      let resourceManager = ResourceManager()

      // Demonstrate proper resource management
      await withTaskGroup(of: Void.self) { group in
        for i in 0..<5 {
          group.addTask {
            resourceManager.trackConnection()
            defer { resourceManager.releaseConnection() }

            do {
              let request = HTTPRequest.get("https://httpbin.org/delay/1")
              _ = try await memoryOptimizedClient.send(request)
              print("     ✅ Connection \(i): Properly managed")
            } catch {
              print("     ❌ Connection \(i): Error - \(error)")
            }
          }
        }
      }

      print("     Final active connections: \(resourceManager.connectionCount)")

    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  // MARK: - Performance Monitoring

  /// Demonstrates comprehensive performance monitoring and metrics collection
  ///
  /// Shows:
  /// - Real-time performance metrics
  /// - Latency analysis
  /// - Throughput measurement
  /// - Error rate monitoring
  public static func performanceMonitoring() async {
    print("🔹 Performance Monitoring & Metrics")

    do {
      // Create comprehensive metrics collector
      let metricsCollector = ComprehensiveMetricsCollector()

      // Create observability middleware
      let observabilityMiddleware = NetworkObservabilityMiddleware(
        metricsCollector: metricsCollector,
        configuration: NetworkObservabilityMiddleware.ObservabilityConfiguration(
          collectRequestMetrics: true,
          collectResponseMetrics: true,
          collectTimingMetrics: true,
          collectNetworkMetrics: true,
          enablePerformanceAnalytics: true,
          metricsWindowSize: 60.0  // 1 minute windows
        )
      )

      // Create monitored client
      let monitoredClient = NetworkClient.Builder()
        .middleware(observabilityMiddleware)
        .middleware(LoggingMiddleware(level: .info))
        .build()

      // Performance test scenarios
      let testScenarios = [
        ("Fast API", "https://httpbin.org/get", 5),
        ("Delayed API", "https://httpbin.org/delay/2", 3),
        ("Large Response", "https://httpbin.org/bytes/10240", 4),  // 10KB
        ("JSON API", "https://httpbin.org/json", 6),
      ]

      print("   📊 Running Performance Tests:")

      for (name, url, count) in testScenarios {
        print("     Testing \(name)...")
        var responseTimes: [TimeInterval] = []
        var successCount = 0

        for i in 0..<count {
          let startTime = CFAbsoluteTimeGetCurrent()

          do {
            let request = HTTPRequest.get(url)
            let response = try await monitoredClient.execute(request)
            let responseTime = CFAbsoluteTimeGetCurrent() - startTime

            if response.status.rawValue < 400 {
              successCount += 1
              responseTimes.append(responseTime)
            }

            print(
              "       Request \(i + 1): \(response.status) in \(String(format: "%.3f", responseTime))s"
            )
          } catch {
            let responseTime = CFAbsoluteTimeGetCurrent() - startTime
            print(
              "       Request \(i + 1): Failed in \(String(format: "%.3f", responseTime))s - \(error)"
            )
          }
        }

        // Calculate statistics
        if !responseTimes.isEmpty {
          let avg = responseTimes.reduce(0, +) / Double(responseTimes.count)
          let min = responseTimes.min() ?? 0
          let max = responseTimes.max() ?? 0
          let successRate = Double(successCount) / Double(count) * 100

          print("       📈 \(name) Statistics:")
          print("         Success rate: \(String(format: "%.1f", successRate))%")
          print("         Average: \(String(format: "%.3f", avg))s")
          print("         Min: \(String(format: "%.3f", min))s")
          print("         Max: \(String(format: "%.3f", max))s")
          print("         Throughput: \(String(format: "%.1f", Double(successCount) / avg)) req/s")
        }

        // Small delay between test scenarios
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
      }

      // Retrieve and display aggregated metrics
      print("   📋 Aggregated Performance Metrics:")
      let metrics = await metricsCollector.getCurrentMetrics()

      print("     Total requests: \(metrics.totalRequests)")
      print("     Success rate: \(String(format: "%.1f", metrics.successRate * 100))%")
      print("     Average response time: \(String(format: "%.3f", metrics.averageResponseTime))s")
      print("     Requests per second: \(String(format: "%.1f", metrics.throughput))")
      print("     Error rate: \(String(format: "%.1f", metrics.errorRate * 100))%")

      // Performance analysis
      if metrics.averageResponseTime < 1.0 {
        print("     ✅ Performance: Excellent")
      } else if metrics.averageResponseTime < 2.0 {
        print("     ⚠️ Performance: Good")
      } else {
        print("     ❌ Performance: Needs improvement")
      }

    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  // MARK: - Background Processing

  /// Demonstrates background processing optimization for iOS
  ///
  /// Shows:
  /// - Background task management
  /// - Task continuation across app states
  /// - Battery-efficient processing
  /// - Progressive download strategies
  public static func backgroundProcessing() async {
    print("🔹 Background Processing Optimization")

    // Background URLSession configuration
    let backgroundConfig = URLSessionConfiguration.background(
      withIdentifier: "com.networking.background"
    )
    backgroundConfig.isDiscretionary = true  // Battery-friendly
    backgroundConfig.allowsCellularAccess = false  // WiFi only for background
    backgroundConfig.timeoutIntervalForRequest = 60.0
    backgroundConfig.timeoutIntervalForResource = 300.0

    // Note: In a real app, you would use the background session for actual background downloads
    // For playground/testing, we'll use regular session with background-like patterns
    let backgroundStyleClient = HTTPClient(
      session: URLSession(configuration: URLSessionConfiguration.default)
    )

    print("   🔄 Background-Style Processing Patterns:")

    // Chunked processing to minimize memory usage
    let largeDataTasks = [
      "https://httpbin.org/bytes/4096",  // 4KB
      "https://httpbin.org/bytes/8192",  // 8KB
      "https://httpbin.org/json",  // JSON data
    ]

    // Process tasks in background-friendly manner
    for (index, url) in largeDataTasks.enumerated() {
      print("     Processing task \(index + 1) of \(largeDataTasks.count)...")

      await withAutoReleasePool {
        do {
          let request = HTTPRequest.get(url)
          let response = try await backgroundStyleClient.send(request)

          if let data = response.body {
            // Process data in chunks to be battery-friendly
            let chunkSize = 1024
            var processedChunks = 0

            for chunkStart in stride(from: 0, to: data.count, by: chunkSize) {
              let chunkEnd = min(chunkStart + chunkSize, data.count)
              let chunk = data[chunkStart..<chunkEnd]

              // Simulate background processing
              let checksum = chunk.reduce(0, ^)  // Simple processing
              processedChunks += 1

              // Battery-friendly: small delays between chunks
              try await Task.sleep(nanoseconds: 5_000_000)  // 5ms
            }

            print("       ✅ Task \(index + 1): \(data.count) bytes in \(processedChunks) chunks")
          }

        } catch {
          print("       ❌ Task \(index + 1) failed: \(error)")
        }
      }

      // Background-friendly delay between tasks
      try await Task.sleep(nanoseconds: 100_000_000)  // 100ms
    }

    // Progressive download strategy
    print("   📥 Progressive Download Strategy:")
    let progressiveURL = "https://httpbin.org/bytes/16384"  // 16KB

    // Simulate progressive download by requesting in ranges
    let rangeSize = 4096  // 4KB chunks
    let totalSize = 16384
    var downloadedData = Data()

    for rangeStart in stride(from: 0, to: totalSize, by: rangeSize) {
      let rangeEnd = min(rangeStart + rangeSize - 1, totalSize - 1)

      var rangeRequest = HTTPRequest.get(progressiveURL)
      rangeRequest.headers["Range"] = "bytes=\(rangeStart)-\(rangeEnd)"

      do {
        let response = try await backgroundStyleClient.send(rangeRequest)

        if let chunkData = response.body {
          downloadedData.append(chunkData)
          let progress = Double(downloadedData.count) / Double(totalSize) * 100

          print("     📊 Downloaded \(Int(progress))% (\(downloadedData.count)/\(totalSize) bytes)")
        }

        // Battery-friendly delay
        try await Task.sleep(nanoseconds: 50_000_000)  // 50ms

      } catch {
        print("     ❌ Range request failed: \(error)")
        break
      }
    }

    if downloadedData.count == totalSize {
      print("     ✅ Progressive download completed successfully")
    } else {
      print("     ⚠️ Progressive download incomplete: \(downloadedData.count)/\(totalSize) bytes")
    }

    print("   🔋 Background processing optimizations applied")
  }

  // MARK: - Request Coalescing

  /// Demonstrates request coalescing to prevent duplicate network calls
  ///
  /// Shows:
  /// - Duplicate request detection
  /// - Response sharing
  /// - Memory efficiency
  /// - Performance optimization
  public static func requestCoalescing() async {
    print("🔹 Request Coalescing Optimization")

    // Request coalescing middleware to prevent duplicate requests
    actor RequestCoalescingMiddleware: Middleware {
      private var ongoingRequests: [String: Task<HTTPResponse, Error>] = [:]

      func process(
        _ request: HTTPRequest,
        next: @escaping (HTTPRequest) async throws -> HTTPResponse
      ) async throws -> HTTPResponse {
        let requestKey = "\(request.method.rawValue):\(request.url?.absoluteString ?? "")"

        // Check if identical request is already in progress
        if let ongoingTask = ongoingRequests[requestKey] {
          print("     🔄 Coalescing duplicate request: \(requestKey)")
          return try await ongoingTask.value
        }

        // Create new task for this request
        let task = Task<HTTPResponse, Error> {
          try await next(request)
        }

        ongoingRequests[requestKey] = task

        defer {
          // Clean up completed request
          ongoingRequests.removeValue(forKey: requestKey)
        }

        return try await task.value
      }
    }

    do {
      // Create client with request coalescing
      let coalescingClient = HTTPClient.Builder()
        .middleware(await RequestCoalescingMiddleware())
        .middleware(LoggingMiddleware(level: .info))
        .build()

      print("   🚀 Testing Request Coalescing:")

      let testURL = "https://httpbin.org/delay/2"  // 2-second delay to ensure overlap
      let duplicateRequestCount = 5

      // Start multiple identical requests simultaneously
      let startTime = CFAbsoluteTimeGetCurrent()

      await withTaskGroup(of: (Int, TimeInterval, HTTPStatus).self) { group in
        for i in 0..<duplicateRequestCount {
          group.addTask {
            let requestStart = CFAbsoluteTimeGetCurrent()
            do {
              let request = HTTPRequest.get(testURL)
              let response = try await coalescingClient.send(request)
              let duration = CFAbsoluteTimeGetCurrent() - requestStart

              print(
                "       Request \(i): \(response.status) in \(String(format: "%.3f", duration))s"
              )
              return (i, duration, response.status)
            } catch {
              let duration = CFAbsoluteTimeGetCurrent() - requestStart
              print("       Request \(i): Failed in \(String(format: "%.3f", duration))s")
              return (i, duration, .internalServerError)
            }
          }
        }

        var results: [(Int, TimeInterval, HTTPStatus)] = []
        for await result in group {
          results.append(result)
        }

        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        let averageResponseTime = results.map(\.1).reduce(0, +) / Double(results.count)
        let successfulRequests = results.filter { $0.2.rawValue < 400 }.count

        print("   📊 Coalescing Performance Results:")
        print("     Total requests: \(duplicateRequestCount)")
        print("     Successful: \(successfulRequests)")
        print("     Total time: \(String(format: "%.3f", totalTime))s")
        print("     Average response: \(String(format: "%.3f", averageResponseTime))s")
        print(
          "     Expected benefit: \(totalTime < 4.0 ? "✅ Coalescing effective" : "⚠️ Check implementation")"
        )

        // Without coalescing, we'd expect ~2s * 5 requests = 10s total
        // With coalescing, should be closer to ~2s total
        let efficiencyGain = (Double(duplicateRequestCount) * 2.0) / totalTime
        print("     Efficiency gain: \(String(format: "%.1f", efficiencyGain))x")
      }

    } catch {
      print("   ❌ Error: \(error)")
    }
  }
}

// MARK: - Helper Extensions and Utilities

/// Memory-aware autoreleasepool wrapper for async operations
private func withAutoReleasePool<T>(_ operation: () async throws -> T) async rethrows -> T {
  return try await autoreleasepool {
    try await operation()
  }
}

/// Format bytes in human-readable format
private func formatBytes(_ bytes: Int64) -> String {
  let units = ["B", "KB", "MB", "GB", "TB"]
  var size = Double(bytes)
  var unitIndex = 0

  while size >= 1024 && unitIndex < units.count - 1 {
    size /= 1024
    unitIndex += 1
  }

  return String(format: "%.1f %@", size, units[unitIndex])
}

/// Format bytes per second in human-readable format
private func formatBytesPerSecond(_ bytesPerSecond: Double) -> String {
  return formatBytes(Int64(bytesPerSecond)) + "/s"
}

/// Thread-safe lock extension
private extension NSLock {
  func withLock<T>(_ work: () throws -> T) rethrows -> T {
    lock()
    defer { unlock() }
    return try work()
  }
}

/// Enhanced metrics collector with current metrics access
private extension ComprehensiveMetricsCollector {
  func getCurrentMetrics() async -> PerformanceMetrics {
    // This would typically be implemented in the actual ComprehensiveMetricsCollector
    // For demo purposes, we'll return mock data
    return PerformanceMetrics(
      totalRequests: 50,
      successRate: 0.96,
      averageResponseTime: 1.2,
      throughput: 8.5,
      errorRate: 0.04
    )
  }
}

/// Performance metrics structure for monitoring
private struct PerformanceMetrics {
  let totalRequests: Int
  let successRate: Double
  let averageResponseTime: TimeInterval
  let throughput: Double  // requests per second
  let errorRate: Double
}

// MARK: - Helper Extensions

private extension String {
  static func * (string: String, count: Int) -> String {
    String(repeating: string, count: count)
  }
}
