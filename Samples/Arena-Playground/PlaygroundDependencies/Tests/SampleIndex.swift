/// # Sample Index - Networking Framework Playground Navigator
///
/// Comprehensive index and navigation system for all networking framework samples.
/// Provides categorized access, learning paths, and interactive exploration of examples.

import Foundation

// MARK: - Sample Organization

/// Categories for organizing samples by feature area and complexity
public enum SampleCategory: String, CaseIterable {
  case gettingStarted = "Getting Started"
  case httpOperations = "HTTP Operations"
  case macros = "Swift Macros"
  case advancedPatterns = "Advanced Patterns"
  case performance = "Performance & Optimization"
  case concurrency = "Swift Concurrency"
  case testing = "Testing & Quality"
  case integration = "Real-World Integration"

  /// Emoji icon for visual identification
  public var icon: String {
    switch self {
    case .gettingStarted: return "🚀"
    case .httpOperations: return "📡"
    case .macros: return "🪄"
    case .advancedPatterns: return "🔧"
    case .performance: return "⚡"
    case .concurrency: return "🔄"
    case .testing: return "✅"
    case .integration: return "🌐"
    }
  }

  /// Detailed description of category focus
  public var description: String {
    switch self {
    case .gettingStarted:
      return "Simple examples for newcomers to learn basic concepts quickly"

    case .httpOperations:
      return "All HTTP methods, headers, parameters, and core operations"

    case .macros:
      return "Swift macros for declarative API client generation with @API, @GET, @POST annotations"

    case .advancedPatterns:
      return "DSL patterns, middleware architecture, and complex request building"

    case .performance:
      return "Optimization techniques, caching strategies, and resource management"

    case .concurrency:
      return "Swift 6 structured concurrency, actors, and async patterns"

    case .testing:
      return "Mocking, testing utilities, and validation patterns"

    case .integration:
      return "Production-ready patterns and real-world application examples"
    }
  }
}

/// Specific use cases for targeted sample discovery
public enum UseCase: String, CaseIterable {
  // Basic scenarios
  case simpleAPICall = "Simple API Call"
  case jsonHandling = "JSON Request/Response"
  case fileDownload = "File Download"
  case fileUpload = "File Upload"

  // Authentication
  case bearerToken = "Bearer Token Auth"
  case apiKey = "API Key Auth"
  case customAuth = "Custom Authentication"

  // Macro scenarios
  case declarativeAPI = "Declarative API Definition"
  case codeGeneration = "Automatic Code Generation"
  case macroAnnotations = "Swift Macro Annotations"

  // Advanced scenarios
  case retryLogic = "Retry & Error Handling"
  case requestMiddleware = "Request Middleware"
  case responseTransformation = "Response Processing"
  case concurrentRequests = "Concurrent Operations"
  case streamingData = "Streaming & Large Data"

  // Production patterns
  case mockTesting = "Mock Testing"
  case performanceOptimization = "Performance Tuning"
  case realTimeUpdates = "Real-time Features"
  case productionReadiness = "Production Deployment"

  /// Find samples that demonstrate this use case
  public var relevantSamples: [SampleInfo] {
    SampleRegistry.samples.filter { $0.useCases.contains(self) }
  }
}

/// Difficulty level for learning progression
public enum DifficultyLevel: String, CaseIterable {
  case beginner = "Beginner"
  case intermediate = "Intermediate"
  case advanced = "Advanced"
  case expert = "Expert"

  public var icon: String {
    switch self {
    case .beginner: return "🟢"
    case .intermediate: return "🟡"
    case .advanced: return "🟠"
    case .expert: return "🔴"
    }
  }
}

// MARK: - Sample Information

/// Comprehensive information about each sample file
public struct SampleInfo {
  public let fileName: String
  public let title: String
  public let description: String
  public let category: SampleCategory
  public let difficulty: DifficultyLevel
  public let useCases: [UseCase]
  public let concepts: [String]
  public let prerequisites: [String]
  public let estimatedTime: String
  public let runFunction: () async -> Void

