import Foundation

/// Mock implementation of TraceExporter for testing distributed tracing functionality.
///
/// Provides state tracking, stubbing, inspection, and verification capabilities for testing
/// trace export behavior without requiring a real backend. Thread-safe via actor isolation.
///
/// ## Usage Example
/// ```swift
/// let mockExporter = MockTraceExporter()
///
/// // Stub behavior
/// mockExporter.stubSuccess()  // Default behavior
/// // or
/// mockExporter.stubFailure(NSError(domain: "test", code: 1))
///
/// // Use in tests
/// let span = TraceSpan(name: "test-operation", context: TraceContext())
/// await span.end()
/// try await mockExporter.export(span)
///
/// // Verify behavior
/// try await mockExporter.verifySpanExported(withName: "test-operation")
/// let spans = await mockExporter.getExportedSpans()
/// ```
public actor MockTraceExporter: TraceExporter, MockVerifiable {
  // MARK: - State Tracking

  /// All exported trace spans
  private var exportedSpans: [TraceSpan] = []

  /// Total number of export calls
  private var exportCallCount: Int = 0

  /// Total number of flush calls
  private var flushCallCount: Int = 0

  /// Error to throw on export (if stubbed to fail)
  private var stubbedError: Error?

  // MARK: - Initialization

  public init() {}

  // MARK: - Stubbing Methods

  /// Stub the exporter to succeed (default behavior)
  public func stubSuccess() {
    stubbedError = nil
  }

  /// Stub the exporter to fail with the specified error
  ///
  /// - Parameter error: The error to throw on export
  public func stubFailure(_ error: Error) {
    stubbedError = error
  }

  // MARK: - TraceExporter Protocol

  public func export(_ span: TraceSpan) async throws {
    exportCallCount += 1

    if let error = stubbedError {
      throw error
    }

    exportedSpans.append(span)
  }

  public func flush() async throws {
    flushCallCount += 1

    if let error = stubbedError {
      throw error
    }
  }

  // MARK: - MockVerifiable Protocol

  /// Total number of calls to export and flush
  nonisolated public var callCount: Int {
    get async {
      await exportCallCount + flushCallCount
    }
  }

  // MARK: - Inspection Methods

  /// Returns all exported spans
  public func getExportedSpans() -> [TraceSpan] {
    exportedSpans
  }

  /// Returns the number of exported spans
  public func getSpanCount() -> Int {
    exportedSpans.count
  }

  /// Returns the number of export calls (including failed ones)
  public func getExportCallCount() -> Int {
    exportCallCount
  }

  /// Returns the number of flush calls
  public func getFlushCallCount() -> Int {
    flushCallCount
  }

  /// Returns spans matching the specified predicate
  ///
  /// - Parameter predicate: Closure that returns true for matching spans
  /// - Returns: Array of spans that match the predicate
  public func getSpansMatching(_ predicate: (TraceSpan) -> Bool) async -> [TraceSpan] {
    exportedSpans.filter(predicate)
  }

  /// Returns spans with the specified name
  ///
  /// - Parameter name: The span name to match
  /// - Returns: Array of spans with matching name
  public func getSpansWithName(_ name: String) -> [TraceSpan] {
    exportedSpans.filter { $0.name == name }
  }

  // MARK: - Verification Methods

  /// Verifies that at least one span with the specified name was exported
  ///
  /// - Parameter name: The expected span name
  /// - Throws: `MockError.unexpectedArgument` if no matching span found
  public func verifySpanExported(withName name: String) throws {
    guard exportedSpans.contains(where: { $0.name == name }) else {
      throw MockError.unexpectedArgument(description: "No span found with name '\(name)'")
    }
  }

  /// Verifies that the exact number of spans was exported
  ///
  /// - Parameter count: Expected number of spans
  /// - Throws: `MockError.unexpectedCallCount` if count doesn't match
  public func verifySpanCount(_ count: Int) throws {
    guard exportedSpans.count == count else {
      throw MockError.unexpectedCallCount(expected: count, actual: exportedSpans.count)
    }
  }

  /// Verifies that no spans were exported
  ///
  /// - Throws: `MockError.unexpectedCallCount` if any spans were exported
  public func verifyNoSpansExported() throws {
    guard exportedSpans.isEmpty else {
      throw MockError.unexpectedCallCount(expected: 0, actual: exportedSpans.count)
    }
  }

  /// Verifies that at least one span matching the predicate was exported
  ///
  /// - Parameter predicate: Closure that returns true for matching spans
  /// - Throws: `MockError.unexpectedArgument` if no matching span found
  public func verifySpanExported(matching predicate: (TraceSpan) async -> Bool) async throws {
    for span in exportedSpans where await predicate(span) {
      return
    }

    throw MockError.unexpectedArgument(description: "No matching span found")
  }

  /// Verifies that flush was called at least once
  ///
  /// - Throws: `MockError.unexpectedCallCount` if flush was never called
  public func verifyFlushed() throws {
    guard flushCallCount > 0 else {
      throw MockError.unexpectedCallCount(expected: 1, actual: flushCallCount)
    }
  }

  // MARK: - Reset

  /// Clears all exported spans and resets call counts
  public func reset() {
    exportedSpans.removeAll()
    exportCallCount = 0
    flushCallCount = 0
    stubbedError = nil
  }
}
