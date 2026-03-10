import NetworkingRuntime
import NetworkingInterceptorsCompat
import NetworkingObservability
import Foundation

#if canImport(OSLog)
import OSLog

/// Mock implementation of MetricsCollector for testing observability functionality.
///
/// Provides state tracking, inspection, and verification capabilities for testing
/// metrics collection without requiring a real backend. Thread-safe via actor isolation.
///
/// ## Usage Example
/// ```swift
/// let mockCollector = MockMetricsCollector()
///
/// // Use in tests
/// await mockCollector.recordEvent(.requestStarted(context))
/// await mockCollector.recordPerformanceMetrics(metrics)
///
/// // Verify behavior
/// let events = await mockCollector.getRecordedEvents()
/// try await mockCollector.verifyEventRecorded { event in
///   if case .requestStarted = event { return true }
///   return false
/// }
/// ```
public actor MockMetricsCollector: MetricsCollector, MockVerifiable {
  // MARK: - State Tracking

  /// All recorded observability events
  private var recordedEvents: [NetworkObservabilityMiddleware.ObservabilityEvent] = []

  /// All recorded performance metrics
  private var recordedMetrics: [NetworkObservabilityMiddleware.PerformanceMetrics] = []

  /// Total number of recordEvent calls
  private var eventCallCount: Int = 0

  /// Total number of recordPerformanceMetrics calls
  private var metricsCallCount: Int = 0

  // MARK: - Initialization

  public init() {}

  // MARK: - MetricsCollector Protocol

  public func recordEvent(_ event: NetworkObservabilityMiddleware.ObservabilityEvent) async {
    recordedEvents.append(event)
    eventCallCount += 1
  }

  public func recordPerformanceMetrics(
    _ metrics: NetworkObservabilityMiddleware.PerformanceMetrics
  ) async {
    recordedMetrics.append(metrics)
    metricsCallCount += 1
  }

  // MARK: - MockVerifiable Protocol

  /// Total number of calls to both recordEvent and recordPerformanceMetrics
  nonisolated public var callCount: Int {
    get async {
      await eventCallCount + metricsCallCount
    }
  }

  // MARK: - Inspection Methods

  /// Returns all recorded observability events
  public func getRecordedEvents() -> [NetworkObservabilityMiddleware.ObservabilityEvent] {
    recordedEvents
  }

  /// Returns the number of recorded events
  public func getEventCount() -> Int {
    recordedEvents.count
  }

  /// Returns all recorded performance metrics
  public func getRecordedMetrics() -> [NetworkObservabilityMiddleware.PerformanceMetrics] {
    recordedMetrics
  }

  /// Returns the number of recorded performance metrics
  public func getMetricsCount() -> Int {
    recordedMetrics.count
  }

  /// Returns events matching the specified predicate
  ///
  /// - Parameter predicate: Closure that returns true for matching events
  /// - Returns: Array of events that match the predicate
  public func getEventsMatching(
    _ predicate: (NetworkObservabilityMiddleware.ObservabilityEvent) -> Bool
  ) -> [NetworkObservabilityMiddleware.ObservabilityEvent] {
    recordedEvents.filter(predicate)
  }

  /// Returns metrics matching the specified predicate
  ///
  /// - Parameter predicate: Closure that returns true for matching metrics
  /// - Returns: Array of metrics that match the predicate
  public func getMetricsMatching(
    _ predicate: (NetworkObservabilityMiddleware.PerformanceMetrics) -> Bool
  ) -> [NetworkObservabilityMiddleware.PerformanceMetrics] {
    recordedMetrics.filter(predicate)
  }

  // MARK: - Verification Methods

  /// Verifies that at least one event matching the predicate was recorded
  ///
  /// - Parameter predicate: Closure that returns true for matching events
  /// - Throws: `MockError.unexpectedArgument` if no matching event found
  public func verifyEventRecorded(
    matching predicate: (NetworkObservabilityMiddleware.ObservabilityEvent) -> Bool
  ) throws {
    guard recordedEvents.contains(where: predicate) else {
      throw MockError.unexpectedArgument(description: "No matching event found")
    }
  }

  /// Verifies that at least one performance metric matching the predicate was recorded
  ///
  /// - Parameter predicate: Closure that returns true for matching metrics
  /// - Throws: `MockError.unexpectedArgument` if no matching metric found
  public func verifyMetricRecorded(
    matching predicate: (NetworkObservabilityMiddleware.PerformanceMetrics) -> Bool
  ) throws {
    guard recordedMetrics.contains(where: predicate) else {
      throw MockError.unexpectedArgument(description: "No matching metric found")
    }
  }

  /// Verifies that no events were recorded
  ///
  /// - Throws: `MockError.unexpectedCallCount` if any events were recorded
  public func verifyNoEventsRecorded() throws {
    guard recordedEvents.isEmpty else {
      throw MockError.unexpectedCallCount(expected: 0, actual: recordedEvents.count)
    }
  }

  /// Verifies that no performance metrics were recorded
  ///
  /// - Throws: `MockError.unexpectedCallCount` if any metrics were recorded
  public func verifyNoMetricsRecorded() throws {
    guard recordedMetrics.isEmpty else {
      throw MockError.unexpectedCallCount(expected: 0, actual: recordedMetrics.count)
    }
  }

  /// Verifies the exact number of recorded events
  ///
  /// - Parameter count: Expected number of events
  /// - Throws: `MockError.unexpectedCallCount` if count doesn't match
  public func verifyEventCount(_ count: Int) throws {
    guard recordedEvents.count == count else {
      throw MockError.unexpectedCallCount(expected: count, actual: recordedEvents.count)
    }
  }

  /// Verifies the exact number of recorded metrics
  ///
  /// - Parameter count: Expected number of metrics
  /// - Throws: `MockError.unexpectedCallCount` if count doesn't match
  public func verifyMetricsCount(_ count: Int) throws {
    guard recordedMetrics.count == count else {
      throw MockError.unexpectedCallCount(expected: count, actual: recordedMetrics.count)
    }
  }

  // MARK: - Reset

  /// Clears all recorded events and metrics
  public func reset() {
    recordedEvents.removeAll()
    recordedMetrics.removeAll()
    eventCallCount = 0
    metricsCallCount = 0
  }
}

#endif  // canImport(OSLog)