  /// Display formatted sample information
  public func displayInfo() {
    print("\n\(category.icon) \(title)")
    print("📁 File: \(fileName)")
    print("📊 Level: \(difficulty.icon) \(difficulty.rawValue)")
    print("⏱️  Time: \(estimatedTime)")
    print("📝 Description: \(description)")

    if !concepts.isEmpty {
      print("🎯 Concepts: \(concepts.joined(separator: ", "))")
    }

    if !prerequisites.isEmpty {
      print("📚 Prerequisites: \(prerequisites.joined(separator: ", "))")
    }

    print("🔍 Use Cases:")
    for useCase in useCases {
      print("   • \(useCase.rawValue)")
    }
  }
}

// MARK: - Sample Registry

/// Central registry of all available samples
public struct SampleRegistry {
  public static let samples: [SampleInfo] = [
    // Getting Started
    SampleInfo(
      fileName: "BasicNetworkingExamples.swift",
      title: "Basic Networking Operations",
      description: "Fundamental HTTP operations including GET, POST, and basic authentication",
      category: .gettingStarted,
      difficulty: .beginner,
      useCases: [.simpleAPICall, .jsonHandling, .bearerToken],
      concepts: ["HTTP basics", "Request creation", "Response handling", "Error management"],
      prerequisites: [],
      estimatedTime: "10-15 minutes",
      runFunction: { await BasicNetworkingExamples.runAll() }
    ),

    // HTTP Operations
    SampleInfo(
      fileName: "HTTPMethodsShowcase.swift",
      title: "Complete HTTP Methods Showcase",
      description: "Comprehensive demonstration of all 9 HTTP methods with real-world scenarios",
      category: .httpOperations,
      difficulty: .intermediate,
      useCases: [.simpleAPICall, .fileUpload, .fileDownload, .jsonHandling],
      concepts: ["HTTP methods", "RESTful APIs", "CRUD operations", "Request patterns"],
      prerequisites: ["Basic networking concepts"],
      estimatedTime: "20-25 minutes",
      runFunction: { await HTTPMethodsShowcase.runAll() }
    ),

    // Swift Macros
    SampleInfo(
      fileName: "MacroShowcase.swift",
      title: "Swift Macros for API Generation",
      description:
        "Declarative API client generation using @API, @GET, @POST, and parameter annotations",
      category: .macros,
      difficulty: .intermediate,
      useCases: [.declarativeAPI, .codeGeneration, .macroAnnotations, .simpleAPICall],
      concepts: [
        "Swift macros", "Code generation", "@API annotation", "Declarative programming",
        "Compile-time code generation",
      ],
      prerequisites: ["Swift macro basics", "HTTP fundamentals"],
      estimatedTime: "20-30 minutes",
      runFunction: { await MacroShowcase.runAll() }
    ),

    SampleInfo(
      fileName: "RequestBuildingExamples.swift",
      title: "Request Builder DSL Patterns",
      description: "Declarative request building using Domain Specific Language patterns",
      category: .advancedPatterns,
      difficulty: .intermediate,
      useCases: [.jsonHandling, .customAuth, .requestMiddleware],
      concepts: ["DSL design", "Fluent interfaces", "Request builders", "Method chaining"],
      prerequisites: ["Basic HTTP knowledge"],
      estimatedTime: "15-20 minutes",
      runFunction: { await RequestBuildingExamples.runAll() }
    ),

    SampleInfo(
      fileName: "AdvancedRequestBuilding.swift",
      title: "Expert DSL & Middleware Architecture",
      description:
        "Production-grade request building with complex middleware and transformation patterns",
      category: .advancedPatterns,
      difficulty: .expert,
      useCases: [.requestMiddleware, .responseTransformation, .customAuth, .productionReadiness],
      concepts: [
        "Advanced DSL", "Middleware chains", "Request transformation", "Production patterns",
      ],
      prerequisites: ["DSL patterns", "Middleware concepts", "Swift generics"],
      estimatedTime: "30-40 minutes",
      runFunction: { await AdvancedRequestBuilding.runAll() }
    ),

    SampleInfo(
      fileName: "MiddlewareExamples.swift",
      title: "Middleware Patterns & Request Processing",
      description: "Retry logic, logging, authentication, and custom middleware implementations",
      category: .advancedPatterns,
      difficulty: .advanced,
      useCases: [.retryLogic, .requestMiddleware, .customAuth, .performanceOptimization],
      concepts: [
        "Middleware architecture", "Request interception", "Cross-cutting concerns",
        "Aspect-oriented programming",
      ],
      prerequisites: ["Request/response cycle", "Error handling"],
      estimatedTime: "25-30 minutes",
      runFunction: { await MiddlewareExamples.runAll() }
    ),

    SampleInfo(
      fileName: "AuthenticationExamples.swift",
      title: "Authentication & Security Patterns",
      description: "Bearer tokens, API keys, OAuth flows, and custom authentication strategies",
      category: .advancedPatterns,
      difficulty: .intermediate,
      useCases: [.bearerToken, .apiKey, .customAuth, .productionReadiness],
      concepts: ["Authentication patterns", "Security headers", "Token management", "OAuth flows"],
      prerequisites: ["HTTP headers", "Security concepts"],
      estimatedTime: "20-25 minutes",
      runFunction: { await AuthenticationExamples.runAll() }
    ),

    // Performance
    SampleInfo(
      fileName: "PerformanceOptimization.swift",
      title: "Performance & Resource Management",
      description:
        "Caching strategies, connection pooling, memory management, and optimization techniques",
      category: .performance,
      difficulty: .advanced,
      useCases: [
        .performanceOptimization, .streamingData, .concurrentRequests, .productionReadiness,
      ],
      concepts: [
        "Caching strategies", "Connection pooling", "Memory management", "Performance profiling",
      ],
      prerequisites: ["HTTP fundamentals", "iOS memory management"],
      estimatedTime: "25-35 minutes",
      runFunction: { await PerformanceOptimization.runAll() }
    ),

    // Concurrency
    SampleInfo(
      fileName: "ConcurrencyShowcase.swift",
      title: "Swift 6 Concurrency & Async Patterns",
      description:
        "Structured concurrency, actors, async sequences, and concurrent request patterns",
      category: .concurrency,
      difficulty: .advanced,
      useCases: [.concurrentRequests, .streamingData, .realTimeUpdates, .performanceOptimization],
      concepts: [
        "Structured concurrency", "Actors", "Async sequences", "Task groups", "Swift 6 concurrency",
      ],
      prerequisites: ["Swift async/await", "Concurrency basics"],
      estimatedTime: "30-40 minutes",
      runFunction: { await ConcurrencyShowcase.runAll() }
    ),

    // Testing
    SampleInfo(
      fileName: "TestingPatterns.swift",
      title: "Testing & Quality Assurance",
      description:
        "Mock implementations, testing utilities, validation patterns, and quality gates",
      category: .testing,
      difficulty: .intermediate,
      useCases: [.mockTesting, .productionReadiness],
      concepts: ["Unit testing", "Mock objects", "Test utilities", "Validation patterns"],
      prerequisites: ["Swift testing fundamentals", "XCTest knowledge"],
      estimatedTime: "20-30 minutes",
      runFunction: { await TestingPatterns.runAll() }
    ),

    // Integration
    SampleInfo(
      fileName: "IntegrationExamples.swift",
      title: "Real-World Integration Patterns",
      description:
        "Production-ready applications demonstrating complete workflows and best practices",
      category: .integration,
      difficulty: .expert,
      useCases: [.productionReadiness, .realTimeUpdates, .performanceOptimization, .customAuth],
      concepts: [
        "Production patterns", "System integration", "Error recovery", "Monitoring",
        "Best practices",
      ],
      prerequisites: ["All previous examples", "Production experience helpful"],
      estimatedTime: "40-60 minutes",
      runFunction: { await IntegrationExamples.runAll() }
    ),
  ]

