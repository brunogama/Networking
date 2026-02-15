import Foundation

/// A global actor for serializing access to shared networking state.
///
/// `NetworkActor` provides a dedicated execution context for networking operations
/// that require serialized access to shared mutable state, such as environment
/// management, token storage, and configuration changes.
///
/// ## Usage
///
/// Annotate classes or functions that manage shared networking state:
///
/// ```swift
/// @NetworkActor
/// public class EnvironmentManager: EnvironmentManaging {
///     private var currentEnvironment: Environment = .production
///
///     func switchEnvironment(to environment: Environment) {
///         currentEnvironment = environment
///     }
/// }
/// ```
///
/// Or isolate individual functions:
///
/// ```swift
/// @NetworkActor
/// func updateSharedConfiguration(_ config: NetworkConfiguration) {
///     // Thread-safe state mutation
/// }
/// ```
@globalActor
public actor NetworkActor {
  /// The shared instance of the network actor.
  public static let shared = NetworkActor()
}
