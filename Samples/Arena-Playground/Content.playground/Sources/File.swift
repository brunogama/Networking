/// # Networking Framework Playground - Entry Point
///
/// This playground demonstrates the comprehensive Networking framework with organized samples,
/// interactive exploration, and structured learning paths.
///
/// ## Quick Start
///
/// Uncomment and run any of these in the playground:
///
/// ```swift
/// // 1. Show all available samples organized by category
/// SampleIndex.displayIndex()
///
/// // 2. Quick start with essential samples (10-15 minutes)
/// await SampleIndex.quickStart()
///
/// // 3. Interactive exploration with menu system
/// await SampleIndex.runInteractiveMenu()
///
/// // 4. Structured learning paths
/// SampleIndex.displayLearningPaths()
/// await SampleIndex.runLearningPath(0) // Quick Start path
///
/// // 5. Search for specific functionality
/// SampleIndex.search("authentication")
/// SampleIndex.search("concurrency")
/// SampleIndex.search("middleware")
///
/// // 6. Browse samples by use case
/// await SampleIndex.runByUseCase(.simpleAPICall)
/// await SampleIndex.runByUseCase(.bearerToken)
/// await SampleIndex.runByUseCase(.concurrentRequests)
/// ```
///
/// ## Sample Categories
///
/// - 🚀 **Getting Started**: Basic concepts for newcomers
/// - 📡 **HTTP Operations**: All HTTP methods and core operations
/// - 🔧 **Advanced Patterns**: DSL, middleware, and complex scenarios
/// - ⚡ **Performance**: Optimization and resource management
/// - 🔄 **Concurrency**: Swift 6 structured concurrency patterns
/// - ✅ **Testing**: Mocking and validation utilities
/// - 🌐 **Integration**: Real-world production patterns
///
/// ## Learning Paths Available
///
/// 1. **🎯 Quick Start (30 minutes)** - Essential networking basics
/// 2. **🏗️ Request Building Mastery (1 hour)** - Master DSL patterns
/// 3. **⚡ Performance Expert (1.5 hours)** - Optimization techniques
/// 4. **🔒 Security & Authentication (1 hour)** - Secure networking
/// 5. **✅ Testing & Quality (45 minutes)** - Reliable, testable code
/// 6. **🚀 Complete Journey (3+ hours)** - Master everything
///
/// Created by Bruno da Gama Porciuncula on 27/08/25.

import Foundation
import PlaygroundDependencies

// MARK: - Quick Examples

/// Uncomment any of these to explore different aspects of the framework:

// 1. Display comprehensive sample index
// SampleIndex.displayIndex()

// 2. Quick start (runs 3 essential samples)
// await SampleIndex.quickStart()

// 3. Show all learning paths
// SampleIndex.displayLearningPaths()

// 4. Interactive menu system
// await SampleIndex.runInteractiveMenu()

// 5. Search examples
// SampleIndex.search("auth")
// SampleIndex.search("json")
// SampleIndex.search("async")

// 6. Use case exploration
// await SampleIndex.runByUseCase(.simpleAPICall)
// await SampleIndex.runByUseCase(.bearerToken)
// await SampleIndex.runByUseCase(.concurrentRequests)

// 7. Category exploration
// await SampleIndex.runByCategory(.gettingStarted)
// await SampleIndex.runByCategory(.httpOperations)
// await SampleIndex.runByCategory(.concurrency)

// 8. Run specific learning path
// await SampleIndex.runLearningPath(0) // Quick Start
// await SampleIndex.runLearningPath(1) // Request Building Mastery

// 9. Statistics and overview
// SampleIndex.showStatistics()

// 10. Run all samples (3-4 hours)
// await SampleIndex.runAll()

// MARK: - Individual Sample Access

// You can also run individual sample files directly:

// Basic networking operations
// await BasicNetworkingExamples.runAll()

// All HTTP methods (GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS, TRACE, CONNECT)
// await HTTPMethodsShowcase.runAll()

// DSL request building patterns
// await RequestBuildingExamples.runAll()

// Advanced DSL and middleware architecture
// await AdvancedRequestBuilding.runAll()

// Middleware patterns and request processing
// await MiddlewareExamples.runAll()

// Authentication and security patterns
// await AuthenticationExamples.runAll()

// Swift 6 concurrency and async patterns
// await ConcurrencyShowcase.runAll()

// Performance optimization and caching
// await PerformanceOptimization.runAll()

// Testing patterns and mock implementations
// await TestingPatterns.runAll()

// Real-world integration patterns
// await IntegrationExamples.runAll()

// MARK: - Legacy PlaygroundDependencies Access

// The original playground interface is still available:

// Show index via PlaygroundDependencies
// PlaygroundDependencies.showIndex()

// Quick start via PlaygroundDependencies
// await PlaygroundDependencies.quickStart()

// Interactive exploration
// await PlaygroundDependencies.interactiveExploration()

// Run all examples
// await PlaygroundDependencies.runAllExamples()