  /// Get samples by category
  public static func samples(for category: SampleCategory) -> [SampleInfo] {
    samples.filter { $0.category == category }
  }

  /// Get samples by difficulty level
  public static func samples(for difficulty: DifficultyLevel) -> [SampleInfo] {
    samples.filter { $0.difficulty == difficulty }
  }

  /// Find samples by search term
  public static func search(_ term: String) -> [SampleInfo] {
    let searchTerm = term.lowercased()
    return samples.filter { sample in
      sample.title.lowercased().contains(searchTerm)
        || sample.description.lowercased().contains(searchTerm)
        || sample.concepts.joined(separator: " ").lowercased().contains(searchTerm)
        || sample.useCases.contains { $0.rawValue.lowercased().contains(searchTerm) }
    }
  }
}

// MARK: - Learning Paths

/// Structured learning paths for different goals
public struct LearningPath {
  public let name: String
  public let description: String
  public let samples: [SampleInfo]
  public let estimatedTotalTime: String

  public static let paths: [Self] = [
    Self(
      name: "🎯 Quick Start (30 minutes)",
      description: "Get up and running with networking basics",
      samples: [
        SampleRegistry.samples.first { $0.fileName == "BasicNetworkingExamples.swift" }!,
        SampleRegistry.samples.first { $0.fileName == "HTTPMethodsShowcase.swift" }!,
      ],
      estimatedTotalTime: "25-30 minutes"
    ),

    Self(
      name: "🏗️ Request Building Mastery (1 hour)",
      description: "Master the request building DSL and patterns",
      samples: [
        SampleRegistry.samples.first { $0.fileName == "BasicNetworkingExamples.swift" }!,
        SampleRegistry.samples.first { $0.fileName == "MacroShowcase.swift" }!,
        SampleRegistry.samples.first { $0.fileName == "RequestBuildingExamples.swift" }!,
        SampleRegistry.samples.first { $0.fileName == "AdvancedRequestBuilding.swift" }!,
        SampleRegistry.samples.first { $0.fileName == "MiddlewareExamples.swift" }!,
      ],
      estimatedTotalTime: "100-135 minutes"
    ),

    Self(
      name: "⚡ Performance Expert (1.5 hours)",
      description: "Optimize for production performance and scalability",
      samples: [
        SampleRegistry.samples.first { $0.fileName == "HTTPMethodsShowcase.swift" }!,
        SampleRegistry.samples.first { $0.fileName == "ConcurrencyShowcase.swift" }!,
        SampleRegistry.samples.first { $0.fileName == "PerformanceOptimization.swift" }!,
        SampleRegistry.samples.first { $0.fileName == "IntegrationExamples.swift" }!,
      ],
      estimatedTotalTime: "115-140 minutes"
    ),

    Self(
      name: "🔒 Security & Authentication (1 hour)",
      description: "Implement secure networking with authentication",
      samples: [
        SampleRegistry.samples.first { $0.fileName == "BasicNetworkingExamples.swift" }!,
        SampleRegistry.samples.first { $0.fileName == "AuthenticationExamples.swift" }!,
        SampleRegistry.samples.first { $0.fileName == "MiddlewareExamples.swift" }!,
        SampleRegistry.samples.first { $0.fileName == "IntegrationExamples.swift" }!,
      ],
      estimatedTotalTime: "85-110 minutes"
    ),

    Self(
      name: "✅ Testing & Quality (45 minutes)",
      description: "Build reliable, testable networking code",
      samples: [
        SampleRegistry.samples.first { $0.fileName == "BasicNetworkingExamples.swift" }!,
        SampleRegistry.samples.first { $0.fileName == "TestingPatterns.swift" }!,
        SampleRegistry.samples.first { $0.fileName == "MiddlewareExamples.swift" }!,
      ],
      estimatedTotalTime: "50-65 minutes"
    ),

    Self(
      name: "🚀 Complete Journey (3+ hours)",
      description: "Master all aspects of the networking framework",
      samples: SampleRegistry.samples,
      estimatedTotalTime: "3-4 hours"
    ),
  ]
}

