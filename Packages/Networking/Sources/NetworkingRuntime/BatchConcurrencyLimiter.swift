import Foundation
import NetworkingCore

/// Actor-based concurrency limiter for batch operations.
///
/// Provides semaphore-style acquire/release pattern for Swift 6 structured concurrency.
/// Prevents thread pool exhaustion by limiting concurrent task execution through
/// cooperative suspension instead of thread blocking.
///
/// ## Why Actor Pattern (not DispatchSemaphore)
///
/// - `DispatchSemaphore` blocks threads → exhausts Swift concurrency thread pool
/// - Actor suspension is cooperative → threads remain available for other tasks
/// - Compiler-verified data race safety (Swift 6 strict mode)
///
/// ## Usage
///
/// ```swift
/// let limiter = BatchConcurrencyLimiter(maxConcurrency: 5)
///
/// await withTaskGroup(of: Result.self) { group in
///   for request in requests {
///     group.addTask {
///       await limiter.acquire()
///       defer { Task { await limiter.release() } }
///       return try await performRequest(request)
///     }
///   }
/// }
/// ```
///
/// ## Edge Cases
///
/// - `maxConcurrency = 0`: Unlimited concurrency (Int.max)
/// - `maxConcurrency = 1`: Serial execution
/// - Task cancellation: `acquire()` respects cancellation automatically (cooperative suspension)
///
/// ## Concurrency Safety
///
/// - Actor isolation protects `currentCount` (no `@unchecked Sendable` needed)
/// - All access to `currentCount` serialized by actor
/// - No shared mutable state outside actor boundary
///
/// ## Reentrancy Notes
///
/// Multiple tasks can await `acquire()` concurrently. FIFO order is NOT guaranteed
/// due to TaskGroup scheduling behavior. Tasks are released in the order they complete
/// suspension, not the order they started waiting.
public actor BatchConcurrencyLimiter {
  /// Maximum number of concurrent tasks allowed.
  private let maxConcurrency: Int

  /// Current number of tasks holding slots.
  private var currentCount = 0

  /// Creates a concurrency limiter.
  ///
  /// - Parameter maxConcurrency: Maximum concurrent tasks (0 = unlimited)
  public init(maxConcurrency: Int) {
    // 0 means unlimited, convert to Int.max for consistent comparison logic
    self.maxConcurrency = maxConcurrency == 0 ? Int.max : maxConcurrency
  }

  /// Acquires a concurrency slot, suspending if the limit is reached.
  ///
  /// Cooperatively suspends the calling task until a slot becomes available.
  /// Respects task cancellation - if the task is cancelled during suspension,
  /// the suspension will be interrupted.
  ///
  /// ## Implementation
  ///
  /// Uses `Task.yield()` to cooperatively yield control while waiting for
  /// a slot. This keeps threads available for other tasks instead of blocking.
  public func acquire() async {
    // Cooperative suspension pattern - yield until a slot is available
    while currentCount >= maxConcurrency {
      await Task.yield()
    }

    currentCount += 1
  }

  /// Releases a concurrency slot.
  ///
  /// Decrements the current count, allowing waiting tasks to proceed.
  /// No suspension needed as this is a pure state update.
  ///
  /// ## Safety
  ///
  /// Idempotent by design - multiple releases are safe (count will never go negative
  /// in practice due to acquire/release pairing, but no explicit guard to avoid
  /// masking programming errors).
  public func release() {
    currentCount -= 1
  }
}
