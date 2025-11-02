/// # Networking Framework - Arena Playground Samples
///
/// This playground provides comprehensive examples demonstrating all features of the Networking framework.
/// Each example is self-contained and can be run independently to understand specific functionality.
///
/// ## Quick Start with Sample Index
///
/// **NEW**: Use the comprehensive Sample Index for guided exploration:
///
/// ```swift
/// // Display all available samples organized by category
/// SampleIndex.displayIndex()
///
/// // Interactive exploration
/// await SampleIndex.runInteractiveMenu()
///
/// // Quick start with essential samples
/// await SampleIndex.quickStart()
///
/// // Follow structured learning paths
/// SampleIndex.displayLearningPaths()
/// await SampleIndex.runLearningPath(0) // Quick Start path
///
/// // Search for specific functionality
/// SampleIndex.search("authentication")
/// SampleIndex.search("concurrency")
///
/// // Browse by use case
/// await SampleIndex.runByUseCase(.simpleAPICall)
/// await SampleIndex.runByUseCase(.bearerToken)
/// ```
///
/// ## Available Examples
///
/// - **BasicNetworking**: Simple HTTP requests and responses
/// - **HTTPMethodsShowcase**: Comprehensive demonstration of all 9 HTTP methods
/// - **RequestBuilding**: Advanced request builder DSL patterns
/// - **AdvancedRequestBuilding**: Expert-level DSL, middleware architecture, and production patterns
/// - **MiddlewareExamples**: Retry, logging, and custom middleware
/// - **AuthenticationExamples**: Bearer tokens, API keys, custom auth
/// - **ConcurrencyShowcase**: Swift 6 structured concurrency, actors, and async patterns
/// - **PerformanceOptimization**: Caching, optimization, and resource management
/// - **TestingPatterns**: Mock implementations and testing utilities
/// - **IntegrationExamples**: Real-world integration patterns
///
/// ## Manual Exploration
///
/// You can also run examples directly:
///
/// ```swift
/// import Networking
///
/// // Run basic example
/// await BasicNetworkingExamples.simpleGETRequest()
///
/// // Explore all HTTP methods
/// await HTTPMethodsShowcase.runAll()
///
/// // Advanced request building patterns
/// await AdvancedRequestBuilding.runAll()
///
/// // Swift 6 concurrency patterns
/// await ConcurrencyShowcase.runAll()
/// ```
///
/// Each example includes detailed documentation and error handling to help you understand
/// both the happy path and edge cases.

import Foundation
@_exported import Networking

public struct PlaygroundDependencies {
  /// Entry point for all playground examples - now powered by SampleIndex
  public static func runAllExamples() async {
    // Use the new SampleIndex system for better organization
    await SampleIndex.runAll()
  }

  /// Quick start with essential samples
  public static func quickStart() async {
    await SampleIndex.quickStart()
  }

  /// Display the comprehensive sample index
  public static func showIndex() {
    SampleIndex.displayIndex()
  }

  /// Show learning paths for structured progression
  public static func showLearningPaths() {
    SampleIndex.displayLearningPaths()
  }

  /// Interactive sample exploration
  public static func interactiveExploration() async {
    await SampleIndex.runInteractiveMenu()
  }
}