// MARK: - Main Sample Index

/// Comprehensive index and navigation for networking framework samples
public struct SampleIndex {
  // MARK: - Display Functions

  /// Display comprehensive sample index with all categories and samples
  public static func displayIndex() {
    print("\n🏠 Networking Framework - Sample Index")
    print("=" * 50)
    print("📚 Total Samples: \(SampleRegistry.samples.count)")
    print("🎯 Categories: \(SampleCategory.allCases.count)")
    print("📖 Learning Paths: \(LearningPath.paths.count)")
    print()

    // Display by category
    for category in SampleCategory.allCases {
      let categorySamples = SampleRegistry.samples(for: category)
      guard !categorySamples.isEmpty else { continue }

      print("\n\(category.icon) \(category.rawValue) (\(categorySamples.count) samples)")
      print("   \(category.description)")
      print("   " + "-" * 40)

      for sample in categorySamples {
        print("   \(sample.difficulty.icon) \(sample.title)")
        print("      📁 \(sample.fileName)")
        print("      ⏱️  \(sample.estimatedTime)")
      }
    }

    print("\n\n🎯 Quick Actions:")
    print("   • SampleIndex.runInteractiveMenu() - Interactive explorer")
    print("   • SampleIndex.displayLearningPaths() - Structured learning")
    print("   • SampleIndex.search(\"term\") - Find specific samples")
    print("   • SampleIndex.runByUseCase(.simpleAPICall) - Use case examples")
  }

