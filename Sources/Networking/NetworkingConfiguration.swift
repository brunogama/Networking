import Foundation

/// Configuration constants for the Networking framework.
///
/// This module centralizes all configuration values to improve maintainability
/// and allow for easier customization of framework behavior.
public enum NetworkingConfiguration {
  /// Retry delay constants for different error scenarios.
  ///
  /// These values are used by the error recovery system to determine
  /// appropriate wait times before attempting retries.
  public enum RetryDelays {
    /// Immediate retry with minimal delay for transient errors
    public static let immediate: TimeInterval = 0.5

    /// Connection lost scenarios - moderate delay to allow network recovery
    public static let connectionLost: TimeInterval = 2.0

    /// Server unreachable - longer delay for infrastructure issues
    public static let serverUnreachable: TimeInterval = 30.0

    /// Rate limiting scenarios - respect API rate limits
    public static let rateLimiting: TimeInterval = 60.0

    /// Server errors (5xx) - moderate delay for server recovery
    public static let serverError: TimeInterval = 15.0

    /// Timeout scenarios - shorter delay for quick retry
    public static let timeout: TimeInterval = 5.0

    /// Default fallback delay for unspecified scenarios
    public static let `default`: TimeInterval = 10.0
  }

  /// Cache-related configuration constants
  public enum Cache {
    /// Default cache duration for successful responses
    public static let defaultTTL: TimeInterval = 300  // 5 minutes

    /// Maximum cache size in bytes
    public static let maxCacheSize: Int = 50 * 1024 * 1024  // 50MB

    /// Cache cleanup interval
    public static let cleanupInterval: TimeInterval = 3600  // 1 hour
  }

  /// Network timeout configuration
  public enum Timeouts {
    /// Default request timeout
    public static let request: TimeInterval = 30.0

    /// Default resource timeout
    public static let resource: TimeInterval = 60.0

    /// Connection timeout
    public static let connection: TimeInterval = 10.0
  }

  /// Logging configuration
  public enum Logging {
    /// Maximum request body size to log (in bytes)
    public static let maxRequestBodyLogSize: Int = 1024

    /// Maximum response body size to log (in bytes)
    public static let maxResponseBodyLogSize: Int = 2048
  }
}
