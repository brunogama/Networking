// Playground generated with 🏟 Arena (https://github.com/finestructure/arena)
// ℹ️ If running the playground fails with an error "No such module"
//    go to Product -> Build to re-trigger building the SPM package.
// ℹ️ Please restart Xcode if autocomplete is not working.

import Networking
import PlaygroundDependencies

// Comprehensive Networking Examples Demonstration
Task {
  print("🚀 ModernNetworking Playground - Comprehensive Examples")
  print("=" * 60)

  // Run all example collections
  await BasicNetworkingExamples.runAll()
  await RequestBuildingExamples.runAll()
  await MiddlewareExamples.runAll()
  await AuthenticationExamples.runAll()
  await AdvancedRequestBuilding.runAll()

  print("\n" + "=" * 60)
  print("✅ All networking examples completed successfully!")
  print("   Check console output for detailed results and patterns.")
}

// Helper extension for formatting
extension String {
  static func * (string: String, count: Int) -> String {
    String(repeating: string, count: count)
  }
}