  /// Display learning paths with progression recommendations
  public static func displayLearningPaths() {
    print("\n📚 Learning Paths - Structured Progression")
    print("=" * 50)

    for (index, path) in LearningPath.paths.enumerated() {
      print("\n\(index + 1). \(path.name)")
      print("   📝 \(path.description)")
      print("   ⏱️  Total Time: \(path.estimatedTotalTime)")
      print("   📊 Samples: \(path.samples.count)")
      print("   📖 Progression:")

      for (stepIndex, sample) in path.samples.enumerated() {
        let arrow = stepIndex == path.samples.count - 1 ? "   └─" : "   ├─"
        print("   \(arrow) \(sample.difficulty.icon) \(sample.title)")
      }
    }

    print("\n\n🎯 To follow a learning path:")
    print("   • Choose a path that matches your goals and time")
    print("   • Follow samples in the recommended order")
    print("   • Each sample builds on previous concepts")
    print("   • Use SampleIndex.runLearningPath(pathIndex) to start")
  }

  /// Run interactive menu system for sample exploration
  public static func runInteractiveMenu() async {
    print("\n🎮 Interactive Sample Explorer")
    print("=" * 40)

    while true {
      print("\n🏠 Main Menu:")
      print("1. 📂 Browse by Category")
      print("2. 🎯 Browse by Use Case")
      print("3. 📊 Browse by Difficulty")
      print("4. 🔍 Search Samples")
      print("5. 📚 Learning Paths")
      print("6. 🏃 Run All Samples")
      print("0. 🚪 Exit")

      print("\nEnter your choice (0-6): ", terminator: "")

      // In a real interactive environment, you'd read user input
      // For this example, we'll demonstrate the menu structure
      print("2")  // Simulating user choice
      await browseByUseCase()
      break  // Exit after demonstration
    }
  }

  /// Browse samples by category
  public static func runByCategory(_ category: SampleCategory) async {
    let samples = SampleRegistry.samples(for: category)

    print("\n\(category.icon) \(category.rawValue) Samples")
    print("=" * 40)
    print("📝 \(category.description)")
    print("📊 \(samples.count) samples available\n")

    for (index, sample) in samples.enumerated() {
      print("\(index + 1). \(sample.difficulty.icon) \(sample.title)")
      print("   ⏱️  \(sample.estimatedTime)")
      print("   🎯 \(sample.useCases.map { $0.rawValue }.joined(separator: ", "))")
    }

    print("\nRunning all samples in category...")
    for sample in samples {
      print("\n🚀 Running: \(sample.title)")
      await sample.runFunction()
    }
  }

  /// Browse samples by use case
  public static func runByUseCase(_ useCase: UseCase) async {
    let samples = useCase.relevantSamples

    print("\n🎯 Use Case: \(useCase.rawValue)")
    print("=" * 40)
    print("📊 \(samples.count) relevant samples\n")

    for (index, sample) in samples.enumerated() {
      print("\(index + 1). \(sample.difficulty.icon) \(sample.title)")
      print("   📁 \(sample.fileName)")
      print("   ⏱️  \(sample.estimatedTime)")
    }

    print("\nRunning samples for use case...")
    for sample in samples {
      print("\n🚀 Running: \(sample.title)")
      await sample.runFunction()
    }
  }

  /// Search samples by term
  public static func search(_ term: String) {
    let results = SampleRegistry.search(term)

    print("\n🔍 Search Results for: '\(term)'")
    print("=" * 40)
    print("📊 Found \(results.count) matching samples\n")

    if results.isEmpty {
      print("No samples found matching '\(term)'")
      print("\n💡 Suggestions:")
      print("   • Try broader terms like 'auth', 'json', 'async'")
      print("   • Use SampleIndex.displayIndex() to see all samples")
      print("   • Browse by category or use case for targeted exploration")
    } else {
      for (index, sample) in results.enumerated() {
        print("\(index + 1). \(sample.category.icon) \(sample.title)")
        print("   📁 \(sample.fileName)")
        print(
          "   \(sample.difficulty.icon) \(sample.difficulty.rawValue) • ⏱️ \(sample.estimatedTime)"
        )
        print("   🎯 \(sample.useCases.map { $0.rawValue }.joined(separator: ", "))")
        print()
      }
    }
  }

  /// Run a specific learning path
  public static func runLearningPath(_ pathIndex: Int) async {
    guard pathIndex >= 0 && pathIndex < LearningPath.paths.count else {
      print("❌ Invalid path index. Use displayLearningPaths() to see available paths.")
      return
    }

    let path = LearningPath.paths[pathIndex]

    print("\n🚀 Starting Learning Path: \(path.name)")
    print("=" * 50)
    print("📝 \(path.description)")
    print("⏱️  Estimated Time: \(path.estimatedTotalTime)")
    print("📊 \(path.samples.count) samples in progression\n")

    for (index, sample) in path.samples.enumerated() {
      print("\n📍 Step \(index + 1) of \(path.samples.count)")
      sample.displayInfo()
      print("\n🚀 Running sample...")
      await sample.runFunction()
      print("✅ Completed: \(sample.title)")

      if index < path.samples.count - 1 {
        print("\n⏳ Preparing next step...")
        // In a real implementation, you might add a delay or wait for user input
      }
    }

    print("\n🎉 Learning Path Complete!")
    print("🏆 You've mastered: \(path.name)")
    print("📈 Next steps: Explore advanced patterns or try a different learning path")
  }

  /// Run all samples in recommended order
  public static func runAll() async {
    print("\n🚀 Running All Networking Framework Samples")
    print("=" * 50)
    print("📊 Total: \(SampleRegistry.samples.count) samples")
    print("⏱️  Estimated time: 3-4 hours")
    print()

    // Run samples in learning progression order
    let orderedSamples = SampleRegistry.samples.sorted { first, second in
      // Sort by difficulty first, then by category
      if first.difficulty != second.difficulty {
        let difficultyOrder: [DifficultyLevel] = [.beginner, .intermediate, .advanced, .expert]
        let firstIndex = difficultyOrder.firstIndex(of: first.difficulty) ?? 0
        let secondIndex = difficultyOrder.firstIndex(of: second.difficulty) ?? 0
        return firstIndex < secondIndex
      }
      return first.title < second.title
    }

    for (index, sample) in orderedSamples.enumerated() {
      print("\n📍 Sample \(index + 1) of \(orderedSamples.count)")
      sample.displayInfo()
      print("\n🚀 Running...")
      await sample.runFunction()
      print("✅ Completed: \(sample.title)")

      if index < orderedSamples.count - 1 {
        print("\n" + "─" * 50)
      }
    }

    print("\n🎉 All Samples Complete!")
    print("🏆 You've explored the complete Networking framework!")
    print("📈 Ready for production development!")
  }

  // MARK: - Private Helper Functions

  private static func browseByUseCase() async {
    print("\n🎯 Browse by Use Case")
    print("=" * 30)

    let commonUseCases: [UseCase] = [
      .simpleAPICall, .jsonHandling, .bearerToken, .retryLogic, .concurrentRequests,
    ]

    for (index, useCase) in commonUseCases.enumerated() {
      let count = useCase.relevantSamples.count
      print("\(index + 1). \(useCase.rawValue) (\(count) samples)")
    }

    print("\nDemonstrating: Simple API Call use case")
    await runByUseCase(.simpleAPICall)
  }
}

// MARK: - Extensions

extension String {
  /// String multiplication for creating separators
  static func * (left: String, right: Int) -> String {
    String(repeating: left, count: right)
  }
}

// MARK: - Quick Access Functions

/// Convenience functions for common operations
extension SampleIndex {
  /// Quick start - run the most essential samples
  public static func quickStart() async {
    print("\n⚡ Quick Start - Essential Samples")
    print("=" * 40)

    let essentialSamples = [
      SampleRegistry.samples.first { $0.fileName == "BasicNetworkingExamples.swift" }!,
      SampleRegistry.samples.first { $0.fileName == "HTTPMethodsShowcase.swift" }!,
      SampleRegistry.samples.first { $0.fileName == "AuthenticationExamples.swift" }!,
    ]

    for sample in essentialSamples {
      print("\n🚀 Running: \(sample.title)")
      await sample.runFunction()
    }

    print("\n✅ Quick Start Complete!")
    print("💡 Use SampleIndex.displayLearningPaths() to continue learning")
  }

  /// Show sample statistics and overview
  public static func showStatistics() {
    print("\n📊 Sample Statistics")
    print("=" * 30)

    print("📚 Total Samples: \(SampleRegistry.samples.count)")

    print("\n📂 By Category:")
    for category in SampleCategory.allCases {
      let count = SampleRegistry.samples(for: category).count
      print("   \(category.icon) \(category.rawValue): \(count)")
    }

    print("\n📊 By Difficulty:")
    for difficulty in DifficultyLevel.allCases {
      let count = SampleRegistry.samples(for: difficulty).count
      print("   \(difficulty.icon) \(difficulty.rawValue): \(count)")
    }

    let totalEstimatedMinutes = SampleRegistry.samples.compactMap { sample in
      // Extract minutes from strings like "10-15 minutes"
      let components = sample.estimatedTime.components(
        separatedBy: CharacterSet.decimalDigits.inverted
      )
      return components.compactMap(Int.init).first
    }.reduce(0, +)

    print(
      "\n⏱️  Total Learning Time: ~\(totalEstimatedMinutes) minutes (\(totalEstimatedMinutes / 60) hours)"
    )

    print("\n🎯 Most Common Use Cases:")
    let useCaseFrequency = Dictionary(grouping: SampleRegistry.samples.flatMap { $0.useCases }) {
      $0
    }
    .mapValues { $0.count }
    .sorted { $0.value > $1.value }
    .prefix(5)

    for (useCase, count) in useCaseFrequency {
      print("   • \(useCase.rawValue): \(count) samples")
    }
  }
}
